import SwiftUI

struct ContentView: View {
    @StateObject private var homebrewManager = HomebrewManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TapView(homebrewManager: homebrewManager)
                .tabItem {
                    Label("Taps", systemImage: "archivebox")
                }
                .tag(0)
            
            PackageView(homebrewManager: homebrewManager)
                .tabItem {
                    Label("Packages", systemImage: "shippingbox")
                }
                .tag(1)
            
            ServiceView(homebrewManager: homebrewManager)
                .tabItem {
                    Label("Services", systemImage: "server.rack")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .environmentObject(homebrewManager)
    }
}

struct SettingsView: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Homebrew Status")) {
                    HStack {
                        Text("Homebrew Installed")
                        Spacer()
                        if homebrewManager.isHomebrewInstalled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    if !homebrewManager.isHomebrewInstalled {
                        Button("Install Homebrew") {
                            Task {
                                try? await homebrewManager.installHomebrew()
                            }
                        }
                    }
                }
                
                Section(header: Text("Backup & Restore")) {
                    Button("Backup Configuration") {
                        Task {
                            if let data = try? await homebrewManager.backupConfiguration() {
                                // TODO: Save backup file
                            }
                        }
                    }
                    
                    Button("Restore Configuration") {
                        // TODO: Load backup file and restore
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
} 