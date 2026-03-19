# 数据库与文件存储系统重设计

## 概述

重新设计 Knot 的数据库和文件存储系统，解决以下核心问题：

1. **并发写入瓶颈**：单 SQLite 数据库无法应对高流量抓包的多线程并发写入
2. **多协议字段差异**：不同协议（HTTP/WebSocket/DNS/MQTT...）的字段结构差异大，需要灵活的存储方案
3. **内存占用**：大载荷的读写不应一次性加载到内存
4. **扩展性**：未来新增协议和网络层数据存储时，不应改动核心 Schema
5. **载荷修改**：支持断点拦截实时修改和事后重放修改

## 架构决策

### 多库分层策略

按**网络分层**将数据拆分到多个 SQLite 数据库，每个 CaptureTask 拥有独立的一组数据库文件。所有库启用 WAL 模式。

**选择理由**：
- 不同层的写入频率差异巨大（传输层每包一条 vs 解码层空闲时写入），分库后各自的写锁互不阻塞
- 同一 task 内仍存在高并发写入（200+ 并发连接），仅按 task 分库不够
- 每个 task 的数据天然隔离，无跨 task 查询需求，删除 task 直接删目录
- WAL 模式提供一写多读的并发能力，配合串行写入队列，彻底消除锁冲突

### 载荷存储策略

- 大载荷（>4KB）以文件形式存储，通过数据库中的引用关联
- 小载荷（≤4KB）内联到 SQLite BLOB，减少文件碎片
- 读写均采用流式 I/O，内存占用不随载荷大小增长
- 载荷分三种状态：原始态（raw）、解码态（decoded）、修改态（modified）

### 协议扩展策略

- 通用字段 + JSON 扩展列 + 高频索引列的混合方案
- 新协议只需实现 `ProtocolRecorder` 接口，零 Schema 变更
- JSON 序列化开销远小于磁盘 I/O，且 SQLite 内置 `json_extract()` 支持直接查询

---

## 目录结构

```
{AppGroup}/
├── catalog.db                          # 全局目录库（CaptureTask 列表 + Rule）
├── tasks/
│   └── {taskId}/
│       ├── transport.db                # 传输层库（TCP/UDP/ICMP 包记录）
│       ├── protocol.db                 # 协议层库（HTTP/WS/DNS 等结构化元数据）
│       ├── decoded.db                  # 解码层库（解压/解码后的可读数据索引 + FTS）
│       ├── state.db                    # 状态层库（连接状态、修改记录、统计）
│       ├── payloads/
│       │   ├── raw/                    # 原始载荷（压缩/编码态）
│       │   │   ├── {flowId}_req.bin
│       │   │   └── {flowId}_rsp.bin
│       │   ├── decoded/                # 解码后载荷
│       │   │   ├── {flowId}_req.{ext}
│       │   │   └── {flowId}_rsp.{ext}
│       │   └── modified/              # 修改版本（copy-on-write）
│       │       ├── {flowId}_v1_req.{ext}
│       │       └── {flowId}_v2_req.{ext}
│       └── export/                     # 导出临时目录
```

**命名规则**：
- `flowId`：时间戳(毫秒) + 4位自增序号，如 `1679012345678_0001`，比 UUID 更短且天然有序
- `raw/` 目录统一用 `.bin` 后缀
- `decoded/` 目录用实际扩展名（json/xml/html/txt/bin）
- `modified/` 带版本号形成修改链

---

## 4 库职责与写入热度

| 库 | 写入频率 | 写入来源 | 读取场景 |
|---|---|---|---|
| **transport.db** | 极高频，每个包一条 | PacketCaptureEngine 线程（VPN 隧道扩展） | 重放、统计、PCAP 导出 |
| **protocol.db** | 高频，每个请求/响应一条 | NIO Capture Handler 线程（代理管道） | UI 列表浏览、过滤、搜索 |
| **decoded.db** | 低频，空闲时后台写入 | 后台解码队列 | 全文搜索、内容预览 |
| **state.db** | 低频，状态变更时写入 | 多个来源 | 连接管理、修改记录、统计面板 |

