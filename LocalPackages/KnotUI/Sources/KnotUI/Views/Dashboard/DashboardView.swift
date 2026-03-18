import SwiftUI

struct DashboardView: View {
    @Bindable var nav: NavigationState

    var body: some View {
        Text("Dashboard")
            .navigationTitle("首页")
    }
}
