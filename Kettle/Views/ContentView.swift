import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var homebrewManager = HomebrewManager()
    @State private var selectedTab: Tab = .taps

    enum Tab: String, Hashable, CaseIterable {
        case taps, packages, casks, services, settings

        var label: String {
            switch self {
            case .taps: return L("menu.taps")
            case .packages: return L("menu.packages")
            case .casks: return L("menu.casks")
            case .services: return L("menu.services")
            case .settings: return L("menu.settings")
            }
        }

        var icon: String {
            switch self {
            case .taps: return "archivebox"
            case .packages: return "shippingbox"
            case .casks: return "app.badge"
            case .services: return "server.rack"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.label, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationTitle("Kettle")
        } detail: {
            detailView
                .navigationTitle(selectedTab.label)
        }
        .environmentObject(homebrewManager)
        .environmentObject(settings)
        .preferredColorScheme(settings.effectiveColorScheme)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .taps:
            TapListView()
        case .packages:
            PackageListView()
        case .casks:
            CaskListView()
        case .services:
            ServiceListView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let refreshTaps = Notification.Name("refreshTaps")
    static let refreshPackages = Notification.Name("refreshPackages")
    static let refreshCasks = Notification.Name("refreshCasks")
    static let refreshServices = Notification.Name("refreshServices")
    static let refreshStateChanged = Notification.Name("refreshStateChanged")
}

#Preview {
    ContentView()
        .environmentObject(AppSettings.shared)
}
