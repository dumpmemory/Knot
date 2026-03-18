import Foundation

public protocol CertificateServiceProtocol: AnyObject {
    var trustStatus: CertTrustStatus { get }
    func installCertificate() async throws
    func exportCertificate() -> Data
    func checkTrustStatus() -> CertTrustStatus
    func startLocalServer(port: Int) async throws
    func stopLocalServer()
}