**注意：两条独立的数据路径**
- **VPN 隧道路径**：原始 IP 包经 `PacketCaptureEngine` 处理（运行在 PacketTunnel 扩展进程），写入 `transport.db`
- **代理管道路径**：解码后的协议数据经 NIO ChannelHandler 处理（运行在主 App 或代理进程），写入 `protocol.db`
- 两条路径通过 `flow_id` 关联——`PacketCaptureEngine` 为每条 TCP/UDP 流分配 `flow_id`，代理管道沿用同一 `flow_id`

---

## 数据流全景

```
原始 IP 数据包到达（VPN 隧道）
    │
    ▼
┌──────────────────────────────────────────────────────┐
│  PacketCaptureEngine 线程（PacketTunnel 扩展进程）      │
│                                                       │
│  1. IP 包解析 ──→ transport.db (Packet)               │
│     分配 flow_id，记录 TCP/UDP/ICMP 包头元数据          │
│     TCP 流量转发到本地代理端口                           │
└──────────────────────────────────────────────────────┘
    │ TCP 流量经本地代理端口进入
    ▼
┌──────────────────────────────────────────────────────┐
│  NIO EventLoop 线程（代理管道）                         │
│                                                       │
│  2. 协议解析 ──→ protocol.db (Flow)                    │
│     (HTTP/WS/DNS 等 Handler 提取结构化字段)              │
│     + payloads/raw/ (请求/响应载荷写入)                  │
│                                                       │
│  3. 状态变更 ──→ state.db (Connection)                 │
│     (连接建立/关闭)                                     │
└──────────────────────────────────────────────────────┘
    │
    │  通知解码队列（flowId + payloadRef）
    ▼
┌──────────────────────────────────────────────────────┐
│  后台解码队列（串行 DispatchQueue，QoS: .utility）      │
│                                                       │
│  4. 读取 payloads/raw/ ──→ 流式解压/解码/合并           │
│     ──→ 写入 payloads/decoded/                         │
│     ──→ decoded.db (DecodedEntry + searchText FTS)     │
└──────────────────────────────────────────────────────┘
```

---

## 数据库 Schema

### 1. catalog.db（全局目录库）

```sql
CREATE TABLE capture_task (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL DEFAULT '',
    created_at      REAL NOT NULL,
    started_at      REAL,
    stopped_at      REAL,
    status          INTEGER NOT NULL DEFAULT 0, -- 0=idle 1=running 2=stopped
    rule_id         INTEGER,
    ssl_enabled     INTEGER NOT NULL DEFAULT 0,

    -- 代理配置
    local_ip        TEXT NOT NULL DEFAULT '127.0.0.1',
    local_port      INTEGER NOT NULL DEFAULT 8080,
    local_enabled   INTEGER NOT NULL DEFAULT 0,
    wifi_ip         TEXT NOT NULL DEFAULT '',
    wifi_port       INTEGER NOT NULL DEFAULT 0,
    wifi_enabled    INTEGER NOT NULL DEFAULT 0,

    -- 统计快照（定期从 state.db 同步，用于列表展示）
    flow_count      INTEGER NOT NULL DEFAULT 0,
    upload_bytes    INTEGER NOT NULL DEFAULT 0,
    download_bytes  INTEGER NOT NULL DEFAULT 0,

    note            TEXT NOT NULL DEFAULT '',
    extra           TEXT NOT NULL DEFAULT ''
);

CREATE TABLE rule (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    name                    TEXT NOT NULL DEFAULT 'Default',
    default_strategy        TEXT NOT NULL DEFAULT 'DIRECT',  -- DIRECT/REJECT/COPY
    blacklist_enabled       INTEGER NOT NULL DEFAULT 0,
    config                  TEXT NOT NULL DEFAULT '',         -- 完整规则文本（[General]/[Rule]/[Host] 格式）
    created_at              REAL NOT NULL,
    author                  TEXT NOT NULL DEFAULT '',
    note                    TEXT NOT NULL DEFAULT ''
);
-- 注意：default_strategy 和 blacklist_enabled 是从 config 中提取的冗余字段，
-- 用于快速查询，config 仍然保存完整的规则文本，运行时由 Rule 解析器解析。

-- 断点规则（全局，跨 task 共享）
CREATE TABLE breakpoint (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    enabled         INTEGER NOT NULL DEFAULT 1,
    match_phase     TEXT NOT NULL DEFAULT 'request',  -- request / response / both
    match_protocol  TEXT NOT NULL DEFAULT '*',         -- HTTP / * (所有)
    match_pattern   TEXT NOT NULL DEFAULT '',          -- host/uri 匹配模式
    action          TEXT NOT NULL DEFAULT 'pause',    -- pause / run_script
    script_ref      TEXT NOT NULL DEFAULT '',          -- JS 脚本文件引用
    priority        INTEGER NOT NULL DEFAULT 0,
    created_at      REAL NOT NULL,
    note            TEXT NOT NULL DEFAULT ''
);

CREATE INDEX idx_breakpoint_enabled ON breakpoint(enabled);
```

