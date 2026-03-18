import Testing
@testable import KnotCore

protocol MockService: AnyObject { var name: String { get } }
final class MockServiceImpl: MockService { let name = "mock" }

@Suite("ServiceContainer Tests")
struct ServiceContainerTests {
    @Test func registerAndResolve() {
        let container = ServiceContainer()
        let impl = MockServiceImpl()
        container.register(MockService.self, instance: impl)
        let resolved: MockService? = container.resolve(MockService.self)
        #expect(resolved != nil)
        #expect(resolved?.name == "mock")
    }
    @Test func resolveUnregisteredReturnsNil() {
        let container = ServiceContainer()
        let resolved: MockService? = container.resolve(MockService.self)
        #expect(resolved == nil)
    }
    @Test func sharedInstanceWorks() {
        let impl = MockServiceImpl()
        ServiceContainer.shared.register(MockService.self, instance: impl)
        let resolved: MockService? = ServiceContainer.shared.resolve(MockService.self)
        #expect(resolved?.name == "mock")
    }
}
