import SwiftUI

struct RuleDetailView: View {
    let ruleId: String
    @Bindable var nav: NavigationState

    var body: some View {
        Text("Rule Detail — \(ruleId)")
            .navigationTitle("规则详情")
    }
}