### 2. transport.db（传输层库）

```sql
CREATE TABLE packet (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    flow_id         TEXT NOT NULL,
    direction       INTEGER NOT NULL,            -- 0=inbound 1=outbound
    timestamp       REAL NOT NULL,               -- 精确到微秒

    -- 网络层
    ip_version      INTEGER NOT NULL DEFAULT 4,
    src_ip          TEXT NOT NULL,
    dst_ip          TEXT NOT NULL,

    -- 传输层
    transport       INTEGER NOT NULL,            -- 6=TCP 17=UDP 1=ICMP
    src_port        INTEGER NOT NULL DEFAULT 0,
    dst_port        INTEGER NOT NULL DEFAULT 0,

    -- TCP 特有（UDP/ICMP 时为 0）
    seq_no          INTEGER NOT NULL DEFAULT 0,
    ack_no          INTEGER NOT NULL DEFAULT 0,
    tcp_flags       INTEGER NOT NULL DEFAULT 0,
    window_size     INTEGER NOT NULL DEFAULT 0,

    -- 载荷
    payload_length  INTEGER NOT NULL DEFAULT 0,
    payload_ref     TEXT NOT NULL DEFAULT ''
);

CREATE INDEX idx_packet_flow_id ON packet(flow_id);
CREATE INDEX idx_packet_timestamp ON packet(timestamp);
CREATE INDEX idx_packet_transport ON packet(transport);
```

**写入优化**：
- 开启 WAL 模式 + `synchronous = NORMAL`
- 批量写入：每 50 条或每 100ms 用一个事务提交
- 预编译 INSERT 语句复用

### 3. protocol.db（协议层库）

```sql
CREATE TABLE flow (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    flow_id         TEXT NOT NULL UNIQUE,
    protocol        TEXT NOT NULL,               -- HTTP, HTTPS, H2, WS, DNS, QUIC, MQTT...

    -- 通用字段
    host            TEXT NOT NULL DEFAULT '',
    port            INTEGER NOT NULL DEFAULT 0,
    started_at      REAL NOT NULL,
    ended_at        REAL,
    duration_ms     REAL,

    -- 详细时间线（性能分析用，均为时间戳，可选）
    connect_at      REAL,                        -- TCP 连接发起
    connected_at    REAL,                        -- TCP 连接建立
    tls_done_at     REAL,                        -- TLS 握手完成
    req_end_at      REAL,                        -- 请求发送完毕
    rsp_start_at    REAL,                        -- 首字节响应到达 (TTFB)

    -- 通用流量统计
    upload_bytes    INTEGER NOT NULL DEFAULT 0,
    download_bytes  INTEGER NOT NULL DEFAULT 0,

    -- 通用状态
    status          INTEGER NOT NULL DEFAULT 0,  -- 0=进行中 1=完成 2=失败
    error_message   TEXT NOT NULL DEFAULT '',

    -- 摘要（各协议 Handler 生成）
    summary         TEXT NOT NULL DEFAULT '',

    -- 高频查询索引列（各协议复用，含义由 protocol 决定）
    search_key1     TEXT NOT NULL DEFAULT '',     -- HTTP:method   DNS:queryType  MQTT:messageType
    search_key2     TEXT NOT NULL DEFAULT '',     -- HTTP:uri      DNS:domain     MQTT:topic
    search_key3     TEXT NOT NULL DEFAULT '',     -- HTTP:statusCode DNS:firstAnswer
    search_key4     TEXT NOT NULL DEFAULT '',     -- HTTP:contentType WS:closeReason

    -- 协议特有字段
    metadata        TEXT NOT NULL DEFAULT '{}',

    -- 载荷引用
    req_payload_ref TEXT NOT NULL DEFAULT '',
    rsp_payload_ref TEXT NOT NULL DEFAULT '',

    -- 标记
    is_intercepted  INTEGER NOT NULL DEFAULT 0,
    is_modified     INTEGER NOT NULL DEFAULT 0,
    tags            TEXT NOT NULL DEFAULT ''
);

CREATE INDEX idx_flow_protocol ON flow(protocol);
CREATE INDEX idx_flow_host ON flow(host);
CREATE INDEX idx_flow_started_at ON flow(started_at);
CREATE INDEX idx_flow_status ON flow(status);
CREATE INDEX idx_flow_search_key1 ON flow(search_key1);
CREATE INDEX idx_flow_search_key2 ON flow(search_key2);
CREATE INDEX idx_flow_search_key3 ON flow(search_key3);
CREATE INDEX idx_flow_search_key4 ON flow(search_key4);
```

