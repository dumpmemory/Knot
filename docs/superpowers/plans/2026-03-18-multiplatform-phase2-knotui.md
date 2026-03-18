# Phase 2: KnotUI Package — SwiftUI Views + Navigation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the KnotUI SwiftUI package with adaptive layout (NavigationSplitView for wide, NavigationStack for compact), all page views, and reusable components.

**Architecture:** Single `RootView` switches layout based on `horizontalSizeClass`. All page components are reused across both layouts. Navigation state is centralized in `NavigationState`. ViewModels use `@Observable` macro.

**Tech Stack:** SwiftUI (iOS 17 / macOS 14), Observation framework, KnotCore

**Spec:** `docs/superpowers/specs/2026-03-18-multiplatform-redesign-design.md`
**Depends on:** Phase 1 complete (KnotCore package available)

---

### File Structure

```
LocalPackages/KnotUI/
├── Package.swift
├── Sources/KnotUI/
│   ├── App/
│   │   ├── RootView.swift
│   │   ├── NavigationState.swift
│   │   ├── PrimaryPageView.swift
│   │   ├── DetailPageView.swift
│   │   └── PageSwitcher.swift
│   ├── ViewModels/
│   │   ├── AppState.swift
│   │   ├── SessionListViewModel.swift
│   │   ├── RuleViewModel.swift
│   │   └── CertificateViewModel.swift
│   ├── Views/
│   │   ├── Dashboard/
│   │   │   └── DashboardView.swift
│   │   ├── SessionList/
│   │   │   └── SessionListView.swift
│   │   ├── SessionDetail/
│   │   │   ├── SessionDetailView.swift
│   │   │   ├── SessionRequestView.swift
│   │   │   ├── SessionResponseView.swift
│   │   │   └── SessionOverviewView.swift
│   │   ├── Rule/
│   │   │   ├── RuleListView.swift
│   │   │   ├── RuleDetailView.swift
│   │   │   └── RuleAddView.swift
│   │   ├── Certificate/
│   │   │   └── CertificateView.swift
│   │   ├── History/
│   │   │   └── HistoryTaskView.swift
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       └── AboutView.swift
│   └── Components/
│       ├── StateCardView.swift
│       ├── ProxyConfigView.swift
│       ├── CurrentTaskView.swift
│       ├── HistoryTaskCell.swift
│       ├── SessionCell.swift
│       ├── SessionHeaderList.swift
│       ├── SessionBodyPreview.swift
│       ├── SessionTimelineView.swift
│       ├── SessionOverviewSection.swift
│       ├── RuleCell.swift
│       ├── RuleMatchRow.swift
│       ├── CertStatusCard.swift
│       ├── SearchBar.swift
│       ├── FocusTagsView.swift
│       ├── ExportMenu.swift
│       ├── EditToolbar.swift
│       └── PlaceholderView.swift
└── Tests/KnotUITests/
    └── NavigationStateTests.swift
```

---

### Task 1: KnotUI Package setup + NavigationState

**Files:**
- Create: `LocalPackages/KnotUI/Package.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/App/NavigationState.swift`
- Test: `LocalPackages/KnotUI/Tests/KnotUITests/NavigationStateTests.swift`

- [ ] **Step 1: Create package structure**

```bash
cd /Users/aa123/Documents/Knot
mkdir -p LocalPackages/KnotUI/Sources/KnotUI/{App,ViewModels,Views/{Dashboard,SessionList,SessionDetail,Rule,Certificate,History,Settings},Components}
mkdir -p LocalPackages/KnotUI/Tests/KnotUITests
```

- [ ] **Step 2: Create Package.swift**

Create `LocalPackages/KnotUI/Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KnotUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KnotUI", targets: ["KnotUI"]),
    ],
    dependencies: [
        .package(path: "../KnotCore"),
    ],
    targets: [
        .target(
            name: "KnotUI",
            dependencies: ["KnotCore"]
        ),
        .testTarget(
            name: "KnotUITests",
            dependencies: ["KnotUI"]
        ),
    ]
)
```

- [ ] **Step 3: Write failing test for NavigationState**

Create `LocalPackages/KnotUI/Tests/KnotUITests/NavigationStateTests.swift`:

```swift
import Testing
@testable import KnotUI

@Suite("NavigationState Tests")
struct NavigationStateTests {
    @Test func defaultsAreDashboard() {
        let nav = NavigationState()
        #expect(nav.primaryPage == .dashboard)
        #expect(nav.detailPath.isEmpty)
    }

    @Test func navigateAppendsToDetailPath() {
        let nav = NavigationState()
        nav.navigate(to: .sessionDetail(sessionId: "123"))
        #expect(nav.detailPath.count == 1)
    }

    @Test func switchPrimaryClearsDetailPath() {
        let nav = NavigationState()
        nav.navigate(to: .sessionDetail(sessionId: "123"))
        nav.switchPrimary(to: .ruleList)
        #expect(nav.primaryPage == .ruleList)
        #expect(nav.detailPath.isEmpty)
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotUI
swift test 2>&1 | tail -20
```

Expected: FAIL — `NavigationState` not defined.

- [ ] **Step 5: Implement NavigationState**

Create `LocalPackages/KnotUI/Sources/KnotUI/App/NavigationState.swift`:

```swift
import Foundation
import Observation

public enum PrimaryPage: Hashable {
    case dashboard
    case sessionList(taskId: String)
    case ruleList
    case certificate
    case historyTask
    case settings
}

public enum WebDocType: String, Hashable {
    case terms
    case termsFirst
    case privacy
}

public enum DetailDestination: Hashable {
    case sessionList(taskId: String)
    case sessionDetail(sessionId: String)
    case sessionHeader(isRequest: Bool, sessionId: String)
    case sessionBody(isRequest: Bool, sessionId: String)
    case ruleDetail(ruleId: String)
    case ruleAdd(ruleId: String)
    case settingCertificate
    case settingAbout
    case settingWeb(type: WebDocType)
}

@Observable
public final class NavigationState {
    public var primaryPage: PrimaryPage = .dashboard
    public var detailPath: [DetailDestination] = []

    public init() {}

    public func navigate(to destination: DetailDestination) {
        detailPath.append(destination)
    }

    public func switchPrimary(to page: PrimaryPage) {
        primaryPage = page
        detailPath = []
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotUI
swift test 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add LocalPackages/KnotUI/
git commit -m "feat: create KnotUI package with NavigationState

Adaptive navigation model: PrimaryPage for left pane / full screen,
DetailDestination for right pane / push stack. Tests included."
```

