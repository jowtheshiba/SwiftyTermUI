import Foundation

/// Event queue for processing in correct order
public final class EventQueue {
    private var queue: [InputEvent] = []
    private let lock = NSLock()
    private let maxQueueSize = 100
    
    public init() {}
    
    /// Adds an event to the queue
    public func enqueue(_ event: InputEvent) {
        lock.lock()
        defer { lock.unlock() }
        
        if queue.count >= maxQueueSize {
            queue.removeFirst()
        }
        
        queue.append(event)
    }
    
    /// Extracts the oldest event from the queue
    public func dequeue() -> InputEvent? {
        lock.lock()
        defer { lock.unlock() }
        
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }
    
    /// Peeks at the next event without removing it
    public func peek() -> InputEvent? {
        lock.lock()
        defer { lock.unlock() }
        
        return queue.first
    }
    
    /// Clears the entire queue
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        queue.removeAll()
    }
    
    /// Whether the queue is empty
    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return queue.isEmpty
    }
    
    /// Number of events in the queue
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        
        return queue.count
    }
}
