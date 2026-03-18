# 05 - SOCKS4/5 代理

## Netty 对应模块
`codec-socks` — SocksMessage, Socks5CommandRequest, Socks5InitialRequest
`handler-proxy` — Socks4ProxyHandler, Socks5ProxyHandler

## 功能描述
在 HTTP 代理基础上增加 SOCKS5 代理支持：
- 支持任意 TCP 协议的代理（不限于 HTTP/HTTPS）
- 支持 SOCKS5 认证（用户名/密码）
- 可作为全局 TCP 代理使用

## 为什么有价值
- **超越 HTTP 代理**: 当前只能抓 HTTP/HTTPS，SOCKS5 可以代理任意 TCP
- **与 tun2socks 配合**: Packet Tunnel 模式可以将所有 TCP 流量转为 SOCKS5
- **第三方 App 支持**: 很多开发工具原生支持 SOCKS5 代理
- swift-nio-extras 已提供 `NIOSOCKS` 模块

## 实现思路

```swift
// TunnelServices/Proxy/SOCKSServer.swift

// 使用 swift-nio-extras 的 NIOSOCKS 模块
import NIOSOCKS

public class SOCKSProxyServer {
    func start(port: Int = 1080)

    // SOCKS5 握手流程:
    // 1. Client → Server: Version(5) + AuthMethods
    // 2. Server → Client: Version(5) + SelectedAuth
    // 3. Client → Server: ConnectRequest(host, port)
    // 4. Server → Client: ConnectResponse(success)
    // 5. 双向数据透传 (同 TunnelHandler)
}
```

### 协议抓取扩展
SOCKS5 建立连接后，可以通过首字节检测应用层协议：

```
建立 SOCKS5 连接后的第一批数据:
  0x16 0x03 → TLS ClientHello → 走 MITMHandler
  "GET " / "POST" → HTTP → 走 HTTPCaptureHandler
  其他 → 记录原始字节流
```

### 集成点
- 在 `ProxyServer` 中额外监听 1080 端口
- SOCKS5 连接建立后复用 `ProtocolRouter` 进行协议检测
- 已有的 `NIOSOCKS` SPM 依赖可直接使用

## 难度评估
**中** — NIOSOCKS 处理 SOCKS5 握手，复用现有的 ProtocolRouter + TunnelHandler。
