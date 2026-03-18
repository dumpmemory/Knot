import SwiftUI

struct HistoryTaskView: View {
    @Bindable var nav: NavigationState

    var body: some View {
        Text("History Task")
            .navigationTitle("历史任务")
    }
}
