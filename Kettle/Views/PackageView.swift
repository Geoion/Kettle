import SwiftUI

struct PackageView: View {
    @ObservedObject var homebrewManager: HomebrewManager
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var selectedPackage: HomebrewPackage?
    @State private var showPackageDetail = false
    
    var filteredPackages: [HomebrewPackage] {
        if searchText.isEmpty {
            return homebrewManager.packages
        } else {
            return homebrewManager.packages.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredPackages) { package in
                    PackageRow(package: package)
                        .onTapGesture {
                            selectedPackage = package
                            showPackageDetail = true
                        }
                }
            }
            .searchable(text: $searchText, prompt: "Search packages")
            .navigationTitle("Packages")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task {
                            isRefreshing = true
                            try? await homebrewManager.refreshPackages()
                            isRefreshing = false
                        }
                    }) {
                        if isRefreshing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
        }
        .sheet(isPresented: $showPackageDetail) {
            if let package = selectedPackage {
                PackageDetailView(package: package, homebrewManager: homebrewManager)
            }
        }
    }
}

struct PackageRow: View {
    let package: HomebrewPackage
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(package.name)
                    .font(.headline)
                Text(package.version)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if package.installed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PackageDetailView: View {
    let package: HomebrewPackage
    @ObservedObject var homebrewManager: HomebrewManager
    @Environment(\.dismiss) private var dismiss
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Package Information")) {
                    LabeledContent("Name", value: package.name)
                    LabeledContent("Version", value: package.version)
                    if let description = package.description {
                        LabeledContent("Description", value: description)
                    }
                }
                
                Section(header: Text("Dependencies")) {
                    if package.dependencies.isEmpty {
                        Text("No dependencies")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(package.dependencies, id: \.self) { dependency in
                            Text(dependency)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            isUpdating = true
                            do {
                                try await homebrewManager.updatePackage(package)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isUpdating = false
                        }
                    }) {
                        if isUpdating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Update Package")
                        }
                    }
                    .disabled(isUpdating)
                    
                    Button(role: .destructive, action: {
                        Task {
                            isUpdating = true
                            do {
                                try await homebrewManager.uninstallPackage(package)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isUpdating = false
                        }
                    }) {
                        Text("Uninstall Package")
                    }
                    .disabled(isUpdating)
                }
            }
            .navigationTitle("Package Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
} 