# 18 - 请求重放 / API Mock

## Netty 对应功能
无直接对应，但 Netty 的 `EmbeddedChannel` 和 `HttpObjectAggregator` 提供了基础设施。

## 功能描述
对已捕获的 HTTP 请求进行重放和 Mock：

### 请求重放
- 从 Session 列表选择一个已捕获的请求
- 一键重新发送完全相同的请求
- 可以修改请求头/请求体后重发
- 对比两次响应的差异

### API Mock / 映射
- 为指定 URL 配置固定响应（Mock）
- 将请求重定向到另一个服务器（Map Remote）
- 将请求映射到本地文件（Map Local）
- 支持正则匹配 URL

## 为什么有价值
- **API 调试**: 修改参数后快速重试，不需要操作 App
- **Mock 服务**: 不依赖后端，直接在代理层返回假数据
- **A/B 测试**: 将部分请求指向测试环境
- Charles Proxy 的 Repeat/Map Remote/Map Local 是最受欢迎的功能

## 实现思路

### 请求重放

```swift
// TunnelServices/Replay/RequestReplayer.swift

public class RequestReplayer {
    /// 重放一个已捕获的 Session
    public static func replay(
        session: Session,
        modifications: RequestModification? = nil
    ) async throws -> ReplayResult

    struct RequestModification {
        var headers: [String: String]?
        var body: Data?
        var host: String?
    }

    struct ReplayResult {
        let statusCode: Int
        let headers: [(String, String)]
        let body: Data
        let latency: TimeInterval
    }
}
```

### API Mock

```swift
// TunnelServices/Mock/MockRule.swift

public struct MockRule {
    let urlPattern: String       // 正则或通配符
    let method: String?          // GET/POST/nil=全部
    let responseStatus: Int      // 200
    let responseHeaders: [String: String]
    let responseBody: Data       // 固定响应体
    let latencyMs: Int           // 模拟延迟
    let enabled: Bool
}

// 在 HTTPCaptureHandler 中拦截:
if let mock = MockRuleManager.match(url: fullURL, method: method) {
    // 直接返回 Mock 响应，不连接真实服务器
    let response = HTTPResponseHead(version: .http1_1, status: .custom(code: mock.responseStatus, ...))
    context.write(.head(response))
    context.write(.body(.byteBuffer(ByteBuffer(data: mock.responseBody))))
    context.writeAndFlush(.end(nil))
    return
}
```

## 难度评估
**高** — 重放本身简单（构造 URLRequest），Mock 拦截需要在管道中插入判断逻辑，UI 需要规则编辑器。
