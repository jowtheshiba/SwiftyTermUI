import Foundation

/// Черга подій для обробки в правильному порядку
public final class EventQueue {
    private var queue: [InputEvent] = []
    private let lock = NSLock()
    private let maxQueueSize = 100
    
    public init() {}
    
    /// Додає подію до черги
    public func enqueue(_ event: InputEvent) {
        lock.lock()
        defer { lock.unlock() }
        
        if queue.count >= maxQueueSize {
            queue.removeFirst()
        }
        
        queue.append(event)
    }
    
    /// Витягує найстарішу подію з черги
    public func dequeue() -> InputEvent? {
        lock.lock()
        defer { lock.unlock() }
        
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }
    
    /// Подивитись наступну подію без видалення
    public func peek() -> InputEvent? {
        lock.lock()
        defer { lock.unlock() }
        
        return queue.first
    }
    
    /// Очищає всю чергу
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        queue.removeAll()
    }
    
    /// Чи черга порожня
    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return queue.isEmpty
    }
    
    /// Кількість подій в черзі
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        
        return queue.count
    }
}
