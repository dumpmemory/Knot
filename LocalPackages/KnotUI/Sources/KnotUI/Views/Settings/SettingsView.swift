import SwiftUI

struct SettingsView: View {
    @Bindable var nav: NavigationState

    var body: some View {
        Text("Settings")
            .navigationTitle("设置")
    }
}
