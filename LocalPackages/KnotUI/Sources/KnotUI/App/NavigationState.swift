import SwiftUI

// MARK: - PrimaryPage

public enum PrimaryPage: Hashable {
    case dashboard
    case sessionList(taskId: String)
    case ruleList
    case certificate
    case historyTask
    case settings
}

// MARK: - WebDocType

public enum WebDocType: String, Hashable {
    case terms
    case termsFirst
    case privacy
}

// MARK: - DetailDestination

public enum DetailDestination: Hashable {
    case sessionList(taskId: String)
    case sessionDetail(sessionId: String)
    case sessionHeader(isRequest: Bool, sessionId: String)
    case sessionBody(isRequest: Bool, sessionId: String)
    case ruleDetail(ruleId: String)
    case ruleAdd(ruleId: String)
    case settingCertificate
    case settingAbout
    case settingWeb(type: WebDocType)
}

// MARK: - NavigationState

@Observable
public final class NavigationState {
    public var primaryPage: PrimaryPage = .dashboard
    public var detailPath: [DetailDestination] = []

    public init() {}

    public func navigate(to destination: DetailDestination) {
        detailPath.append(destination)
    }

    public func switchPrimary(to page: PrimaryPage) {
        detailPath = []
        primaryPage = page
    }
}
