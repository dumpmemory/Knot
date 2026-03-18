# 02 - 流量整形 / 弱网模拟

## Netty 对应模块
`handler/traffic` — ChannelTrafficShapingHandler, GlobalTrafficShapingHandler, TrafficCounter

## 功能描述
在代理管道中插入流量控制 handler，实现：
- **限速**: 限制上传/下载带宽（如模拟 3G 网络 384kbps）
- **延迟**: 给每个请求/响应添加固定延迟（如 200ms RTT）
- **丢包**: 按概率丢弃数据包（如 5% 丢包率）
- **弱网预设**: 2G/3G/4G/WiFi 弱信号等场景一键切换

## 为什么有价值
- **移动开发必备**: 测试 App 在弱网环境下的表现
- **性能测试**: 验证超时、重试、降级策略是否正常
- **竞品分析**: 对比不同 App 在相同网络条件下的体验
- Charles Proxy 的 "Throttle" 功能是付费版核心功能之一

## 实现思路

```swift
// TunnelServices/Proxy/TrafficShaper.swift

public struct NetworkProfile {
    let name: String
    let downloadBytesPerSecond: Int  // 0 = unlimited
    let uploadBytesPerSecond: Int
    let latencyMs: Int               // 额外延迟
    let packetLossRate: Double       // 0.0 ~ 1.0

    public static let unlimited = NetworkProfile(name: "No Limit", ...)
    public static let wifi = NetworkProfile(name: "WiFi", download: 30_000_000, ...)
    public static let lte = NetworkProfile(name: "4G LTE", download: 12_000_000, ...)
    public static let edge3G = NetworkProfile(name: "3G", download: 384_000, ...)
    public static let edge2G = NetworkProfile(name: "2G", download: 50_000, ...)
    public static let lossy = NetworkProfile(name: "Lossy Network", ..., packetLoss: 0.05)
}

public class TrafficShapingHandler: ChannelDuplexHandler {
    // 入站: 控制读取速率 (下载限速)
    // 出站: 控制写入速率 (上传限速)
    // 使用 eventLoop.scheduleTask 实现延迟
    // 使用 random 实现概率丢包
}
```

### 集成点
在 `ProtocolRouter` 构建管道时，根据当前 NetworkProfile 插入 TrafficShapingHandler：
```swift
if ProxyConfig.networkProfile != .unlimited {
    pipeline.addHandler(TrafficShapingHandler(profile: currentProfile))
}
```

## 难度评估
**中** — 限速和延迟用 NIO 的 `scheduleTask` 实现比较直接，丢包用随机数。关键是令牌桶算法的精确实现。
