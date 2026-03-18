# Knot 三端适配设计文档

> Mac / iPad / iPhone 全平台支持 — SwiftUI UI 重写 + macOS 网络层适配

## 1. 概述

### 目标
将 Knot（iOS 抓包工具）从 UIKit 单平台应用改造为 Mac、iPad、iPhone 三端可用的应用，采用 SwiftUI 重写 UI 层，同时适配 macOS 的 System Extension 抓包能力。

### 约束
- 最低支持版本：iOS 17 / macOS 14
- 架构方案：多 Target + 共享 Swift Package（方案 B）
- UI 复用：一套页面组件，宽屏/窄屏通过 `horizontalSizeClass` 自适应
- 左栏 = 竖屏完整页面，右栏 = 左栏操作产生的详情内容

---

## 2. 项目结构

### 目录布局

```
Knot/
├── KnotApp-iOS/                    # iOS App Target (iPhone + iPad)
│   ├── KnotApp_iOS.entitlements
│   ├── Info.plist
│   ├── iOSApp.swift                # @main 入口
│   └── Services/
│       ├── iOSTunnelService.swift
│       └── iOSCertificateService.swift
│
├── KnotApp-macOS/                  # macOS App Target
│   ├── KnotApp_macOS.entitlements
│   ├── Info.plist
│   ├── macOSApp.swift              # @main 入口
│   └── Services/
│       ├── macOSTunnelService.swift
│       └── macOSCertificateService.swift
│
├── PacketTunnel-iOS/               # iOS Network Extension
│   ├── PacketTunnelProvider.swift
│   └── Info.plist
│
├── SystemExtension-macOS/          # macOS System Extension
│   ├── SystemExtensionProvider.swift
│   └── Info.plist
│
├── Resources/
│   └── Http/                       # 证书安装 HTML 页面（中英文）
│       ├── index.html
│       ├── privacy_en.html
│       └── privacy_cn.html
│
├── LocalPackages/
│   ├── KnotUI/                     # 共享 SwiftUI 视图层
│   │   ├── Package.swift
│   │   └── Sources/
│   │       ├── App/
│   │       │   ├── RootView.swift
│   │       │   └── NavigationState.swift
│   │       ├── Views/
│   │       │   ├── Dashboard/
│   │       │   │   └── DashboardView.swift
│   │       │   ├── SessionList/
│   │       │   │   └── SessionListView.swift
│   │       │   ├── SessionDetail/
│   │       │   │   ├── SessionDetailView.swift
│   │       │   │   ├── SessionRequestView.swift
│   │       │   │   ├── SessionResponseView.swift
│   │       │   │   └── SessionOverviewView.swift
│   │       │   ├── Rule/
│   │       │   │   ├── RuleListView.swift
│   │       │   │   ├── RuleDetailView.swift
│   │       │   │   └── RuleAddView.swift
│   │       │   ├── Certificate/
│   │       │   │   └── CertificateView.swift
│   │       │   ├── History/
│   │       │   │   └── HistoryTaskView.swift
│   │       │   └── Settings/
│   │       │       ├── SettingsView.swift
│   │       │       └── AboutView.swift
│   │       ├── ViewModels/
│   │       │   ├── AppState.swift
│   │       │   ├── SessionListViewModel.swift
│   │       │   ├── RuleViewModel.swift
│   │       │   └── CertificateViewModel.swift
│   │       └── Components/
│   │           ├── StateCardView.swift
│   │           ├── ProxyConfigView.swift
│   │           ├── CurrentTaskView.swift
│   │           ├── HistoryTaskCell.swift
│   │           ├── SessionCell.swift
│   │           ├── SessionHeaderList.swift
│   │           ├── SessionBodyPreview.swift
│   │           ├── SessionTimelineView.swift
│   │           ├── SessionOverviewSection.swift
│   │           ├── RuleCell.swift
│   │           ├── RuleMatchRow.swift
│   │           ├── CertStatusCard.swift
│   │           ├── SearchBar.swift
│   │           ├── FocusTagsView.swift
│   │           ├── ExportMenu.swift
│   │           ├── EditToolbar.swift
│   │           └── PlaceholderView.swift
│   │
│   ├── KnotCore/                   # 共享业务逻辑与数据模型
│   │   ├── Package.swift
│   │   └── Sources/
│   │       ├── Models/
│   │       │   ├── Session.swift
│   │       │   ├── CaptureTask.swift
│   │       │   ├── RuleConfig.swift
│   │       │   └── MatchRule.swift
│   │       ├── Database/
│   │       │   ├── DatabaseManager.swift
│   │       │   └── ActiveSQLite/
│   │       ├── Services/
│   │       │   ├── TunnelServiceProtocol.swift
│   │       │   ├── CertificateServiceProtocol.swift
│   │       │   ├── ServiceContainer.swift
│   │       │   ├── ExportService.swift
│   │       │   └── RuleService.swift
│   │       └── Extensions/
│   │
│   ├── TunnelServices/             # 现有网络层（SPM 化）
│   │   ├── Package.swift
│   │   └── Sources/
│   │       ├── Codec/
│   │       ├── Proxy/
│   │       ├── Handler/
│   │       ├── Detector/
│   │       ├── HttpService/
│   │       ├── PacketCapture/
│   │       ├── Config/
│   │       ├── Rule/
│   │       ├── Export/              # PCAPExporter 等
│   │       └── Utils/
│   │
│   ├── SwiftQuiche/                # 现有
│   └── SwiftLsquic/                # 现有
│
├── Frameworks/                     # xcframework (quiche, lsquic)
└── Knot.xcodeproj
```

