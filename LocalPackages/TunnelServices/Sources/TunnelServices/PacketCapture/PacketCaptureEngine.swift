//
//  PacketCaptureEngine.swift
//  TunnelServices
//
//  Central engine that processes all IP packets from the VPN tunnel.
//  Dispatches to protocol-specific decoders and forwards traffic.
//
//  Architecture:
//  ┌─────────────────────────────────────────────────────┐
//  │ PacketCaptureEngine                                  │
//  │                                                      │
//  │  IP Packet → parse → ┬─ TCP → log + passthrough      │
//  │                      ├─ UDP → decode + forward        │
//  │                      │   ├─ DNS  → DNSDecoder         │
//  │                      │   ├─ NTP  → NTPDecoder         │
//  │                      │   ├─ QUIC → QUICDecoder        │
//  │                      │   └─ raw  → log payload        │
//  │                      └─ ICMP → log                    │
//  └─────────────────────────────────────────────────────┘
//

import Foundation
// import AxLogger  // provided by AxLoggerShim in this package

// MARK: - Captured Packet Record

public struct CapturedPacket {
    public let timestamp: Date
    public let direction: Direction
    public let ipPacket: IPPacket
    public let decodedProtocol: String?   // "DNS", "NTP", "QUIC", "HTTP", etc.
    public let summary: String
    public let detail: String?

    public enum Direction: String {
        case outbound = "→"   // device → server
        case inbound = "←"    // server → device
    }
}

// MARK: - Packet Capture Delegate

public protocol PacketCaptureDelegate: AnyObject {
    /// Called for every captured packet.
    func didCapturePacket(_ packet: CapturedPacket)

    /// Called when a UDP response is ready to write back.
    func writePacket(_ data: Data, protocolNumber: UInt32)
}

// MARK: - Packet Capture Engine

public class PacketCaptureEngine {

    public weak var delegate: PacketCaptureDelegate?

    private let udpForwarder = UDPForwarder()
    private var pcapWriter: PCAPWriter?
    private var captureEnabled = true
    private var packetCount: UInt64 = 0
    private let statsLock = NSLock()

    // Statistics
    private var tcpPacketCount: UInt64 = 0
    private var udpPacketCount: UInt64 = 0
    private var icmpPacketCount: UInt64 = 0
    private var totalBytesIn: UInt64 = 0
    private var totalBytesOut: UInt64 = 0

    public init() {}

    // MARK: - Start/Stop

    /// Start pcap file recording (optional).
    public func startPCAPRecording(filePath: String) {
        pcapWriter = try? PCAPWriter(filePath: filePath)
        AxLogger.log("PCAP recording started: \(filePath)", level: .Info)
    }

    public func stopPCAPRecording() {
        pcapWriter?.close()
        pcapWriter = nil
    }

    public func shutdown() {
        udpForwarder.shutdown()
        stopPCAPRecording()
    }

    // MARK: - Process Outbound Packet (device → internet)

    /// Process a raw IP packet read from packetFlow.
    /// Returns: true if packet was handled (UDP forwarded), false if should passthrough.
    public func processOutboundPacket(_ data: Data, protocolNumber: UInt32) -> Bool {
        guard captureEnabled, let packet = IPPacketParser.parse(data) else { return false }

        statsLock.lock()
        packetCount += 1
        totalBytesOut += UInt64(data.count)
        statsLock.unlock()

        switch packet.proto {
        case .tcp:
            processTCPPacket(packet, direction: .outbound, rawData: data)
            return false  // TCP passthrough (handled by HTTP proxy)

        case .udp:
            processUDPPacket(packet, direction: .outbound, rawData: data)
            return true   // UDP handled by forwarder

        case .icmp, .icmpv6:
            processICMPPacket(packet, direction: .outbound, rawData: data)
            return false  // ICMP passthrough

        default:
            return false
        }
    }

