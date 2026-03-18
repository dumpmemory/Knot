import SwiftUI

struct SessionListView: View {
    let taskId: String
    @Bindable var nav: NavigationState

    var body: some View {
        Text("Session List — \(taskId)")
            .navigationTitle("会话列表")
    }
}
