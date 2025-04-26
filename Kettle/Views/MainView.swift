import SwiftUI

struct MainView: View {
    @StateObject private var homebrewManager = HomebrewManager()
    @State private var selectedTab = 0
    
    var body: some View {
        if !homebrewManager.isHomebrewInstalled {
            HomebrewInstallationView(homebrewManager: homebrewManager)
        } else {
            TabView(selection: $selectedTab) {
                PackageView(homebrewManager: homebrewManager)
                    .tabItem {
                        Label("Packages", systemImage: "shippingbox")
                    }
                    .tag(0)
                
                ServiceView(homebrewManager: homebrewManager)
                    .tabItem {
                        Label("Services", systemImage: "gearshape")
                    }
                    .tag(1)
                
                TapView(homebrewManager: homebrewManager)
                    .tabItem {
                        Label("Taps", systemImage: "drop")
                    }
                    .tag(2)
                
                BackupView(homebrewManager: homebrewManager)
                    .tabItem {
                        Label("Backup", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .tag(3)
            }
        }
    }
}

struct HomebrewInstallationView: View {
    @ObservedObject var homebrewManager: HomebrewManager
    @State private var isInstalling = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Homebrew Not Installed")
                .font(.title)
                .bold()
            
            Text("Homebrew is required to manage your packages. Would you like to install it now?")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Button(action: {
                Task {
                    isInstalling = true
                    do {
                        try await homebrewManager.installHomebrew()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    isInstalling = false
                }
            }) {
                if isInstalling {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Install Homebrew")
                        .bold()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isInstalling)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
} 