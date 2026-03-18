//
//  CertGenerator.swift
//  TunnelServices
//
//  Pure Swift certificate generation using apple/swift-certificates.
//  Replaces the BoringSSL-based CertUtils.
//

import Foundation
import X509
import SwiftASN1
import Crypto
import _CryptoExtras
import NIOSSL

public class CertGenerator {

    /// Generate a dynamic TLS certificate for the given host, signed by the CA.
    /// This is the core of MITM - we create a fake cert that the proxy presents to the client.
    public static func generateCert(
        host: String,
        rsaKey: _RSA.Signing.PrivateKey,
        caKey: _RSA.Signing.PrivateKey,
        caCert: Certificate
    ) throws -> Certificate {
        let subject = try DistinguishedName {
            CountryName(ProxyConfig.CertSubject.country)
            OrganizationName(ProxyConfig.CertSubject.organization)
            CommonName(host)
        }

        let extensions = try Certificate.Extensions {
            Critical(BasicConstraints.notCertificateAuthority)
            try ExtendedKeyUsage([.serverAuth, .ocspSigning])
            SubjectKeyIdentifier(
                keyIdentifier: ArraySlice(Crypto.SHA256.hash(data: rsaKey.publicKey.derRepresentation))
            )
            SubjectAlternativeNames([.dnsName(host)])
        }

        let now = Date()
        let cert = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: Certificate.PublicKey(rsaKey.publicKey),
            notValidBefore: now,
            notValidAfter: now.addingTimeInterval(86400 * 365),
            issuer: caCert.subject,
            subject: subject,
            signatureAlgorithm: .sha256WithRSAEncryption,
            extensions: extensions,
            issuerPrivateKey: Certificate.PrivateKey(rsaKey)
        )

        return cert
    }

    /// Convert a swift-certificates Certificate to NIOSSLCertificate (for TLS handler use).
    public static func toNIOSSL(_ cert: Certificate) throws -> NIOSSLCertificate {
        var serializer = DER.Serializer()
        try cert.serialize(into: &serializer)
        let derBytes = serializer.serializedBytes
        return try NIOSSLCertificate(bytes: derBytes, format: .der)
    }

    /// Load a Certificate from a PEM file (using swift-certificates).
    public static func loadCertificate(fromPEMFile path: String) throws -> Certificate {
        let pemString = try String(contentsOfFile: path, encoding: .utf8)
        return try Certificate(pemEncoded: pemString)
    }

    /// Load an RSA private key from a PEM file.
    public static func loadRSAPrivateKey(fromPEMFile path: String) throws -> _RSA.Signing.PrivateKey {
        let pemString = try String(contentsOfFile: path, encoding: .utf8)
        return try _RSA.Signing.PrivateKey(pemRepresentation: pemString)
    }
}