**各协议的 search_key 映射**：

| 协议 | search_key1 | search_key2 | search_key3 | search_key4 |
|------|-------------|-------------|-------------|-------------|
| HTTP/HTTPS/H2 | method | uri | statusCode | contentType |
| WebSocket | direction | uri | frameCount | closeCode |
| DNS | queryType | domain | firstAnswer | responseCode |
| MQTT | messageType | topic | qos | clientId |
| QUIC | version | connectionId | - | - |
| gRPC | method | service | statusCode | grpcStatus |

### 4. decoded.db（解码层库）

```sql
CREATE TABLE decoded_entry (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    flow_id         TEXT NOT NULL,
    direction       INTEGER NOT NULL,             -- 0=request 1=response

    -- 解码信息
    original_encoding TEXT NOT NULL DEFAULT '',
    decoded_type    TEXT NOT NULL DEFAULT '',
    decoded_size    INTEGER NOT NULL DEFAULT 0,
    charset         TEXT NOT NULL DEFAULT 'utf-8',

    -- 载荷引用
    payload_ref     TEXT NOT NULL DEFAULT '',
    is_inline       INTEGER NOT NULL DEFAULT 0,
    inline_data     BLOB,                         -- ≤4KB 内联

    -- 可搜索文本（仅文本类型载荷）
    search_text     TEXT,

    decoded_at      REAL NOT NULL,

    -- 对于 HTTP 等请求/响应模式：sequence = 0
    -- 对于 WebSocket/gRPC streaming 等多帧协议：sequence 递增
    sequence        INTEGER NOT NULL DEFAULT 0,

    UNIQUE(flow_id, direction, sequence)
);

-- FTS5 全文搜索
CREATE VIRTUAL TABLE decoded_fts USING fts5(
    search_text,
    content='decoded_entry',
    content_rowid='id'
);

CREATE TRIGGER decoded_fts_insert AFTER INSERT ON decoded_entry
WHEN NEW.search_text IS NOT NULL BEGIN
    INSERT INTO decoded_fts(rowid, search_text) VALUES (NEW.id, NEW.search_text);
END;

CREATE TRIGGER decoded_fts_delete BEFORE DELETE ON decoded_entry
WHEN OLD.search_text IS NOT NULL BEGIN
    INSERT INTO decoded_fts(decoded_fts, rowid, search_text)
    VALUES('delete', OLD.id, OLD.search_text);
END;

CREATE TRIGGER decoded_fts_update AFTER UPDATE OF search_text ON decoded_entry BEGIN
    INSERT INTO decoded_fts(decoded_fts, rowid, search_text)
    VALUES('delete', OLD.id, OLD.search_text);
    INSERT INTO decoded_fts(rowid, search_text) VALUES (NEW.id, NEW.search_text);
END;

CREATE INDEX idx_decoded_flow_id ON decoded_entry(flow_id);
```

### 5. state.db（状态层库）

