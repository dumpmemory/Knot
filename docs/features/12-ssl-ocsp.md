# 12 - SSL/TLS 增强 (OCSP Stapling)

## Netty 对应模块
`handler-ssl-ocsp` — OcspClientHandler, OcspServerHandler

## 功能描述
- OCSP (Online Certificate Status Protocol) 查询支持
- 检查目标服务器证书的吊销状态
- 在 Session 中显示证书有效性信息

## 价值
- 安全审计: 检测使用已吊销证书的服务器
- 证书诊断: 帮助开发者排查 SSL 错误

## 实现思路
在 MITMHandler 的 TLS 握手完成后，查询目标服务器证书的 OCSP 状态，并记录到 Session。

## 难度: 中
