import Foundation
import NetworkExtension
import SystemExtensions
import KnotCore
import TunnelServices

final class macOSTunnelService: NSObject, TunnelServiceProtocol {

    let state = TunnelServiceState()
    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    /// Bundle ID of the system extension (macOS PacketTunnel)
    private let extensionBundleID = "Lojii.NIO1901.SystemExtension-macOS"

    override init() {
        super.init()
        Task { await loadManager() }
    }

    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Manager Loading

    @MainActor
    private func loadManager() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            self.manager = managers.first ?? NETunnelProviderManager()
            observeVPNStatus()
            updateStatus()
        } catch {
            state.status = .error(error.localizedDescription)
        }
    }

    private func observeVPNStatus() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatus()
        }
    }

    @MainActor
    private func updateStatus() {
        guard let connection = manager?.connection else {
            state.status = .disconnected
            return
        }
        switch connection.status {
        case .invalid:       state.status = .invalid
        case .disconnected:  state.status = .disconnected
        case .connecting:    state.status = .connecting
        case .connected:     state.status = .connected(since: connection.connectedDate ?? Date())
        case .reasserting:   state.status = .reasserting
        case .disconnecting: state.status = .disconnecting
        @unknown default:    state.status = .disconnected
        }
    }

    // MARK: - TunnelServiceProtocol

    func startCapture(config: CaptureConfig) async throws {
        guard let manager = manager else { throw TunnelError.notReady }
        try await configureAndSave(manager: manager, config: config)
        try manager.connection.startVPNTunnel()
    }

    func stopCapture() async throws {
        manager?.connection.stopVPNTunnel()
    }

    func installExtension() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let request = OSSystemExtensionRequest.activationRequest(
                forExtensionWithIdentifier: extensionBundleID,
                queue: .main
            )
            let delegate = ExtensionRequestDelegate(continuation: continuation)
            // Keep delegate alive for the duration of the request
            request.delegate = delegate
            OSSystemExtensionManager.shared.submitRequest(request)
            // Store delegate reference so ARC doesn't collect it
            objc_setAssociatedObject(request, &AssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    func uninstallExtension() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let request = OSSystemExtensionRequest.deactivationRequest(
                forExtensionWithIdentifier: extensionBundleID,
                queue: .main
            )
            let delegate = ExtensionRequestDelegate(continuation: continuation)
            request.delegate = delegate
            OSSystemExtensionManager.shared.submitRequest(request)
            objc_setAssociatedObject(request, &AssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    // MARK: - Private

    private func configureAndSave(manager: NETunnelProviderManager, config: CaptureConfig) async throws {
        try await manager.loadFromPreferences()

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = extensionBundleID
        proto.serverAddress = ProxyConfig.LocalProxy.endpoint
        proto.providerConfiguration = [
            "localPort": config.localPort,
            "wifiPort": config.wifiPort,
            "localEnabled": config.localEnabled,
            "wifiEnabled": config.wifiEnabled,
        ]

        manager.protocolConfiguration = proto
        manager.localizedDescription = "Knot"
        manager.isEnabled = true
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
    }
}

// MARK: - Extension Request Delegate

private enum AssociatedKeys {
    static var delegate = "ExtensionRequestDelegate"
}

private final class ExtensionRequestDelegate: NSObject, OSSystemExtensionRequestDelegate {

    private let continuation: CheckedContinuation<Void, Error>

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        return .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        // User must approve in System Settings → Privacy & Security
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        continuation.resume()
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        continuation.resume(throwing: error)
    }
}
