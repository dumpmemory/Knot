import SwiftUI

struct PageSwitcher: View {
    @Bindable var nav: NavigationState

    var body: some View {
        HStack(spacing: 0) {
            tabItem(
                title: "首页",
                systemImage: "gauge",
                page: .dashboard
            )
            tabItem(
                title: "规则",
                systemImage: "ruler",
                page: .ruleList
            )
            tabItem(
                title: "证书",
                systemImage: "lock.shield",
                page: .certificate
            )
            tabItem(
                title: "设置",
                systemImage: "gearshape",
                page: .settings
            )
        }
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    @ViewBuilder
    private func tabItem(title: String, systemImage: String, page: PrimaryPage) -> some View {
        let isSelected = nav.primaryPage == page
        Button {
            nav.switchPrimary(to: page)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}
