import SwiftUI

struct DetailPageView: View {
    let destination: DetailDestination
    @Bindable var nav: NavigationState

    var body: some View {
        switch destination {
        case .sessionList(let taskId):
            SessionListView(taskId: taskId, nav: nav)
        case .sessionDetail(let sessionId):
            SessionDetailView(sessionId: sessionId)
        case .sessionHeader(let isRequest, let sessionId):
            SessionHeaderList(isRequest: isRequest, sessionId: sessionId)
        case .sessionBody(let isRequest, let sessionId):
            SessionBodyPreview(isRequest: isRequest, sessionId: sessionId)
        case .ruleDetail(let ruleId):
            RuleDetailView(ruleId: ruleId, nav: nav)
        case .ruleAdd(let ruleId):
            RuleAddView(ruleId: ruleId)
        case .settingCertificate:
            CertificateView()
        case .settingAbout:
            AboutView()
        case .settingWeb(let type):
            PlaceholderView()
                .navigationTitle(type.rawValue)
        }
    }
}
