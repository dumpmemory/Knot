//
//  SessionRecorder.swift
//  TunnelServices
//
//  Pure data recording logic, completely decoupled from NIO pipeline.
//  Extracts session field population from handler code.
//

import Foundation
import NIOHTTP1
import NIO

/// Records HTTP session data to the database and file system.
/// This is NOT a ChannelHandler - it's a plain helper used by handlers.
public class SessionRecorder {

    public let session: Session
    public let task: CaptureTask

    public init(task: CaptureTask) {
        self.task = task
        self.session = Session.newSession(task)
        session.inState = "open"
        session.startTime = NSNumber(value: Date().timeIntervalSince1970)
    }

    // MARK: - Request Recording

    public func recordRequestHead(_ head: HTTPRequestHead, localAddress: SocketAddress?, isSSL: Bool) {
        session.reqLine = "\(head.method) \(head.uri) \(head.version)"
        session.host = head.headers["Host"].first
        session.localAddress = Session.getIPAddress(socketAddress: localAddress)
        session.methods = "\(head.method)"
        session.uri = head.uri
        session.reqHttpVersion = "\(head.version)"
        session.target = Session.getUserAgent(target: head.headers["User-Agent"].first)
        session.reqHeads = Session.getHeadsJson(headers: head.headers)
        session.reqEncoding = head.headers["Content-Encoding"].first ?? ""
        session.reqType = head.headers["Content-Type"].first ?? ""

        if !isSSL {
            session.ignore = task.rule.matching(
                host: session.host ?? "", uri: head.uri, target: session.target ?? ""
            )
            if task.rule.defaultStrategy == .COPY {
                session.ignore = !session.ignore
            }
        }

        session.connectTime = NSNumber(value: Date().timeIntervalSince1970)
        try? session.saveToDB()
    }

    public func recordRequestBody(_ buffer: ByteBuffer) {
        guard !session.ignore else { return }
        session.writeBody(type: .REQ, buffer: buffer)
    }

    public func recordRequestEnd() {
        guard !session.ignore else { return }
        session.writeBody(type: .REQ, buffer: nil)
        session.reqEndTime = NSNumber(value: Date().timeIntervalSince1970)
        try? session.saveToDB()
    }

    // MARK: - Connection Recording

    public func recordConnected(remoteAddress: SocketAddress?) {
        session.connectedTime = NSNumber(value: Date().timeIntervalSince1970)
        session.outState = "open"
        session.remoteAddress = Session.getIPAddress(socketAddress: remoteAddress)
        try? session.saveToDB()
    }

    public func recordHandshakeComplete() {
        session.handshakeEndTime = NSNumber(value: Date().timeIntervalSince1970)
    }

    public func recordConnectionError(_ error: Error, host: String, port: Int) {
        session.outState = "failure"
        session.note = "error:connect \(host):\(port) failure:\(error)"
    }

    // MARK: - Response Recording

    public func recordResponseHead(_ head: HTTPResponseHead) {
        session.rspStartTime = NSNumber(value: Date().timeIntervalSince1970)
        session.rspHttpVersion = "\(head.version)"
        session.state = "\(head.status.code)"
        session.rspMessage = head.status.reasonPhrase
        session.rspType = head.headers["Content-Type"].first ?? ""
        session.rspEncoding = head.headers["Content-Encoding"].first ?? ""
        session.rspHeads = Session.getHeadsJson(headers: head.headers)
        session.rspDisposition = head.headers["Content-Disposition"].first ?? ""

        if let contentType = head.headers["Content-Type"].first?.components(separatedBy: ";").first {
            session.suffix = contentType.components(separatedBy: "/").last ?? ""
        }

        try? session.saveToDB()
    }

    public func recordResponseBody(_ buffer: ByteBuffer) {
        guard !session.ignore else { return }
        if session.fileName == "" {
            if let fileName = session.uri?.getFileName() {
                session.fileName = fileName
                let nameParts = session.fileName.components(separatedBy: ".")
                if nameParts.count < 2 {
                    let type = session.rspType.getRealType()
                    if type != "" { session.fileName = "\(session.fileName).\(type)" }
                }
                try? session.saveToDB()
            }
        }
        session.writeBody(type: .RSP, buffer: buffer, realName: session.fileName)
    }

    public func recordResponseEnd() {
        guard !session.ignore else { return }
        session.writeBody(type: .RSP, buffer: nil, realName: session.fileName)
        session.rspEndTime = NSNumber(value: Date().timeIntervalSince1970)
    }

    // MARK: - Traffic Counting

    public func addUpload(_ bytes: Int) {
        session.uploadTraffic = NSNumber(value: session.uploadTraffic.intValue + bytes)
    }

    public func addDownload(_ bytes: Int) {
        session.downloadFlow = NSNumber(value: session.downloadFlow.intValue + bytes)
    }

    // MARK: - Lifecycle

    public func recordClosed() {
        session.endTime = NSNumber(value: Date().timeIntervalSince1970)
        try? session.saveToDB()
        if !session.ignore {
            task.sendInfo(
                url: session.getFullUrl(),
                uploadTraffic: session.uploadTraffic,
                downloadFlow: session.downloadFlow
            )
        }
    }

    public func recordError(_ message: String) {
        session.sstate = "failure"
        session.note = message
    }
}
