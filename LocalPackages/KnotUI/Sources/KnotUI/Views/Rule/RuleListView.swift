import SwiftUI

struct RuleListView: View {
    @Bindable var nav: NavigationState

    var body: some View {
        Text("Rule List")
            .navigationTitle("规则")
    }
}
