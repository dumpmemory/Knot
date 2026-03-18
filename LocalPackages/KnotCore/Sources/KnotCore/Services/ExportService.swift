import Foundation
import TunnelServices

public enum ExportFormat: String, CaseIterable, Identifiable {
    case url = "URL"
    case curl = "cURL"
    case har = "HAR"
    case pcap = "PCAP"
    public var id: String { rawValue }
}

public struct ExportService {
    public init() {}

    public func export(sessions: [Session], format: ExportFormat) -> Data? {
        switch format {
        case .url:
            let urls = sessions.compactMap { $0.uri }.joined(separator: "\n")
            return urls.data(using: .utf8)
        case .curl:
            let curls = sessions.map { session -> String in
                var cmd = "curl"
                if let method = session.methods, method != "GET" { cmd += " -X \(method)" }
                if let uri = session.uri { cmd += " '\(session.schemes ?? "https")://\(session.host ?? "")\(uri)'" }
                return cmd
            }.joined(separator: "\n\n")
            return curls.data(using: .utf8)
        case .har, .pcap:
            return nil // Delegate to TunnelServices exporters
        }
    }
}
