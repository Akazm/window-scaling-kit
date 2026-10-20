import AppKit
import Atomics
import AXKit
import IOKit.ps
import Mutex

private typealias Spring = WindowTransitionController.Config.Spring

/// A transition waiting to be folded into its window's target frame.
private struct QueuedTransition: Sendable {
    let window: AXWindow
    let transition: WindowTransition
    /// Produced by key autorepeat rather than a deliberate keystroke.
    let isRepeat: Bool
}

/// How far each edge of a frame moved between two targets.
private struct EdgeDeltas: Sendable {
    let minX: Double
    let minY: Double
    let maxX: Double
    let maxY: Double

    init(from: CGRect, to: CGRect) {
        minX = to.minX - from.minX
        minY = to.minY - from.minY
        maxX = to.maxX - from.maxX
        maxY = to.maxY - from.maxY
    }
}

/// The four edges of a window frame as independently animated values.
///
/// Animating edges rather than origin and size keeps an edge that is not supposed to move exactly still,
/// rounding included: a `resizeLeft` only ever touches `minX`.
private struct SpringFrame: Sendable {
    var minX: SpringValue
    var minY: SpringValue
    var maxX: SpringValue
    var maxY: SpringValue

    init(resting frame: CGRect) {
        minX = .init(value: frame.minX)
        minY = .init(value: frame.minY)
        maxX = .init(value: frame.maxX)
        maxY = .init(value: frame.maxY)
    }

    /// The frame rounded to whole points, which is all a window can show anyway.
    var rounded: CGRect {
        let x = minX.value.rounded()
        let y = minY.value.rounded()
        return CGRect(x: x, y: y, width: maxX.value.rounded() - x, height: maxY.value.rounded() - y)
    }

    mutating func step(_ spring: Spring, toward target: CGRect, dt: TimeInterval) {
        spring.step(&minX, toward: target.minX, dt: dt)
        spring.step(&minY, toward: target.minY, dt: dt)
        spring.step(&maxX, toward: target.maxX, dt: dt)
        spring.step(&maxY, toward: target.maxY, dt: dt)
    }

    func isSettled(_ spring: Spring, at target: CGRect) -> Bool {
        spring.isSettled(minX, at: target.minX)
            && spring.isSettled(minY, at: target.minY)
            && spring.isSettled(maxX, at: target.maxX)
            && spring.isSettled(maxY, at: target.maxY)
    }

    /// Whether every edge has come within `fraction` of its last step of `target`: the window has mostly
    /// arrived and the next step may begin.
    func isWithin(_ fraction: Double, of step: EdgeDeltas, from target: CGRect) -> Bool {
        abs(minX.value - target.minX) <= max(fraction * abs(step.minX), 1)
            && abs(minY.value - target.minY) <= max(fraction * abs(step.minY), 1)
            && abs(maxX.value - target.maxX) <= max(fraction * abs(step.maxX), 1)
            && abs(maxY.value - target.maxY) <= max(fraction * abs(step.maxY), 1)
    }

    /// Aims at `target`, dropping the momentum of any edge now heading away from it. Momentum towards the
    /// target carries over, which is what keeps a run of steps flowing.
    mutating func retarget(to target: CGRect) {
        Self.dropOpposingVelocity(of: &minX, towards: target.minX)
        Self.dropOpposingVelocity(of: &minY, towards: target.minY)
        Self.dropOpposingVelocity(of: &maxX, towards: target.maxX)
        Self.dropOpposingVelocity(of: &maxY, towards: target.maxY)
    }

    private static func dropOpposingVelocity(of state: inout SpringValue, towards target: Double) {
        if (target - state.value) * state.velocity < 0 {
            state.velocity = 0
        }
    }

    /// Moves to `frame` at once, as for a jump to another screen.
    mutating func snap(to frame: CGRect) {
        self = .init(resting: frame)
    }
}