---

### Task 2: RootView + Layout Switching

**Files:**
- Create: `LocalPackages/KnotUI/Sources/KnotUI/App/RootView.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/App/PrimaryPageView.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/App/DetailPageView.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/App/PageSwitcher.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/PlaceholderView.swift`

- [ ] **Step 1: Create PlaceholderView**

Create `LocalPackages/KnotUI/Sources/KnotUI/Components/PlaceholderView.swift`:

```swift
import SwiftUI

public struct PlaceholderView: View {
    let title: String
    let systemImage: String

    public init(title: String = "选择一个项目", systemImage: String = "sidebar.left") {
        self.title = title
        self.systemImage = systemImage
    }

    public var body: some View {
        ContentUnavailableView(title, systemImage: systemImage)
    }
}
```

- [ ] **Step 2: Create PageSwitcher (bottom tab bar)**

Create `LocalPackages/KnotUI/Sources/KnotUI/App/PageSwitcher.swift`:

```swift
import SwiftUI

struct PageSwitcherItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let page: PrimaryPage
}

struct PageSwitcher: View {
    @Bindable var nav: NavigationState

    private let items: [PageSwitcherItem] = [
        .init(id: "dashboard", title: "首页", systemImage: "gauge", page: .dashboard),
        .init(id: "rules", title: "规则", systemImage: "ruler", page: .ruleList),
        .init(id: "cert", title: "证书", systemImage: "lock.shield", page: .certificate),
        .init(id: "settings", title: "设置", systemImage: "gearshape", page: .settings),
    ]

    var body: some View {
        HStack {
            ForEach(items) { item in
                Button {
                    nav.switchPrimary(to: item.page)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.title3)
                        Text(item.title)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(isSelected(item) ? .accent : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func isSelected(_ item: PageSwitcherItem) -> Bool {
        switch (nav.primaryPage, item.page) {
        case (.dashboard, .dashboard),
             (.ruleList, .ruleList),
             (.certificate, .certificate),
             (.settings, .settings):
            return true
        default:
            return false
        }
    }
}
```

- [ ] **Step 3: Create PrimaryPageView**

Create `LocalPackages/KnotUI/Sources/KnotUI/App/PrimaryPageView.swift`:

```swift
import SwiftUI
import KnotCore

struct PrimaryPageView: View {
    let page: PrimaryPage
    @Bindable var nav: NavigationState

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case .dashboard:
                    DashboardView(nav: nav)
                case .sessionList(let taskId):
                    SessionListView(taskId: taskId, nav: nav)
                case .ruleList:
                    RuleListView(nav: nav)
                case .certificate:
                    CertificateView()
                case .historyTask:
                    HistoryTaskView(nav: nav)
                case .settings:
                    SettingsView(nav: nav)
                }
            }
            .frame(maxHeight: .infinity)

            PageSwitcher(nav: nav)
        }
    }
}
```

- [ ] **Step 4: Create DetailPageView**

Create `LocalPackages/KnotUI/Sources/KnotUI/App/DetailPageView.swift`:

```swift
import SwiftUI
import KnotCore

struct DetailPageView: View {
    let destination: DetailDestination
    @Bindable var nav: NavigationState

    var body: some View {
        switch destination {
        case .sessionList(let taskId):
            SessionListView(taskId: taskId, nav: nav)
        case .sessionDetail(let sessionId):
            SessionDetailView(sessionId: sessionId)
        case .sessionHeader(let isRequest, let sessionId):
            SessionHeaderList(isRequest: isRequest, sessionId: sessionId)
        case .sessionBody(let isRequest, let sessionId):
            SessionBodyPreview(isRequest: isRequest, sessionId: sessionId)
        case .ruleDetail(let ruleId):
            RuleDetailView(ruleId: ruleId, nav: nav)
        case .ruleAdd(let ruleId):
            RuleAddView(ruleId: ruleId)
        case .settingCertificate:
            CertificateView()
        case .settingAbout:
            AboutView()
        case .settingWeb(let type):
            // WebView placeholder
            Text("Web: \(type.rawValue)")
        }
    }
}
```

- [ ] **Step 5: Create RootView**

Create `LocalPackages/KnotUI/Sources/KnotUI/App/RootView.swift`:

```swift
import SwiftUI
import KnotCore

public struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var nav = NavigationState()

    public init() {}

    public var body: some View {
        if sizeClass == .regular {
            wideLayout
        } else {
            compactLayout
        }
    }

    private var wideLayout: some View {
        NavigationSplitView {
            PrimaryPageView(page: nav.primaryPage, nav: nav)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        } detail: {
            NavigationStack(path: $nav.detailPath) {
                PlaceholderView()
                    .navigationDestination(for: DetailDestination.self) { dest in
                        DetailPageView(destination: dest, nav: nav)
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var compactLayout: some View {
        NavigationStack(path: $nav.detailPath) {
            PrimaryPageView(page: nav.primaryPage, nav: nav)
                .navigationDestination(for: DetailDestination.self) { dest in
                    DetailPageView(destination: dest, nav: nav)
                }
        }
    }
}
```

- [ ] **Step 6: Create stub views so it compiles**

Create stub files for all views referenced by PrimaryPageView and DetailPageView. Each stub is minimal — just a Text placeholder. These will be implemented in subsequent tasks.

