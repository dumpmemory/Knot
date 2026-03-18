import Testing
@testable import KnotCore

@Suite("TunnelStatus Tests")
struct TunnelStatusTests {
    @Test func disconnectedIsDefault() {
        let status = TunnelStatus.disconnected
        #expect(status == .disconnected)
    }
    @Test func connectedCarriesDate() {
        let date = Date()
        let status = TunnelStatus.connected(since: date)
        if case .connected(let since) = status { #expect(since == date) }
        else { Issue.record("Expected connected") }
    }
    @Test func errorCarriesMessage() {
        let status = TunnelStatus.error("timeout")
        if case .error(let msg) = status { #expect(msg == "timeout") }
        else { Issue.record("Expected error") }
    }
    @Test func equalityWorks() {
        #expect(TunnelStatus.disconnected == TunnelStatus.disconnected)
        #expect(TunnelStatus.connecting != TunnelStatus.disconnected)
    }
}
