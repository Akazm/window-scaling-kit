import Atomics
import Foundation

extension Timer {
    
    static func scheduledTimerSequence(
        withTimeInterval interval: TimeInterval, repeats: Bool = true
    ) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let thread = Thread {
                let runLoop = RunLoop.current
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
                runLoop.add(Port(), forMode: .default)
                runLoop.run()
            }
            thread.start()
        }
    }
    
}
