# 07 - Redis 协议解析

## Netty 对应模块
`codec-redis` — RedisDecoder, RedisEncoder, RedisMessage, ArrayRedisMessage, BulkStringRedisMessage

## 功能描述
解析 Redis RESP (REdis Serialization Protocol) 协议流量：
- 显示 Redis 命令和响应（GET/SET/HGET/LPUSH 等）
- 解析 Key/Value 内容
- 统计命令频率和响应时间
- 检测慢查询和大 Key

## 为什么有价值
- **后端调试**: 直接查看 App 与 Redis 的交互
- **性能分析**: 发现 N+1 查询、热点 Key
- **安全**: 检测未加密的 Redis 连接
- Redis 使用 TCP 端口 6379

## RESP 协议格式

```
简单字符串: +OK\r\n
错误:       -ERR unknown command\r\n
整数:       :1000\r\n
批量字符串: $5\r\nhello\r\n
数组:       *2\r\n$3\r\nGET\r\n$4\r\nname\r\n
```

## 实现思路

```swift
// TunnelServices/Codec/RedisDecoder.swift

public enum RedisValue {
    case simpleString(String)
    case error(String)
    case integer(Int64)
    case bulkString(Data?)
    case array([RedisValue]?)
}

public class RedisDecoder {
    static func decode(_ buffer: ByteBuffer) -> [RedisValue]
    static func formatCommand(_ values: [RedisValue]) -> String
    // 例: "GET user:123" → "SET user:123 {\"name\":\"John\"}"
}
```

### 前置依赖
需要 SOCKS5 代理或 Packet Tunnel 拦截 TCP 6379 端口。

## 难度评估
**低** — RESP 是文本协议，解析非常简单。
