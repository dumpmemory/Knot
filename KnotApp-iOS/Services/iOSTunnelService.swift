import Foundation
import NetworkExtension
import KnotCore
import TunnelServices

final class iOSTunnelService: TunnelServiceProtocol {

    let state = TunnelServiceState()
    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    init() {
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
            if let existing = managers.first {
                self.manager = existing
            } else {
                self.manager = NETunnelProviderManager()
            }
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
        // iOS: the packet tunnel extension is bundled; no separate install step
    }

    func uninstallExtension() async throws {
        guard let manager = manager else { return }
        try await manager.removeFromPreferences()
    }

    // MARK: - Private

    private func configureAndSave(manager: NETunnelProviderManager, config: CaptureConfig) async throws {
        try await manager.loadFromPreferences()

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "Lojii.NIO1901.PacketTunnel-iOS"
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

enum TunnelError: Error {
    case notReady
}
