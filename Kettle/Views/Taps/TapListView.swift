import SwiftUI

// MARK: - Add Tap Sheet

struct AddTapView: View {
    @ObservedObject var homebrewManager: HomebrewManager
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var logMessages: [String] = []
    @State private var addTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Text(L("Add Tap"))
                    .font(.headline)
                    .padding(.top)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Name (user/repo)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. homebrew/core", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("URL (Optional)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. https://github.com/user/repo.git", text: $url)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Command"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(commandPreview)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal)

                if !logMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Log"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(logMessages, id: \.self) { msg in
                                    Text(msg)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 72)
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }

            Divider()

            HStack {
                Button(L("Cancel")) {
                    addTask?.cancel()
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                if isAdding {
                    Button(L("Stop")) {
                        addTask?.cancel()
                        Task { try? await homebrewManager.terminateBrewProcess(); dismiss() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Button {
                    addTask = Task {
                        isAdding = true
                        logMessages = []
                        do {
                            let tap = HomebrewTap(name: name, url: url, installed: false)
                            logMessages.append("Running: \(commandPreview)")
                            try await homebrewManager.addTap(tap)
                            logMessages.append("Done.")
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                            logMessages.append("Error: \(error.localizedDescription)")
                        }
                        isAdding = false
                    }
                } label: {
                    if isAdding {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(L("Add"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAdding || !isValidName(name))
            }
            .padding()
        }
        .frame(width: 420, height: 340)
        .alert(L("Error"), isPresented: .constant(errorMessage != nil)) {
            Button(L("OK")) { errorMessage = nil }
        } message: {
            if let err = errorMessage { Text(err) }
        }
    }

    private var commandPreview: String {
        url.isEmpty ? "brew tap \(name)" : "brew tap \(name) \(url)"
    }

    private func isValidName(_ name: String) -> Bool {
        let parts = name.split(separator: "/")
        return parts.count == 2 && !parts[0].isEmpty && !parts[1].isEmpty
    }
}

// MARK: - Tap List

struct TapListView: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var lastUpdate: Date?
    @State private var showAddTap = false

    private var filteredTaps: [HomebrewTap] {
        if searchText.isEmpty { return homebrewManager.taps }
        return homebrewManager.taps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SearchToolbar(
                    text: $searchText,
                    placeholder: L("Search Tap")
                )
                .frame(maxWidth: 260)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if isRefreshing && homebrewManager.taps.isEmpty {
                LoadingView()
            } else if filteredTaps.isEmpty {
                EmptyStateView(
                    icon: "archivebox",
                    title: searchText.isEmpty ? L("No Taps") : L("No Results"),
                    description: searchText.isEmpty
                        ? L("No Homebrew taps are installed.")
                        : L("No taps match your search."),
                    action: searchText.isEmpty ? { refresh() } : nil,
                    actionLabel: searchText.isEmpty ? L("Refresh") : nil
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredTaps) { tap in
                            TapRowView(tap: tap, onRemoved: { refresh() })
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button { errorMessage = nil } label: {
                        Image(systemName: "xmark").font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.red.opacity(0.08))
            }

            Divider()
            StatusFooter(
                count: homebrewManager.taps.count,
                itemLabel: L("taps"),
                lastUpdate: lastUpdate
            )
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                LastUpdatedLabel(date: lastUpdate)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    refresh()
                } label: {
                    if isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(L("Refresh"), systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddTap = true
                } label: {
                    Label(L("Add"), systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTap) {
            AddTapView(homebrewManager: homebrewManager)
        }
        .onAppear {
            if homebrewManager.taps.isEmpty {
                if let (_, update) = homebrewManager.loadTapsFromCache() {
                    lastUpdate = update
                } else {
                    refresh()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshTaps)) { _ in
            refresh()
        }
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        Task {
            do {
                try await homebrewManager.refreshTaps()
                lastUpdate = Date()
                homebrewManager.saveTapsToCache(homebrewManager.taps, lastUpdate: lastUpdate)
            } catch {
                errorMessage = error.localizedDescription
            }
            isRefreshing = false
        }
    }
}

// MARK: - Tap Row

struct TapRowView: View {
    let tap: HomebrewTap
    var onRemoved: (() -> Void)?

    @EnvironmentObject var homebrewManager: HomebrewManager
    @Environment(\.openURL) private var openURL
    @State private var isExpanded = false
    @State private var showingRemoveAlert = false

    private var tapInfo: TapInfo? {
        homebrewManager.tapInfos[tap.name]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

            VStack(spacing: 0) {
                detailSection
            }
            .frame(maxHeight: isExpanded ? .infinity : 0, alignment: .top)
            .clipped()
            .opacity(isExpanded ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .alert(L("Remove Tap"), isPresented: $showingRemoveAlert) {
            Button(L("Cancel"), role: .cancel) {}
            Button(L("Remove"), role: .destructive) {
                Task {
                    try? await homebrewManager.removeTap(tap)
                    onRemoved?()
                }
            }
        } message: {
            Text(String(format: L("Are you sure you want to remove '%@'?"), tap.name))
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 10)

            Image(systemName: "archivebox")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(tap.name)
                    .font(.headline)
                    .lineLimit(1)
                if let repoURL = tapInfo?.repoURL {
                    Text(repoURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if tap.installed {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                    Text(L("Installed"))
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.green.opacity(0.12), in: Capsule())
            }

            if let count = tapInfo?.filesCount {
                Text("\(count) files")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.leading, 44)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    if let info = tapInfo {
                        if let status = info.status {
                            DetailRow(key: L("Status"), value: status)
                        }
                        if let branch = info.branch {
                            DetailRow(key: L("Branch"), value: branch)
                        }
                        if let head = info.head {
                            DetailRow(key: "HEAD", value: String(head.prefix(12)))
                        }
                        if let lastCommit = info.lastCommit {
                            DetailRow(key: L("Last Commit"), value: lastCommit)
                        }
                        if let path = info.filesPath {
                            DetailRow(key: L("Path"), value: path)
                        }
                        if let size = info.filesSize {
                            DetailRow(key: L("Size"), value: size)
                        }
                        if let commands = info.commands {
                            DetailRow(key: L("Formulae"), value: commands)
                        }
                    } else {
                        Text(L("Loading tap info..."))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 44)
                            .padding(.top, 8)
                    }
                }
                .padding(.leading, 44)
                .padding(.vertical, 10)

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if let path = tapInfo?.filesPath {
                        Button {
                            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                        } label: {
                            Label(L("Open in Finder"), systemImage: "folder")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if let repoURL = tapInfo?.repoURL, let url = URL(string: repoURL) {
                        Button {
                            openURL(url)
                        } label: {
                            Label(L("Repository"), systemImage: "safari")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if tap.installed {
                        Button(role: .destructive) {
                            showingRemoveAlert = true
                        } label: {
                            Label(L("Remove"), systemImage: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                    }
                }
                .padding(.trailing, 8)
                .padding(.vertical, 10)
            }
        }
    }
}