/// Hands frames to the window over the accessibility API and remembers what it last sent.
///
/// Every write is a blocking round trip into the target application, where AppKit applies each one as
/// its own `setFrame` with all screen constraints. The writer therefore sends as little as possible, and
/// in an order whose intermediate states fit within the frame the window leaves and the one it heads to.
private struct FrameWriter: Sendable {
    private let window: AXWindow
    private var lastWritten: CGRect
    /// Whether the window takes a whole frame in one write. Probed on the first write.
    private var writesWholeFrame: Bool?
    /// The application whose enhanced user interface was switched off for the run.
    private var enhancedUserInterface: AnyAXElement?

    @MainActor
    init(window: AXWindow, restingAt frame: CGRect) {
        self.window = window
        lastWritten = frame
        // Keeps a stalled target application from holding up the animation, and this app's main thread,
        // for the 6 second default.
        window.setMessagingTimeout(0.25)
        // With the enhanced user interface on (VoiceOver and some automation tools set it) AppKit animates
        // accessibility driven frame changes itself, which fights the frames sent here.
        if let application = window.application, application.isEnhancedUserInterfaceEnabled() {
            try? application.setAttribute(.enhancedUserInterface, value: kCFBooleanFalse as CFBoolean)
            enhancedUserInterface = application
        }
    }

    @MainActor
    func finish() {
        if let enhancedUserInterface {
            try? enhancedUserInterface.setAttribute(.enhancedUserInterface, value: kCFBooleanTrue as CFBoolean)
        }
    }

    @MainActor
    mutating func write(_ frame: CGRect, isFinal: Bool) {
        defer { lastWritten = frame }
        if writeWholeFrame(frame) {
            return
        }
        if isFinal {
            // The window server clamps a size that does not fit at the window's *current* origin, so the
            // size is written again once the window has moved and reliably lands where it was asked to.
            set(size: frame.size)
            set(position: frame.origin)
            set(size: frame.size)
            return
        }
        switch (frame.size != lastWritten.size, frame.origin != lastWritten.origin) {
            case (false, false):
                return
            case (true, false):
                set(size: frame.size)
            case (false, true):
                set(position: frame.origin)
            case (true, true):
                let shrinks = frame.width <= lastWritten.width && frame.height <= lastWritten.height
                let grows = frame.width >= lastWritten.width && frame.height >= lastWritten.height
                if shrinks {
                    // Never extends past the frame it leaves ...
                    set(size: frame.size)
                    set(position: frame.origin)
                } else if grows {
                    // ... nor past the frame it is headed to.
                    set(position: frame.origin)
                    set(size: frame.size)
                } else {
                    set(size: frame.size)
                    set(position: frame.origin)
                    set(size: frame.size)
                }
        }
    }

    @MainActor
    private func set(size: CGSize) {
        try? window.setAttribute(Attribute.size, value: size)
    }

    @MainActor
    private func set(position: CGPoint) {
        try? window.setAttribute(Attribute.position, value: position)
    }

    /// Writes the frame in one go where the window supports it, which spares the intermediate state of
    /// two separate writes. AppKit windows are expected to decline, so the first attempt is verified.
    @MainActor
    private mutating func writeWholeFrame(_ frame: CGRect) -> Bool {
        switch writesWholeFrame {
            case false:
                return false
            case true:
                return (try? window.setAttribute(Attribute.frame, value: frame)) != nil
            case nil:
                writesWholeFrame = false
                guard (try? window.attributeIsSettable(.frame)) == true,
                      (try? window.setAttribute(Attribute.frame, value: frame)) != nil,
                      let written = try? window.getFrame(),
                      written.isClose(to: frame) else {
                    return false
                }
                writesWholeFrame = true
                return true
        }
    }
}

/// Holds the visible edges of a single frame's worth of transitions.
///
/// `visibleEdges` costs a full window list sweep and a quadratic overlap pass, none of which can change
/// between transitions that arrived within the same frame.
private struct EdgeCache {
    private let activeFrame: CGRect
    private var cache: [UInt8: Set<WindowTransitionBreakpoints.Value>] = [:]

