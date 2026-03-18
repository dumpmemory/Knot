import SwiftUI

struct SessionDetailView: View {
    let sessionId: String

    var body: some View {
        Text("Session Detail — \(sessionId)")
            .navigationTitle("会话详情")
    }
}