```sql
CREATE TABLE connection (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    flow_id         TEXT NOT NULL,
    client_state    TEXT NOT NULL DEFAULT 'open',
    server_state    TEXT NOT NULL DEFAULT 'open',
    started_at      REAL NOT NULL,
    closed_at       REAL,
    close_reason    TEXT NOT NULL DEFAULT '',
    tls_version     TEXT NOT NULL DEFAULT '',
    tls_cipher      TEXT NOT NULL DEFAULT '',
    server_cert     TEXT NOT NULL DEFAULT '',
    UNIQUE(flow_id)
);

-- 注意：breakpoint 表已移至 catalog.db（全局），不在 per-task 的 state.db 中

CREATE TABLE modify_log (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    flow_id         TEXT NOT NULL,
    direction       INTEGER NOT NULL,
    modify_type     TEXT NOT NULL,
    original_ref    TEXT NOT NULL DEFAULT '',
    modified_ref    TEXT NOT NULL DEFAULT '',
    diff_summary    TEXT NOT NULL DEFAULT '',
    source          TEXT NOT NULL DEFAULT '',
    modified_at     REAL NOT NULL
);

CREATE TABLE task_stats (
    id                  INTEGER PRIMARY KEY CHECK (id = 1),
    total_flows         INTEGER NOT NULL DEFAULT 0,
    active_connections  INTEGER NOT NULL DEFAULT 0,
    total_packets       INTEGER NOT NULL DEFAULT 0,
    upload_bytes        INTEGER NOT NULL DEFAULT 0,
    download_bytes      INTEGER NOT NULL DEFAULT 0,
    intercepted_count   INTEGER NOT NULL DEFAULT 0,
    error_count         INTEGER NOT NULL DEFAULT 0,
    updated_at          REAL NOT NULL
);

CREATE INDEX idx_connection_flow_id ON connection(flow_id);
CREATE INDEX idx_modify_log_flow_id ON modify_log(flow_id);
```

**task_stats 初始化**：表创建后立即插入唯一行：
```sql
INSERT INTO task_stats (id, updated_at) VALUES (1, 0);
```
后续只用 `UPDATE` 更新，不再 `INSERT`。

---

## 载荷文件管理与流式 I/O

### PayloadWriter（流式写入）

写入端永远不在内存中持有完整载荷。

```swift
class PayloadWriter {
    private let fileHandle: FileHandle
    private let filePath: String
    private var bytesWritten: Int64 = 0
    private var buffer: Data
    private let flushThreshold: Int  // 默认 32KB

    init(directory: String, fileName: String, flushThreshold: Int = 32 * 1024) throws

    /// 追加数据块（从 NIO ByteBuffer 零拷贝获取）
    func append(_ byteBuffer: ByteBuffer) throws

    /// 刷盘
    func flush() throws

    /// 关闭（刷剩余缓冲 + 关闭句柄）
    func close() throws
}
```

关键设计点：
- 32KB 缓冲区，攒 2~4 次 NIO channelRead 再刷盘
- `removeAll(keepingCapacity: true)` 复用已分配内存
- 从 ByteBuffer.readableBytesView 零拷贝读取

### PayloadReader（流式读取）

读取端按需分块，永远不把整个文件加载到内存。

```swift
class PayloadReader {
    init(filePath: String, chunkSize: Int = 64 * 1024) throws

    /// 范围读取（UI 分页预览）
    func read(offset: Int64, length: Int) -> Data

    /// 迭代器模式（导出、流式传输）
    func chunks() -> ChunkSequence

    var size: Int64 { get }
    func close()
}
```

各场景的读取方式：

| 场景 | 调用方式 | 内存占用 |
|------|---------|---------|
| UI 预览文本 | `reader.read(offset: 0, length: 4096)` | 4KB |
| UI 分页加载 | `reader.read(offset: pageStart, length: pageSize)` | pageSize |
| 导出 HAR/PCAP | `for chunk in reader.chunks() { write(chunk) }` | 64KB |
| 全文搜索 | 走 decoded.db 的 FTS 索引 | 0 |
| Body 修改 | `reader.chunks()` → 修改 → `PayloadWriter` 写新文件 | 64KB |

### PayloadDecoder（流式解码管道）