    /// - Parameter activeFrame: Where the window being moved currently is on screen, so that its own
    ///   edges are left out.
    init(excluding activeFrame: CGRect) {
        self.activeFrame = activeFrame
    }

    mutating func edges(of screen: NSScreen, on axis: WindowAxis) -> Set<WindowTransitionBreakpoints.Value> {
        if let cached = cache[axis.rawValue] {
            return cached
        }
        let edges = screen.visibleEdges(on: axis, excluding: activeFrame)
        cache[axis.rawValue] = edges
        return edges
    }
}

private extension CGRect {
    /// Holds any edge that would overshoot `bounds` at that bound, leaving the other edges where they are.
    func clamped(within bounds: CGRect?) -> CGRect {
        guard let bounds else {
            return self
        }
        let minX = max(minX, bounds.minX)
        let minY = max(minY, bounds.minY)
        let maxX = min(maxX, bounds.maxX)
        let maxY = min(maxY, bounds.maxY)
        return CGRect(x: minX, y: minY, width: max(maxX - minX, 0), height: max(maxY - minY, 0))
    }

    func isClose(to other: CGRect, tolerance: CGFloat = 1) -> Bool {
        abs(minX - other.minX) <= tolerance
            && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }
}

/// A controller that manages window transitions and animations on macOS.
///
/// This class provides functionality to transform window positions and sizes with smooth animations
/// and grid-based snapping. It handles various window transitions including moving, resizing, and
/// screen-to-screen movements.
///
/// The controller supports configurable animation behavior, grid tolerance, and context-aware grid
/// snapping. It uses accessibility APIs to manipulate windows and animates them with retargetable
/// springs, the way the system animates windows itself.
public final class WindowTransitionController: Sendable {

    private struct State {
        /// Where the window is headed. Queued transitions resolve against this rather than the window's
        /// live position, so a held key produces consistent steps whatever the animation is doing.
        var targetFrame: CGRect?
        /// The last frame written to the window, i.e. where it visually is.
        var nextTransitionFrame: CGRect?
    }

    /// How close to its current target the window has to be, as a fraction of the last step, before the
    /// next autorepeat step is taken. Low enough that every breakpoint registers on the way, high enough
    /// that momentum carries from one step into the next.
    private static let repeatFoldThreshold = 0.5

    private let state: Mutex<State> = .init(.init())
    private let transitionQueue: Mutex<[QueuedTransition]> = .init([])
    private let isProcessingTransitions = ManagedAtomic<Bool>(false)
    public let config: Config

    public init(config: Config = .default) {
        self.config = config
    }

    /// Cancels scheduled autorepeat transitions.
    ///
    /// Deliberate keystrokes stay queued and a running animation is not interrupted: callers invoke this
    /// on every key up, which usually arrives well before the window has settled, and aborting there
    /// would leave it stranded on an intermediate frame. Dropping the repeats is what makes a held key
    /// stop where the user sees it stop.
    public func cancel() {
        transitionQueue.withLock { queue in
            queue.removeAll(where: \.isRepeat)
        }
    }

    private func clearTransitionState() {
        state.withLock { state in
            state.targetFrame = nil
            state.nextTransitionFrame = nil
        }
    }

