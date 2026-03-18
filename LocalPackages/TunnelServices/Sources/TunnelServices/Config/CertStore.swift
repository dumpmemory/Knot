//
//  CertStore.swift
//  TunnelServices
//
//  Centralized certificate and key loading.
//  Eliminates duplicated loadCACert() across CaptureTask and SSLServer.
//

import Foundation
import NIOSSL
import X509
import _CryptoExtras

public class CertStore {

    public let cacert: NIOSSLCertificate?
    public let cakey: NIOSSLPrivateKey?
    public let rsakey: NIOSSLPrivateKey?
    public let x509CACert: Certificate?
    public let rsaSigningKey: _RSA.Signing.PrivateKey?

    public var isValid: Bool {
        cacert != nil && cakey != nil && rsakey != nil && x509CACert != nil && rsaSigningKey != nil
    }

    public init() {
        guard let certDir = CertStore.certDirectoryURL() else {
            cacert = nil; cakey = nil; rsakey = nil; x509CACert = nil; rsaSigningKey = nil
            return
        }

        let certPath = CertStore.filePath(in: certDir, name: ProxyConfig.CertFiles.caCert)
        let keyPath = CertStore.filePath(in: certDir, name: ProxyConfig.CertFiles.caKey)
        let rsaPath = CertStore.filePath(in: certDir, name: ProxyConfig.CertFiles.rsaKey)

        cacert = try? NIOSSLCertificate(file: certPath, format: .pem)
        cakey = try? NIOSSLPrivateKey(file: keyPath, format: .pem)
        rsakey = try? NIOSSLPrivateKey(file: rsaPath, format: .pem)
        x509CACert = try? CertGenerator.loadCertificate(fromPEMFile: certPath)
        rsaSigningKey = try? CertGenerator.loadRSAPrivateKey(fromPEMFile: rsaPath)
    }

    // MARK: - Path Helpers

    public static func certDirectoryURL() -> URL? {
        let fileManager = FileManager.default
        guard var certDir = fileManager.containerURL(forSecurityApplicationGroupIdentifier: ProxyConfig.appGroupIdentifier) else {
            return nil
        }
        certDir.appendPathComponent(ProxyConfig.Storage.certFolder)
        let dirPath = certDir.path
        if !fileManager.fileExists(atPath: dirPath) {
            try? fileManager.createDirectory(at: certDir, withIntermediateDirectories: true, attributes: nil)
        }
        return certDir
    }

    static func filePath(in dir: URL, name: String) -> String {
        dir.appendingPathComponent(name, isDirectory: false).path
    }
}
