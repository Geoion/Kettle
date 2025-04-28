import SwiftUI

struct TapView: View {
    @ObservedObject var homebrewManager: HomebrewManager
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var selectedTap: HomebrewTap?
    @State private var showTapDetail = false
    @State private var showingAddTap = false
    @State private var lastUpdate: Date? = nil
    @State private var cachedTaps: [HomebrewTap] = []
    
    var filteredTaps: [HomebrewTap] {
        if searchText.isEmpty {
            return cachedTaps
        } else {
            return cachedTaps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                // 左侧列表
                VStack(spacing: 0) {
                    List {
                        ForEach(filteredTaps) { tap in
                            HStack {
                                Text(tap.name)
                                    .font(.body)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTap = tap
                            }
                            .background(selectedTap == tap ? Color.accentColor.opacity(0.15) : Color.clear)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .searchable(text: $searchText, prompt: "Search taps")
                    .overlay(
                        VStack {
                            Spacer()
                            Divider()
                            HStack {
                                Text("上次更新时间：" + (lastUpdate?.formatted() ?? "未知"))
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 6)
                        }
                    )
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 350)
                }
                .toolbar(id: "TapViewToolbar") {
                    ToolbarItem(id: "refresh", placement: .primaryAction) {
                        Button(action: {
                            Task {
                                isRefreshing = true
                                try? await homebrewManager.refreshTaps()
                                lastUpdate = Date()
                                isRefreshing = false
                                // 刷新后覆盖本地缓存
                                saveTapsToCache(homebrewManager.taps, lastUpdate: lastUpdate)
                                cachedTaps = homebrewManager.taps
                            }
                        }) {
                            if isRefreshing {
                                ProgressView().progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isRefreshing)
                        .help("Refresh Taps")
                    }
                    
                    ToolbarItem(id: "add", placement: .primaryAction) {
                        Button(action: {
                            showingAddTap = true
                        }) {
                            Image(systemName: "plus")
                        }
                        .help("Add New Tap")
                    }
                }
                
                // 右侧详情
                ZStack {
                    if let tap = selectedTap {
                        TapDetailPanel(tap: tap, selectedTap: $selectedTap)
                    } else {
                        Text("请选择一个 Tap 查看详情")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(.windowBackgroundColor))
            }
            .navigationTitle("Taps")
        }
        .onAppear {
            // 优先加载本地缓存
            if let (taps, update) = loadTapsFromCache() {
                cachedTaps = taps
                lastUpdate = update
            } else {
                cachedTaps = homebrewManager.taps
            }
        }
        .sheet(isPresented: $showingAddTap) {
            AddTapView(homebrewManager: homebrewManager)
        }
    }
    
    // 本地缓存逻辑
    func saveTapsToCache(_ taps: [HomebrewTap], lastUpdate: Date?) {
        if let data = try? JSONEncoder().encode(taps) {
            UserDefaults.standard.set(data, forKey: "cachedTaps")
        }
        if let date = lastUpdate {
            UserDefaults.standard.set(date, forKey: "cachedTapsUpdate")
        }
    }
    func loadTapsFromCache() -> ([HomebrewTap], Date?)? {
        guard let data = UserDefaults.standard.data(forKey: "cachedTaps"),
              let taps = try? JSONDecoder().decode([HomebrewTap].self, from: data) else { return nil }
        let update = UserDefaults.standard.object(forKey: "cachedTapsUpdate") as? Date
        return (taps, update)
    }
}

struct TapDetailView: View {
    let tap: HomebrewTap
    @ObservedObject var homebrewManager: HomebrewManager
    @Environment(\.dismiss) private var dismiss
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Tap Information")) {
                    LabeledContent("Name", value: tap.name)
                    LabeledContent("URL", value: tap.url)
                    LabeledContent("Status", value: tap.installed ? "Installed" : "Not Installed")
                }
                
                Section {
                    if tap.installed {
                        Button(role: .destructive, action: {
                            Task {
                                isUpdating = true
                                do {
                                    try await homebrewManager.removeTap(tap)
                                    dismiss()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isUpdating = false
                            }
                        }) {
                            Text("Remove Tap")
                        }
                        .disabled(isUpdating)
                    } else {
                        Button(action: {
                            Task {
                                isUpdating = true
                                do {
                                    try await homebrewManager.addTap(tap)
                                    dismiss()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isUpdating = false
                            }
                        }) {
                            Text("Install Tap")
                        }
                        .disabled(isUpdating)
                    }
                }
            }
            .navigationTitle("Tap Details")
            .toolbar(id: "TapDetailToolbar") {
                ToolbarItem(id: "close", placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .help("Close Details")
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

struct AddTapView: View {
    @ObservedObject var homebrewManager: HomebrewManager
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var logMessages: [String] = []
    @State private var task: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            VStack(spacing: 20) {
                // Title
                Text("Add a tap")
                    .font(.headline)
                    .padding(.top)
                
                // Input fields
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name (user/repo)")
                            .foregroundColor(.secondary)
                        TextField("e.g. homebrew/core", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .help("Required. Format: user/repo")
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL (Optional)")
                            .foregroundColor(.secondary)
                        TextField("e.g. https://github.com/user/repo.git", text: $url)
                            .textFieldStyle(.roundedBorder)
                            .help("Optional. The git repository URL")
                    }
                }
                .padding(.horizontal)
                
                // Command preview
                VStack(alignment: .leading, spacing: 4) {
                    Text("Command")
                        .foregroundColor(.secondary)
                    Text(commandPreview)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(6)
                }
                .padding(.horizontal)
                
                // Log area
                if !logMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log")
                            .foregroundColor(.secondary)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(logMessages, id: \.self) { message in
                                    Text(message)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 80)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(6)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            
            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                if isAdding {
                    Button("Close") {
                        task?.cancel()
                        // 终止 brew 进程
                        Task {
                            try? await homebrewManager.terminateBrewProcess()
                            dismiss()
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                Button(action: {
                    task = Task {
                        isAdding = true
                        logMessages = []
                        do {
                            let newTap = HomebrewTap(name: name, url: url, installed: false)
                            logMessages.append("Running: \(commandPreview)")
                            try await homebrewManager.addTap(newTap)
                            logMessages.append("Successfully added tap: \(name)")
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                            logMessages.append("Error: \(error.localizedDescription)")
                        }
                        isAdding = false
                    }
                }) {
                    if isAdding {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Add")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAdding || !isValidName(name))
            }
            .padding()
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 400, height: 350)
        .background(Color(.windowBackgroundColor))
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
    
    private var commandPreview: String {
        if url.isEmpty {
            return "brew tap \(name)"
        } else {
            return "brew tap \(name) \(url)"
        }
    }
    
    private func isValidName(_ name: String) -> Bool {
        // Check if name follows user/repo format
        let components = name.split(separator: "/")
        return components.count == 2 && !components[0].isEmpty && !components[1].isEmpty
    }
} 