# 14 - 超时精细控制

## Netty 对应模块
`handler/timeout` — ReadTimeoutHandler, WriteTimeoutHandler, IdleStateHandler

## 功能描述
三种独立超时控制:
- **ReadTimeout**: 一定时间内没有收到数据 → 触发超时
- **WriteTimeout**: 写操作在一定时间内未完成 → 触发超时
- **IdleState**: 读/写/全部空闲检测 → 触发心跳或关闭

## 价值
- 精确控制每种超时场景（当前只有 connectTimeout）
- 长连接保活检测（WebSocket/gRPC streaming）

## 当前状态
项目只有 `connectTimeout = 10s` 和 handshake timeout。
可以扩展为 per-handler 级别的读写超时。

## 难度: 低
