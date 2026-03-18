import Foundation
import os

public struct Log {
    private static let subsystem = "com.knot.app"
    public static let general = Logger(subsystem: subsystem, category: "general")
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let proxy = Logger(subsystem: subsystem, category: "proxy")
    public static let tunnel = Logger(subsystem: subsystem, category: "tunnel")
    public static let database = Logger(subsystem: subsystem, category: "database")
    public static let cert = Logger(subsystem: subsystem, category: "certificate")
}
