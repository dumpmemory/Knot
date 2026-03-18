# Netty 功能移植总览

基于 [Netty 4.1](https://github.com/netty/netty) 全部模块分析，以下功能可以移植到 Knot 项目。

## 功能分类

| 编号 | 功能 | Netty 模块 | 难度 | 价值 | 文档 |
|------|------|-----------|------|------|------|
| 01 | PCAP 导出 | handler/pcap | 低 | 高 | [pcap-export.md](01-pcap-export.md) |
| 02 | 流量整形 / 限速 | handler/traffic | 中 | 高 | [traffic-shaping.md](02-traffic-shaping.md) |
| 03 | IP 过滤 / 访问控制 | handler/ipfilter | 低 | 中 | [ip-filter.md](03-ip-filter.md) |
| 04 | DNS 协议解析 | codec-dns | 中 | 高 | [dns-capture.md](04-dns-capture.md) |
| 05 | SOCKS4/5 代理 | codec-socks + handler-proxy | 中 | 高 | [socks-proxy.md](05-socks-proxy.md) |
| 06 | MQTT 协议解析 | codec-mqtt | 中 | 中 | [mqtt-capture.md](06-mqtt-capture.md) |
| 07 | Redis 协议解析 | codec-redis | 低 | 中 | [redis-capture.md](07-redis-capture.md) |
| 08 | Memcache 协议解析 | codec-memcache | 低 | 低 | [memcache-capture.md](08-memcache-capture.md) |
| 09 | SMTP 协议解析 | codec-smtp | 低 | 低 | [smtp-capture.md](09-smtp-capture.md) |
| 10 | STOMP 协议解析 | codec-stomp | 低 | 低 | [stomp-capture.md](10-stomp-capture.md) |
| 11 | HAProxy 协议支持 | codec-haproxy | 低 | 低 | [haproxy-protocol.md](11-haproxy-protocol.md) |
| 12 | SSL/TLS 增强 (OCSP) | handler-ssl-ocsp | 中 | 中 | [ssl-ocsp.md](12-ssl-ocsp.md) |
| 13 | 管道日志/调试 | handler/logging | 低 | 中 | [pipeline-logging.md](13-pipeline-logging.md) |
| 14 | 超时精细控制 | handler/timeout | 低 | 中 | [timeout-control.md](14-timeout-control.md) |
| 15 | Protobuf 编解码 | codec/protobuf | 已实现 | 高 | [protobuf-codec.md](15-protobuf-codec.md) |
| 16 | 压缩增强 (Brotli/Zstd/LZ4) | codec/compression | 中 | 中 | [compression.md](16-compression.md) |
| 17 | XML 协议解析 | codec-xml | 低 | 低 | [xml-codec.md](17-xml-codec.md) |
| 18 | 请求重放/Mock | 无直接对应 | 高 | 高 | [request-replay.md](18-request-replay.md) |
| 19 | 连接断点/注入 | 无直接对应 | 高 | 高 | [breakpoint-inject.md](19-breakpoint-inject.md) |

## 推荐实现优先级

### 第一优先级 (对抓包工具价值最高)

1. **PCAP 导出** — 将抓到的流量导出为 .pcap 文件，可在 Wireshark 打开
2. **流量整形** — 模拟弱网环境（限速、延迟、丢包）
3. **DNS 协议解析** — 抓取 DNS 查询/响应（最常见的 UDP 协议）
4. **SOCKS5 代理** — 支持全局 TCP 代理（不只是 HTTP）
5. **请求重放** — 重放已捕获的请求用于测试
6. **断点/注入** — 拦截请求并修改后再转发

### 第二优先级

7. **IP 过滤** — 按 IP/子网控制抓包范围
8. **管道日志** — 开发调试用，记录每个 handler 的数据流
9. **超时精细控制** — 读超时、写超时、空闲超时分离
10. **SSL OCSP** — 证书状态在线查询
11. **压缩增强** — 支持 Brotli/Zstd 解压

### 第三优先级 (特殊场景)

12. **MQTT 解析** — IoT 设备流量抓包
13. **Redis 解析** — 数据库调试
14. **Memcache 解析** — 缓存调试
15. **SMTP 解析** — 邮件协议调试
16. **STOMP/XML** — 消息队列/Web Service
