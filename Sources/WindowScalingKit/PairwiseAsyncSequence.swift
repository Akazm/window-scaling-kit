struct PairwiseAsyncSequence<Base: AsyncSequence>: AsyncSequence where Base.Element: Equatable {
    typealias Element = (Base.Element, Base.Element)
    typealias AsyncIterator = Iterator

    let base: Base

    struct Iterator: AsyncIteratorProtocol {
        var baseIterator: Base.AsyncIterator
        var previousElement: Base.Element?

        mutating func next() async throws -> Element? {
            while let nextElement = try await baseIterator.next() {
                defer { previousElement = nextElement }
                if let previousElement = previousElement {
                    return (previousElement, nextElement)
                }
            }
            return nil
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        Iterator(baseIterator: base.makeAsyncIterator(), previousElement: nil)
    }
}

extension AsyncSequence where Self.Element: Equatable {
    func pairwise() -> PairwiseAsyncSequence<Self> {
        PairwiseAsyncSequence(base: self)
    }
}
