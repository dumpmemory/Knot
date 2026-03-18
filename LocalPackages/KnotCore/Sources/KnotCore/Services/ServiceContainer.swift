import Foundation

public final class ServiceContainer: @unchecked Sendable {
    public static let shared = ServiceContainer()
    private var services: [String: AnyObject] = [:]
    private let lock = NSLock()

    public init() {}

    public func register<T>(_ type: T.Type, instance: AnyObject) {
        let key = String(describing: type)
        lock.lock()
        services[key] = instance
        lock.unlock()
    }

    public func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        lock.lock()
        let service = services[key] as? T
        lock.unlock()
        return service
    }
}
