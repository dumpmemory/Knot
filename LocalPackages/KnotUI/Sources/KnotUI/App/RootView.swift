import SwiftUI

public struct RootView: View {
    @State private var nav = NavigationState()

#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    public init() {}

    public var body: some View {
#if os(iOS)
        if horizontalSizeClass == .regular {
            splitLayout
        } else {
            compactLayout
        }
#else
        splitLayout
#endif
    }

    // MARK: - Layouts

    private var splitLayout: some View {
        NavigationSplitView {
            PrimaryPageView(nav: nav)
        } detail: {
            NavigationStack(path: $nav.detailPath) {
                PlaceholderView()
                    .navigationDestinations(nav: nav)
#if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
#endif
            }
        }
    }

    private var compactLayout: some View {
        NavigationStack(path: $nav.detailPath) {
            PrimaryPageView(nav: nav)
                .navigationDestinations(nav: nav)
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }
}

// MARK: - Navigation Destinations

private extension View {
    func navigationDestinations(nav: NavigationState) -> some View {
        self.navigationDestination(for: DetailDestination.self) { destination in
            DetailPageView(destination: destination, nav: nav)
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }
}
