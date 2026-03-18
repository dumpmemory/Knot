import SwiftUI

struct RuleAddView: View {
    let ruleId: String

    var body: some View {
        Text("Add Rule — \(ruleId)")
            .navigationTitle("添加规则")
    }
}
