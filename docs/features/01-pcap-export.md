# 01 - PCAP 文件导出

## Netty 对应模块
`handler/pcap` — PcapWriteHandler, PcapWriter, PcapHeaders, TCPPacket, UDPPacket, IPPacket, EthernetPacket

## 功能描述
将 Knot 抓取的网络流量导出为标准 `.pcap` 文件格式，可直接在 **Wireshark**、**tcpdump** 等工具中打开分析。

## 为什么有价值
- 用户可以用专业工具深入分析流量
- 可以分享给其他开发者协作排查问题
- 支持离线分析
- `.pcap` 是行业标准，所有网络工具都支持

## 实现思路

### 数据来源
Knot 的 `SessionRecorder` 已经记录了完整的请求/响应数据，只需要将这些数据按 pcap 格式封装。

### PCAP 文件格式

```
PCAP Global Header (24 bytes)
  magic_number:  0xa1b2c3d4
  version_major: 2
  version_minor: 4
  snaplen:       65535
  network:       LINKTYPE_RAW (101) 或 LINKTYPE_ETHERNET (1)

For each packet:
  Packet Header (16 bytes)
    ts_sec:    timestamp seconds
    ts_usec:   timestamp microseconds
    incl_len:  captured length
    orig_len:  original length

  Packet Data
    [IP Header] [TCP Header] [Payload]
```

### 实现方式

```swift
// 新增文件: TunnelServices/Export/PCAPExporter.swift

public class PCAPExporter {
    /// 将一组 Session 导出为 .pcap 文件
    public static func export(sessions: [Session], to url: URL) throws

    /// 实时写入模式：每抓一个包写一条记录
    public static func createWriter(at url: URL) throws -> PCAPWriter
}

public class PCAPWriter {
    func writePacket(timestamp: Date, srcIP: String, srcPort: UInt16,
                     dstIP: String, dstPort: UInt16, payload: Data, isTCP: Bool)
    func close()
}
```

### 集成点
- `SessionRecorder.recordClosed()` 时可选地追加到 pcap 文件
- 导出按钮: Session 列表 → 选中 → 导出为 .pcap
- swift-nio-extras 已提供 `PCAPRingBuffer`，可以直接使用

## SwiftNIO 现有支持
`swift-nio-extras` 的 `NIOWritePCAPHandler` 已支持 pcap 写入，可直接集成到管道中。

## 难度评估
**低** — pcap 格式简单固定，swift-nio-extras 已有基础实现。
