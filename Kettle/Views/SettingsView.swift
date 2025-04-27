import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showingPrivacyPolicy = false
    
    var body: some View {
        Form {
            Section(header: Text("Privacy")) {
                Toggle("Enable Analytics", isOn: $settings.analyticsEnabled)
                .help("Help us improve Kettle by sharing anonymous usage data")
                
                Button("View Privacy Policy") {
                    showingPrivacyPolicy = true
                }
            }
            
            Section(header: Text("Appearance")) {
                Picker("Color Scheme", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.displayName).tag(appearance)
                    }
                }
            }
            
            Section(header: Text("Language")) {
                Picker("Language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let privacyPath = Bundle.main.path(forResource: "PRIVACY", ofType: "md"),
                   let privacyContent = try? String(contentsOfFile: privacyPath) {
                    Text(privacyContent)
                        .padding()
                } else {
                    Text("Privacy policy not found")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .navigationTitle("Privacy Policy")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
} 