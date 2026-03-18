# 17 - XML 协议解析

## Netty 对应模块
`codec-xml` — XmlFrameDecoder, XmlDocumentDecoder

## 功能描述
解析 XML-based 协议:
- SOAP Web Services
- XML-RPC
- RSS/Atom feeds

## 价值
- 企业应用 SOAP API 调试
- 部分旧系统仍使用 XML API

## 当前状态
HTTP 响应体已可抓取。如果 content-type 是 text/xml 或 application/soap+xml，
只需在 UI 层添加 XML 语法高亮和格式化即可，不需要在管道层做特殊处理。

## 难度: 低 (UI 层格式化)
