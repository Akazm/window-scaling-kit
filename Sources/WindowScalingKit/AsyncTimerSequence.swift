import Atomics
import Foundation

extension Timer {
    @MainActor
    static func scheduledTimerSequence(
        withTimeInterval interval: TimeInterval, repeats: Bool = true
    ) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let isTerminated: ManagedAtomic<Bool> = .init(false)
            Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: repeats
            ) { timer in
                if isTerminated.load(ordering: .relaxed) {
                    timer.invalidate()
                    continuation.finish()
                } else {
                    continuation.yield(())
                }
            }
            continuation.onTermination = { @Sendable _ in
                isTerminated.store(true, ordering: .relaxed)
            }
        }
    }
}

public struct AsyncTimerSequence: AsyncSequence, Sendable {
    public typealias Element = Void
    public typealias AsyncIterator = Iterator

    private let interval: TimeInterval
    private let repeats: Bool

    public init(withTimeInterval interval: TimeInterval, repeats: Bool) {
        self.interval = interval
        self.repeats = repeats
    }

    public func makeAsyncIterator() -> AsyncIterator {
        Self.Iterator(withTimeInterval: interval, repeats: repeats)
    }

    public struct Iterator: AsyncIteratorProtocol, Sendable {
        private let interval: TimeInterval
        private let repeats: Bool
        private let didFinish: ManagedAtomic<Bool> = .init(false)

        init(withTimeInterval interval: TimeInterval, repeats: Bool) {
            self.interval = interval
            self.repeats = repeats
        }

        public mutating func next() async throws -> Void? {
            if didFinish.load(ordering: .sequentiallyConsistent) {
                return nil
            }
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            if !repeats {
                didFinish.store(true, ordering: .sequentiallyConsistent)
            }
            return ()
        }
    }
}
