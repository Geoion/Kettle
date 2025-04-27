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
    
    var body: some View {
        HStack {
            Image(systemName: service.status.icon)
                .foregroundStyle(service.status.color)
            
            VStack(alignment: .leading) {
                Text(service.name)
                    .font(.headline)
                Text(service.status.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(service.status.color)
            }
            
            Spacer()
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
    @State private var configuration: String = ""
    @State private var isLoadingConfig = false
    
    func loadConfiguration() {
        guard let filePath = service.filePath else {
            print("[Config] No file path available for service: \(service.name)")
            return
        }
        
        isLoadingConfig = true
        
        Task {
            // 展开路径中的 ~
            let expandedPath = NSString(string: filePath).expandingTildeInPath
            print("[Config] Service: \(service.name)")
            print("[Config] Original path: \(filePath)")
            print("[Config] Expanded path: \(expandedPath)")
            
            // 检查文件是否存在和权限
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: expandedPath) else {
                await MainActor.run {
                    print("[Config] File does not exist at path: \(expandedPath)")
                    errorMessage = "Configuration file does not exist"
                    isLoadingConfig = false
                }
                return
            }
            
            guard fileManager.isReadableFile(atPath: expandedPath) else {
                await MainActor.run {
                    print("[Config] File is not readable: \(expandedPath)")
                    errorMessage = "Configuration file is not readable"
                    isLoadingConfig = false
                }
                return
            }
            
            // 尝试直接读取文件
            do {
                let fileContent = try String(contentsOfFile: expandedPath, encoding: .utf8)
                print("[Config] Successfully read file directly")
                await MainActor.run {
                    configuration = fileContent
                    isLoadingConfig = false
                }
                return
            } catch {
                print("[Config] Failed to read file directly: \(error)")
                // 如果直接读取失败，继续尝试使用 cat 命令
            }
            
            // 使用 cat 命令作为备选方案
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/bin/cat")
            process.arguments = [expandedPath]
            process.standardOutput = pipe
            process.standardError = pipe
            
            print("[Config] Executing command: cat \(expandedPath)")
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let status = process.terminationStatus
                print("[Config] Process terminated with status: \(status)")
                
                if status != 0 {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let errorMessage = String(data: errorData, encoding: .utf8) {
                        print("[Config] Error output: \(errorMessage)")
                    }
                    throw NSError(domain: "ServiceView",
                                code: Int(status),
                                userInfo: [NSLocalizedDescriptionKey: "Failed to read configuration file"])
                }
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                print("[Config] Read \(data.count) bytes")
                
                if let output = String(data: data, encoding: .utf8) {
                    await MainActor.run {
                        configuration = output
                        isLoadingConfig = false
                    }
                    print("[Config] Successfully parsed configuration")
                } else {
                    await MainActor.run {
                        print("[Config] Failed to parse data as UTF-8")
                        errorMessage = "Failed to parse configuration file as text"
                        isLoadingConfig = false
                    }
                }
            } catch {
                await MainActor.run {
                    print("[Config] Error: \(error)")
                    errorMessage = "Failed to read configuration: \(error.localizedDescription)"
                    isLoadingConfig = false
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: service.status.icon)
                            .foregroundStyle(service.status.color)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text(service.name)
                                .font(.headline)
                            Text(service.status.rawValue.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(service.status.color)
                        }
                        
                        Spacer()
                    }
                }
                
                Section {
                    if let user = service.user {
                        LabeledContent("User", value: user)
                    }
                    
                    if let path = service.filePath {
                        LabeledContent("File Path") {
                            Text(path)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
                
                if !configuration.isEmpty {
                    Section("Configuration") {
                        if isLoadingConfig {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Spacer()
                            }
                        } else {
                            Text(configuration)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
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
                            Label("Start Service", systemImage: "play.circle.fill")
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
                        Label("Stop Service", systemImage: "stop.circle.fill")
                    }
                    .disabled(isUpdating || service.status == .stopped)
                }
            }
            .formStyle(.grouped)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .onAppear {
            loadConfiguration()
        }
    }
} 