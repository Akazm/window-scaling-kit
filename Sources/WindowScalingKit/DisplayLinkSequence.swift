import AppKit
import CoreVideo
import Foundation

/// Receives display link callbacks on behalf of ``DisplayLink``.
///
/// `CADisplayLink` requires an Objective-C target/selector pair and keeps a strong reference to it,
/// so the proxy stays alive for as long as the link it was handed to.
private final class DisplayLinkProxy: NSObject {
    private let onTick: @Sendable (CFTimeInterval) -> Void

    init(onTick: @escaping @Sendable (CFTimeInterval) -> Void) {
        self.onTick = onTick
    }

    @available(macOS 14, *)
    @objc func tick(_ link: CADisplayLink) {
        onTick(link.targetTimestamp)
    }
}

/// Wraps a display link handle so it can cross into the `@Sendable` termination closure.
///
/// Both handle types are confined to a single thread by the code below: the `CADisplayLink` is only
/// ever touched on the main thread, the `CVDisplayLink` only by CoreVideo itself.
private final class UncheckedBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

/// A display synchronised tick source used to pace window transition frames.
///
/// Window frames are handed to other applications over the accessibility API, where every write is a
/// blocking cross process round trip. Pacing those writes to the display refresh keeps the cadence even
/// and, more importantly, stops the animation from submitting more work than the target application is
/// able to drain.
enum DisplayLink {

    /// Yields the presentation time of the upcoming frame, once per refresh of `screen`.
    ///
    /// The stream buffers a single element: ticks arriving while the consumer is still busy with the
    /// previous frame are dropped rather than queued, so a slow target application lowers the frame
    /// rate instead of building up a backlog of stale frames. Consumers get the newest tick's timestamp,
    /// which keeps their clock right across dropped frames.
    @MainActor
    static func ticks(on screen: NSScreen?) -> AsyncStream<CFTimeInterval> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            // `NSScreen.main` is the screen holding keyboard focus and is nil for an accessory app
            // without a key window, which is the common host for this library.
            if #available(macOS 14, *), let screen = screen ?? NSScreen.main ?? NSScreen.screens.first {
                start(on: screen, yieldingInto: continuation)
            } else {
                startLegacy(yieldingInto: continuation)
            }
        }
    }

    @available(macOS 14, *)
    @MainActor
    private static func start(on screen: NSScreen, yieldingInto continuation: AsyncStream<CFTimeInterval>.Continuation) {
        let proxy = DisplayLinkProxy { continuation.yield($0) }
        let link = screen.displayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        // Without the hint a ProMotion panel may pace the first frames of a run at 60 Hz.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        // .common keeps frames coming while the user holds a menu or resizes something else.
        link.add(to: .main, forMode: .common)
        let box = UncheckedBox(link)
        continuation.onTermination = { _ in
            // Termination is delivered on whichever thread drops the stream, so hop rather than assume.
            DispatchQueue.main.async { box.value.invalidate() }
        }
    }

    /// `CVDisplayLink` drives its callback on a private, high priority thread, so no run loop of our own
    /// is required. Superseded by `CADisplayLink` above, which additionally tracks variable refresh rates.
    @available(macOS, deprecated: 15, message: "Fallback for macOS < 14, where CADisplayLink is unavailable")
    private static func startLegacy(yieldingInto continuation: AsyncStream<CFTimeInterval>.Continuation) {
        var handle: CVDisplayLink?
        guard CVDisplayLinkCreateWithActiveCGDisplays(&handle) == kCVReturnSuccess, let handle else {
            continuation.finish()
            return
        }
        CVDisplayLinkSetOutputHandler(handle) { _, _, outputTime, _, _ in
            let stamp = outputTime.pointee
            // The host time shares its clock with `CACurrentMediaTime`, which seeds the consumer's clock.
            let isHostTimeValid = stamp.flags & CVTimeStampFlags.hostTimeValid.rawValue != 0
            continuation.yield(
                isHostTimeValid ? Double(stamp.hostTime) / CVGetHostClockFrequency() : CACurrentMediaTime()
            )
            return kCVReturnSuccess
        }
        guard CVDisplayLinkStart(handle) == kCVReturnSuccess else {
            continuation.finish()
            return
        }
        let box = UncheckedBox(handle)
        continuation.onTermination = { _ in
            CVDisplayLinkStop(box.value)
        }
    }

}
