# 11 - HAProxy Protocol 支持

## Netty 对应模块
`codec-haproxy` — HAProxyMessage, HAProxyProtocolVersion, HAProxyMessageDecoder

## 功能描述
支持 HAProxy PROXY Protocol v1/v2，在代理链中传递原始客户端 IP。

## 价值
- 在 Knot 作为中间代理时，保留原始客户端 IP 信息
- 支持企业级代理链部署

## 协议格式
- v1: `PROXY TCP4 192.168.1.1 10.0.0.1 12345 80\r\n`
- v2: 12 字节签名 + 二进制头

## 难度: 低
