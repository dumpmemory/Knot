# Phase 1: Foundation — TunnelServices SPM化 + KnotCore Package

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract TunnelServices into a Swift Package, create KnotCore shared package with models/services/protocols, enabling cross-platform compilation.

**Architecture:** TunnelServices becomes a local SPM package with all 29 `import UIKit` replaced by `import Foundation`. KnotCore is a new package that depends on TunnelServices, exposing data models, database access, service protocols, and a dependency injection container. Both packages must compile for iOS and macOS.

**Tech Stack:** Swift 5.9+, SPM, SQLite (ActiveSQLite), SwiftNIO, Foundation

**Spec:** `docs/superpowers/specs/2026-03-18-multiplatform-redesign-design.md`

---

### File Structure

**TunnelServices Package (convert existing framework to SPM):**
- Create: `LocalPackages/TunnelServices/Package.swift`
- Move: All files from `TunnelServices/` → `LocalPackages/TunnelServices/Sources/TunnelServices/`
- Modify: 29 files — replace `import UIKit` with `import Foundation`

**KnotCore Package (new):**
- Create: `LocalPackages/KnotCore/Package.swift`
- Create: `LocalPackages/KnotCore/Sources/KnotCore/Services/TunnelServiceProtocol.swift`
- Create: `LocalPackages/KnotCore/Sources/KnotCore/Services/CertificateServiceProtocol.swift`
- Create: `LocalPackages/KnotCore/Sources/KnotCore/Services/ServiceContainer.swift`
- Create: `LocalPackages/KnotCore/Sources/KnotCore/Services/ExportService.swift`
- Create: `LocalPackages/KnotCore/Sources/KnotCore/Models/TunnelStatus.swift`
- Create: `LocalPackages/KnotCore/Sources/KnotCore/Models/CertTrustStatus.swift`
- Create: `LocalPackages/KnotCore/Tests/KnotCoreTests/ServiceContainerTests.swift`
- Create: `LocalPackages/KnotCore/Tests/KnotCoreTests/TunnelStatusTests.swift`

---

### Task 1: TunnelServices — Replace UIKit imports

**Files:**
- Modify: 29 files in `TunnelServices/` (listed below)

All files use `import UIKit` at line 9 but **no actual UIKit types are used** — they only need `Foundation` (which provides `NSObject`, `NSNumber`, `Data`, etc. on all Apple platforms).

> **Note:** The exact file count may vary. Use `grep -rl "import UIKit" TunnelServices/` to get the definitive list. The list below covers known files — verify against grep output and add any missing ones (e.g. `HTTPHandler.swift`).

- [ ] **Step 1: Replace all UIKit imports**

Replace `import UIKit` with `import Foundation` in all matching files. Known files:

```
TunnelServices/MitmService.swift
TunnelServices/Session.swift
TunnelServices/CaptureTask.swift
TunnelServices/Rule/Rule.swift
TunnelServices/Rule/RuleItem.swift
TunnelServices/Rule/TypeItem.swift
TunnelServices/Rule/HostItem.swift
TunnelServices/Rule/GeneralItem.swift
TunnelServices/Rule/OtherItem.swift
TunnelServices/HttpService/HTTPServer.swift
TunnelServices/HttpService/SSLServer.swift
TunnelServices/HttpService/HTTPServerHandler.swift
TunnelServices/Detector/ProtocolDetector.swift
TunnelServices/Detector/HttpMatcher.swift
TunnelServices/Detector/HttpsMatcher.swift
TunnelServices/Detector/SSLMatcher.swift
TunnelServices/Detector/ProtocolMatcher.swift
TunnelServices/Utils/Date+Extension.swift
TunnelServices/Utils/String+Extension.swift
TunnelServices/Utils/NetAddress.swift
TunnelServices/Utils/ProxyContext.swift
TunnelServices/Utils/Extension.swift
TunnelServices/Utils/NetFileManager.swift
TunnelServices/Handler/ChannelWatchHandler.swift
TunnelServices/Handler/ChannelActiveAwareHandler.swift
TunnelServices/Handler/CloseTimeoutChannelHandler.swift
TunnelServices/Handler/HTTPSHandler.swift
TunnelServices/Handler/SSLHandler.swift
TunnelServices/Handler/ExchangeHandler.swift
```

