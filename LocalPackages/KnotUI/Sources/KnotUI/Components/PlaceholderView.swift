import SwiftUI

public struct PlaceholderView: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView(
            "暂无内容",
            systemImage: "doc.text.magnifyingglass",
            description: Text("请从左侧选择内容")
        )
    }
}
