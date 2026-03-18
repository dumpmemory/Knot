# 03 - IP 过滤 / 访问控制

## Netty 对应模块
`handler/ipfilter` — RuleBasedIpFilter, IpSubnetFilter, UniqueIpFilter

## 功能描述
在代理接受连接时，按 IP 地址或子网过滤连接：
- **白名单模式**: 只允许指定 IP/子网的设备通过代理
- **黑名单模式**: 拒绝指定 IP 的连接
- **唯一 IP**: 每个 IP 只允许一个连接（防止连接洪泛）

## 为什么有价值
- 局域网抓包时只关注特定设备
- WiFi 代理模式下防止未授权设备使用
- 安全审计：限制可接入的客户端

## 实现思路

```swift
// TunnelServices/Proxy/IPFilter.swift

public class IPFilterHandler: ChannelInboundHandler {
    enum Mode { case whitelist, blacklist }

    let rules: [IPFilterRule]
    let mode: Mode

    func channelActive(context: ChannelHandlerContext) {
        guard let remoteAddress = context.channel.remoteAddress else { return }
        let allowed = evaluate(remoteAddress)
        if !allowed {
            context.close(promise: nil)
            return
        }
        context.fireChannelActive()
    }
}

public struct IPFilterRule {
    let subnet: String   // "192.168.1.0/24" or "10.0.0.5"
    let action: Action   // .accept / .reject
}
```

### 集成点
在 `ProxyServer` 的 `ServerBootstrap.childChannelInitializer` 中，在 ProtocolRouter 之前添加：
```swift
channel.pipeline.addHandler(IPFilterHandler(rules: currentRules))
```

## 难度评估
**低** — CIDR 子网匹配算法简单，NIO 的 `SocketAddress` 已提供 IP 解析。
