# 09 - SMTP 协议解析

## Netty 对应模块
`codec-smtp` — SmtpRequest, SmtpResponse, SmtpCommand, SmtpContent

## 功能描述
解析 SMTP 邮件发送协议：EHLO/MAIL FROM/RCPT TO/DATA 命令及邮件内容。

## 价值
- 检测 App 是否在后台发送邮件
- 邮件 SDK 调试
- 安全审计

## 协议格式
文本协议，端口 25/587/465(TLS)。

## 难度: 低