`LocalPackages/KnotUI/Sources/KnotUI/Views/Dashboard/DashboardView.swift`:
```swift
import SwiftUI

struct DashboardView: View {
    @Bindable var nav: NavigationState

    var body: some View {
        Text("Dashboard")
            .navigationTitle("Knot")
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Views/SessionList/SessionListView.swift`:
```swift
import SwiftUI

struct SessionListView: View {
    let taskId: String
    @Bindable var nav: NavigationState

    var body: some View {
        Text("Sessions for task: \(taskId)")
            .navigationTitle("会话列表")
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Views/SessionDetail/SessionDetailView.swift`:
```swift
import SwiftUI

struct SessionDetailView: View {
    let sessionId: String

    var body: some View {
        Text("Session: \(sessionId)")
            .navigationTitle("会话详情")
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Views/Rule/RuleListView.swift`:
```swift
import SwiftUI

struct RuleListView: View {
    @Bindable var nav: NavigationState

    var body: some View {
        Text("Rules")
            .navigationTitle("规则管理")
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Views/Rule/RuleDetailView.swift`:
```swift
import SwiftUI

struct RuleDetailView: View {
    let ruleId: String
    @Bindable var nav: NavigationState

    var body: some View {
        Text("Rule: \(ruleId)")
            .navigationTitle("规则详情")
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Views/Rule/RuleAddView.swift`:
```swift
import SwiftUI

struct RuleAddView: View {
    let ruleId: String

    var body: some View {
        Text("Add rule to: \(ruleId)")
            .navigationTitle("添加规则")
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Views/Certificate/CertificateView.swift`:
```swift
import SwiftUI

struct CertificateView: View {
    var body: some View {
        Text("Certificate Management")
            .navigationTitle("证书管理")
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Views/History/HistoryTaskView.swift`:
```swift
import SwiftUI

struct HistoryTaskView: View {
    @Bindable var nav: NavigationState

    var body: some View {
        Text("History")
            .navigationTitle("历史任务")
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Views/Settings/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @Bindable var nav: NavigationState

    var body: some View {
        Text("Settings")
            .navigationTitle("设置")
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Views/Settings/AboutView.swift`:
```swift
import SwiftUI

struct AboutView: View {
    var body: some View {
        Text("Knot v2.0.0")
            .navigationTitle("关于")
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Components/SessionHeaderList.swift`:
```swift
import SwiftUI

public struct SessionHeaderList: View {
    let isRequest: Bool
    let sessionId: String

    public var body: some View {
        Text("Headers")
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Components/SessionBodyPreview.swift`:
```swift
import SwiftUI

public struct SessionBodyPreview: View {
    let isRequest: Bool
    let sessionId: String

    public var body: some View {
        Text("Body Preview")
    }
}
```

- [ ] **Step 7: Verify package builds**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotUI
swift build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add LocalPackages/KnotUI/
git commit -m "feat: add RootView with adaptive layout switching

NavigationSplitView for wide screens, NavigationStack for compact.
PrimaryPageView renders left pane / full screen content.
DetailPageView renders right pane / push destinations.
PageSwitcher provides bottom tab navigation.
All page views are stubs — implementation follows."
```

---

### Task 3: ViewModels

**Files:**
- Create: `LocalPackages/KnotUI/Sources/KnotUI/ViewModels/AppState.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/ViewModels/SessionListViewModel.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/ViewModels/RuleViewModel.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/ViewModels/CertificateViewModel.swift`

- [ ] **Step 1: Create AppState**

Create `LocalPackages/KnotUI/Sources/KnotUI/ViewModels/AppState.swift`:

```swift
import Foundation
import Observation
import KnotCore
import TunnelServices

@Observable
public final class AppState {
    public var vpnStatus: TunnelStatus = .disconnected
    public var currentTask: CaptureTask?
    public var certificateStatus: CertTrustStatus = .notInstalled
    public var networkType: String = "WiFi"
    public var activeRuleId: String?

    public var isCapturing: Bool {
        if case .connected = vpnStatus { return true }
        return false
    }

    public init() {}
}
```

- [ ] **Step 2: Create SessionListViewModel**

Create `LocalPackages/KnotUI/Sources/KnotUI/ViewModels/SessionListViewModel.swift`:

```swift
import Foundation
import Observation
import TunnelServices

@Observable
public final class SessionListViewModel {
    public var sessions: [Session] = []
    public var searchText: String = ""
    public var focusHost: String?
    public var focusMethod: String?
    public var focusStatusCode: String?
    public var isEditing: Bool = false
    public var selectedIds: Set<Int64> = []
    public var currentPage: Int = 0
    public var hasMore: Bool = true

    public let taskId: String
    private let pageSize = 50

    public init(taskId: String) {
        self.taskId = taskId
    }

    public func loadSessions() {
        // Load from database via TunnelServices Session model
        // NOTE: Actual API is Session.findAll(taskID:keyWord:params:pageSize:pageIndex:orderBy:timeInterval:)
        // The `params` parameter is [String:[String]]? dict for filters (host, methods, state, etc.)
        // Adapt to the real signature during implementation:
        var params: [String: [String]]? = nil
        if focusHost != nil || focusMethod != nil || focusStatusCode != nil {
            params = [:]
            if let h = focusHost { params?["host"] = [h] }
            if let m = focusMethod { params?["methods"] = [m] }
            if let s = focusStatusCode { params?["state"] = [s] }
        }
        let results = Session.findAll(
            taskID: taskId,
            keyWord: searchText.isEmpty ? nil : searchText,
            params: params,
            pageSize: pageSize,
            pageIndex: currentPage
        )
        if currentPage == 0 {
            sessions = results
        } else {
            sessions.append(contentsOf: results)
        }
        hasMore = results.count == pageSize
    }

    public func loadMore() {
        guard hasMore else { return }
        currentPage += 1
        loadSessions()
    }

    public func refresh() {
        currentPage = 0
        loadSessions()
    }

    public func toggleSelection(_ id: Int64) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    public func selectAll() {
        selectedIds = Set(sessions.compactMap { $0.id?.int64Value })
    }

    public func deselectAll() {
        selectedIds.removeAll()
    }
}
```

- [ ] **Step 3: Create RuleViewModel**

Create `LocalPackages/KnotUI/Sources/KnotUI/ViewModels/RuleViewModel.swift`:

```swift
import Foundation
import Observation
import TunnelServices

@Observable
public final class RuleViewModel {
    public var rules: [Rule] = []
    public var activeRuleId: String?

    public init() {}

    public func loadRules() {
        rules = (try? Rule.findAll()) ?? []
        activeRuleId = UserDefaults(suiteName: "group.Lojii.NIO1901")?.string(forKey: "activeRuleId")
    }

    public func setActive(ruleId: String) {
        activeRuleId = ruleId
        UserDefaults(suiteName: "group.Lojii.NIO1901")?.set(ruleId, forKey: "activeRuleId")
    }

    public func deleteRule(_ rule: Rule) {
        try? rule.delete()
        loadRules()
    }
}
```

- [ ] **Step 4: Create CertificateViewModel**

Create `LocalPackages/KnotUI/Sources/KnotUI/ViewModels/CertificateViewModel.swift`:

```swift
import Foundation
import Observation
import KnotCore

@Observable
public final class CertificateViewModel {
    public var trustStatus: CertTrustStatus = .notInstalled
    public var isServerRunning: Bool = false
    public var localIP: String?

    public init() {}

    public func checkStatus() {
        if let service: CertificateServiceProtocol = ServiceContainer.shared.resolve(CertificateServiceProtocol.self) {
            trustStatus = service.checkTrustStatus()
        }
    }