Use sed or editor to batch replace line 9 in each file:
```bash
cd /Users/aa123/Documents/Knot
for f in $(grep -rl "import UIKit" TunnelServices/); do
  sed -i '' 's/^import UIKit$/import Foundation/' "$f"
done
```

- [ ] **Step 2: Verify no remaining UIKit references**

```bash
grep -r "import UIKit" TunnelServices/
grep -r "UI[A-Z]" TunnelServices/ --include="*.swift" | grep -v "//\|URI\|UUID\|UINT\|UInn"
```

Expected: No matches for `import UIKit`. No UIKit type usage (UIColor, UIView, etc.).

- [ ] **Step 3: Build TunnelServices framework to verify compilation**

Open Xcode, select TunnelServices framework target, build for iOS Simulator.

```bash
cd /Users/aa123/Documents/Knot
xcodebuild -project Knot.xcodeproj -scheme TunnelServices -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add TunnelServices/
git commit -m "refactor: replace import UIKit with import Foundation in TunnelServices

All 29 files imported UIKit but used no UIKit types.
Foundation provides NSObject/NSNumber needed by ActiveSQLite ORM.
This enables macOS compilation of the network layer."
```

---

### Task 2: TunnelServices — Convert to Swift Package

**Files:**
- Create: `LocalPackages/TunnelServices/Package.swift`
- Move: `TunnelServices/` → `LocalPackages/TunnelServices/Sources/TunnelServices/`

- [ ] **Step 1: Create TunnelServices package directory structure**

```bash
cd /Users/aa123/Documents/Knot
mkdir -p LocalPackages/TunnelServices/Sources/TunnelServices
```

- [ ] **Step 2: Move source files**

> **Note:** TunnelServices contains an embedded `ActiveSQLite/` directory (an ORM layer). This will be copied as part of the sources and requires the `SQLite.swift` SPM dependency to resolve its `import SQLite` statements.

```bash
cd /Users/aa123/Documents/Knot
# Copy all Swift sources to the package (including ActiveSQLite ORM)
cp -R TunnelServices/* LocalPackages/TunnelServices/Sources/TunnelServices/
```

- [ ] **Step 3: Create Package.swift**

Create `LocalPackages/TunnelServices/Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TunnelServices",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TunnelServices", targets: ["TunnelServices"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.42.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.23.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
        .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket.git", from: "7.6.5"),
        .package(path: "../SwiftQuiche"),
        .package(path: "../SwiftLsquic"),
    ],
    targets: [
        .target(
            name: "TunnelServices",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "CocoaAsyncSocket", package: "CocoaAsyncSocket"),
                "SwiftQuiche",
                "SwiftLsquic",
            ]
        ),
    ]
)
```

> **Note:** The exact dependency versions and product names must be verified against the existing Xcode project's resolved package versions. Check `Knot.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` for pinned versions.

- [ ] **Step 4: Update SwiftQuiche and SwiftLsquic platforms**

Modify `LocalPackages/SwiftQuiche/Package.swift` line 6:
```swift
// Before:
platforms: [.iOS(.v15)],
// After:
platforms: [.iOS(.v17), .macOS(.v14)],
```

Modify `LocalPackages/SwiftLsquic/Package.swift` line 6:
```swift
// Before:
platforms: [.iOS(.v15)],
// After:
platforms: [.iOS(.v17), .macOS(.v14)],
```

