import SwiftUI

struct ServiceView: View {
    @ObservedObject var homebrewManager: HomebrewManager
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var selectedService: HomebrewService?
    @State private var showServiceDetail = false
    
    var filteredServices: [HomebrewService] {
        if searchText.isEmpty {
            return homebrewManager.services
        } else {
            return homebrewManager.services.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredServices) { service in
                    ServiceRow(service: service)
                        .onTapGesture {
                            selectedService = service
                            showServiceDetail = true
                        }
                }
            }
            .searchable(text: $searchText, prompt: "Search services")
            .navigationTitle("Services")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task {
                            isRefreshing = true
                            try? await homebrewManager.refreshServices()
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
        .sheet(isPresented: $showServiceDetail) {
            if let service = selectedService {
                ServiceDetailView(service: service, homebrewManager: homebrewManager)
            }
        }
    }
}

struct ServiceRow: View {
    let service: HomebrewService
    
    var statusColor: Color {
        switch service.status {
        case .running:
            return .green
        case .stopped:
            return .red
        case .error:
            return .orange
        case .unknown:
            return .gray
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(service.name)
                    .font(.headline)
                Text(service.status.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 4)
    }
}

struct ServiceDetailView: View {
    let service: HomebrewService
    @ObservedObject var homebrewManager: HomebrewManager
    @Environment(\.dismiss) private var dismiss
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var editedConfiguration: [String: String]
    
    init(service: HomebrewService, homebrewManager: HomebrewManager) {
        self.service = service
        self.homebrewManager = homebrewManager
        _editedConfiguration = State(initialValue: service.configuration)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Service Information")) {
                    LabeledContent("Name", value: service.name)
                    LabeledContent("Status", value: service.status.rawValue.capitalized)
                }
                
                Section(header: Text("Configuration")) {
                    ForEach(editedConfiguration.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Text(key)
                            Spacer()
                            TextField("Value", text: Binding(
                                get: { value },
                                set: { newValue in
                                    editedConfiguration[key] = newValue
                                }
                            ))
                            .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            isUpdating = true
                            do {
                                try await homebrewManager.startService(service)
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
                            Text("Start Service")
                        }
                    }
                    .disabled(isUpdating || service.status == .running)
                    
                    Button(action: {
                        Task {
                            isUpdating = true
                            do {
                                try await homebrewManager.stopService(service)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isUpdating = false
                        }
                    }) {
                        Text("Stop Service")
                    }
                    .disabled(isUpdating || service.status == .stopped)
                }
            }
            .navigationTitle("Service Details")
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