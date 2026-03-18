# 13 - 管道日志 / 调试模式

## Netty 对应模块
`handler/logging` — LoggingHandler

## 功能描述
在 NIO Pipeline 中插入日志 handler，记录每个 handler 处理数据的详细信息：
- 入站/出站事件类型
- 数据大小
- Handler 处理时间
- 错误和异常

## 价值
- 开发调试: 排查管道数据流问题
- 性能分析: 发现瓶颈 handler

## 实现思路
```swift
class PipelineLogger: ChannelDuplexHandler {
    func channelRead(context:, data:) {
        let start = DispatchTime.now()
        context.fireChannelRead(data)
        let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        AxLogger.log("[\(name)] read: \(dataSize)B in \(elapsed)ns")
    }
}
```

## 难度: 低
