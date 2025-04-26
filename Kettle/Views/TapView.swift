import SwiftUI

struct TapView: View {
    @ObservedObject var homebrewManager: HomebrewManager
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var selectedTap: HomebrewTap?
    @State private var showTapDetail = false
    @State private var showingAddTap = false
    @State private var lastUpdate: Date? = nil
    
    var filteredTaps: [HomebrewTap] {
        if searchText.isEmpty {
            return homebrewManager.taps
        } else {
            return homebrewManager.taps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                // 左侧列表
                VStack(spacing: 0) {
                    List(selection: $selectedTap) {
                        ForEach(filteredTaps) { tap in
                            HStack {
                                Text(tap.name)
                                    .font(.body)
                                Spacer()
                                if tap.installed {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                } else {
                                    Image(systemName: "circle").foregroundColor(.gray)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTap = tap
                                showTapDetail = true
                            }
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
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            Task {
                                isRefreshing = true
                                try? await homebrewManager.refreshTaps()
                                lastUpdate = Date()
                                isRefreshing = false
                                // TODO: 缓存 taps 到本地
                            }
                        }) {
                            if isRefreshing {
                                ProgressView().progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isRefreshing)
                    }
                    ToolbarItem(placement: .automatic) {
                        Button(action: {
                            showingAddTap = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                // 右侧详情
                VStack {
                    if let tap = selectedTap {
                        TapDetailPanel(tap: tap)
                    } else {
                        Text("请选择一个 Tap 查看详情")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Taps")
        }
        .onAppear {
            // TODO: 加载本地缓存的 taps 和 lastUpdate
        }
        .sheet(isPresented: $showingAddTap) {
            AddTapView(homebrewManager: homebrewManager)
        }
    }
}

struct TapDetailPanel: View {
    let tap: HomebrewTap
    var body: some View {
        Form {
            Section(header: Text("Tap 信息")) {
                LabeledContent("名称", value: tap.name)
                LabeledContent("URL", value: tap.url)
                LabeledContent("状态", value: tap.installed ? "已安装" : "未安装")
            }
            // 可扩展更多信息
        }
        .navigationTitle("Tap 详情")
    }
}

struct TapRow: View {
    let tap: HomebrewTap
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(tap.name)
                    .font(.headline)
                Text(tap.url)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if tap.installed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
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