    /// Transforms the given window according to the provided transition instruction.
    ///
    /// This method handles all types of window transitions including:
    /// - Moving windows (left, right, up, down)
    /// - Resizing windows (from any edge)
    /// - Moving windows between screens
    /// - Grid-based snapping
    ///
    /// The transformation respects the controller's configuration settings for animations
    /// and grid snapping.
    ///
    /// Transitions arriving while an animation is already running do not queue up behind it. A deliberate
    /// keystroke is folded into the pending target frame right away and the running animation re-aimed,
    /// momentum included. Autorepeat transitions are taken one at a time, each once the window has mostly
    /// reached the previous one, so that a held key walks the window visibly from breakpoint to breakpoint
    /// and ``cancel()`` on key up stops it within a step of where it is.
    ///
    /// - Parameter window: The window with the frame to transition
    /// - Parameter transition: The transition instruction to apply to the window
    /// - Parameter isRepeat: Whether the transition stems from key autorepeat rather than a keystroke
    public func transformRect(
        ofWindow window: AXWindow, withTransition transition: WindowTransition, isRepeat: Bool = false
    ) {
        transitionQueue.withLock { queue in
            queue.append(.init(window: window, transition: transition, isRepeat: isRepeat))
        }
        // Claim the animator before spawning it. Claiming inside the task lets two callers both observe
        // `false` and drive the same window at once.
        guard isProcessingTransitions.compareExchange(
            expected: false,
            desired: true,
            ordering: .acquiringAndReleasing
        ).exchanged else {
            // An animator is already running and picks this transition up on its next frame.
            return
        }
        Task { [weak self] in
            await self?.drainTransitions()
        }
    }
}

private extension WindowTransitionController {

    /// What folding the queue into the target frame produced.
    enum Fold {
        /// The target moved. `origin` is where the window visually is; `snaps` when it is to jump rather
        /// than glide, as between screens.
        case moved(origin: CGRect, target: CGRect, snaps: Bool)
        /// Nothing foldable was queued, or what was queued does not move the window.
        case nothing
        /// The next queued transition belongs to another window: this run is over.
        case otherWindow
    }

    /// Takes what may be folded now: every leading deliberate transition, or a single autorepeat step
    /// when `allowRepeat`. Returns `nil` when the queue's head belongs to another window.
    func takeFoldable(for window: AXWindow, allowRepeat: Bool) -> [QueuedTransition]? {
        transitionQueue.withLock { queue in
            var taken: [QueuedTransition] = []
            while let head = queue.first, head.window == window {
                if head.isRepeat {
                    // One autorepeat step per fold, so that every breakpoint registers.
                    guard allowRepeat, taken.isEmpty else {
                        break
                    }
                    taken.append(queue.removeFirst())
                    break
                }
                taken.append(queue.removeFirst())
            }
            if taken.isEmpty, let head = queue.first, head.window != window {
                return nil
            }
            return taken
        }
    }

    func fold(for window: AXWindow, allowRepeat: Bool) -> Fold {
        guard let taken = takeFoldable(for: window, allowRepeat: allowRepeat) else {
            return .otherWindow
        }
        guard !taken.isEmpty else {
            return .nothing
        }
        // The user is holding a key if a repeat came in, or if more than one transition landed within a
        // single frame.
        let isConsecutive = taken.count > 1 || taken.contains(where: \.isRepeat)
        guard let moved = applyPendingTransitions(
            taken.map(\.transition),
            ofWindow: window,
            isConsecutive: isConsecutive
        ) else {
            return .nothing
        }
        let snaps = taken.contains { queued in
            if case .moveToScreen = queued.transition {
                return true
            }
            return false
        }
        return .moved(origin: moved.origin, target: moved.target, snaps: snaps)
    }

    /// Runs the queue window by window until it stays empty, then hands the claim back.
    nonisolated func drainTransitions() async {
        // Evaluated once per run: `evaluateSpring` reads the power source, which is far too expensive to
        // repeat for every transition of a key hold.
        let spring = config.disableAnimations.evaluateSpring()
        while true {
            if !Task.isCancelled, let window = transitionQueue.withLock({ $0.first?.window }) {
                if let spring {
                    await animate(window, with: spring)
                } else {
                    await apply(toWindow: window)
                }
                // The resolved target is dropped once the run is over, so that the next one starts from
                // the window's own frame in case it was moved by other means meanwhile.
                clearTransitionState()
                continue
            }
            isProcessingTransitions.store(false, ordering: .releasing)
            // A transition enqueued between the check above and the claim being released would otherwise
            // never be processed: its producer saw the animator as still running.
            guard !Task.isCancelled,
                  !transitionQueue.withLock({ $0.isEmpty }),
                  isProcessingTransitions.compareExchange(
                      expected: false,
                      desired: true,
                      ordering: .acquiringAndReleasing
                  ).exchanged else {
                return
            }
        }
    }

