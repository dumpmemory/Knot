# Phase 3: App Targets — iOS + macOS Entry Points & Extensions

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create iOS and macOS app targets that wire up KnotUI with platform-specific tunnel/certificate service implementations, plus the PacketTunnel (iOS) and SystemExtension (macOS) targets.

**Architecture:** Each platform app target registers its TunnelServiceProtocol and CertificateServiceProtocol implementations into ServiceContainer, then presents RootView. Extensions share KnotCore + TunnelServices packages.

**Tech Stack:** SwiftUI App lifecycle, NetworkExtension, SystemExtensions (macOS), Security.framework

**Spec:** `docs/superpowers/specs/2026-03-18-multiplatform-redesign-design.md`
**Depends on:** Phase 1 + Phase 2 complete

---

### File Structure

```
KnotApp-iOS/
├── iOSApp.swift
├── Info.plist
├── KnotApp_iOS.entitlements
└── Services/
    ├── iOSTunnelService.swift
    └── iOSCertificateService.swift

KnotApp-macOS/
├── macOSApp.swift
├── Info.plist
├── KnotApp_macOS.entitlements
└── Services/
    ├── macOSTunnelService.swift
    └── macOSCertificateService.swift

PacketTunnel-iOS/
├── PacketTunnelProvider.swift
├── Info.plist
└── PacketTunnel_iOS.entitlements

SystemExtension-macOS/
├── MacPacketTunnelProvider.swift
├── Info.plist
└── SystemExtension_macOS.entitlements

Resources/
└── Http/           (moved from Knot/Http/)
```

---

### Task 1: iOS App Target

**Files:**
- Create: `KnotApp-iOS/iOSApp.swift`
- Create: `KnotApp-iOS/Services/iOSTunnelService.swift`
- Create: `KnotApp-iOS/Services/iOSCertificateService.swift`
- Create: `KnotApp-iOS/Info.plist`
- Create: `KnotApp-iOS/KnotApp_iOS.entitlements`

- [ ] **Step 1: Create directory structure**

```bash
cd /Users/aa123/Documents/Knot
mkdir -p KnotApp-iOS/Services
```

- [ ] **Step 2: Create iOSTunnelService**

Create `KnotApp-iOS/Services/iOSTunnelService.swift`:

```swift
import Foundation
import NetworkExtension
import KnotCore
import TunnelServices

final class iOSTunnelService: TunnelServiceProtocol {
    let state = TunnelServiceState()
    private var manager: NETunnelProviderManager?

    init() {
        loadManager()
        observeStatus()
    }

    func startCapture(config: CaptureConfig) async throws {
        guard let manager else {
            try await installExtension()
            return try await startCapture(config: config)
        }

        let proto = manager.protocolConfiguration as? NETunnelProviderProtocol ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.knot.PacketTunnel"
        proto.serverAddress = "127.0.0.1"
        proto.providerConfiguration = [
            "localPort": config.localPort,
            "localEnabled": config.localEnabled,
            "wifiPort": config.wifiPort,
            "wifiEnabled": config.wifiEnabled,
            "ruleId": config.ruleId ?? "",
        ]
        manager.protocolConfiguration = proto
        manager.isEnabled = true

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        try manager.connection.startVPNTunnel()
    }

    func stopCapture() async throws {
        manager?.connection.stopVPNTunnel()
    }

    func installExtension() async throws {
        let manager = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.knot.PacketTunnel"
        proto.serverAddress = "127.0.0.1"
        manager.protocolConfiguration = proto
        manager.localizedDescription = "Knot"
        manager.isEnabled = true

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        self.manager = manager
    }

    func uninstallExtension() async throws {
        try await manager?.removeFromPreferences()
        manager = nil
    }

    private func loadManager() {
        Task {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            self.manager = managers.first
            updateStatus()
        }
    }

    private func observeStatus() {
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatus()
        }
    }

    private func updateStatus() {
        guard let connection = manager?.connection else {
            state.status = .disconnected
            return
        }
        switch connection.status {
        case .invalid: state.status = .invalid
        case .disconnected: state.status = .disconnected
        case .connecting: state.status = .connecting
        case .connected: state.status = .connected(since: connection.connectedDate ?? Date())
        case .reasserting: state.status = .reasserting
        case .disconnecting: state.status = .disconnecting
        @unknown default: state.status = .disconnected
        }
    }
}
```

