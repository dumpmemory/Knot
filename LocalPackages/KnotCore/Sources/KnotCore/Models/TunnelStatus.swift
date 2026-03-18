import Foundation

public enum TunnelStatus: Equatable {
    case invalid
    case disconnected
    case connecting
    case connected(since: Date)
    case disconnecting
    case reasserting
    case error(String)
}
