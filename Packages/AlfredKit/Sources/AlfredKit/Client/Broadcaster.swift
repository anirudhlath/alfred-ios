import Foundation

/// Thread-safe multi-consumer broadcast for AsyncStream values.
///
/// Unlike AsyncStream (single-consumer), Broadcaster delivers each
/// yielded value to ALL active subscribers. Subscribers that are
/// terminated are automatically cleaned up.
final class Broadcaster<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<T>.Continuation] = [:]

    /// Create a new subscriber stream. Each call returns an independent
    /// stream that receives all future values yielded to this broadcaster.
    func subscribe() -> AsyncStream<T> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: T.self)
        lock.withLock {
            continuations[id] = continuation
        }
        continuation.onTermination = { [weak self] _ in
            self?.lock.withLock {
                _ = self?.continuations.removeValue(forKey: id)
            }
        }
        return stream
    }

    /// Yield a value to all active subscribers.
    func yield(_ value: T) {
        let conts = lock.withLock { Array(continuations.values) }
        for cont in conts {
            cont.yield(value)
        }
    }
}