### Package 依赖关系

```
KnotApp-iOS  ──→ KnotUI ──→ KnotCore ──→ TunnelServices
KnotApp-macOS ──→ KnotUI ──→ KnotCore ──→ TunnelServices
PacketTunnel-iOS ──────────→ KnotCore ──→ TunnelServices
SystemExtension-macOS ─────→ KnotCore ──→ TunnelServices
```

---

## 3. UI 架构设计

### 3.1 自适应布局策略

通过 `@Environment(\.horizontalSizeClass)` 判断布局模式：

- **宽屏模式**（`.regular`）：Mac / iPad 横屏 → `NavigationSplitView` 左右两栏
- **窄屏模式**（`.compact`）：iPhone / iPad 竖屏 → `NavigationStack` 单栏

核心复用原则：**左栏 = 竖屏的完整页面，右栏 = 左栏操作产生的详情内容**。每个页面组件不感知自己在左栏还是全屏，只负责内容渲染和触发导航动作。

### 3.2 导航状态模型

```swift
@Observable class NavigationState {
    var primaryPage: PrimaryPage = .dashboard
    var detailPath: [DetailDestination] = []

    func navigate(to destination: DetailDestination) {
        detailPath.append(destination)
    }

    func switchPrimary(to page: PrimaryPage) {
        primaryPage = page
        detailPath = []
    }
}

enum PrimaryPage: Hashable {
    case dashboard
    case sessionList(taskId: String)
    case ruleList
    case certificate
    case historyTask
    case settings
}

enum DetailDestination: Hashable {
    case sessionList(taskId: String)
    case sessionDetail(sessionId: String)
    case ruleDetail(ruleId: String)
    case ruleAdd
    case settingCertificate
    case settingAbout
    case settingWeb(type: WebDocType)
}
```

### 3.3 根视图

```swift
struct RootView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @State var nav = NavigationState()

    var body: some View {
        if sizeClass == .regular {
            NavigationSplitView {
                PrimaryPageView(page: nav.primaryPage, nav: nav)
            } detail: {
                NavigationStack(path: $nav.detailPath) {
                    PlaceholderView()
                        .navigationDestination(for: DetailDestination.self) { dest in
                            DetailPageView(destination: dest, nav: nav)
                        }
                }
            }
        } else {
            NavigationStack(path: $nav.detailPath) {
                PrimaryPageView(page: nav.primaryPage, nav: nav)
                    .navigationDestination(for: DetailDestination.self) { dest in
                        DetailPageView(destination: dest, nav: nav)
                    }
            }
        }
    }
}
```

### 3.4 宽屏布局

```
┌──────────────┬───────────────────────────────┐
│              │                               │
│  左栏         │  右栏                         │
│  = 竖屏同款   │  = 左栏操作触发的详情页         │
│  页面组件     │                               │
│              │  Dashboard 点击任务             │
│              │  → SessionListView             │
│              │                               │
│              │  SessionList 点击会话           │
│              │  → SessionDetailView           │
│              │                               │
├──────────────│  RuleList 点击规则              │
│ 首页 规则 证书 设置│  → RuleDetailView           │
└──────────────┴───────────────────────────────┘
  底部切换栏
```

左栏底部放置页面切换栏，与窄屏 Dashboard 底部的快捷入口一致。

### 3.5 页面组件复用表

| 组件 | 窄屏 | 宽屏左栏 | 宽屏右栏 |
|------|------|---------|---------|
| DashboardView | 首页全屏 | 左栏首页 | — |
| SessionListView | push | 左栏（直接进入时） | 右栏（从 Dashboard 跳转） |
| SessionDetailView | push | — | 右栏 |
| RuleListView | push | 左栏 | — |
| RuleDetailView | push | — | 右栏 |
| CertificateView | push | 左栏 | — |
| HistoryTaskView | push | 左栏 | — |
| SettingsView | push | 左栏 | — |