    /// Process a response packet (internet → device).
    public func processInboundPacket(_ data: Data) {
        guard captureEnabled, let packet = IPPacketParser.parse(data) else { return }

        statsLock.lock()
        totalBytesIn += UInt64(data.count)
        statsLock.unlock()

        let summary = IPPacketParser.format(packet)
        let captured = CapturedPacket(
            timestamp: Date(), direction: .inbound, ipPacket: packet,
            decodedProtocol: nil, summary: summary, detail: nil
        )
        delegate?.didCapturePacket(captured)

        // Write to pcap
        writeToPCAP(packet: packet, rawData: data, direction: .inbound)
    }

    // MARK: - TCP Processing

    private func processTCPPacket(_ packet: IPPacket, direction: CapturedPacket.Direction, rawData: Data) {
        statsLock.lock()
        tcpPacketCount += 1
        statsLock.unlock()

        guard let tcp = packet.tcpHeader else { return }

        let summary = IPPacketParser.format(packet)
        var detail: String? = nil
        var proto: String? = nil

        // Identify well-known TCP ports
        let port = direction == .outbound ? tcp.destinationPort : tcp.sourcePort
        switch port {
        case 80: proto = "HTTP"
        case 443: proto = "HTTPS"
        case 8080, 8443: proto = "HTTP-ALT"
        case 6379: proto = "Redis"
        case 3306: proto = "MySQL"
        case 5432: proto = "PostgreSQL"
        case 27017: proto = "MongoDB"
        case 1883: proto = "MQTT"
        case 8883: proto = "MQTT-TLS"
        case 25, 587: proto = "SMTP"
        case 143, 993: proto = "IMAP"
        case 110, 995: proto = "POP3"
        case 21: proto = "FTP"
        case 22: proto = "SSH"
        case 23: proto = "Telnet"
        case 11211: proto = "Memcache"
        default: break
        }

        // For SYN packets, log connection initiation
        if tcp.isSYN && !tcp.isACK {
            detail = "New connection to \(packet.destinationIP):\(tcp.destinationPort)"
        }

        let captured = CapturedPacket(
            timestamp: Date(), direction: direction, ipPacket: packet,
            decodedProtocol: proto, summary: summary, detail: detail
        )
        delegate?.didCapturePacket(captured)
        writeToPCAP(packet: packet, rawData: rawData, direction: direction)
    }

    // MARK: - UDP Processing

    private func processUDPPacket(_ packet: IPPacket, direction: CapturedPacket.Direction, rawData: Data) {
        statsLock.lock()
        udpPacketCount += 1
        statsLock.unlock()

        guard let udp = packet.udpHeader else { return }
        let appData = packet.applicationData

        var decodedProtocol: String? = udp.knownProtocol
        var detail: String? = nil

        // Decode known UDP protocols
        let port = direction == .outbound ? udp.destinationPort : udp.sourcePort
        switch port {
        case 53: // DNS
            decodedProtocol = "DNS"
            if let dns = DNSParser.parse(appData) {
                detail = DNSParser.format(dns)
            }

        case 123: // NTP
            decodedProtocol = "NTP"
            if let ntp = NTPDecoder.parse(appData) {
                detail = NTPDecoder.format(ntp)
            }

        case 443: // QUIC
            decodedProtocol = "QUIC"
            if let quic = QUICDecoder.parseHeader(appData) {
                detail = QUICDecoder.format(quic)
            }

        case 5353: // mDNS
            decodedProtocol = "mDNS"
            if let dns = DNSParser.parse(appData) {
                detail = DNSParser.format(dns)
            }

        default:
            break
        }

        let summary = IPPacketParser.format(packet)
        let captured = CapturedPacket(
            timestamp: Date(), direction: direction, ipPacket: packet,
            decodedProtocol: decodedProtocol, summary: summary, detail: detail
        )
        delegate?.didCapturePacket(captured)
        writeToPCAP(packet: packet, rawData: rawData, direction: direction)

        // Forward UDP packet and handle response
        if direction == .outbound {
            udpForwarder.forward(packet: packet) { [weak self] responseData in
                guard let self = self, let responseData = responseData else { return }

                // Build response IP packet
                let responsePacketData = IPPacketBuilder.buildUDPResponse(
                    originalPacket: packet, payload: responseData
                )

                // Decode response
                if let responsePacket = IPPacketParser.parse(responsePacketData) {
                    self.processInboundPacket(responsePacketData)
                }

                // Write response back to tunnel
                self.delegate?.writePacket(responsePacketData, protocolNumber: packet.version == 4 ? AF_INET : AF_INET6)
            }
        }
    }

