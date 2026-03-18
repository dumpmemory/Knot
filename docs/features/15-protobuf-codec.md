# 15 - Protobuf 编解码

## Netty 对应模块
`codec/protobuf` — ProtobufDecoder, ProtobufEncoder, ProtobufVarint32FrameDecoder

## 功能描述
Protocol Buffers 消息的编解码。

## 当前状态
**已实现。** `GRPCCaptureHandler.swift` 中的 `ProtobufDecoder` 已支持无 schema 的 protobuf wire format 解码。

## 可扩展方向
- 支持加载 .proto 文件，显示字段名而非 f1/f2
- 支持 protobuf 消息的编辑和重发
- 支持 gRPC reflection API 自动获取 schema

## 难度: 已实现基础版
