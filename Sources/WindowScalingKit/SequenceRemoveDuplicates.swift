extension Sequence where Element: Hashable {
    func removeDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }

    func removeDuplicates<Key: Hashable>(by keySelector: (Element) -> Key) -> [Element] {
        var seen = Set<Key>()
        return filter { element in
            let key = keySelector(element)
            return seen.insert(key).inserted
        }
    }

    func removeDuplicates<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Element] {
        removeDuplicates { $0[keyPath: keyPath] }
    }
}
