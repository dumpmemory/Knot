import SwiftUI

public struct SessionHeaderList: View {
    public let isRequest: Bool
    public let sessionId: String

    public init(isRequest: Bool, sessionId: String) {
        self.isRequest = isRequest
        self.sessionId = sessionId
    }

    public var body: some View {
        Text(isRequest ? "Request Headers" : "Response Headers")
            .navigationTitle(isRequest ? "请求头" : "响应头")
    }
}