- [ ] **Step 5: Resolve the TunnelServices package**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/TunnelServices
swift package resolve 2>&1 | tail -20
```

If there are compilation issues, fix them iteratively. Common issues:
- Missing `import` statements (some files may have relied on UIKit re-exports)
- AxLogger dependency — temporarily add `import os` and use `Logger` or keep AxLogger as source files within the package

- [ ] **Step 6: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add LocalPackages/TunnelServices/ LocalPackages/SwiftQuiche/Package.swift LocalPackages/SwiftLsquic/Package.swift
git commit -m "feat: convert TunnelServices to Swift Package

Create SPM package under LocalPackages/TunnelServices with all
existing source files. Update platform targets to iOS 17 / macOS 14.
Dependencies: SwiftNIO, NIOSSL, SQLite.swift, CocoaAsyncSocket,
SwiftQuiche, SwiftLsquic."
```

---

### Task 3: KnotCore — Service Protocols and Enums

**Files:**
- Create: `LocalPackages/KnotCore/Package.swift`
- Create: `LocalPackages/KnotCore/Sources/KnotCore/Models/TunnelStatus.swift`
- Create: `LocalPackages/KnotCore/Sources/KnotCore/Models/CertTrustStatus.swift`
- Create: `LocalPackages/KnotCore/Sources/KnotCore/Services/TunnelServiceProtocol.swift`
- Create: `LocalPackages/KnotCore/Sources/KnotCore/Services/CertificateServiceProtocol.swift`
- Create: `LocalPackages/KnotCore/Sources/KnotCore/Services/ServiceContainer.swift`
- Test: `LocalPackages/KnotCore/Tests/KnotCoreTests/ServiceContainerTests.swift`
- Test: `LocalPackages/KnotCore/Tests/KnotCoreTests/TunnelStatusTests.swift`

- [ ] **Step 1: Create KnotCore package structure**

```bash
cd /Users/aa123/Documents/Knot
mkdir -p LocalPackages/KnotCore/Sources/KnotCore/Models
mkdir -p LocalPackages/KnotCore/Sources/KnotCore/Services
mkdir -p LocalPackages/KnotCore/Sources/KnotCore/Extensions
mkdir -p LocalPackages/KnotCore/Tests/KnotCoreTests
```

- [ ] **Step 2: Create Package.swift**

Create `LocalPackages/KnotCore/Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KnotCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KnotCore", targets: ["KnotCore"]),
    ],
    dependencies: [
        .package(path: "../TunnelServices"),
    ],
    targets: [
        .target(
            name: "KnotCore",
            dependencies: ["TunnelServices"]
        ),
        .testTarget(
            name: "KnotCoreTests",
            dependencies: ["KnotCore"]
        ),
    ]
)
```

- [ ] **Step 3: Write failing tests for TunnelStatus**

Create `LocalPackages/KnotCore/Tests/KnotCoreTests/TunnelStatusTests.swift`:

```swift
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
        if case .connected(let since) = status {
            #expect(since == date)
        } else {
            Issue.record("Expected connected status")
        }
    }

    @Test func errorCarriesMessage() {
        let status = TunnelStatus.error("timeout")
        if case .error(let msg) = status {
            #expect(msg == "timeout")
        } else {
            Issue.record("Expected error status")
        }
    }

    @Test func equalityWorks() {
        #expect(TunnelStatus.disconnected == TunnelStatus.disconnected)
        #expect(TunnelStatus.connecting != TunnelStatus.disconnected)
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotCore
swift test 2>&1 | tail -20
```

Expected: FAIL — `TunnelStatus` not defined.

- [ ] **Step 5: Implement TunnelStatus and CertTrustStatus**

Create `LocalPackages/KnotCore/Sources/KnotCore/Models/TunnelStatus.swift`:

```swift
import Foundation

public enum TunnelStatus: Equatable {
    case invalid
    case disconnected
    case connecting
    case connected(since: Date)
    case disconnecting
    case reasserting
    case error(String)
}
```

Create `LocalPackages/KnotCore/Sources/KnotCore/Models/CertTrustStatus.swift`:

```swift
import Foundation

public enum CertTrustStatus: Equatable {
    case notInstalled
    case installed
    case trusted
}
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotCore
swift test 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 7: Write failing tests for ServiceContainer**

Create `LocalPackages/KnotCore/Tests/KnotCoreTests/ServiceContainerTests.swift`:

```swift
import Testing
@testable import KnotCore

protocol MockService: AnyObject {
    var name: String { get }
}