    /// Drives one continuously retargeted spring animation, paced by the refresh of the window's screen.
    nonisolated func animate(_ window: AXWindow, with spring: Spring) async {
        // Resolve the first target before the display link is set up. Its setup then overlaps with the
        // accessibility work instead of adding to the latency in front of the first frame.
        guard case let .moved(origin, firstTarget, snaps) = fold(for: window, allowRepeat: true) else {
            return
        }
        var target = firstTarget
        var frame = SpringFrame(resting: origin)
        var lastStep = EdgeDeltas(from: origin, to: target)
        if snaps {
            frame.snap(to: target)
        }
        var bounds = Self.visibleBounds(around: target)
        var writer = await MainActor.run { FrameWriter(window: window, restingAt: origin) }
        var lastTimestamp = CACurrentMediaTime()
        var isSettled = false
        let ticks = await MainActor.run { DisplayLink.ticks(on: NSScreen.screenContaining(rect: target)) }
        frames: for await timestamp in ticks {
            if Task.isCancelled {
                break
            }
            // The next autorepeat step is taken once the window has mostly arrived at the current one, so
            // every breakpoint registers while momentum carries from step to step.
            let mayStep = frame.isWithin(Self.repeatFoldThreshold, of: lastStep, from: target)
            switch fold(for: window, allowRepeat: mayStep) {
                case let .moved(_, next, snaps):
                    lastStep = EdgeDeltas(from: target, to: next)
                    if snaps {
                        frame.snap(to: next)
                    } else {
                        frame.retarget(to: next)
                    }
                    target = next
                    bounds = Self.visibleBounds(around: target)
                    isSettled = false
                case .otherWindow:
                    break frames
                case .nothing where isSettled:
                    break frames
                case .nothing:
                    break
            }
            // The timestamp is the upcoming frame's presentation time; frames are computed for when they
            // are seen. A stalled target application gets a short catch-up rather than a teleport.
            let dt = min(max(timestamp - lastTimestamp, 0), 0.1)
            lastTimestamp = timestamp
            frame.step(spring, toward: target, dt: dt)
            isSettled = frame.isSettled(spring, at: target)
            let next = isSettled ? target : frame.rounded.clamped(within: bounds)
            state.withLock { $0.nextTransitionFrame = next }
            writer = await MainActor.run { [writer, next, isSettled] in
                var writer = writer
                writer.write(next, isFinal: isSettled)
                return writer
            }
        }
        if !isSettled {
            // The display link failed to start or the run was cut short: the window still has to end up
            // where it was asked to go.
            state.withLock { $0.nextTransitionFrame = target }
            writer = await MainActor.run { [writer, target] in
                var writer = writer
                writer.write(target, isFinal: true)
                return writer
            }
        }
        await MainActor.run { [writer] in writer.finish() }
    }

    /// The `disableAnimations` path: every step lands at once.
    nonisolated func apply(toWindow window: AXWindow) async {
        var writer: FrameWriter?
        while !Task.isCancelled, case let .moved(origin, target, _) = fold(for: window, allowRepeat: true) {
            if writer == nil {
                writer = await MainActor.run { FrameWriter(window: window, restingAt: origin) }
            }
            guard let current = writer else {
                return
            }
            state.withLock { $0.nextTransitionFrame = target }
            writer = await MainActor.run { [current, target] in
                var current = current
                current.write(target, isFinal: true)
                return current
            }
        }
        if let writer {
            await MainActor.run { [writer] in writer.finish() }
        }
    }