### 3.6 页面详细功能

#### Dashboard（仪表盘）
- VPN 启动/停止控制（StateCardView）
- 连接状态指示（颜色 + 文字）
- 证书信任状态提示（未安装时显示引导）
- 代理配置：本机监听 / WiFi 监听开关及端口（ProxyConfigView）
- 当前任务：计时器、上传/下载流量统计（CurrentTaskView）
- 最近 5 个历史任务快捷入口
- 底部快捷入口：规则、证书、设置

#### SessionList（会话列表）
- 搜索：关键字、域名、方法、状态码
- Focus 筛选标签
- 搜索历史
- 分页加载（50条/页）+ 下拉刷新
- 编辑模式：多选 → 批量导出（URL/cURL/HAR/PCAP）
- 每个 Cell：方法标签、域名、路径、状态码、大小、耗时

#### SessionDetail（会话详情）
- 三个 Tab：Request / Response / Overview
- **Request Tab**：请求行、Header 列表（可展开）、Body 预览
- **Response Tab**：响应行、Header 列表、Body 预览（语法高亮/图片预览）
- **Overview Tab**：协议信息、数据统计、时间线（队列→连接→SSL→发送→接收）
- 导出按钮

#### RuleList（规则管理）
- 规则配置列表，当前激活标记
- 新建 / 下载配置
- 规则详情编辑：概览（General）+ 匹配规则列表（Rule）+ Host 映射（Host）
- 匹配规则类型：Domain / Domain Keyword / Domain Suffix / User-Agent / URL Regex / IP-CIDR
- 默认策略：DIRECT / REJECT / COPY / DEFAULT

#### Certificate（证书管理）
- 证书状态卡片（未安装 / 已安装 / 已信任）
- 本机安装引导（iOS: 设置手动信任 / macOS: Keychain 安装）
- 其他设备安装（WiFi + HTTP Server）
- 导出/分享证书

#### HistoryTask（历史任务）
- 所有历史任务列表
- 编辑模式：批量导出/删除
- 点击进入对应任务的会话列表

#### Settings（设置）
- 证书设置入口
- 反馈（邮件）
- 使用条款 / 隐私政策
- 关于页面（版本号）

### 3.7 状态管理

```swift
@Observable class AppState {
    var vpnStatus: TunnelStatus
    var currentTask: CaptureTask?
    var certificateStatus: CertTrustStatus
    var networkType: NetworkType
    var activeRule: RuleConfig?
}

@Observable class SessionListViewModel {
    var sessions: [Session]
    var searchText: String
    var focusFilters: [FocusFilter]
    var isEditing: Bool
    var currentPage: Int
}

@Observable class RuleViewModel {
    var rules: [RuleConfig]
    var activeRuleId: String?
}

@Observable class CertificateViewModel {
    var trustStatus: CertTrustStatus
    var isServerRunning: Bool
}
```

使用 iOS 17 的 `@Observable` 宏，配合 SwiftUI 自动依赖追踪。

### 3.8 可复用组件清单

```
Components/
├── StateCardView          # VPN 状态卡片
├── ProxyConfigView        # 代理配置（本机/WiFi）
├── CurrentTaskView        # 当前任务卡片（计时+流量）
├── HistoryTaskCell        # 任务列表行
├── SessionCell            # 会话列表行
├── SessionHeaderList      # Header 键值对列表
├── SessionBodyPreview     # Body 预览（语法高亮/图片）
├── SessionTimelineView    # 时间线可视化
├── SessionOverviewSection # 概览信息段
├── RuleCell               # 规则列表行
├── RuleMatchRow           # 匹配规则行
├── CertStatusCard         # 证书状态卡片
├── SearchBar              # 搜索栏 + 筛选
├── FocusTagsView          # Focus 筛选标签
├── ExportMenu             # 导出菜单（URL/cURL/HAR/PCAP）
├── EditToolbar            # 编辑模式工具栏
└── PlaceholderView        # 空状态 / 未选择占位
```

---

## 4. 网络层设计

### 4.1 TunnelServices 现有能力清单

TunnelServices 已实现以下协议和功能，SPM 化后全部保留：