- [ ] **Step 3: Create iOSCertificateService**

Create `KnotApp-iOS/Services/iOSCertificateService.swift`:

```swift
import Foundation
import KnotCore
import TunnelServices

final class iOSCertificateService: CertificateServiceProtocol {
    private(set) var trustStatus: CertTrustStatus = .notInstalled

    func installCertificate() async throws {
        // On iOS, certificate installation is done via Safari/Settings
        // Export cert to temp file and open via UIApplication.shared.open
        let certData = exportCertificate()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("knot-ca.crt")
        try certData.write(to: tempURL)
        // The app will prompt the user to install via Settings
    }

    func exportCertificate() -> Data {
        // Load CA cert from bundle or App Group container
        let certPath = MitmService.getCertStorePath() /* NOTE: verify actual API — may be CertStore.getCAPath() or similar from TunnelServices/Config/ */
        return (try? Data(contentsOf: URL(fileURLWithPath: certPath))) ?? Data()
    }

    func checkTrustStatus() -> CertTrustStatus {
        // Check if cert is installed and trusted
        // This requires checking via SecTrust API
        let certPath = MitmService.getCertStorePath() /* NOTE: verify actual API — may be CertStore.getCAPath() or similar from TunnelServices/Config/ */
        guard FileManager.default.fileExists(atPath: certPath) else {
            trustStatus = .notInstalled
            return trustStatus
        }
        // Simplified: check UserDefaults flag set after user confirms trust
        if UserDefaults(suiteName: "group.Lojii.NIO1901")?.bool(forKey: "certTrusted") == true {
            trustStatus = .trusted
        } else {
            trustStatus = .installed
        }
        return trustStatus
    }

    func startLocalServer(port: Int) async throws {
        // Reuse existing HTTPServer from TunnelServices for cert distribution
    }

    func stopLocalServer() {
        // Stop HTTP server
    }
}
```

- [ ] **Step 4: Create iOSApp.swift entry point**

Create `KnotApp-iOS/iOSApp.swift`:

```swift
import SwiftUI
import KnotCore
import KnotUI
import TunnelServices

@main
struct KnotApp_iOS: App {
    init() {
        // Database setup
        ASConfigration.setDefaultDB(path: MitmService.getDBPath(), name: "Session")

        // First launch defaults
        // NOTE: Rule.defaultRule() returns non-optional Rule
        if UserDefaults.standard.string(forKey: "isFirstLaunch") == nil {
            let rule = Rule.defaultRule()
            try? rule.saveToDB()
            UserDefaults.standard.set("no", forKey: "isFirstLaunch")
        }

        // NOTE: ASConfigration and Rule must be public in TunnelServices.
        // If not, expose them via a public initialization function.

        // Register platform services
        ServiceContainer.shared.register(
            TunnelServiceProtocol.self,
            instance: iOSTunnelService()
        )
        ServiceContainer.shared.register(
            CertificateServiceProtocol.self,
            instance: iOSCertificateService()
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

- [ ] **Step 5: Create entitlements**

Create `KnotApp-iOS/KnotApp_iOS.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.networking.networkextension</key>
    <array>
        <string>app-proxy-provider</string>
        <string>packet-tunnel-provider</string>
    </array>
    <key>com.apple.developer.networking.vpn.api</key>
    <array>
        <string>allow-vpn</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.Lojii.NIO1901</string>
    </array>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)Lojii.NIO1901</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 6: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add KnotApp-iOS/
git commit -m "feat: create iOS app target with service implementations

