//
//  PacketTunnelProvider.swift
//  PacketTunnel
//
//  Hybrid Packet Tunnel: HTTP Proxy + IP Packet Capture
//
//  Architecture:
//  ┌─────────────────────────────────────────────┐
//  │  NEPacketTunnelProvider                       │
//  │                                               │
//  │  ┌─ NEProxySettings ──────────────────────┐  │
//  │  │  HTTP/HTTPS → MitmService (port 8034)  │  │
//  │  │  → HTTP/HTTPS/WS/gRPC/H2 capture      │  │
//  │  └────────────────────────────────────────┘  │
//  │                                               │
//  │  ┌─ packetFlow (IP packets) ──────────────┐  │
//  │  │  ALL traffic → PacketCaptureEngine      │  │
//  │  │  TCP → log + passthrough (proxy handles)│  │
//  │  │  UDP → decode + forward via NWConnection│  │
//  │  │    ├─ DNS  (port 53)  → DNSDecoder     │  │
//  │  │    ├─ NTP  (port 123) → NTPDecoder     │  │
//  │  │    ├─ QUIC (port 443) → QUICDecoder    │  │
//  │  │    └─ other           → raw capture    │  │
//  │  │  ICMP → log                             │  │
//  │  └────────────────────────────────────────┘  │
//  └─────────────────────────────────────────────┘
//

import NetworkExtension
import TunnelServices
import Network

class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - Properties

    var mitmServer: MitmService!
    private let captureEngine = PacketCaptureEngine()
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.knot.tunnel.network")

    var pendingStartCompletion: ((Error?) -> Void)?
    var pendingStopCompletion: (() -> Void)?

    // MARK: - Start Tunnel

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        pendingStartCompletion = completionHandler
        captureEngine.delegate = self

        // Step 1: Start MITM proxy server (handles HTTP/HTTPS)
        guard let server = MitmService.prepare() else {
            NSLog("PacketTunnel: MitmService.prepare() failed")
            completionHandler(nil)
            return
        }
        mitmServer = server

        mitmServer.run { [weak self] result in
            switch result {
            case .success:
                // Step 2: Configure tunnel network settings
                self?.configureTunnel { error in
                    if let error = error {
                        NSLog("PacketTunnel: configureTunnel failed: %@", error.localizedDescription)
                        completionHandler(error)
                        return
                    }

                    NSLog("PacketTunnel: Started successfully (HTTP Proxy + Packet Capture)")

                    // Step 3: Start reading IP packets
                    self?.startPacketCapture()

                    // Step 4: Start network monitoring
                    self?.startNetworkMonitor()

                    completionHandler(nil)
                }

            case .failure(let error):
                NSLog("PacketTunnel: MitmService.run() failed: %@", error.localizedDescription)
                completionHandler(error)
            }
        }
    }

    // MARK: - Configure Tunnel

    private func configureTunnel(completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: ProxyConfig.VPN.tunnelAddress)
        settings.mtu = ProxyConfig.VPN.mtu

        // --- HTTP Proxy (handles HTTP/HTTPS via MitmService) ---
        let proxySettings = NEProxySettings()
        proxySettings.httpServer = NEProxyServer(address: ProxyConfig.LocalProxy.host, port: ProxyConfig.LocalProxy.port)
        proxySettings.httpEnabled = true
        proxySettings.httpsServer = NEProxyServer(address: ProxyConfig.LocalProxy.host, port: ProxyConfig.LocalProxy.port)
        proxySettings.httpsEnabled = true
        proxySettings.matchDomains = [""]
        settings.proxySettings = proxySettings

        // --- IPv4 Settings (enables packet capture for ALL traffic) ---
        let ipv4 = NEIPv4Settings(
            addresses: [ProxyConfig.VPN.ipv4Address],
            subnetMasks: [ProxyConfig.VPN.subnetMask]
        )
        // Route all traffic through the tunnel
        ipv4.includedRoutes = [NEIPv4Route.default()]
        // Exclude local network and proxy itself
        ipv4.excludedRoutes = [
            NEIPv4Route(destinationAddress: "127.0.0.0", subnetMask: "255.0.0.0"),    // localhost
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"), // local network
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),      // private network
        ]
        settings.ipv4Settings = ipv4

        // --- IPv6 Settings ---
        let ipv6 = NEIPv6Settings(
            addresses: ["fd00::1"],
            networkPrefixLengths: [64]
        )
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        // --- DNS Settings (capture DNS queries) ---
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        dnsSettings.matchDomains = [""]  // Match all domains
        settings.dnsSettings = dnsSettings

        setTunnelNetworkSettings(settings) { error in
            completionHandler(error)
        }
    }

    // MARK: - Packet Capture Loop

    private func startPacketCapture() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self else { return }

            for (index, packetData) in packets.enumerated() {
                let protoNumber = protocols[index].uint32Value

                // Process through capture engine
                let handled = self.captureEngine.processOutboundPacket(packetData, protocolNumber: protoNumber)

                if !handled {
                    // TCP and other non-UDP packets: write back to tunnel for normal routing
                    // The proxy settings will redirect HTTP/HTTPS to MitmService
                    self.packetFlow.writePackets([packetData], withProtocols: [protocols[index]])
                }
                // UDP packets are handled by PacketCaptureEngine (forwarded via NWConnection)
            }

            // Continue reading
            self.startPacketCapture()
        }
    }

    // MARK: - Network Monitor

    private func startNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                NSLog("PacketTunnel: Network available (\(path.usesInterfaceType(.wifi) ? "WiFi" : "Cellular"))")
            } else {
                NSLog("PacketTunnel: Network unavailable")
            }
            _ = self
        }
        pathMonitor.start(queue: monitorQueue)
    }

    // MARK: - Stop Tunnel

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("PacketTunnel: Stopping (reason: \(reason.rawValue))")
        pathMonitor.cancel()
        captureEngine.shutdown()
        mitmServer?.close(completionHandler)
    }

    // MARK: - App Messages

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        // Handle messages from the main app
        // Can be used to toggle capture, change settings, etc.
        if let command = String(data: messageData, encoding: .utf8) {
            switch command {
            case "start_pcap":
                let path = MitmService.getStoreFolder() + "capture.pcap"
                captureEngine.startPCAPRecording(filePath: path)
                completionHandler?("pcap_started".data(using: .utf8))
            case "stop_pcap":
                captureEngine.stopPCAPRecording()
                completionHandler?("pcap_stopped".data(using: .utf8))
            case "stats":
                let stats = captureEngine.statistics
                let json = "{\"packets\":\(stats.packets),\"tcp\":\(stats.tcp),\"udp\":\(stats.udp),\"icmp\":\(stats.icmp)}"
                completionHandler?(json.data(using: .utf8))
            default:
                completionHandler?(nil)
            }
        }
    }
}

// MARK: - PacketCaptureDelegate

extension PacketTunnelProvider: PacketCaptureDelegate {

    func didCapturePacket(_ packet: CapturedPacket) {
        // Log packet summary for debugging
        // In production, send to main app via IPC
        #if DEBUG
        NSLog("PKT %@ %@ %@",
              packet.direction.rawValue,
              packet.decodedProtocol ?? packet.ipPacket.proto.name,
              packet.summary)
        #endif
    }

    func writePacket(_ data: Data, protocolNumber: UInt32) {
        // Write response packet back to the tunnel (for UDP responses)
        let proto = NSNumber(value: protocolNumber)
        packetFlow.writePackets([data], withProtocols: [proto])
    }
}