```swift
class PayloadDecoder {
    /// 流式解码：读一块 → 解码一块 → 写一块
    static func decode(
        rawPath: String,
        decodedPath: String,
        encoding: String,
        chunkSize: Int = 64 * 1024
    ) throws -> DecodeResult

    /// 同步解码（断点/脚本拦截路径，同一套逻辑）
    static func decodeSynchronously(rawBuffer: ByteBuffer, encoding: String) throws -> Data
}
```

基于 Apple Compression 框架的 `compression_stream` API 实现流式解压，支持 gzip/deflate/brotli。

### TextAccumulator（流式文本提取）

从二进制流中提取可搜索文本，上限 100KB 防止内存爆炸。超过上限停止积累，二进制内容不入 FTS。

### 内存预算

| 组件 | 峰值内存 | 说明 |
|------|---------|------|
| PayloadWriter 缓冲 | 32KB × 并发连接数 | 200 连接 ≈ 6.4MB |
| PayloadReader 分块 | 64KB × 并发读取数 | UI 通常 1~2 个 ≈ 128KB |
| 解码管道 | 64KB input + 64KB output | 单管道 128KB |
| TextAccumulator | 最大 100KB/flow | 解码队列串行，同时只有一个 |
| SQLite WAL | 每库约 1~4MB | 4 库 ≈ 16MB |
| **总计** | **约 25MB（200 并发连接）** | 不随载荷大小增长 |

---

## 数据库连接管理

### DatabaseManager（全局单例）

```swift
class DatabaseManager {
    static let shared = DatabaseManager()

    /// catalog.db 常驻连接
    private let catalogDB: Connection

    /// 当前活跃 task 的库连接池（引用计数）
    private var activePools: [Int64: TaskDatabaseGroup] = [:]

    func openTask(_ taskId: Int64) throws -> TaskDatabaseGroup
    func closeTask(_ taskId: Int64)
    func deleteTask(_ taskId: Int64) throws  // 关闭连接 + rm -rf 目录
}
```

### TaskDatabaseGroup（单 Task 的 4 库封装）

```swift
class TaskDatabaseGroup {
    let taskId: Int64

    let transport: Connection
    let proto: Connection
    let decoded: Connection
    let state: Connection

    // 每个库独立的串行写入队列
    let transportWriteQueue: DispatchQueue
    let protoWriteQueue: DispatchQueue
    let decodedWriteQueue: DispatchQueue
    let stateWriteQueue: DispatchQueue
}
```

### PRAGMA 配置

根据执行环境区分配置：

**主 App 进程**：
```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = -2000;          -- 2MB 页缓存
PRAGMA mmap_size = 134217728;       -- 128MB mmap
PRAGMA busy_timeout = 3000;         -- 3 秒写锁等待
```

**PacketTunnel 扩展进程**（内存严格受限，Apple 建议 < 15MB）：
```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = -512;           -- 512KB 页缓存
PRAGMA mmap_size = 16777216;        -- 16MB mmap
PRAGMA busy_timeout = 3000;
```

### 并发模型

```
NIO EventLoop Threads ──→ 写入分发 ──→ transportWriteQueue (串行) ──→ transport.db
                                   ──→ protoWriteQueue (串行)     ──→ protocol.db
                                   ──→ stateWriteQueue (串行)     ──→ state.db

DecodeScheduler        ──→ decodedWriteQueue (串行) ──→ decoded.db

读取：任意线程可直接读（WAL 模式允许读写并发）
```

### BatchWriter（transport.db 专用批量写入）

```swift
class BatchWriter {
    /// 攒够 batchSize 条或到达 flushInterval 时用单个事务提交
    init(db: Connection, queue: DispatchQueue, batchSize: Int = 50, flushInterval: TimeInterval = 0.1)

    /// NIO 线程调用：投递一条记录（非阻塞）
    func enqueue(_ row: PacketRow)

    /// 停止抓包时调用：刷完剩余数据
    func finalize()
}
```

批量写入大幅降低事务开销（200 包/秒：逐条 200 次事务 → 批量 4 次事务，减少锁获取和 WAL 帧写入次数）。

### catalog.db 统计快照同步

`capture_task` 表中的 `flow_count`/`upload_bytes`/`download_bytes` 是来自 `state.db → task_stats` 的快照：

