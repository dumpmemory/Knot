# 08 - Memcache 协议解析

## Netty 对应模块
`codec-memcache` — MemcacheMessage, BinaryMemcacheDecoder, BinaryMemcacheEncoder

## 功能描述
解析 Memcached 二进制/文本协议，展示 GET/SET/DELETE 命令和缓存数据。

## 价值
缓存调试：查看 App 的缓存读写行为，发现缓存穿透/雪崩。

## 协议格式
- 文本协议: `set key 0 3600 5\r\nhello\r\n`
- 二进制协议: 24 字节固定头 + key + value

## 前置依赖
需要 SOCKS5/Packet Tunnel 拦截 TCP 11211 端口。

## 难度: 低