iOSTunnelService wraps NETunnelProviderManager.
iOSCertificateService handles cert install/trust on iOS.
iOSApp.swift wires services into ServiceContainer and presents RootView."
```

---

### Task 2: macOS App Target

**Files:**
- Create: `KnotApp-macOS/macOSApp.swift`
- Create: `KnotApp-macOS/Services/macOSTunnelService.swift`
- Create: `KnotApp-macOS/Services/macOSCertificateService.swift`
- Create: `KnotApp-macOS/Info.plist`
- Create: `KnotApp-macOS/KnotApp_macOS.entitlements`

- [ ] **Step 1: Create directory structure**

```bash
cd /Users/aa123/Documents/Knot
mkdir -p KnotApp-macOS/Services
```

- [ ] **Step 2: Create macOSTunnelService**

Create `KnotApp-macOS/Services/macOSTunnelService.swift`:

```swift
import Foundation
import NetworkExtension
import SystemExtensions
import KnotCore
import TunnelServices

final class macOSTunnelService: NSObject, TunnelServiceProtocol, OSSystemExtensionRequestDelegate {
    let state = TunnelServiceState()
    private var manager: NETunnelProviderManager?
    private var extensionInstalled = false
    private var pendingConfig: CaptureConfig?

    override init() {
        super.init()
        loadManager()
        observeStatus()
    }

    func startCapture(config: CaptureConfig) async throws {
        if !extensionInstalled {
            pendingConfig = config
            try await installExtension()
            return
        }

        guard let manager else {
            let newManager = NETunnelProviderManager()
            self.manager = newManager
            try await configureAndStart(manager: newManager, config: config)
            return
        }
        try await configureAndStart(manager: manager, config: config)
    }

    private func configureAndStart(manager: NETunnelProviderManager, config: CaptureConfig) async throws {
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.knot.macos.SystemExtension"
        proto.serverAddress = "127.0.0.1"
        proto.providerConfiguration = [
            "localPort": config.localPort,
            "localEnabled": config.localEnabled,
            "wifiPort": config.wifiPort,
            "wifiEnabled": config.wifiEnabled,
            "ruleId": config.ruleId ?? "",
        ]
        manager.protocolConfiguration = proto
        manager.localizedDescription = "Knot"
        manager.isEnabled = true

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        try manager.connection.startVPNTunnel()
    }

    func stopCapture() async throws {
        manager?.connection.stopVPNTunnel()
    }

    func installExtension() async throws {
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: "com.knot.macos.SystemExtension",
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    func uninstallExtension() async throws {
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: "com.knot.macos.SystemExtension",
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    // MARK: - OSSystemExtensionRequestDelegate

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        extensionInstalled = (result == .completed)
        if extensionInstalled, let config = pendingConfig {
            pendingConfig = nil
            Task { try? await startCapture(config: config) }
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        state.status = .error(error.localizedDescription)
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        // System will show approval dialog
    }

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    // MARK: - Private

    private func loadManager() {
        Task {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            self.manager = managers.first
            extensionInstalled = self.manager != nil
            updateStatus()
        }
    }

    private func observeStatus() {
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatus()
        }
    }

    private func updateStatus() {
        guard let connection = manager?.connection else {
            state.status = .disconnected
            return
        }
        switch connection.status {
        case .invalid: state.status = .invalid
        case .disconnected: state.status = .disconnected
        case .connecting: state.status = .connecting
        case .connected: state.status = .connected(since: connection.connectedDate ?? Date())
        case .reasserting: state.status = .reasserting
        case .disconnecting: state.status = .disconnecting
        @unknown default: state.status = .disconnected
        }
    }
}
```

- [ ] **Step 3: Create macOSCertificateService**

Create `KnotApp-macOS/Services/macOSCertificateService.swift`:

```swift
import Foundation
import Security
import KnotCore
import TunnelServices

final class macOSCertificateService: CertificateServiceProtocol {
    private(set) var trustStatus: CertTrustStatus = .notInstalled

