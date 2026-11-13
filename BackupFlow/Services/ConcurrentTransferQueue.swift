import Foundation

/// Runs asynchronous work items with a bounded concurrency window using `withThrowingTaskGroup`.
enum ConcurrentTransferQueue {
    static func run<Item: Sendable, Result: Sendable>(
        items: [Item],
        maxConcurrency: Int,
        isCancelled: () -> Bool = { false },
        operation: @escaping @Sendable (Int, Item) async throws -> Result
    ) async throws -> [Result] {
        guard !items.isEmpty else { return [] }
        let limit = max(1, maxConcurrency)

        if limit == 1 {
            var results: [Result] = []
            results.reserveCapacity(items.count)
            for (index, item) in items.enumerated() {
                if isCancelled() || Task.isCancelled {
                    throw BackupServiceError.cancelled
                }
                results.append(try await operation(index, item))
            }
            return results
        }

        return try await withThrowingTaskGroup(of: (Int, Result).self) { group in
            var results: [Result?] = Array(repeating: nil, count: items.count)
            var nextIndex = 0

            func enqueueNext() throws {
                guard nextIndex < items.count else { return }
                if isCancelled() || Task.isCancelled {
                    throw BackupServiceError.cancelled
                }
                let index = nextIndex
                let item = items[index]
                nextIndex += 1
                group.addTask {
                    let value = try await operation(index, item)
                    return (index, value)
                }
            }

            for _ in 0..<min(limit, items.count) {
                try enqueueNext()
            }

            while let (index, value) = try await group.next() {
                results[index] = value
                try enqueueNext()
            }

            return results.compactMap { $0 }
        }
    }
}