- **抓包进行中**：每 5 秒定时器从 `task_stats` 读取最新值，写入 `capture_task`
- **抓包停止时**：立即做一次最终同步
- **App 启动时**：对所有 `status = running` 的 task 重新同步（处理上次崩溃的情况）
- 同步由主 App 进程的 `TaskStatsSync` 组件负责，在主线程或低优先级队列执行

### flowId 生成

`flowId` 格式：`{timestamp_ms}_{sequence}`，如 `1679012345678_0001`。

```swift
/// 线程安全的 flowId 生成器（每个 task 一个实例）
class FlowIdGenerator {
    private let lock = NSLock()
    private var lastTimestamp: Int64 = 0
    private var sequence: Int = 0

    func next() -> String {
        lock.lock()
        defer { lock.unlock() }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        if now == lastTimestamp {
            sequence += 1
        } else {
            lastTimestamp = now
            sequence = 1
        }
        return String(format: "%lld_%04d", now, sequence)
    }
}
```

---

## 后台解码队列

### DecodeScheduler

```swift
class DecodeScheduler {
    /// 闲时异步解码：NIO 线程调用，将 flowId 加入队列
    func enqueueAsync(flowId: String)

    /// 拦截同步解码：断点/脚本命中时，返回 EventLoopFuture
    /// EventLoop 挂起当前请求转发但继续处理其他连接 I/O
    func decodeSynchronously(flowId: String, eventLoop: EventLoop) -> EventLoopFuture<DecodedPayload>
}
```

### 解码调度策略

```
请求到达
    │
    ▼
命中断点/JS 脚本规则？──→ 否 ──→ 入队闲时解码队列（异步，不阻塞转发）
    │
    是
    ▼
同步解码（DecodeScheduler 队列执行，EventLoop 挂起等待 Future）
    ▼
解码结果交给断点 UI / JS 脚本修改
    ▼
修改后数据替换原始数据转发
    ▼
同时写入 decoded.db + payloads/decoded/
如有修改 → 额外写入 payloads/modified/ + state.db (ModifyLog)
```

关键：EventLoop 线程不做任何阻塞操作。`decodeSynchronously` 返回 `EventLoopFuture`，EventLoop 挂起当前请求但继续处理其他连接。

---

## 协议扩展接口

### ProtocolRecorder 协议

```swift
protocol ProtocolRecorder {
    static var protocolName: String { get }
    static var searchKeyMapping: SearchKeyMapping { get }
    func buildFlowRecord() -> FlowRecord
}

struct FlowRecord {
    let flowId: String
    let protocolName: String
    let host: String
    let port: Int
    let startedAt: TimeInterval
    var endedAt: TimeInterval?
    var uploadBytes: Int64 = 0
    var downloadBytes: Int64 = 0
    var status: FlowStatus = .inProgress
    var errorMessage: String = ""
    var summary: String = ""
    // 高频查询字段
    var searchKey1: String = ""
    var searchKey2: String = ""
    var searchKey3: String = ""
    var searchKey4: String = ""
    // 详细时间线（可选）
    var connectAt: TimeInterval?
    var connectedAt: TimeInterval?
    var tlsDoneAt: TimeInterval?
    var reqEndAt: TimeInterval?
    var rspStartAt: TimeInterval?
    // 协议特有字段（序列化为 JSON TEXT）
    // 实现时应使用 Codable 协议或 [String: AnyCodable] 替代 [String: Any]
    var metadata: [String: Any] = [:]
    var reqPayloadRef: String = ""
    var rspPayloadRef: String = ""
}
```

### 新协议接入清单

| 步骤 | 工作内容 | 涉及文件 | 改动量 |
|------|---------|---------|-------|
| 1 | 实现 `ProtocolRecorder` | 新建 `XXXRecorder.swift` | 一个文件 |
| 2 | 定义 searchKey 映射 | 同上 | 4 行 |
| 3 | 在 ProtocolRouter 注册 | `ProtocolRouter.swift` | 几行 |
| 4 | 实现 ChannelHandler | 新建/复用 Handler | 视复杂度 |
| - | **不需要改动的** | Schema、DAO、PathManager、解码队列 | **零** |

---

## 路径管理