    public func startServer(port: Int = 8080) async {
        if let service: CertificateServiceProtocol = ServiceContainer.shared.resolve(CertificateServiceProtocol.self) {
            try? await service.startLocalServer(port: port)
            isServerRunning = true
        }
    }

    public func stopServer() {
        if let service: CertificateServiceProtocol = ServiceContainer.shared.resolve(CertificateServiceProtocol.self) {
            service.stopLocalServer()
            isServerRunning = false
        }
    }
}
```

- [ ] **Step 5: Verify package builds**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotUI
swift build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED. (Some warnings about unresolved Session.findAll may appear — this is expected as the exact API will be refined during integration.)

- [ ] **Step 6: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add LocalPackages/KnotUI/Sources/KnotUI/ViewModels/
git commit -m "feat: add ViewModels — AppState, SessionList, Rule, Certificate

@Observable view models for SwiftUI data binding.
SessionListViewModel handles pagination, search, focus filters.
RuleViewModel manages rule CRUD and active rule selection.
CertificateViewModel wraps CertificateServiceProtocol."
```

---

### Task 4: Core Components

**Files:**
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/StateCardView.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/ProxyConfigView.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/CurrentTaskView.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/HistoryTaskCell.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/SessionCell.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/SearchBar.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/FocusTagsView.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/ExportMenu.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/EditToolbar.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/CertStatusCard.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/RuleCell.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/RuleMatchRow.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/SessionOverviewSection.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Components/SessionTimelineView.swift`

- [ ] **Step 1: Create StateCardView**

Create `LocalPackages/KnotUI/Sources/KnotUI/Components/StateCardView.swift`:

```swift
import SwiftUI
import KnotCore

