# 04 - DNS 协议解析与捕获

## Netty 对应模块
`codec-dns` — DnsQuery, DnsResponse, DnsRecord, DnsRecordType, DnsMessageUtil, DatagramDnsQueryDecoder, DatagramDnsResponseEncoder

## 功能描述
拦截和解析 DNS 查询/响应：
- 记录哪个 App 查询了哪个域名
- 显示 DNS 响应的 IP 地址
- 检测 DNS 劫持或异常解析
- 支持 DNS over UDP (端口 53) 和 DNS over HTTPS (DoH)

## 为什么有价值
- **隐私审计**: 查看 App 在后台访问了哪些域名
- **调试**: 确认域名解析结果是否正确
- **安全**: 检测恶意 DNS 劫持
- DNS 是所有网络请求的第一步，抓取 DNS 能看到全貌

## 实现思路

### 方案 A: DoH 抓取（当前架构可实现）

DNS over HTTPS 是标准 HTTPS 请求（`content-type: application/dns-message`），当前 MITM 架构可以直接捕获：

```swift
// 在 HTTPCaptureHandler 中检测 DoH:
if head.headers["content-type"].first == "application/dns-message" ||
   head.uri.contains("/dns-query") {
    recorder.session.schemes = "DoH"
    // 解析 DNS wire format
}

// DNS 报文解析:
public struct DNSParser {
    struct Query {
        let name: String       // "api.github.com"
        let type: RecordType   // A, AAAA, CNAME, MX...
    }
    struct Answer {
        let name: String
        let type: RecordType
        let ttl: UInt32
        let data: String       // "185.199.108.133"
    }
    static func parse(_ data: Data) -> DNSMessage
}
```

### 方案 B: UDP DNS 抓取（需要架构扩展）

传统 DNS 使用 UDP 端口 53，需要 Packet Tunnel 模式：

```
NEPacketTunnelProvider
    → 拦截 UDP 包
    → 端口 53 → DNS 解析器
    → 其他端口 → 透传
```

这需要之前讨论的用户态协议栈支持。

## 推荐路径
先实现 **方案 A (DoH)**，零架构改动。iOS 15+ 越来越多 App 使用 DoH，覆盖率逐渐提高。

## 难度评估
**中** — DoH 解析简单（只需 DNS wire format 解码器），UDP DNS 需要 Packet Tunnel 重构。
