import SwiftUI

struct PrimaryPageView: View {
    @Bindable var nav: NavigationState

    var body: some View {
        VStack(spacing: 0) {
            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            PageSwitcher(nav: nav)
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch nav.primaryPage {
        case .dashboard:
            DashboardView(nav: nav)
        case .sessionList(let taskId):
            SessionListView(taskId: taskId, nav: nav)
        case .ruleList:
            RuleListView(nav: nav)
        case .certificate:
            CertificateView()
        case .historyTask:
            HistoryTaskView(nav: nav)
        case .settings:
            SettingsView(nav: nav)
        }
    }
}