| 类别 | 功能 | 关键文件 |
|------|------|---------|
| HTTP/HTTPS 抓包 | 核心 MITM 抓包 | HTTPHandler, HTTPSHandler |
| SOCKS5 代理 | SOCKS5 协议支持 | SOCKSProxyHandler |
| WebSocket 抓包 | WebSocket 帧捕获 | WebSocketCaptureHandler |
| HTTP/2 抓包 | HTTP/2 多路复用捕获 | HTTP2CaptureHandler |
| HTTP/3 抓包 | QUIC/HTTP3 捕获 | quiche/lsquic 集成 |
| gRPC 抓包 | gRPC 协议解析 | GRPCCaptureHandler |
| DNS 解析 | DNS 请求/响应捕获 | DNS Codec |
| MQTT 解析 | MQTT 协议解析 | MQTT Codec |
| 断点/重写 | 暂停并编辑请求/响应 | BreakpointHandler |
| 请求重放 | Mock/Map Local/Map Remote | RequestReplayer |
| 流量整形 | 带宽限速 | TrafficShapingHandler |
| PCAP 导出 | 标准 PCAP 格式导出 | PCAPExporter |
| 协议检测 | 自动识别流量协议 | ProtocolDetector |

> 注：UI 层当前仅展示 HTTP/HTTPS 会话。断点/重写、请求重放、流量整形等高级功能的 UI 入口将在后续版本中添加，TunnelServices 层已具备完整支持。

### 4.2 协议抽象层

```swift
// KnotCore/Sources/Services/TunnelServiceProtocol.swift
@Observable class TunnelServiceState {
    var status: TunnelStatus = .disconnected
}

protocol TunnelServiceProtocol: AnyObject {
    var state: TunnelServiceState { get }

    func startCapture(config: CaptureConfig) async throws
    func stopCapture() async throws
    func installExtension() async throws
    func uninstallExtension() async throws
}

protocol CertificateServiceProtocol {
    var trustStatus: CertTrustStatus { get }

    func installCertificate() async throws
    func exportCertificate() -> Data
    func checkTrustStatus() -> CertTrustStatus
    func startLocalServer(port: Int) async throws
}

enum TunnelStatus: Equatable {
    case invalid
    case disconnected
    case connecting
    case connected(since: Date)
    case disconnecting
    case reasserting
    case error(String)
}

enum CertTrustStatus {
    case notInstalled
    case installed
    case trusted
}
```

### 4.3 iOS 实现

`iOSTunnelService`：基于现有 `NETunnelProviderManager` 逻辑，封装为 `TunnelServiceProtocol` 实现。PacketTunnelProvider 保持不变，继续调用 TunnelServices 中的 ProxyServer、ProtocolDetector、各 Handler。

`iOSCertificateService`：保持现有逻辑 — 本地安装引导 + HTTP Server 给其他设备下载。

### 4.4 macOS 实现

`macOSTunnelService`：
- 使用 `OSSystemExtensionManager` 提交激活请求
- 用户需在系统设置中批准 System Extension
- 抓包启动后同样通过 `NETunnelProviderManager` 管理隧道
- 核心抓包逻辑与 iOS 共享（TunnelServices）

`macOSCertificateService`：
- 通过 `Security.framework` 安装 CA 证书到 Keychain
- 使用 `SecTrustSettingsSetTrustSettings` 设置信任（需用户授权）
- 证书导出和本地 HTTP Server 与 iOS 共享逻辑

`MacPacketTunnelProvider`（SystemExtension-macOS）：
- 继承 `NEPacketTunnelProvider`
- 核心抓包逻辑调用 TunnelServices（与 iOS 共享）
- 差异点：DNS 配置方式、路由配置（通过少量条件编译处理）

### 4.5 IPC 架构（App ↔ Extension 通信）

现有 IPC 机制：
- **App Group**（`group.Lojii.NIO1901`）：共享 SQLite 数据库、配置文件
- **UDP Socket**（CocoaAsyncSocket / GCDAsyncUdpSocket）：实时流量计数器、状态更新

macOS 适配：
- App Group 在 macOS System Extension 中同样可用，标识符保持一致
- UDP Socket 通信在 macOS 上行为一致（localhost 通信），CocoaAsyncSocket 支持 macOS
- macOS System Extension 的沙盒限制不同于 iOS，需要在 entitlements 中声明 `com.apple.developer.system-extension.install` 和网络相关权限
- 如 CocoaAsyncSocket 在 macOS 下有兼容问题，备选方案：使用 `Network.framework` (NWConnection) 替换 UDP 通信

### 4.6 依赖注入