    /// The visible area of the screen holding `frame`, in accessibility coordinates, as far as `frame`
    /// itself fits into it. Intermediate frames are held within it so that a spring overshooting into a
    /// screen edge does not get pushed around by AppKit's own constraints for a frame or two.
    static func visibleBounds(around frame: CGRect) -> CGRect? {
        guard let screen = NSScreen.screenContaining(rect: frame),
              let primaryHeight = NSScreen.primary?.frame.height else {
            return nil
        }
        let visible = screen.visibleFrame
        let bounds = CGRect(
            x: visible.minX,
            y: primaryHeight - visible.maxY,
            width: visible.width,
            height: visible.height
        )
        return bounds.insetBy(dx: -1, dy: -1).contains(frame) ? bounds : nil
    }

    /// Folds every transition that arrived since the last frame into the pending target.
    ///
    /// - Returns: The frame the window is visually at and the frame it is to head to, or `nil` when
    ///   nothing moved.
    nonisolated func applyPendingTransitions(
        _ pending: [WindowTransition], ofWindow window: AXWindow, isConsecutive: Bool
    ) -> (origin: CGRect, target: CGRect)? {
        let (pendingTarget, visualFrame) = state.withLock { ($0.targetFrame, $0.nextTransitionFrame) }
        // Read the window outside the lock: `getFrame` is a blocking cross process call.
        guard let initialFrame = pendingTarget ?? (try? window.getFrame()) else {
            return nil
        }
        // Only the first transition of a run has to work out which screen the window is on. From then on
        // the pending target identifies it for free, which also keeps `.moveToScreen` chaining correct.
        guard var screen = NSScreen.screenContaining(rect: initialFrame) else {
            return nil
        }
        let origin = visualFrame ?? initialFrame
        let useContextAwareGrid = switch config.enableContextAwareGrid {
            case .disabled:
                false
            case .enabled:
                true
            case .whenNonConsecutive:
                !isConsecutive
        }
        var edgeCache = EdgeCache(excluding: origin)
        var target = initialFrame
        for transition in pending {
            let instruction = useContextAwareGrid
                ? contextAware(transition, on: screen, edges: &edgeCache)
                : transition
            guard let next = instruction.rect(onScreen: screen, from: target), next != target else {
                continue
            }
            target = next
            if case .moveToScreen = transition, let landed = NSScreen.screenContaining(rect: target) {
                screen = landed
                edgeCache = .init(excluding: origin)
            }
        }
        guard target != initialFrame else {
            return nil
        }
        state.withLock { $0.targetFrame = target }
        return (origin: origin, target: target)
    }

    /// Merges the edges of other visible windows into the transition's own breakpoints.
    nonisolated func contextAware(
        _ transition: WindowTransition, on screen: NSScreen, edges: inout EdgeCache
    ) -> WindowTransition {
        guard let axis = transition.contextAwareAxis else {
            return transition
        }
        return transition.with(
            breakpoints: transition.breakpoints
                .merge(with: edges.edges(of: screen, on: axis))
                .with(tolerance: Proportion.percentual(config.gridTolerance))
        )
    }
}

private extension WindowTransition {

    /// The axis whose neighbouring window edges this transition is able to snap to, if any.
    var contextAwareAxis: WindowAxis? {
        switch self {
            case .moveLeft, .moveRight, .resizeLeft, .resizeRight:
                .horizontal
            case .moveUp, .moveDown, .resizeTop, .resizeBottom:
                .vertical
            default:
                nil
        }
    }

    /// The same transition, carrying a different set of breakpoints.
    func with(breakpoints: WindowTransitionBreakpoints) -> WindowTransition {
        switch self {
            case .moveLeft:
                .moveLeft(breakpoints)
            case .moveRight:
                .moveRight(breakpoints)
            case .moveUp:
                .moveUp(breakpoints)
            case .moveDown:
                .moveDown(breakpoints)
            case let .resizeLeft(behavior, _):
                .resizeLeft(behavior, breakpoints)
            case let .resizeRight(behavior, _):
                .resizeRight(behavior, breakpoints)
            case let .resizeTop(behavior, _):
                .resizeTop(behavior, breakpoints)
            case let .resizeBottom(behavior, _):
                .resizeBottom(behavior, breakpoints)
            default:
                self
        }
    }
}
