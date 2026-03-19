//
//  MacPacketTunnelProvider.swift
//  SystemExtension-macOS
//
//  macOS System Extension Packet Tunnel Provider
//
//  Architecture mirrors iOS PacketTunnelProvider but with macOS-specific
//  DNS and route configuration. Runs as a system extension (not in-process).
//

import NetworkExtension
import TunnelServices
import Network

class MacPacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - Properties

    var mitmServer: MitmService!
    private let captureEngine = PacketCaptureEngine()
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.knot.sysext.network")

    // MARK: - Start Tunnel

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        captureEngine.delegate = self

        guard let server = MitmService.prepare() else {
            NSLog("SystemExtension-macOS: MitmService.prepare() failed")
            completionHandler(nil)
            return
        }
        mitmServer = server

        mitmServer.run { [weak self] result in
            switch result {
            case .success:
                self?.configureTunnel { error in
                    if let error = error {
                        NSLog("SystemExtension-macOS: configureTunnel failed: %@", error.localizedDescription)
                        completionHandler(error)
                        return
                    }
                    NSLog("SystemExtension-macOS: Started successfully")
                    self?.startPacketCapture()
                    self?.startNetworkMonitor()
                    completionHandler(nil)
                }

            case .failure(let error):
                NSLog("SystemExtension-macOS: MitmService.run() failed: %@", error.localizedDescription)
                completionHandler(error)
            }
        }
    }

    // MARK: - Configure Tunnel (macOS-specific)

    private func configureTunnel(completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: ProxyConfig.VPN.tunnelAddress)
        settings.mtu = ProxyConfig.VPN.mtu

        // HTTP Proxy
        let proxySettings = NEProxySettings()
        proxySettings.httpServer = NEProxyServer(address: ProxyConfig.LocalProxy.host, port: ProxyConfig.LocalProxy.port)
        proxySettings.httpEnabled = true
        proxySettings.httpsServer = NEProxyServer(address: ProxyConfig.LocalProxy.host, port: ProxyConfig.LocalProxy.port)
        proxySettings.httpsEnabled = true
        proxySettings.matchDomains = [""]
        settings.proxySettings = proxySettings

        // IPv4
        let ipv4 = NEIPv4Settings(
            addresses: [ProxyConfig.VPN.ipv4Address],
            subnetMasks: [ProxyConfig.VPN.subnetMask]
        )
        ipv4.includedRoutes = [NEIPv4Route.default()]
        // macOS: also exclude link-local and multicast ranges
        var excludedRoutes = ProxyConfig.VPN.excludedIPv4Routes.map {
            NEIPv4Route(destinationAddress: $0.0, subnetMask: $0.1)
        }
        excludedRoutes.append(NEIPv4Route(destinationAddress: "169.254.0.0", subnetMask: "255.255.0.0"))  // link-local
        excludedRoutes.append(NEIPv4Route(destinationAddress: "224.0.0.0",   subnetMask: "240.0.0.0"))   // multicast
        ipv4.excludedRoutes = excludedRoutes
        settings.ipv4Settings = ipv4

        // IPv6
        let ipv6 = NEIPv6Settings(
            addresses: [ProxyConfig.VPN.ipv6Address],
            networkPrefixLengths: [64]
        )
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        // DNS — macOS supports split DNS; route all through tunnel DNS
        let dnsSettings = NEDNSSettings(servers: ProxyConfig.VPN.dnsServers)
        dnsSettings.matchDomains = [""]
        dnsSettings.matchDomainsNoSearch = false
        settings.dnsSettings = dnsSettings

        setTunnelNetworkSettings(settings) { error in
            completionHandler(error)
        }
    }

    // MARK: - Packet Capture

    private func startPacketCapture() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self else { return }

            for (index, packetData) in packets.enumerated() {
                let protoNumber = protocols[index].uint32Value
                let handled = self.captureEngine.processOutboundPacket(packetData, protocolNumber: protoNumber)
                if !handled {
                    self.packetFlow.writePackets([packetData], withProtocols: [protocols[index]])
                }
            }

            self.startPacketCapture()
        }
    }

    // MARK: - Network Monitor

    private func startNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { path in
            NSLog("SystemExtension-macOS: Network \(path.status == .satisfied ? "available" : "unavailable")")
        }
        pathMonitor.start(queue: monitorQueue)
    }

    // MARK: - Stop Tunnel

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("SystemExtension-macOS: Stopping (reason: \(reason.rawValue))")
        pathMonitor.cancel()
        captureEngine.shutdown()
        mitmServer?.close(completionHandler)
    }

    // MARK: - App Messages

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let command = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }
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

// MARK: - PacketCaptureDelegate

extension MacPacketTunnelProvider: PacketCaptureDelegate {

    func didCapturePacket(_ packet: CapturedPacket) {
        #if DEBUG
        NSLog("PKT %@ %@ %@",
              packet.direction.rawValue,
              packet.decodedProtocol ?? packet.ipPacket.proto.name,
              packet.summary)
        #endif
    }

    func writePacket(_ data: Data, protocolNumber: UInt32) {
        packetFlow.writePackets([data], withProtocols: [NSNumber(value: protocolNumber)])
    }
}
