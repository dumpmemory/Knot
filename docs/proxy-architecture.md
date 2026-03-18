# Knot Proxy 协议抓取架构

## 目录

- [整体架构](#整体架构)
- [明文 HTTP 抓取](#明文-http-抓取)
- [HTTPS MITM 拦截抓取](#https-mitm-拦截抓取)
- [HTTPS 隧道模式 (不拦截)](#https-隧道模式)
- [WebSocket 抓取](#websocket-抓取)
- [直连 TLS](#直连-tls)
- [模块文件说明](#模块文件说明)
- [Session 数据模型](#session-数据模型)
- [流程对比总览](#流程对比总览)

---

## 整体架构

所有连接都从同一个入口进来：

```
iOS 系统 (VPN/代理)
    |
NEPacketTunnelProvider 将 HTTP/HTTPS 流量转发到 127.0.0.1:8034
    |
ProxyServer 监听 8034 端口
    |
每个新连接创建一条 Channel Pipeline
    |
第一个 Handler: ProtocolRouter (读取前 4 字节判断协议)
    |
+----------------------------------------------+
| "GET "/"POST"/"PUT " -> 明文 HTTP             |
| "CONN"               -> HTTPS (CONNECT 隧道)  |
| 0x16 (TLS记录)        -> 直连 TLS (罕见)       |
| 其他                   -> 关闭连接              |
+----------------------------------------------+
```

### 核心设计原则

1. **ProtocolRouter** 是唯一的入口 handler，根据首字节分发到不同管道
2. **SessionRecorder** 不是 ChannelHandler，是纯数据记录器，所有 handler 共享同一个实例
3. **HTTPCaptureHandler** 统一处理请求捕获和响应回传，替代原来分离的 HTTPHandler + ExchangeHandler
4. **NIOHTTPResponseDecompressor** 自动解压 gzip/deflate，抓到的是明文内容

---

## 明文 HTTP 抓取

**场景：** App 发起 `http://example.com/api/data` 请求

### 步骤 1：协议识别 (ProtocolRouter)

```
客户端发来第一批字节: "GET /api/data HTTP/1.1\r\nHost: example.com\r\n..."
                      ^^^^
ProtocolRouter 读取前 4 字节 = "GET " -> 匹配 HTTP
```

### 步骤 2：构建管道

ProtocolRouter 在 Pipeline 中添加：

```
[ByteToMessageHandler(HTTPRequestDecoder)]  <- 将原始字节解码为 HTTPServerRequestPart
    |
[HTTPResponseEncoder]                       <- 将 HTTPServerResponsePart 编码为字节
    |
[HTTPServerPipelineHandler]                 <- 处理 HTTP 管线化 (pipelining)
    |
[HTTPCaptureHandler]                        <- 核心捕获 + 转发 handler
```

然后 ProtocolRouter **自我移除**，把之前读到的数据往下传。

### 步骤 3：请求捕获 (HTTPCaptureHandler)

收到 `.head` 部分时：

1. 创建 `NetRequest` 解析目标地址（从 Host 头解析出 host:port）
2. 去掉代理专用头（Proxy-Connection 等）
3. 检测是否是 WebSocket 升级请求
4. 记录请求元数据到 Session 数据库：
   - `session.reqLine = "GET /api/data HTTP/1.1"`
   - `session.host = "example.com"`
   - `session.methods = "GET"`
   - `session.uri = "/api/data"`
   - `session.reqHeads = [所有头部的 JSON]`
   - `session.ignore = rule.matching(host, uri, userAgent)`
5. 修正 URI（代理请求中 URI 可能是完整 URL，需转为相对路径）
6. 发起到真实服务器的连接
7. 排队等发送（服务器还没连上）

### 步骤 4：连接真实服务器

```
ClientBootstrap 连接 example.com:80

出站管道:
  HTTPClientHandlers (自动添加编解码)
    |
  NIOHTTPResponseDecompressor  <- 自动解压 gzip/deflate
    |
  ResponseRelayHandler         <- 响应回传
```

连接成功后记录：
- `session.connectedTime = NOW`
- `session.outState = "open"`
- `session.remoteAddress = "93.184.216.34"`

然后刷出排队的请求数据。

### 步骤 5：请求转发

```
HTTPCaptureHandler -> sendPart() -> 出站 Channel

.head(HTTPRequestHead)  -> HTTPClientRequestPart.head  -> 写入出站 Channel
.body(ByteBuffer)       -> HTTPClientRequestPart.body  -> 写入出站 Channel
.end(HTTPHeaders?)      -> HTTPClientRequestPart.end   -> 写入出站 Channel
```

同时通过 SessionRecorder 记录：
- `recordRequestBody(buffer)` 写入磁盘文件（如果 ignore=false）
- `addUpload(bytes)` 累计上传字节数

### 步骤 6：响应接收 (ResponseRelayHandler)

```
真实服务器 -> 出站 Channel -> NIOHTTPResponseDecompressor(自动解压) -> ResponseRelayHandler
```

ResponseRelayHandler 处理每个部分：

**收到 .head：**
- 记录 `session.state = "200"`, `session.rspType = "application/json"`, `session.rspHeads = [JSON]`
- 转发给客户端

**收到 .body：**
- 记录响应体到磁盘（已解压的明文）
- 统计下载字节数
- 转发给客户端

**收到 .end：**
- 记录 `session.rspEndTime`
- 关闭两端连接

### 步骤 7：连接关闭

```
HTTPCaptureHandler.channelUnregistered():
    recorder.recordClosed()
    -> session.endTime = NOW
    -> session.saveToDB()
    -> task.sendInfo(url, uploadTraffic, downloadFlow)  // 通知主 App UI
```

### 最终 Session 记录

```
+----------------------------------------------+
| schemes:      "Http"                         |
| host:         "example.com"                  |
| methods:      "GET"                          |
| uri:          "/api/data"                    |
| state:        "200"                          |
| rspType:      "application/json"             |
| uploadTraffic: 256                           |
| downloadFlow:  1024                          |
| 时间线: startTime -> connectTime              |
|         -> connectedTime -> reqEndTime        |
|         -> rspStartTime -> rspEndTime         |
|         -> endTime                            |
| reqBody:      /Task/xxx/req_xxx.dat          |
| rspBody:      /Task/xxx/rsp_xxx.dat          |
+----------------------------------------------+
```

---

## HTTPS MITM 拦截抓取

**场景：** App 发起 `https://api.github.com/repos`

### 步骤 1：协议识别

```
客户端发来: "CONNECT api.github.com:443 HTTP/1.1\r\n..."
            ^^^^
ProtocolRouter 读取前 4 字节 = "CONN" -> 匹配 HTTPS CONNECT
```

### 步骤 2：构建 CONNECT 管道

```
[HTTPRequestDecoder] -> [HTTPResponseEncoder] -> [HTTPServerPipelineHandler] -> [ConnectHandler]
```

### 步骤 3：处理 CONNECT (ConnectHandler)

1. 解析目标：`api.github.com:443`
2. 记录请求元数据，设置 `session.schemes = "Https"`
3. 应用规则匹配决定是否忽略
4. **回复 200 Connection Established**（告诉客户端隧道已建立）
5. **移除所有 HTTP handler**（接下来是原始字节）
6. 根据配置决定：
   - `sslEnable == 1 && !ignore` -> 添加 **MITMHandler**（拦截解密）
   - 否则 -> 添加 **TunnelHandler**（原始转发）

### 步骤 4：TLS 拦截 (MITMHandler)

客户端认为隧道已建立，开始发送 TLS ClientHello：

1. **验证 TLS ClientHello**（byte1=22, byte2<=3, byte3<=3）
2. **获取或生成动态证书**：
   - 检查证书缓存 `task.certPool["api.github.com"]`
   - 缓存未命中时，使用 swift-certificates 纯 Swift 生成：
     ```
     Subject:    CN=api.github.com, O=Company, C=SE
     Issuer:     [CA 证书的 Subject]
     SAN:        DNS:api.github.com
     Extensions: basicConstraints=CA:FALSE, extKeyUsage=serverAuth
     有效期:     1 年
     签名算法:    SHA256WithRSA
     ```
   - 缓存生成的证书供后续使用
3. **创建 TLS 服务端上下文**（使用动态证书 + RSA 私钥）
4. **设置握手超时**（10 秒）
5. **添加 NIOSSLServerHandler + ALPN Handler** 到管道
6. 把 ClientHello 数据传给 SSL Handler
7. MITMHandler **自我移除**

### 步骤 5：TLS 握手

```
                      代理 (伪装的 api.github.com)
客户端  <-------- TLS 握手 ---------> NIOSSLServerHandler
     ClientHello        ->
     <- ServerHello + 动态证书 (CN=api.github.com)
     ClientKeyExchange  ->
     <- Finished
     Finished           ->

握手完成! 客户端信任此证书 (因为用户已安装并信任了 CA 根证书)
```

### 步骤 6：ALPN 完成，添加 HTTP 捕获管道

握手完成后，在解密层之上添加 HTTP 处理：

```
[NIOSSLServerHandler]                          <- TLS 解密/加密
    |
[ByteToMessageHandler(HTTPRequestDecoder)]     <- 解码解密后的 HTTP 请求
    |
[HTTPResponseEncoder]                          <- 编码 HTTP 响应
    |
[HTTPServerPipelineHandler]                    <- HTTP 管线化
    |
[HTTPCaptureHandler(isSSL: true)]              <- 捕获解密后的明文 HTTP
```

### 步骤 7：解密后的 HTTP 处理

HTTPCaptureHandler 收到的是**已解密的明文 HTTP**，处理流程和明文 HTTP 完全一样。

唯一区别是连接真实服务器时使用 TLS 客户端：

```
ClientBootstrap 连接 api.github.com:443

出站管道:
  NIOSSLClientHandler(serverHostname: "api.github.com")  <- 真实 TLS
    |
  ALPN Handler
    |
  HTTPRequestEncoder
    |
  HTTPResponseDecoder
    |
  NIOHTTPResponseDecompressor  <- 自动解压
    |
  ResponseRelayHandler         <- 响应回传
```

### 双向 TLS 全景图

```
         TLS 隧道 1 (假证书)              TLS 隧道 2 (真证书)
Client <------------------------> Proxy <------------------------> api.github.com

  加密请求 -> [NIOSSLServer 解密]   明文 HTTP   [NIOSSLClient 加密] -> 加密请求
              | 抓包记录!                                           |
  加密响应 <- [NIOSSLServer 加密]   明文 HTTP   [NIOSSLClient 解密] <- 加密响应
              ^ 抓包记录!
```

---

## HTTPS 隧道模式

**场景：** SSL 拦截关闭 或 规则匹配设为忽略

### 流程

前 3 步和 MITM 一样（接收 CONNECT -> 回复 200），但不执行 TLS 拦截：

```
ConnectHandler -> shouldIntercept = false

添加 TunnelHandler (原始字节转发)
recorder.session.note = "no cert config !"
```

### TunnelHandler 工作方式

```
Client <-- TLS 加密字节 --> TunnelHandler <-- TLS 加密字节 --> api.github.com

TunnelHandler:
  1. 收到客户端的加密字节 -> 原样转发给服务器
  2. TunnelRelayHandler 收到服务器的加密字节 -> 原样转发给客户端
  3. 只统计流量字节数，不解密任何内容
```

Session 记录：
- 有 host, uploadTraffic, downloadFlow
- **无** reqBody, rspBody（因为是加密的，无法读取）
- note = "no cert config !"

---

## WebSocket 抓取

**场景：** App 连接 `wss://echo.websocket.org/chat`

### 步骤 1-6：和 HTTPS 完全一样

CONNECT -> 200 -> MITMHandler -> TLS 握手 -> HTTP 管道

### 步骤 7：WebSocket 升级检测 (HTTPCaptureHandler)

客户端发送 HTTP 升级请求（已被 TLS 解密）：

```
GET /chat HTTP/1.1
Host: echo.websocket.org
Connection: Upgrade
Upgrade: websocket
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
```

HTTPCaptureHandler 检测到 `Connection: Upgrade` + `Upgrade: websocket`：
- 设置 `isWebSocketUpgrade = true`
- 创建 `WebSocketUpgradeInterceptor`
- 设置 `session.schemes = "WSS"`
- 请求被正常转发到真实服务器

### 步骤 8：服务器回复 101 (ResponseRelayHandler)

```
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

ResponseRelayHandler 检测到 101：
1. 将 101 响应转发给客户端
2. 触发 `WebSocketUpgradeInterceptor.performWebSocketUpgrade()`

### 步骤 9：管道切换

移除所有 HTTP Handler，两侧都切换为 WebSocket 帧编解码：

**客户端侧 Pipeline (client -> proxy):**
```
[NIOSSLServerHandler]       <- TLS
    |
[WebSocketFrameDecoder]     <- 字节 -> WebSocketFrame
    |
[WebSocketFrameEncoder]     <- WebSocketFrame -> 字节
    |
[WebSocketFrameLogger]      <- 记录帧到 reqBody 文件
    |
[WebSocketForwarder]        <- 转发到服务器
```

**服务器侧 Pipeline (server -> proxy):**
```
[NIOSSLClientHandler]       <- TLS
    |
[WebSocketFrameDecoder]     <- 字节 -> WebSocketFrame
    |
[WebSocketFrameEncoder]     <- WebSocketFrame -> 字节
    |
[WebSocketFrameLogger]      <- 记录帧到 rspBody 文件
    |
[WebSocketForwarder]        <- 转发到客户端
```

### 步骤 10：WebSocket 帧捕获 (持续)

**WebSocketFrameLogger** 对每个帧：
1. 解析 opcode（TEXT/BINARY/PING/PONG/CLOSE）
2. 格式化为可读的日志行
3. TEXT 帧显示前 512 字符的 payload
4. BINARY 帧显示字节大小
5. 根据方向写入 reqBody（上行）或 rspBody（下行）文件
6. 统计流量

**WebSocketForwarder** 对每个帧：
1. 去掉 Mask（代理转发时必须 unmask）
2. 创建新的 Frame
3. 发送给对端
4. 如果是 CLOSE 帧，关闭两端连接

### 帧记录文件示例

**reqBody 文件 (client -> server):**
```
[2026-03-17T19:30:00Z] [FIN] [TEXT] [45B] -> {"type":"subscribe","channel":"trades"}
[2026-03-17T19:30:05Z] [FIN] [PING] [0B] -> <ping>
[2026-03-17T19:30:30Z] [FIN] [TEXT] [28B] -> {"type":"unsubscribe","id":1}
[2026-03-17T19:31:00Z] [FIN] [CLOSE] [2B] -> <close>
```

**rspBody 文件 (server -> client):**
```
[2026-03-17T19:30:01Z] [FIN] [TEXT] [89B] <- {"type":"ack","channel":"trades","status":"ok"}
[2026-03-17T19:30:02Z] [FIN] [TEXT] [156B] <- {"type":"trade","price":42150.50,"size":0.5}
[2026-03-17T19:30:03Z] [FIN] [TEXT] [148B] <- {"type":"trade","price":42151.00,"size":1.2}
[2026-03-17T19:30:05Z] [FIN] [PONG] [0B] <- <pong>
[2026-03-17T19:31:00Z] [FIN] [CLOSE] [2B] <- <close>
```

---

## 直连 TLS

**场景：** 非 HTTP 协议的 TLS 连接（极少见）

```
客户端直接发送 TLS ClientHello (不是 CONNECT):
  0x16 0x03 0x01 ...

ProtocolRouter: byte1=22(0x16), byte2<=3, byte3<=3 -> TLS Handshake

没有 HTTP CONNECT 前置，无法知道目标地址
-> 使用 TunnelHandler (仅统计流量，无实际转发)
```

---

## 模块文件说明

| 文件 | 职责 |
|------|------|
| `ProxyServer.swift` | 服务器启动、绑定端口、生命周期管理 |
| `ProtocolRouter.swift` | 协议路由：读取首字节分发到 HTTP/HTTPS/TLS 管道 |
| `ConnectHandler.swift` | 处理 HTTP CONNECT 请求，建立隧道，决定是否 MITM |
| `MITMHandler.swift` | TLS 中间人拦截：动态证书生成 + TLS 握手 |
| `HTTPCaptureHandler.swift` | HTTP 请求/响应统一捕获、转发、WebSocket 升级检测 |
| `ResponseRelayHandler` | (内嵌) 服务器响应回传、101 WebSocket 升级触发 |
| `TunnelHandler.swift` | 原始 TCP 隧道：双向字节转发，不解密 |
| `TunnelRelayHandler` | (内嵌) 服务器到客户端的字节回传 |
| `WebSocketCaptureHandler.swift` | WebSocket 帧捕获：升级拦截器 + 帧日志 + 帧转发 |
| `SessionRecorder.swift` | 纯数据记录器：Session 字段赋值、磁盘写入、流量统计 |

---

## Session 数据模型

### Session 时间线

```
startTime          连接建立
    |
connectTime        开始连接服务器
    |
connectedTime      服务器连接成功
    |
handshakeEndTime   TLS 握手完成 (仅 HTTPS)
    |
reqEndTime         请求发送完毕
    |
rspStartTime       开始接收响应
    |
rspEndTime         响应接收完毕
    |
endTime            连接关闭
```

### Session 字段填充来源

| 字段 | 填充位置 | 说明 |
|------|---------|------|
| `schemes` | ProtocolRouter / ConnectHandler / HTTPCaptureHandler | "Http" / "Https" / "WS" / "WSS" |
| `host` | SessionRecorder.recordRequestHead | 从 Host 头提取 |
| `methods` | SessionRecorder.recordRequestHead | GET / POST / CONNECT 等 |
| `uri` | SessionRecorder.recordRequestHead | 请求路径 |
| `state` | SessionRecorder.recordResponseHead | HTTP 状态码 (200, 404 等) |
| `reqBody` | SessionRecorder.recordRequestBody | 请求体文件路径 |
| `rspBody` | SessionRecorder.recordResponseBody | 响应体文件路径 |
| `uploadTraffic` | SessionRecorder.addUpload | 上传字节数 |
| `downloadFlow` | SessionRecorder.addDownload | 下载字节数 |
| `ignore` | SessionRecorder.recordRequestHead | 规则匹配结果 |

---

## 流程对比总览

| 阶段 | HTTP | HTTPS (MITM) | HTTPS (隧道) | WebSocket |
|------|------|-------------|-------------|-----------|
| **检测** | 前 4 字节是 HTTP 方法 | 前 4 字节是 "CONN" | 同左 | 同 HTTPS + Upgrade 头 |
| **管道** | HTTP 编解码 -> HTTPCaptureHandler | CONNECT -> 200 -> MITM -> TLS -> HTTP 编解码 -> HTTPCaptureHandler | CONNECT -> 200 -> TunnelHandler | 同 HTTPS 到 101 后切 WS 帧 |
| **解密** | 不需要 | NIOSSLServer 解密 + NIOSSLClient 重加密 | 不解密 | 在已解密的 TLS 隧道上运行 |
| **请求抓取** | 完整 HTTP 头部 + 体 | 完整 HTTP 头部 + 体 | 仅流量统计 | 每个 WS 帧带时间戳 |
| **响应抓取** | 完整 HTTP 头部 + 体 + 自动解压 | 完整 HTTP 头部 + 体 + 自动解压 | 仅流量统计 | 每个 WS 帧带时间戳 |
| **Session.schemes** | "Http" | "Https" | "Https" | "WS" / "WSS" |
| **Session.reqBody** | HTTP 请求体文件 | HTTP 请求体文件 | 无 | WS 帧日志文件 |
| **Session.rspBody** | HTTP 响应体文件 | HTTP 响应体文件 | 无 | WS 帧日志文件 |