```swift
// iOS
@main struct KnotApp_iOS: App {
    init() {
        ServiceContainer.register(TunnelServiceProtocol.self, impl: iOSTunnelService())
        ServiceContainer.register(CertificateServiceProtocol.self, impl: iOSCertificateService())
    }
    var body: some Scene { WindowGroup { RootView() } }
}

// macOS
@main struct KnotApp_macOS: App {
    init() {
        ServiceContainer.register(TunnelServiceProtocol.self, impl: macOSTunnelService())
        ServiceContainer.register(CertificateServiceProtocol.self, impl: macOSCertificateService())
    }
    var body: some Scene {
        WindowGroup { RootView() }
            .defaultSize(width: 1100, height: 700)
    }
}
```

### 4.7 TunnelServices SPM 化改造

#### UIKit 依赖移除计划

TunnelServices 中多处文件 `import UIKit`，需逐一处理：

| 文件 | UIKit 用途 | 替换方案 |
|------|-----------|---------|
| Session.swift | NSObject 继承（via ASModel） | 改为纯 Swift struct/class，移除 ASModel 基类 |
| CaptureTask.swift | NSObject 继承 + CocoaAsyncSocket | 移除 NSObject，保留 GCDAsyncUdpSocket（已支持 macOS） |
| Rule.swift | NSObject 继承（via ASModel） | 同 Session.swift |
| MitmService.swift | UIKit 类型引用 | 替换为 Foundation 等价物 |
| 其他模型文件 | ASModel 基类 | 评估 ActiveSQLite ORM 的 macOS 兼容性；若 ASModel 强依赖 UIKit/NSObject，考虑替换为 GRDB 或直接 SQLite |

> ActiveSQLite ORM 的 ASModel 继承自 NSObject。需验证 `import Foundation`（而非 UIKit）是否足以提供 NSObject。在 macOS 上 Foundation 包含 NSObject，因此大多数情况下只需替换 import 即可。

#### 其他改造项

1. SQLite 路径改用 App Group container，通过注入传入
2. SwiftNIO 依赖天然跨平台，无需改动
3. AxLogger 迁移：现有 `Lib/AxLogger` 已包含 `AxLoggerOSX` target，优先评估直接使用；若不满足需求则统一替换为 `os.Logger`
4. quiche/lsquic xcframework 重新编译（见 4.8 前置任务）

### 4.8 前置任务（必须在开发前完成）

#### xcframework macOS 架构编译

现有 `CQuiche.xcframework` 和 `CLsquic.xcframework` **仅包含 iOS 架构**（ios-arm64、ios-arm64-simulator），缺少 macOS slice。这是确定性问题，非风险。

**所需步骤：**
1. 从 Cloudflare quiche 源码编译 macOS arm64 和 x86_64 静态库
2. 从 LiteSpeed lsquic 源码编译 macOS arm64 和 x86_64 静态库
3. 使用 `xcodebuild -create-xcframework` 重建包含 iOS + macOS 的 xcframework
4. 更新 SwiftQuiche 和 SwiftLsquic 的 Package.swift binaryTarget 路径

> 如果编译困难或耗时过长，可暂时在 macOS 上禁用 HTTP3 支持（通过条件编译），后续补充。

### 4.9 其他风险点

| 风险 | 影响 | 应对 |
|------|------|------|
| macOS SystemExtension 审核 | 需要特殊 entitlement | 开发阶段 SIP 关闭测试，发布需向 Apple 申请 |
| NETunnelProviderManager macOS 差异 | 路由/DNS 配置不同 | 条件编译 `#if os(macOS)` 仅在 Extension 入口处 |
| CocoaAsyncSocket macOS 兼容性 | UDP IPC 可能异常 | 备选 Network.framework NWConnection |

---

## 5. 数据迁移

从现有 UIKit 版本升级到新版本时：

- **SQLite 数据库**：Schema 不变，仅路径可能调整（确保 App Group container 路径一致）
- **证书文件**：CA 目录下的证书文件保持不变，新版本继续读取
- **规则配置**：INI 格式规则文件保持兼容
- **用户偏好**：UserDefaults 迁移到 App Group 共享域

---

## 6. 技术栈总结

| 层 | 技术 |
|----|------|
| UI 框架 | SwiftUI (iOS 17 / macOS 14) |
| 导航 | NavigationSplitView + NavigationStack |
| 状态管理 | @Observable 宏 |
| 布局自适应 | horizontalSizeClass |
| 网络框架 | SwiftNIO |
| 数据库 | SQLite (ActiveSQLite) |
| HTTP3 | quiche / lsquic |
| iOS 抓包 | NetworkExtension (PacketTunnel) |
| macOS 抓包 | SystemExtension + PacketTunnel |
| IPC | App Group + UDP Socket (CocoaAsyncSocket) |
| 包管理 | Swift Package Manager |
| 最低版本 | iOS 17 / macOS 14 |
