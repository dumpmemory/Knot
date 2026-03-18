# 16 - 压缩算法增强

## Netty 对应模块
`codec/compression` — Brotli, Zstd, LZ4, Snappy, LZMA (13种压缩算法)

## 功能描述
当前仅支持 gzip/deflate 解压（NIOHTTPResponseDecompressor），可扩展支持:
- **Brotli** (br): 现代 Web 标准，越来越多 CDN 使用
- **Zstandard** (zstd): Facebook 开发，比 gzip 更快更小
- **LZ4**: 游戏/实时应用使用的快速压缩

## 当前状态
已通过 `NIOHTTPResponseDecompressor` 支持 gzip/deflate。

## 扩展方案
Swift 端可使用 Apple 的 `Compression` framework (支持 lz4, lzma, zlib, lzfse)
或 SPM 包 `swift-compression` 添加 Brotli/Zstd。

## 难度: 中