final class MockServiceImpl: MockService {
    let name = "mock"
}

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
```

- [ ] **Step 8: Run tests to verify they fail**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotCore
swift test 2>&1 | tail -20
```

Expected: FAIL — `ServiceContainer` not defined.

- [ ] **Step 9: Implement ServiceContainer**

Create `LocalPackages/KnotCore/Sources/KnotCore/Services/ServiceContainer.swift`:

```swift
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
```

- [ ] **Step 10: Run tests to verify they pass**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotCore
swift test 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 11: Implement service protocols**

Create `LocalPackages/KnotCore/Sources/KnotCore/Services/TunnelServiceProtocol.swift`:

```swift
import Foundation
import Observation

@Observable
public final class TunnelServiceState {
    public var status: TunnelStatus = .disconnected

    public init() {}
}

public struct CaptureConfig: Sendable {
    public var localPort: Int
    public var localEnabled: Bool
    public var wifiPort: Int
    public var wifiEnabled: Bool
    public var ruleId: String?

    public init(
        localPort: Int = 9090,
        localEnabled: Bool = true,
        wifiPort: Int = 9091,
        wifiEnabled: Bool = false,
        ruleId: String? = nil
    ) {
        self.localPort = localPort
        self.localEnabled = localEnabled
        self.wifiPort = wifiPort
        self.wifiEnabled = wifiEnabled
        self.ruleId = ruleId
    }
}

public protocol TunnelServiceProtocol: AnyObject {
    var state: TunnelServiceState { get }

    func startCapture(config: CaptureConfig) async throws
    func stopCapture() async throws
    func installExtension() async throws
    func uninstallExtension() async throws
}
```

Create `LocalPackages/KnotCore/Sources/KnotCore/Services/CertificateServiceProtocol.swift`:

```swift
import Foundation

public protocol CertificateServiceProtocol: AnyObject {
    var trustStatus: CertTrustStatus { get }

    func installCertificate() async throws
    func exportCertificate() -> Data
    func checkTrustStatus() -> CertTrustStatus
    func startLocalServer(port: Int) async throws
    func stopLocalServer()
}
```

- [ ] **Step 12: Create ExportService**

Create `LocalPackages/KnotCore/Sources/KnotCore/Services/ExportService.swift`:

```swift
import Foundation
import TunnelServices

public enum ExportFormat: String, CaseIterable, Identifiable {
    case url = "URL"
    case curl = "cURL"
    case har = "HAR"
    case pcap = "PCAP"

    public var id: String { rawValue }
}

public struct ExportService {
    public init() {}

    public func export(sessions: [Session], format: ExportFormat) -> Data? {
        switch format {
        case .url:
            let urls = sessions.compactMap { $0.uri }.joined(separator: "\n")
            return urls.data(using: .utf8)
        case .curl:
            let curls = sessions.map { session -> String in
                var cmd = "curl"
                if let method = session.methods, method != "GET" {
                    cmd += " -X \(method)"
                }
                if let uri = session.uri {
                    cmd += " '\(session.schemes ?? "https")://\(session.host ?? "")\(uri)'"
                }
                return cmd
            }.joined(separator: "\n\n")
            return curls.data(using: .utf8)
        case .har, .pcap:
            // Delegate to TunnelServices existing exporters
            return nil
        }
    }
}
```

- [ ] **Step 13: Verify full package builds**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotCore
swift build 2>&1 | tail -20
swift test 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED, all tests PASS.

- [ ] **Step 14: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add LocalPackages/KnotCore/
git commit -m "feat: create KnotCore package with service protocols

- TunnelStatus/CertTrustStatus enums
- TunnelServiceProtocol/CertificateServiceProtocol abstractions
- ServiceContainer for dependency injection
- ExportService for session data export
- Unit tests for ServiceContainer and TunnelStatus"
```

---

### Task 4: AxLogger — Replace with os.Logger wrapper

**Files:**
- Create: `LocalPackages/KnotCore/Sources/KnotCore/Logging/Log.swift`
- Modify: TunnelServices sources that import AxLogger

- [ ] **Step 1: Create unified logging wrapper**

Create `LocalPackages/KnotCore/Sources/KnotCore/Logging/Log.swift`:

```swift
import Foundation
import os