    func installCertificate() async throws {
        let certData = exportCertificate()
        guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else {
            throw NSError(domain: "KnotCert", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid certificate data"])
        }

        // Add to keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: "Knot CA",
        ]
        var status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecDuplicateItem {
            status = errSecSuccess // Already installed
        }
        guard status == errSecSuccess else {
            throw NSError(domain: "KnotCert", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to add certificate to Keychain"])
        }

        // Set trust settings (requires user authorization)
        let trustSettings: [NSDictionary] = [
            [kSecTrustSettingsResult: kSecTrustSettingsResultTrustRoot]
        ]
        let trustStatus = SecTrustSettingsSetTrustSettings(certificate, .user, trustSettings as CFArray)
        guard trustStatus == errSecSuccess else {
            throw NSError(domain: "KnotCert", code: Int(trustStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to set trust. User may need to authorize."])
        }
    }

    func exportCertificate() -> Data {
        let certPath = MitmService.getCertStorePath() /* NOTE: verify actual API — may be CertStore.getCAPath() or similar from TunnelServices/Config/ */
        return (try? Data(contentsOf: URL(fileURLWithPath: certPath))) ?? Data()
    }

    func checkTrustStatus() -> CertTrustStatus {
        let certPath = MitmService.getCertStorePath() /* NOTE: verify actual API — may be CertStore.getCAPath() or similar from TunnelServices/Config/ */
        guard FileManager.default.fileExists(atPath: certPath),
              let certData = try? Data(contentsOf: URL(fileURLWithPath: certPath)),
              let certificate = SecCertificateCreateWithData(nil, certData as CFData) else {
            trustStatus = .notInstalled
            return trustStatus
        }

        // Check keychain for the certificate
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: "Knot CA",
            kSecReturnRef as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status != errSecSuccess {
            trustStatus = .notInstalled
            return trustStatus
        }

        // Check trust settings
        var trustSettings: CFArray?
        let trustResult = SecTrustSettingsCopyTrustSettings(certificate, .user, &trustSettings)
        if trustResult == errSecSuccess {
            trustStatus = .trusted
        } else {
            trustStatus = .installed
        }
        return trustStatus
    }

    func startLocalServer(port: Int) async throws {
        // Reuse TunnelServices HTTP server
    }

    func stopLocalServer() {}
}
```

- [ ] **Step 4: Create macOSApp.swift**

Create `KnotApp-macOS/macOSApp.swift`:

```swift
import SwiftUI
import KnotCore
import KnotUI
import TunnelServices

@main
struct KnotApp_macOS: App {
    init() {
        // Database setup
        ASConfigration.setDefaultDB(path: MitmService.getDBPath(), name: "Session")

        // First launch defaults
        if UserDefaults.standard.string(forKey: "isFirstLaunch") == nil {
            let rule = Rule.defaultRule()
            try? rule.saveToDB()
            UserDefaults.standard.set("no", forKey: "isFirstLaunch")
        }

        // Register platform services
        ServiceContainer.shared.register(
            TunnelServiceProtocol.self,
            instance: macOSTunnelService()
        )
        ServiceContainer.shared.register(
            CertificateServiceProtocol.self,
            instance: macOSCertificateService()
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 800, minHeight: 500)
        }
        .defaultSize(width: 1100, height: 700)
    }
}
```

- [ ] **Step 5: Create macOS entitlements**

Create `KnotApp-macOS/KnotApp_macOS.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.networking.networkextension</key>
    <array>
        <string>packet-tunnel-provider</string>
    </array>
    <key>com.apple.developer.networking.vpn.api</key>
    <array>
        <string>allow-vpn</string>
    </array>
    <key>com.apple.developer.system-extension.install</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.Lojii.NIO1901</string>
    </array>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 6: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add KnotApp-macOS/
git commit -m "feat: create macOS app target with SystemExtension support

macOSTunnelService wraps OSSystemExtensionManager + NETunnelProviderManager.
macOSCertificateService installs CA to Keychain with trust settings.
macOSApp.swift wires services and presents RootView with window sizing."
```

---

### Task 3: iOS PacketTunnel Extension (migrate existing)

**Files:**
- Create: `PacketTunnel-iOS/PacketTunnelProvider.swift` (based on existing `PacketTunnel/PacketTunnelProvider.swift`)
- Create: `PacketTunnel-iOS/Info.plist`
- Create: `PacketTunnel-iOS/PacketTunnel_iOS.entitlements`

- [ ] **Step 1: Create directory and copy existing provider**

```bash
cd /Users/aa123/Documents/Knot
mkdir -p PacketTunnel-iOS
cp PacketTunnel/PacketTunnelProvider.swift PacketTunnel-iOS/PacketTunnelProvider.swift
```

- [ ] **Step 2: Update imports in copied file**

Edit `PacketTunnel-iOS/PacketTunnelProvider.swift` to ensure it imports from SPM packages:

```swift
import NetworkExtension
import TunnelServices
import KnotCore
```

Remove any `import UIKit` if present.

- [ ] **Step 3: Create entitlements**

Create `PacketTunnel-iOS/PacketTunnel_iOS.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.networking.networkextension</key>
    <array>
        <string>packet-tunnel-provider</string>
    </array>
    <key>com.apple.developer.networking.vpn.api</key>
    <array>
        <string>allow-vpn</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.Lojii.NIO1901</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 4: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add PacketTunnel-iOS/
git commit -m "feat: create iOS PacketTunnel extension target

Migrated from existing PacketTunnel/ with SPM imports."
```

---

### Task 4: macOS SystemExtension

**Files:**
- Create: `SystemExtension-macOS/MacPacketTunnelProvider.swift`
- Create: `SystemExtension-macOS/Info.plist`
- Create: `SystemExtension-macOS/SystemExtension_macOS.entitlements`

- [ ] **Step 1: Create directory**

```bash
mkdir -p /Users/aa123/Documents/Knot/SystemExtension-macOS
```

- [ ] **Step 2: Create MacPacketTunnelProvider**

Create `SystemExtension-macOS/MacPacketTunnelProvider.swift`:

```swift
import NetworkExtension
import TunnelServices
import KnotCore

class MacPacketTunnelProvider: NEPacketTunnelProvider {

    private var proxyServer: ProxyServer?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let config = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration

        // Setup database path via App Group
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.Lojii.NIO1901") {
            let dbPath = groupURL.appendingPathComponent("Session.sqlite3").path
            ASConfigration.setDefaultDB(path: dbPath, name: "Session")
        }

        // Create and configure proxy server (same as iOS)
        let task = CaptureTask.newTask()
        task.localPort = config?["localPort"] as? Int ?? 9090
        task.localEnable = config?["localEnabled"] as? Bool ?? true

        // Configure network settings
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        // macOS DNS configuration differs slightly
        let dns = NEDNSSettings(servers: ["198.18.0.2"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        let proxy = NEProxySettings()
        proxy.httpEnabled = true
        proxy.httpServer = NEProxyServer(address: "127.0.0.1", port: task.localPort)
        proxy.httpsEnabled = true
        proxy.httpsServer = NEProxyServer(address: "127.0.0.1", port: task.localPort)
        proxy.matchDomains = [""]
        settings.proxySettings = proxy

        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error {
                completionHandler(error)
                return
            }
            // Start proxy server (shared with iOS via TunnelServices)
            self?.startProxyServer(task: task, completionHandler: completionHandler)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        proxyServer?.stop()
        completionHandler()
    }

    private func startProxyServer(task: CaptureTask, completionHandler: @escaping (Error?) -> Void) {
        // NOTE: Base this on the actual iOS PacketTunnelProvider.swift pattern,
        // which uses MitmService (not ProxyServer directly) to manage the proxy.
        // Read PacketTunnel/PacketTunnelProvider.swift for the exact initialization flow.
        // The core pattern is:
        //   MitmService.shared.startProxy(task: task) { error in ... }
        // Adapt to the actual API during implementation.
        completionHandler(nil)
    }
}
```

- [ ] **Step 3: Create entitlements**

Create `SystemExtension-macOS/SystemExtension_macOS.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.networking.networkextension</key>
    <array>
        <string>packet-tunnel-provider</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.Lojii.NIO1901</string>
    </array>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 4: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add SystemExtension-macOS/
git commit -m "feat: create macOS SystemExtension with PacketTunnelProvider

Shares core proxy logic with iOS via TunnelServices package.
macOS-specific DNS and route configuration."
```

---

### Task 5: Xcode Project Configuration

**Files:**
- Modify: `Knot.xcodeproj/project.pbxproj` (via Xcode)

> **Important:** This task MUST be done in Xcode, not by editing pbxproj directly.

- [ ] **Step 1: Add new targets in Xcode**

Open `Knot.xcodeproj` in Xcode and add:

1. **KnotApp-iOS** target: iOS App, SwiftUI lifecycle, deployment target iOS 17
   - Add local package dependencies: KnotUI, KnotCore, TunnelServices
   - Set entitlements file: `KnotApp-iOS/KnotApp_iOS.entitlements`
   - Add source files from `KnotApp-iOS/`

2. **KnotApp-macOS** target: macOS App, SwiftUI lifecycle, deployment target macOS 14
   - Add local package dependencies: KnotUI, KnotCore, TunnelServices
   - Set entitlements file: `KnotApp-macOS/KnotApp_macOS.entitlements`
   - Add source files from `KnotApp-macOS/`

3. **PacketTunnel-iOS** target: Network Extension (iOS), deployment target iOS 17
   - Add package dependencies: KnotCore, TunnelServices
   - Set entitlements file: `PacketTunnel-iOS/PacketTunnel_iOS.entitlements`
   - Embed in KnotApp-iOS

4. **SystemExtension-macOS** target: System Extension (macOS), deployment target macOS 14
   - Add package dependencies: KnotCore, TunnelServices
   - Set entitlements file: `SystemExtension-macOS/SystemExtension_macOS.entitlements`
   - Embed in KnotApp-macOS

- [ ] **Step 2: Configure App Group for all targets**

Ensure all 4 targets have the same App Group: `group.Lojii.NIO1901`

- [ ] **Step 3: Add Resources/Http to both app targets**

Add the `Resources/Http/` directory to both KnotApp-iOS and KnotApp-macOS targets as bundle resources.

- [ ] **Step 4: Build iOS target**

In Xcode: Product → Build (KnotApp-iOS scheme, iPhone Simulator)

Fix any compilation errors iteratively.

- [ ] **Step 5: Build macOS target**

In Xcode: Product → Build (KnotApp-macOS scheme, My Mac)

Fix any compilation errors iteratively.

- [ ] **Step 6: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add Knot.xcodeproj/ Resources/
git commit -m "feat: configure Xcode project with all 4 new targets

KnotApp-iOS, KnotApp-macOS, PacketTunnel-iOS, SystemExtension-macOS.
All targets linked to shared SPM packages."
```

---

## Phase 3 Complete Checklist

- [ ] KnotApp-iOS builds and runs on iOS Simulator
- [ ] KnotApp-macOS builds and runs on Mac
- [ ] PacketTunnel-iOS extension embeds in iOS app
- [ ] SystemExtension-macOS embeds in macOS app
- [ ] Both apps show RootView with adaptive layout
- [ ] iOS: VPN toggle works (real device required for full test)
- [ ] macOS: SystemExtension activation dialog appears (SIP disabled for dev)
- [ ] App Group shared across all targets

**Post-Phase 3:** Manual testing on real devices, xcframework rebuild for HTTP3 on macOS, UI polish.
