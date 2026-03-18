# 19 - 请求断点 / 数据注入

## Netty 对应功能
无直接对应。灵感来自 Netty 的 `ChannelDuplexHandler` 拦截能力和 Charles/Fiddler 的 Breakpoints 功能。

## 功能描述
在代理管道中设置"断点"，当匹配的请求/响应经过时暂停传输，允许用户查看和修改数据后再放行：

### 请求断点
- 拦截发往特定 URL 的请求
- 暂停请求，在 UI 中展示完整的请求头和请求体
- 用户可以修改任意字段（URL、Header、Body）
- 点击"继续"后将修改后的请求发送到服务器

### 响应断点
- 拦截特定 URL 的服务器响应
- 暂停响应，展示状态码、响应头、响应体
- 用户可以修改响应内容（如修改 JSON 数据）
- 修改后的响应发送给 App

### 自动注入（Rewrite 规则）
- 不需要手动暂停，自动按规则修改
- 添加/删除/修改请求头
- 替换请求体中的特定字符串
- 修改响应状态码
- 替换响应体内容

## 为什么有价值
- **最强大的调试功能**: 实时修改网络请求，不需要改代码
- **安全测试**: 注入恶意数据测试 App 的安全性
- **UI 测试**: 修改 API 响应来测试各种边界条件
- 这是 Charles Proxy 最核心的付费功能之一

## 实现思路

### 断点拦截 Handler

```swift
// TunnelServices/Proxy/BreakpointHandler.swift

public class BreakpointHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundIn = HTTPServerResponsePart

    // 请求到达时检查是否命中断点
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        if case .head(let head) = part, shouldBreak(head) {
            // 暂停管道传输
            context.channel.setOption(ChannelOptions.autoRead, value: false)

            // 通知 UI 层展示断点编辑器
            BreakpointManager.shared.pause(
                request: head,
                channel: context.channel
            ) { modifiedHead in
                // 用户编辑完成，继续传输
                context.fireChannelRead(self.wrapInboundOut(.head(modifiedHead)))
                context.channel.setOption(ChannelOptions.autoRead, value: true)
            }
            return
        }
        context.fireChannelRead(data)
    }
}

// 断点规则
public struct BreakpointRule {
    let urlPattern: String         // "*.api.example.com/users/*"
    let method: String?            // nil = 全部
    let breakOnRequest: Bool       // 拦截请求?
    let breakOnResponse: Bool      // 拦截响应?
    let enabled: Bool
}
```

### 自动 Rewrite 规则

```swift
// TunnelServices/Proxy/RewriteRule.swift

public struct RewriteRule {
    let urlPattern: String

    // 请求修改
    let addRequestHeaders: [String: String]?
    let removeRequestHeaders: [String]?
    let replaceRequestBody: [(find: String, replace: String)]?

    // 响应修改
    let overrideStatusCode: Int?
    let addResponseHeaders: [String: String]?
    let removeResponseHeaders: [String]?
    let replaceResponseBody: [(find: String, replace: String)]?
}

// 在管道中自动应用:
class RewriteHandler: ChannelDuplexHandler {
    func channelRead(context:, data:) {
        // 自动修改请求头/体
    }
    func write(context:, data:) {
        // 自动修改响应头/体
    }
}
```

### 集成点
- BreakpointHandler 插入在 HTTPCaptureHandler 之前
- 通过 AppGroupIPC 通知主 App 显示断点 UI
- 用户操作后通过回调恢复管道

## 难度评估
**高** — 核心拦截逻辑不复杂（暂停 autoRead），但需要：
1. 跨进程通信（Network Extension → 主 App UI）
2. 断点编辑 UI
3. 规则管理 UI
4. 处理超时和用户取消
