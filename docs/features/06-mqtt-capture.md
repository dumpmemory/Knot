# 06 - MQTT 协议解析

## Netty 对应模块
`codec-mqtt` — MqttDecoder, MqttEncoder, MqttMessage, MqttPublishMessage, MqttSubscribeMessage

## 功能描述
解析和展示 MQTT 协议流量（IoT 设备最常用的协议）：
- 显示 CONNECT/SUBSCRIBE/PUBLISH/DISCONNECT 消息
- 解析 Topic 名称和 QoS 等级
- 展示发布的消息内容（payload）
- 支持 MQTT 3.1.1 和 5.0

## 为什么有价值
- **IoT 开发调试**: 智能家居、传感器设备大量使用 MQTT
- **安全审计**: 检查 IoT 设备是否有异常通信
- MQTT 使用 TCP 端口 1883 (明文) 或 8883 (TLS)

## 实现思路

MQTT 运行在 TCP 之上，如果通过 SOCKS5 代理或 Packet Tunnel 拦截：

```swift
// TunnelServices/Codec/MQTTDecoder.swift

public struct MQTTPacket {
    enum PacketType: UInt8 {
        case connect = 1, connack, publish, puback, pubrec,
             pubrel, pubcomp, subscribe, suback, unsubscribe,
             unsuback, pingreq, pingresp, disconnect
    }

    let type: PacketType
    let flags: UInt8
    let remainingLength: Int
    let payload: Data

    // PUBLISH 特有:
    var topic: String?
    var message: Data?
    var qos: Int?
}

public class MQTTDecoder {
    /// 从 ByteBuffer 解析 MQTT 包
    static func decode(_ buffer: ByteBuffer) -> [MQTTPacket]

    /// 格式化为可读文本
    static func format(_ packet: MQTTPacket) -> String
    // 例: "[PUBLISH] topic=home/sensor/temp qos=1 payload=\"23.5\""
}
```

### 检测方式
MQTT CONNECT 包的前两个字节固定为: `0x10` + remaining length，之后是 `"MQTT"` 或 `"MQIsdp"` 字符串。

### 前置依赖
需要 SOCKS5 代理（功能 05）或 Packet Tunnel 才能拦截非 HTTP 的 TCP 流量。

## 难度评估
**中** — MQTT 协议本身简单（固定头 + 可变头 + payload），但需要 TCP 流拦截能力。