public struct Log {
    private static let subsystem = "com.knot.app"

    public static let general = Logger(subsystem: subsystem, category: "general")
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let proxy = Logger(subsystem: subsystem, category: "proxy")
    public static let tunnel = Logger(subsystem: subsystem, category: "tunnel")
    public static let database = Logger(subsystem: subsystem, category: "database")
    public static let cert = Logger(subsystem: subsystem, category: "certificate")
}
```

- [ ] **Step 2: Replace AxLogger imports directly in TunnelServices with os.Logger**

TunnelServices CANNOT depend on KnotCore (circular dependency). Instead, replace `import AxLogger` with `import os` directly in TunnelServices files.

For each file that imports AxLogger:
```bash
cd /Users/aa123/Documents/Knot/LocalPackages/TunnelServices/Sources/TunnelServices
grep -rl "import AxLogger" . | head -30
```

Replace `import AxLogger` with `import os` and replace `Qlog.log(...)` calls with `Logger` calls.

> **Note:** This is a file-by-file migration. The exact number of files and call sites needs to be determined during execution. If AxLogger usage is extensive (50+ call sites), consider creating a thin `Qlog` compatibility shim using `os.Logger` within TunnelServices to minimize changes.

- [ ] **Step 3: Verify TunnelServices builds without AxLogger**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/TunnelServices
swift build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add LocalPackages/TunnelServices/ LocalPackages/KnotCore/Sources/KnotCore/Logging/
git commit -m "refactor: replace AxLogger with os.Logger

Add Log utility in KnotCore. Replace AxLogger imports in
TunnelServices with os.Logger for cross-platform compatibility."
```

---

### Task 5: Integration verification — both packages build for iOS + macOS

**Files:** No new files. Verification only.

- [ ] **Step 1: Verify TunnelServices builds for macOS**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/TunnelServices
swift build 2>&1 | tail -30
```

> **Note:** This will likely fail due to quiche/lsquic xcframeworks lacking macOS slices. If it fails, add conditional compilation to exclude QUIC on macOS temporarily:

In Package.swift, make quiche/lsquic dependencies conditional using `.when(platforms:)`:
```swift
.product(name: "SwiftQuiche", package: "SwiftQuiche", condition: .when(platforms: [.iOS])),
.product(name: "SwiftLsquic", package: "SwiftLsquic", condition: .when(platforms: [.iOS])),
```

In source files that import SwiftQuiche/SwiftLsquic, wrap with:
```swift
#if canImport(SwiftQuiche)
import SwiftQuiche
#endif
```

- [ ] **Step 2: Verify KnotCore builds for macOS**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotCore
swift build 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run all KnotCore tests**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotCore
swift test 2>&1 | tail -30
```

Expected: All tests PASS.

- [ ] **Step 4: Commit any fixes**

```bash
cd /Users/aa123/Documents/Knot
git add LocalPackages/
git commit -m "fix: ensure TunnelServices and KnotCore build for iOS + macOS

Conditionally exclude QUIC dependencies on macOS until
xcframeworks are rebuilt with macOS slices."
```

---

## Phase 1 Complete Checklist

After all tasks are done:
- [ ] `LocalPackages/TunnelServices/` builds for iOS
- [ ] `LocalPackages/TunnelServices/` builds for macOS (with QUIC conditionally excluded)
- [ ] `LocalPackages/KnotCore/` builds for iOS and macOS
- [ ] All KnotCore tests pass
- [ ] No `import UIKit` in TunnelServices
- [ ] No `import AxLogger` in TunnelServices
- [ ] Service protocols defined: `TunnelServiceProtocol`, `CertificateServiceProtocol`
- [ ] `ServiceContainer` working with tests
- [ ] `ExportService` defined with format support

**Next:** Phase 2 — KnotUI Package (SwiftUI views, components, navigation)
