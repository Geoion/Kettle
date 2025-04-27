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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Tap Information")) {
                    TextField("Name", text: $name)
                    TextField("URL", text: $url)
                }
                
                Section {
                    Button(action: {
                        Task {
                            isAdding = true
                            do {
                                let newTap = HomebrewTap(name: name, url: url, installed: false)
                                try await homebrewManager.addTap(newTap)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isAdding = false
                        }
                    }) {
                        if isAdding {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Add Tap")
                        }
                    }
                    .disabled(isAdding || name.isEmpty || url.isEmpty)
                }
            }
            .navigationTitle("Add New Tap")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
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