    // MARK: - ICMP Processing

    private func processICMPPacket(_ packet: IPPacket, direction: CapturedPacket.Direction, rawData: Data) {
        statsLock.lock()
        icmpPacketCount += 1
        statsLock.unlock()

        let summary = IPPacketParser.format(packet)
        let captured = CapturedPacket(
            timestamp: Date(), direction: direction, ipPacket: packet,
            decodedProtocol: "ICMP", summary: summary, detail: nil
        )
        delegate?.didCapturePacket(captured)
        writeToPCAP(packet: packet, rawData: rawData, direction: direction)
    }

    // MARK: - PCAP

    private func writeToPCAP(packet: IPPacket, rawData: Data, direction: CapturedPacket.Direction) {
        guard let writer = pcapWriter else { return }
        guard let tcp = packet.tcpHeader else {
            if let udp = packet.udpHeader {
                writer.writeUDPPacket(
                    timestamp: Date(),
                    srcIP: packet.sourceIP, srcPort: udp.sourcePort,
                    dstIP: packet.destinationIP, dstPort: udp.destinationPort,
                    payload: packet.applicationData
                )
            }
            return
        }
        writer.writeTCPPacket(
            timestamp: Date(),
            srcIP: packet.sourceIP, srcPort: tcp.sourcePort,
            dstIP: packet.destinationIP, dstPort: tcp.destinationPort,
            payload: packet.applicationData
        )
    }

    // MARK: - Statistics

    public var statistics: (packets: UInt64, tcp: UInt64, udp: UInt64, icmp: UInt64, bytesIn: UInt64, bytesOut: UInt64) {
        statsLock.lock()
        defer { statsLock.unlock() }
        return (packetCount, tcpPacketCount, udpPacketCount, icmpPacketCount, totalBytesIn, totalBytesOut)
    }
}

// MARK: - Convenience: Build response packet

public enum IPPacketBuilder {

    /// Build a UDP response packet by swapping src/dst from the original.
    public static func buildUDPResponse(originalPacket: IPPacket, payload: Data) -> Data {
        guard let udp = originalPacket.udpHeader else { return Data() }

        // Swap source and destination
        var data = Data()

        if originalPacket.version == 4 {
            // IPv4 header (20 bytes)
            let totalLength = UInt16(20 + 8 + payload.count)
            data.append(0x45)  // version + IHL
            data.append(0x00)  // DSCP
            data.append(UInt8(totalLength >> 8))
            data.append(UInt8(totalLength & 0xFF))
            data.append(contentsOf: [0, 0, 0x40, 0x00])  // ID + flags
            data.append(64)    // TTL
            data.append(17)    // UDP
            data.append(contentsOf: [0, 0])  // checksum

            // Swap: dst becomes src, src becomes dst
            for octet in originalPacket.destinationIP.split(separator: ".") {
                data.append(UInt8(octet) ?? 0)
            }
            for octet in originalPacket.sourceIP.split(separator: ".") {
                data.append(UInt8(octet) ?? 0)
            }

            // UDP header (8 bytes) - swap ports
            let udpLen = UInt16(8 + payload.count)
            data.append(UInt8(udp.destinationPort >> 8))
            data.append(UInt8(udp.destinationPort & 0xFF))
            data.append(UInt8(udp.sourcePort >> 8))
            data.append(UInt8(udp.sourcePort & 0xFF))
            data.append(UInt8(udpLen >> 8))
            data.append(UInt8(udpLen & 0xFF))
            data.append(contentsOf: [0, 0])  // checksum

            // Payload
            data.append(payload)
        }

        return data
    }
}

// MARK: - AF_INET constant for packet protocol number
private let AF_INET: UInt32 = 2
private let AF_INET6: UInt32 = 30
