import Foundation
import KnotCore
import TunnelServices

/// iOS certificate service.
/// On iOS, installing a root CA requires the user to open the downloaded profile in Settings.
/// Trust status is tracked via a UserDefaults flag that the user sets after trusting in Settings.
final class iOSCertificateService: CertificateServiceProtocol {

    private static let trustedKey = "com.knot.cert.trusted"

    private(set) var trustStatus: CertTrustStatus = .notInstalled
    private var localServer: MitmService?

    init() {
        _ = checkTrustStatus()
    }

    // MARK: - CertificateServiceProtocol

    func installCertificate() async throws {
        // On iOS, export the DER cert to a temp file and open it via UIApplication.
        // The system will prompt "Profile Downloaded" → user installs in Settings → General → VPN & Device Management.
        guard let certURL = MitmService.getCertPath() else {
            throw CertError.certNotFound
        }
        let destURL = FileManager.default.temporaryDirectory.appendingPathComponent("KnotCA.crt")
        let data = try Data(contentsOf: certURL)
        try data.write(to: destURL)

        // Signal install request via notification; the UI layer opens the file.
        await MainActor.run {
            NotificationCenter.default.post(name: .knotInstallCertificate, object: destURL)
        }
    }

    func exportCertificate() -> Data {
        guard let certURL = MitmService.getCertPath(),
              let data = try? Data(contentsOf: certURL) else {
            return Data()
        }
        return data
    }

    @discardableResult
    func checkTrustStatus() -> CertTrustStatus {
        let trusted = UserDefaults.standard.bool(forKey: Self.trustedKey)
        if trusted {
            trustStatus = .trusted
        } else if MitmService.getCertPath() != nil {
            trustStatus = .installed
        } else {
            trustStatus = .notInstalled
        }
        return trustStatus
    }

    func startLocalServer(port: Int) async throws {
        guard let service = MitmService.prepare() else {
            throw CertError.serverStartFailed
        }
        localServer = service
        return try await withCheckedThrowingContinuation { continuation in
            service.openLocalServer(ip: ProxyConfig.LocalProxy.host, port: port) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let e): continuation.resume(throwing: e)
                }
            }
        }
    }

    func stopLocalServer() {
        localServer?.closeLocalServer()
        localServer = nil
    }
}

enum CertError: Error {
    case certNotFound
    case serverStartFailed
}

extension Notification.Name {
    static let knotInstallCertificate = Notification.Name("com.knot.installCertificate")
}
