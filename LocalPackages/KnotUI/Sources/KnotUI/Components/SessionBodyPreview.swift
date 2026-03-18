import SwiftUI

public struct SessionBodyPreview: View {
    public let isRequest: Bool
    public let sessionId: String

    public init(isRequest: Bool, sessionId: String) {
        self.isRequest = isRequest
        self.sessionId = sessionId
    }

    public var body: some View {
        Text(isRequest ? "Request Body" : "Response Body")
            .navigationTitle(isRequest ? "请求体" : "响应体")
    }
}