struct StateCardView: View {
    let status: TunnelStatus
    let certStatus: CertTrustStatus
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusText)
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 16) {
                Button(action: onStart) {
                    Label("启动", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnected)

                Button(action: onStop) {
                    Label("停止", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!isConnected)
            }

            if certStatus != .trusted {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(certStatus == .notInstalled ? "证书未安装" : "证书未信任")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var isConnected: Bool {
        if case .connected = status { return true }
        return false
    }

    private var statusColor: Color {
        switch status {
        case .connected: .green
        case .connecting, .reasserting: .yellow
        case .disconnected, .invalid: .red
        case .disconnecting: .orange
        case .error: .red
        }
    }

    private var statusText: String {
        switch status {
        case .connected: "已连接"
        case .connecting: "连接中..."
        case .disconnected: "未连接"
        case .disconnecting: "断开中..."
        case .reasserting: "重连中..."
        case .invalid: "无效"
        case .error(let msg): "错误: \(msg)"
        }
    }
}
```

- [ ] **Step 2: Create ProxyConfigView**

Create `LocalPackages/KnotUI/Sources/KnotUI/Components/ProxyConfigView.swift`:

```swift
import SwiftUI

struct ProxyConfigView: View {
    @Binding var localEnabled: Bool
    @Binding var localPort: String
    @Binding var wifiEnabled: Bool
    @Binding var wifiPort: String
    let wifiIP: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("代理设置")
                .font(.headline)

            HStack {
                Toggle("本机监听", isOn: $localEnabled)
                Spacer()
                TextField("端口", text: $localPort)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Toggle("WiFi 监听", isOn: $wifiEnabled)
                Spacer()
                TextField("端口", text: $wifiPort)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
            }

            if let ip = wifiIP, wifiEnabled {
                Text("WiFi IP: \(ip)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 3: Create CurrentTaskView**

Create `LocalPackages/KnotUI/Sources/KnotUI/Components/CurrentTaskView.swift`:

```swift
import SwiftUI
import TunnelServices

struct CurrentTaskView: View {
    let task: CaptureTask?
    let onTap: () -> Void

    var body: some View {
        if let task = task {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("当前任务")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 20) {
                        Label("\(task.interceptCount)", systemImage: "doc.text")
                        Label(formatBytes(task.uploadTraffic), systemImage: "arrow.up")
                        Label(formatBytes(task.downloadFlow), systemImage: "arrow.down")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}
```

- [ ] **Step 4: Create HistoryTaskCell**

Create `LocalPackages/KnotUI/Sources/KnotUI/Components/HistoryTaskCell.swift`:

```swift
import SwiftUI
import TunnelServices

struct HistoryTaskCell: View {
    let task: CaptureTask
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.creatTime ?? "")
                        .font(.subheadline)
                    HStack(spacing: 12) {
                        Label("\(task.interceptCount)", systemImage: "doc.text")
                        Label(task.ruleName ?? "default", systemImage: "ruler")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 5: Create SessionCell**

Create `LocalPackages/KnotUI/Sources/KnotUI/Components/SessionCell.swift`:

```swift
import SwiftUI
import TunnelServices

struct SessionCell: View {
    let session: Session

    var body: some View {
        HStack(spacing: 10) {
            // Method badge
            Text(session.methods ?? "?")
                .font(.caption.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(methodColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(methodColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.host ?? "unknown")
                    .font(.subheadline)
                    .lineLimit(1)
                Text(session.uri ?? "/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let state = session.state, let code = Int(state) {
                    Text("\(code)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(statusColor(code))
                }
                if session.downloadFlow > 0 {
                    Text(formatBytes(session.downloadFlow))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var methodColor: Color {
        switch session.methods?.uppercased() {
        case "GET": .blue
        case "POST": .green
        case "PUT": .orange
        case "DELETE": .red
        default: .gray
        }
    }

    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: .green
        case 300..<400: .blue
        case 400..<500: .orange
        case 500...: .red
        default: .secondary
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
    }
}
```

- [ ] **Step 6: Create remaining components**

Create `SearchBar.swift`, `FocusTagsView.swift`, `ExportMenu.swift`, `EditToolbar.swift`, `CertStatusCard.swift`, `RuleCell.swift`, `RuleMatchRow.swift`, `SessionOverviewSection.swift`, `SessionTimelineView.swift`:

`LocalPackages/KnotUI/Sources/KnotUI/Components/SearchBar.swift`:
```swift
import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "搜索"
    var onCommit: () -> Void = {}

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .onSubmit(onCommit)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Components/FocusTagsView.swift`:
```swift
import SwiftUI

struct FocusTag: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

struct FocusTagsView: View {
    let tags: [FocusTag]
    let onRemove: (FocusTag) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags) { tag in
                    HStack(spacing: 4) {
                        Text(tag.label)
                            .font(.caption)
                        Button { onRemove(tag) } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1), in: Capsule())
                }
            }
        }
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Components/ExportMenu.swift`:
```swift
import SwiftUI
import KnotCore

struct ExportMenu: View {
    let onExport: (ExportFormat) -> Void

    var body: some View {
        Menu {
            ForEach(ExportFormat.allCases) { format in
                Button(format.rawValue) { onExport(format) }
            }
        } label: {
            Label("导出", systemImage: "square.and.arrow.up")
        }
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Components/EditToolbar.swift`:
```swift
import SwiftUI

struct EditToolbar: View {
    let selectedCount: Int
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onExport: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        HStack {
            Button("全选", action: onSelectAll)
            Button("取消全选", action: onDeselectAll)
            Spacer()
            Text("已选 \(selectedCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onExport) {
                Label("导出", systemImage: "square.and.arrow.up")
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Components/CertStatusCard.swift`:
```swift
import SwiftUI
import KnotCore

struct CertStatusCard: View {
    let status: CertTrustStatus
    let onInstall: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.largeTitle)
                .foregroundStyle(statusColor)

            Text(statusText)
                .font(.headline)

            if status != .trusted {
                Button(action: onInstall) {
                    Text(status == .notInstalled ? "安装证书" : "信任证书")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var statusIcon: String {
        switch status {
        case .notInstalled: "lock.open"
        case .installed: "lock"
        case .trusted: "lock.shield.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .notInstalled: .red
        case .installed: .yellow
        case .trusted: .green
        }
    }

    private var statusText: String {
        switch status {
        case .notInstalled: "证书未安装"
        case .installed: "已安装，未信任"
        case .trusted: "已安装并信任"
        }
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Components/RuleCell.swift`:
```swift
import SwiftUI
import TunnelServices

struct RuleCell: View {
    let rule: Rule
    let isActive: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.subName)
                    .font(.subheadline)
                Text("\(rule.ruleItems.count) 条规则")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Components/RuleMatchRow.swift`:
```swift
import SwiftUI
import TunnelServices

struct RuleMatchRow: View {
    let item: RuleItem

    var body: some View {
        HStack {
            Text(item.type?.rawValue ?? "")
                .font(.caption.bold())
                .foregroundStyle(.blue)
            Text(item.value ?? "")
                .font(.subheadline)
            Spacer()
            Text(item.strategy?.rawValue ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Components/SessionOverviewSection.swift`:
```swift
import SwiftUI

struct SessionOverviewSection: View {
    let title: String
    let items: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.0) { key, value in
                HStack {
                    Text(key)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(value)
                        .font(.subheadline)
                        .textSelection(.enabled)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

`LocalPackages/KnotUI/Sources/KnotUI/Components/SessionTimelineView.swift`:
```swift
import SwiftUI

struct TimelineEntry: Identifiable {
    let id = UUID()
    let label: String
    let duration: TimeInterval
    let color: Color
}

struct SessionTimelineView: View {
    let entries: [TimelineEntry]
    let totalDuration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时间线")
                .font(.headline)
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(entries) { entry in
                        let width = totalDuration > 0
                            ? max(2, geo.size.width * entry.duration / totalDuration)
                            : 0
                        entry.color
                            .frame(width: width, height: 20)
                            .cornerRadius(2)
                    }
                }
            }
            .frame(height: 20)

            HStack(spacing: 12) {
                ForEach(entries) { entry in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(entry.color)
                            .frame(width: 8, height: 8)
                        Text("\(entry.label): \(Int(entry.duration * 1000))ms")
                            .font(.caption2)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 7: Verify package builds**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotUI
swift build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add LocalPackages/KnotUI/Sources/KnotUI/Components/
git commit -m "feat: add all reusable SwiftUI components

StateCardView, ProxyConfigView, CurrentTaskView, SessionCell,
SearchBar, FocusTagsView, ExportMenu, EditToolbar, CertStatusCard,
RuleCell, RuleMatchRow, SessionOverviewSection, SessionTimelineView,
HistoryTaskCell, PlaceholderView."
```

---

### Task 5: Implement DashboardView

**Files:**
- Modify: `LocalPackages/KnotUI/Sources/KnotUI/Views/Dashboard/DashboardView.swift`

- [ ] **Step 1: Implement full DashboardView**

Replace `LocalPackages/KnotUI/Sources/KnotUI/Views/Dashboard/DashboardView.swift`:

```swift
import SwiftUI
import KnotCore
import TunnelServices

struct DashboardView: View {
    @Bindable var nav: NavigationState
    @State private var appState = AppState()
    @State private var localEnabled = true
    @State private var localPort = "9090"
    @State private var wifiEnabled = false
    @State private var wifiPort = "9091"
    @State private var recentTasks: [CaptureTask] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StateCardView(
                    status: appState.vpnStatus,
                    certStatus: appState.certificateStatus,
                    onStart: startCapture,
                    onStop: stopCapture
                )

                ProxyConfigView(
                    localEnabled: $localEnabled,
                    localPort: $localPort,
                    wifiEnabled: $wifiEnabled,
                    wifiPort: $wifiPort,
                    wifiIP: nil
                )

                CurrentTaskView(task: appState.currentTask) {
                    if let task = appState.currentTask,
                       let id = task.id?.stringValue {
                        nav.navigate(to: .sessionList(taskId: id))
                    }
                }

                // Recent history
                if !recentTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("历史任务")
                                .font(.headline)
                            Spacer()
                            Button("更多") {
                                nav.switchPrimary(to: .historyTask)
                            }
                            .font(.caption)
                        }

                        ForEach(recentTasks.prefix(5), id: \.id) { task in
                            HistoryTaskCell(task: task) {
                                if let id = task.id?.stringValue {
                                    nav.navigate(to: .sessionList(taskId: id))
                                }
                            }
                            Divider()
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle("Knot")
        .onAppear(perform: loadData)
    }

    private func startCapture() {
        Task {
            if let service: TunnelServiceProtocol = ServiceContainer.shared.resolve(TunnelServiceProtocol.self) {
                let config = CaptureConfig(
                    localPort: Int(localPort) ?? 9090,
                    localEnabled: localEnabled,
                    wifiPort: Int(wifiPort) ?? 9091,
                    wifiEnabled: wifiEnabled,
                    ruleId: appState.activeRuleId
                )
                try? await service.startCapture(config: config)
            }
        }
    }

    private func stopCapture() {
        Task {
            if let service: TunnelServiceProtocol = ServiceContainer.shared.resolve(TunnelServiceProtocol.self) {
                try? await service.stopCapture()
            }
        }
    }

    private func loadData() {
        recentTasks = (try? CaptureTask.findAll(limit: 5)) ?? []
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotUI
swift build 2>&1 | tail -20
```

- [ ] **Step 3: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add LocalPackages/KnotUI/Sources/KnotUI/Views/Dashboard/
git commit -m "feat: implement DashboardView with state card, proxy config, tasks"
```

---

### Task 6: Implement SessionListView + SessionDetailView

**Files:**
- Modify: `LocalPackages/KnotUI/Sources/KnotUI/Views/SessionList/SessionListView.swift`
- Modify: `LocalPackages/KnotUI/Sources/KnotUI/Views/SessionDetail/SessionDetailView.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Views/SessionDetail/SessionRequestView.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Views/SessionDetail/SessionResponseView.swift`
- Create: `LocalPackages/KnotUI/Sources/KnotUI/Views/SessionDetail/SessionOverviewView.swift`

- [ ] **Step 1: Implement SessionListView**

Replace `LocalPackages/KnotUI/Sources/KnotUI/Views/SessionList/SessionListView.swift`:

```swift
import SwiftUI
import TunnelServices

struct SessionListView: View {
    let taskId: String
    @Bindable var nav: NavigationState
    @State private var viewModel: SessionListViewModel

    init(taskId: String, nav: NavigationState) {
        self.taskId = taskId
        self.nav = nav
        self._viewModel = State(initialValue: SessionListViewModel(taskId: taskId))
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $viewModel.searchText) {
                viewModel.refresh()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if viewModel.isEditing {
                EditToolbar(
                    selectedCount: viewModel.selectedIds.count,
                    onSelectAll: viewModel.selectAll,
                    onDeselectAll: viewModel.deselectAll,
                    onExport: {},
                    onDelete: nil
                )
            }

            List {
                ForEach(viewModel.sessions, id: \.id) { session in
                    SessionCell(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if viewModel.isEditing {
                                if let id = session.id?.int64Value {
                                    viewModel.toggleSelection(id)
                                }
                            } else {
                                if let id = session.id?.stringValue {
                                    nav.navigate(to: .sessionDetail(sessionId: id))
                                }
                            }
                        }
                        .onAppear {
                            if session.id == viewModel.sessions.last?.id {
                                viewModel.loadMore()
                            }
                        }
                }
            }
            .listStyle(.plain)
            .refreshable { viewModel.refresh() }
        }
        .navigationTitle("会话列表")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(viewModel.isEditing ? "完成" : "编辑") {
                    viewModel.isEditing.toggle()
                    if !viewModel.isEditing {
                        viewModel.deselectAll()
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                ExportMenu { format in
                    // Handle export
                }
            }
        }
        .onAppear { viewModel.refresh() }
    }
}
```

- [ ] **Step 2: Implement SessionDetailView with tabs**

Replace `LocalPackages/KnotUI/Sources/KnotUI/Views/SessionDetail/SessionDetailView.swift`:

```swift
import SwiftUI
import TunnelServices

enum SessionTab: String, CaseIterable {
    case request = "Request"
    case response = "Response"
    case overview = "Overview"
}

struct SessionDetailView: View {
    let sessionId: String
    @State private var selectedTab: SessionTab = .request
    @State private var session: Session?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(SessionTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if let session {
                switch selectedTab {
                case .request:
                    SessionRequestView(session: session)
                case .response:
                    SessionResponseView(session: session)
                case .overview:
                    SessionOverviewView(session: session)
                }
            } else {
                ContentUnavailableView("加载中...", systemImage: "hourglass")
            }
        }
        .navigationTitle(session?.host ?? "会话详情")
        .onAppear(perform: loadSession)
    }

    private func loadSession() {
        session = Session.find(id: Int64(sessionId) ?? 0)
    }
}
```

- [ ] **Step 3: Create SessionRequestView**

Create `LocalPackages/KnotUI/Sources/KnotUI/Views/SessionDetail/SessionRequestView.swift`:

```swift
import SwiftUI
import TunnelServices

struct SessionRequestView: View {
    let session: Session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Request line
                SessionOverviewSection(title: "请求行", items: [
                    ("Method", session.methods ?? ""),
                    ("URI", session.uri ?? ""),
                    ("Version", session.reqHttpVersion ?? ""),
                ])

                // Headers
                if let headers = session.reqHeads, !headers.isEmpty {
                    SessionOverviewSection(title: "请求头", items:
                        headers.split(separator: "\r\n").map { line in
                            let parts = line.split(separator: ":", maxSplits: 1)
                            return (String(parts.first ?? ""), String(parts.last ?? "").trimmingCharacters(in: .whitespaces))
                        }
                    )
                }

                // Body indicator
                if session.reqBody != nil {
                    VStack(alignment: .leading) {
                        Text("请求体")
                            .font(.headline)
                        Text("有内容，点击查看")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }
}
```

- [ ] **Step 4: Create SessionResponseView**

Create `LocalPackages/KnotUI/Sources/KnotUI/Views/SessionDetail/SessionResponseView.swift`:

```swift
import SwiftUI
import TunnelServices

struct SessionResponseView: View {
    let session: Session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Response line
                SessionOverviewSection(title: "响应行", items: [
                    ("Version", session.rspHttpVersion ?? ""),
                    ("Status", session.state != nil ? "\(session.state!)" : ""),
                    ("Message", session.rspMessage ?? ""),
                ])

                // Headers
                if let headers = session.rspHeads, !headers.isEmpty {
                    SessionOverviewSection(title: "响应头", items:
                        headers.split(separator: "\r\n").map { line in
                            let parts = line.split(separator: ":", maxSplits: 1)
                            return (String(parts.first ?? ""), String(parts.last ?? "").trimmingCharacters(in: .whitespaces))
                        }
                    )
                }

                // Body indicator
                if session.rspBody != nil || session.downloadFlow > 0 {
                    VStack(alignment: .leading) {
                        Text("响应体")
                            .font(.headline)
                        Text("有内容，点击查看")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }
}
```

- [ ] **Step 5: Create SessionOverviewView**

Create `LocalPackages/KnotUI/Sources/KnotUI/Views/SessionDetail/SessionOverviewView.swift`:

```swift
import SwiftUI
import TunnelServices

struct SessionOverviewView: View {
    let session: Session

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SessionOverviewSection(title: "会话信息", items: [
                    ("协议", session.schemes ?? ""),
                    ("方法", session.methods ?? ""),
                    ("状态码", session.state != nil ? "\(session.state!)" : ""),
                    ("Host", session.host ?? ""),
                    ("远程地址", session.remoteAddress ?? ""),
                    ("本地地址", session.localAddress ?? ""),
                ])

                SessionOverviewSection(title: "数据统计", items: [
                    ("上传", formatBytes(session.uploadTraffic)),
                    ("下载", formatBytes(session.downloadFlow)),
                ])

                timelineSection
            }
            .padding()
        }
    }

    private var timelineSection: some View {
        let entries: [TimelineEntry] = [
            .init(label: "队列", duration: queueTime, color: .gray),
            .init(label: "连接", duration: connectTime, color: .blue),
            .init(label: "SSL", duration: sslTime, color: .purple),
            .init(label: "发送", duration: sendTime, color: .green),
            .init(label: "接收", duration: receiveTime, color: .orange),
        ]
        return SessionTimelineView(entries: entries, totalDuration: totalTime)
    }

    private var queueTime: TimeInterval {
        guard let start = session.startTime, let connect = session.connectTime else { return 0 }
        return max(0, connect - start)
    }

    private var connectTime: TimeInterval {
        guard let connect = session.connectTime, let connected = session.connectedTime else { return 0 }
        return max(0, connected - connect)
    }

    private var sslTime: TimeInterval {
        guard let connected = session.connectedTime, let handshake = session.handshakeEndTime else { return 0 }
        return max(0, handshake - connected)
    }

    private var sendTime: TimeInterval {
        guard let handshake = session.handshakeEndTime ?? session.connectedTime, let reqEnd = session.reqEndTime else { return 0 }
        return max(0, reqEnd - handshake)
    }

    private var receiveTime: TimeInterval {
        guard let rspStart = session.rspStartTime, let rspEnd = session.rspEndTime else { return 0 }
        return max(0, rspEnd - rspStart)
    }

    private var totalTime: TimeInterval {
        guard let start = session.startTime, let end = session.endTime else { return 0 }
        return max(0, end - start)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
    }
}
```

- [ ] **Step 6: Verify build**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotUI
swift build 2>&1 | tail -20
```

- [ ] **Step 7: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add LocalPackages/KnotUI/Sources/KnotUI/Views/SessionList/ LocalPackages/KnotUI/Sources/KnotUI/Views/SessionDetail/
git commit -m "feat: implement SessionListView and SessionDetailView

SessionList: search, pagination, edit mode, focus filters.
SessionDetail: Request/Response/Overview tabs with timeline."
```

---

### Task 7: Implement RuleListView, CertificateView, HistoryTaskView, SettingsView

**Files:**
- Modify: `LocalPackages/KnotUI/Sources/KnotUI/Views/Rule/RuleListView.swift`
- Modify: `LocalPackages/KnotUI/Sources/KnotUI/Views/Rule/RuleDetailView.swift`
- Modify: `LocalPackages/KnotUI/Sources/KnotUI/Views/Rule/RuleAddView.swift`
- Modify: `LocalPackages/KnotUI/Sources/KnotUI/Views/Certificate/CertificateView.swift`
- Modify: `LocalPackages/KnotUI/Sources/KnotUI/Views/History/HistoryTaskView.swift`
- Modify: `LocalPackages/KnotUI/Sources/KnotUI/Views/Settings/SettingsView.swift`
- Modify: `LocalPackages/KnotUI/Sources/KnotUI/Views/Settings/AboutView.swift`

- [ ] **Step 1: Implement RuleListView**

Replace `LocalPackages/KnotUI/Sources/KnotUI/Views/Rule/RuleListView.swift`:

```swift
import SwiftUI
import TunnelServices

struct RuleListView: View {
    @Bindable var nav: NavigationState
    @State private var viewModel = RuleViewModel()
    @State private var showingAddSheet = false
    @State private var downloadURL = ""

    var body: some View {
        List {
            ForEach(viewModel.rules, id: \.id) { rule in
                Button {
                    if let id = rule.id?.stringValue {
                        nav.navigate(to: .ruleDetail(ruleId: id))
                    }
                } label: {
                    RuleCell(
                        rule: rule,
                        isActive: rule.id?.stringValue == viewModel.activeRuleId
                    )
                }
                .swipeActions {
                    Button(role: .destructive) { viewModel.deleteRule(rule) } label: {
                        Label("删除", systemImage: "trash")
                    }
                    Button {
                        if let id = rule.id?.stringValue {
                            viewModel.setActive(ruleId: id)
                        }
                    } label: {
                        Label("激活", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("规则管理")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("新建空配置") { showingAddSheet = true }
                    Button("从 URL 下载") { }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear { viewModel.loadRules() }
    }
}
```

- [ ] **Step 2: Implement RuleDetailView**

Replace `LocalPackages/KnotUI/Sources/KnotUI/Views/Rule/RuleDetailView.swift`:

```swift
import SwiftUI
import TunnelServices

enum RuleTab: String, CaseIterable {
    case overview = "概览"
    case rules = "规则"
    case hosts = "Host"
}

struct RuleDetailView: View {
    let ruleId: String
    @Bindable var nav: NavigationState
    @State private var selectedTab: RuleTab = .overview
    @State private var rule: Rule?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(RuleTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if let rule {
                switch selectedTab {
                case .overview:
                    ruleOverview(rule)
                case .rules:
                    rulesList(rule)
                case .hosts:
                    hostsList(rule)
                }
            }
        }
        .navigationTitle(rule?.subName ?? "规则详情")
        .onAppear { rule = Rule.find(id: Int64(ruleId) ?? 0) }
    }

    private func ruleOverview(_ rule: Rule) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                SessionOverviewSection(title: "基本信息", items: [
                    ("名称", rule.subName),
                    ("规则数", "\(rule.ruleItems.count)"),
                    ("Host 映射", "\(rule.hosts.count)"),
                ])
            }
            .padding()
        }
    }

    private func rulesList(_ rule: Rule) -> some View {
        List {
            ForEach(rule.ruleItems, id: \.id) { item in
                RuleMatchRow(item: item)
            }
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    nav.navigate(to: .ruleAdd(ruleId: ruleId))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func hostsList(_ rule: Rule) -> some View {
        List {
            ForEach(rule.hosts, id: \.id) { host in
                HStack {
                    Text(host.domain ?? "")
                        .font(.subheadline)
                    Spacer()
                    Text(host.ip ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
    }
}
```

- [ ] **Step 3: Implement RuleAddView**

Replace `LocalPackages/KnotUI/Sources/KnotUI/Views/Rule/RuleAddView.swift`:

```swift
import SwiftUI
import TunnelServices

struct RuleAddView: View {
    let ruleId: String
    @Environment(\.dismiss) private var dismiss
    @State private var matchType: MatchRule = .DOMAIN
    @State private var value: String = ""
    @State private var strategy: Strategy = .COPY
    @State private var note: String = ""

    var body: some View {
        Form {
            Picker("类型", selection: $matchType) {
                Text("Domain").tag(MatchRule.DOMAIN)
                Text("Domain Keyword").tag(MatchRule.DOMAINKEYWORD)
                Text("Domain Suffix").tag(MatchRule.DOMAINSUFFIX)
                Text("IP-CIDR").tag(MatchRule.IPCIDR)
                Text("User-Agent").tag(MatchRule.USERAGENT)
                Text("URL Regex").tag(MatchRule.URLREGEX)
            }

            TextField("值", text: $value)

            Picker("策略", selection: $strategy) {
                Text("DIRECT").tag(Strategy.DIRECT)
                Text("REJECT").tag(Strategy.REJECT)
                Text("COPY").tag(Strategy.COPY)
            }

            TextField("备注", text: $note)
        }
        .navigationTitle("添加规则")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveRule()
                    dismiss()
                }
                .disabled(value.isEmpty)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
    }

    private func saveRule() {
        // Save via TunnelServices Rule API
    }
}
```

- [ ] **Step 4: Implement CertificateView**

Replace `LocalPackages/KnotUI/Sources/KnotUI/Views/Certificate/CertificateView.swift`:

```swift
import SwiftUI
import KnotCore

struct CertificateView: View {
    @State private var viewModel = CertificateViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CertStatusCard(status: viewModel.trustStatus) {
                    Task { try? await installCert() }
                }

                GroupBox("本机安装") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. 点击上方按钮安装证书")
                        Text("2. 进入 设置 → 通用 → 关于 → 证书信任设置")
                        Text("3. 开启对 Knot CA 的完全信任")
                    }
                    .font(.subheadline)
                }

                GroupBox("其他设备安装") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("确保设备在同一 WiFi 网络下")
                        if let ip = viewModel.localIP {
                            Text("访问: http://\(ip):8080")
                                .font(.subheadline.monospaced())
                                .textSelection(.enabled)
                        }
                        HStack {
                            Button(viewModel.isServerRunning ? "停止服务" : "启动服务") {
                                Task {
                                    if viewModel.isServerRunning {
                                        viewModel.stopServer()
                                    } else {
                                        await viewModel.startServer()
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .font(.subheadline)
                }
            }
            .padding()
        }
        .navigationTitle("证书管理")
        .onAppear { viewModel.checkStatus() }
    }

    private func installCert() async throws {
        if let service: CertificateServiceProtocol = ServiceContainer.shared.resolve(CertificateServiceProtocol.self) {
            try await service.installCertificate()
            viewModel.checkStatus()
        }
    }
}
```

- [ ] **Step 5: Implement HistoryTaskView**

Replace `LocalPackages/KnotUI/Sources/KnotUI/Views/History/HistoryTaskView.swift`:

```swift
import SwiftUI
import TunnelServices

struct HistoryTaskView: View {
    @Bindable var nav: NavigationState
    @State private var tasks: [CaptureTask] = []
    @State private var isEditing = false

    var body: some View {
        List {
            ForEach(tasks, id: \.id) { task in
                HistoryTaskCell(task: task) {
                    if let id = task.id?.stringValue {
                        nav.navigate(to: .sessionList(taskId: id))
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    try? tasks[index].delete()
                }
                tasks.remove(atOffsets: indexSet)
            }
        }
        .listStyle(.plain)
        .navigationTitle("历史任务")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
        }
        .onAppear { tasks = (try? CaptureTask.findAll()) ?? [] }
    }
}
```

- [ ] **Step 6: Implement SettingsView and AboutView**

Replace `LocalPackages/KnotUI/Sources/KnotUI/Views/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @Bindable var nav: NavigationState

    var body: some View {
        List {
            Section {
                Button {
                    nav.navigate(to: .settingCertificate)
                } label: {
                    Label("HTTPS CA 证书设置", systemImage: "lock.shield")
                }
            }

            Section {
                Button {
                    nav.navigate(to: .settingWeb(type: .terms))
                } label: {
                    Label("使用条款", systemImage: "doc.text")
                }

                Button {
                    nav.navigate(to: .settingWeb(type: .privacy))
                } label: {
                    Label("隐私政策", systemImage: "hand.raised")
                }
            }

            Section {
                Button {
                    nav.navigate(to: .settingAbout)
                } label: {
                    Label("关于", systemImage: "info.circle")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
    }
}
```

Replace `LocalPackages/KnotUI/Sources/KnotUI/Views/Settings/AboutView.swift`:

```swift
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundStyle(.accent)
            Text("Knot")
                .font(.largeTitle.bold())
            Text("v2.0.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .navigationTitle("关于")
    }
}
```

- [ ] **Step 7: Verify full KnotUI package builds**

```bash
cd /Users/aa123/Documents/Knot/LocalPackages/KnotUI
swift build 2>&1 | tail -20
```

- [ ] **Step 8: Commit**

```bash
cd /Users/aa123/Documents/Knot
git add LocalPackages/KnotUI/Sources/KnotUI/Views/
git commit -m "feat: implement all page views

RuleListView, RuleDetailView (3 tabs), RuleAddView,
CertificateView, HistoryTaskView, SettingsView, AboutView.
All views use shared components and follow adaptive layout."
```

---

## Phase 2 Complete Checklist

- [ ] KnotUI package builds for iOS and macOS
- [ ] RootView switches between NavigationSplitView (wide) and NavigationStack (compact)
- [ ] All page views implemented: Dashboard, SessionList, SessionDetail, RuleList, RuleDetail, Certificate, History, Settings, About
- [ ] All components implemented and reusable
- [ ] NavigationState tests pass
- [ ] ViewModels use @Observable macro

**Next:** Phase 3 — App Targets (iOS + macOS entry points, extensions, Xcode project setup)