### PathManager

```swift
enum PathManager {
    static var root: String                              // App Group 根目录
    static var catalogDBPath: String                     // catalog.db 路径
    static func taskDirectory(_ taskId: Int64) -> String
    static func transportDBPath(_ taskId: Int64) -> String
    static func protocolDBPath(_ taskId: Int64) -> String
    static func decodedDBPath(_ taskId: Int64) -> String
    static func stateDBPath(_ taskId: Int64) -> String
    static func rawPayloadPath(taskId: Int64, ref: String) -> String
    static func decodedPayloadPath(taskId: Int64, flowId: String, direction: PayloadDirection) -> String
    static func modifiedPayloadPath(taskId: Int64, flowId: String, version: Int, direction: PayloadDirection) -> String
    static func ensureTaskDirectories(_ taskId: Int64) throws
}
```

所有文件路径的唯一入口，其他模块不应自行拼路径。

---

## 迁移方案

### 渐进式替换（3 个阶段）

**阶段 1：新架构并行运行**
- 新建所有新的 Schema、DAO、Manager
- 现有 Handler 中双写：同时写入旧 Session 和新 FlowRecord
- UI 仍然读旧库
- 目的：验证新架构正确性和性能

**阶段 2：UI 切换到新库**
- UI 层从旧 Session 切换到新 Flow
- 移除旧 Session 的写入

**阶段 3：清理旧代码**
- 移除 ActiveSQLite 框架
- 移除旧的 Session、CaptureTask 模型
- 移除 nio.db

### 旧数据迁移

提供 `LegacyMigrator` 一次性迁移工具：
- CaptureTask → catalog.db (capture_task)
- Rule → catalog.db (rule)，`config` 字段原样迁移，`default_strategy`/`blacklist_enabled` 从 config 中解析提取
- Session → protocol.db (flow)
- body 文件 → payloads/raw/（文件移动，非复制）

**迁移安全措施**：
- 迁移前先备份 `nio.db`
- 使用事务保证原子性：单个 task 的所有 session 在一个事务内迁移
- 迁移中断恢复：记录迁移进度到 `catalog.db` 的 `migration_state` 键值，重启后从断点继续
- 迁移完成后保留 `nio.db.bak`，用户确认无误后可手动删除

### 新旧字段映射

| 旧 Session 字段 | 新位置 | 新字段 |
|-----------------|--------|--------|
| host, schemes, methods, uri | protocol.db → flow | host, searchKey1, searchKey2 |
| reqHeads, rspHeads | protocol.db → flow.metadata | JSON |
| reqBody, rspBody | payloads/raw/ | flow.req_payload_ref, rsp_payload_ref |
| state(statusCode) | protocol.db → flow | searchKey3 |
| reqType/rspType | protocol.db → flow | searchKey4 |
| startTime, endTime | protocol.db → flow | started_at, ended_at |
| connectTime, connectedTime | protocol.db → flow | connect_at, connected_at |
| handshakeEndTime | protocol.db → flow | tls_done_at |
| reqEndTime | protocol.db → flow | req_end_at |
| rspStartTime | protocol.db → flow | rsp_start_at |
| uploadTraffic, downloadFlow | protocol.db → flow | upload_bytes, download_bytes |
| sstate | protocol.db → flow | status |
| taskID | 不需要 | 库本身在 task 目录下 |
| fileFolder | 不需要 | PathManager 统一管理 |

---

## 跨库关联

各库通过 `flow_id` 关联，但**不做跨库 JOIN**——应用层按需从不同库查询。

```
transport.db (Packet.flow_id)
        ↕
protocol.db  (Flow.flow_id)      ← 主键，所有关联的锚点
        ↕
decoded.db   (DecodedEntry.flow_id)
        ↕
state.db     (Connection.flow_id, ModifyLog.flow_id)
```

典型查询路径：
1. UI 列表 → `protocol.db` 查 Flow 列表
2. 用户点击某条 Flow → 用 `flow_id` 查 `decoded.db` 获取解码内容
3. 需要重放 → 用 `flow_id` 查 `transport.db` 获取原始包序列
4. 查看修改历史 → 用 `flow_id` 查 `state.db` 的 ModifyLog
