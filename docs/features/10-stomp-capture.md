# 10 - STOMP 协议解析

## Netty 对应模块
`codec-stomp` — StompFrame, StompSubframeDecoder, StompCommand

## 功能描述
解析 STOMP (Simple Text Oriented Messaging Protocol) 消息队列协议，展示 CONNECT/SEND/SUBSCRIBE/MESSAGE 帧。

## 价值
- 调试 WebSocket + STOMP 消息（Spring WebSocket 常用）
- 实时消息系统调试

## 协议格式
文本帧: `SEND\ndestination:/queue/test\n\nhello\x00`

## 与 WebSocket 关系
STOMP 常在 WebSocket 之上运行。当前 WebSocket 抓取已实现，只需在 WebSocketFrameLogger 中添加 STOMP 帧解析。

## 难度: 低
