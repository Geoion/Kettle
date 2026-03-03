import SwiftUI

struct CaskListView: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var lastUpdate: Date?
    @State private var showOutdatedOnly = false

    private var filteredCasks: [HomebrewCask] {
        var list = homebrewManager.casks
        if showOutdatedOnly { list = list.filter { $0.outdated } }
        if searchText.isEmpty { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var outdatedCount: Int {
        homebrewManager.casks.filter { $0.outdated }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SearchToolbar(text: $searchText, placeholder: L("Search casks..."))
                    .frame(maxWidth: 260)

                if outdatedCount > 0 {
                    Toggle(isOn: $showOutdatedOnly) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill").foregroundStyle(.orange)
                            Text(String(format: L("%d outdated"), outdatedCount)).font(.caption)
                        }
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .tint(showOutdatedOnly ? .orange : .secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            if isRefreshing && homebrewManager.casks.isEmpty {
                LoadingView()
            } else if filteredCasks.isEmpty {
                EmptyStateView(
                    icon: "app.badge",
                    title: searchText.isEmpty
                        ? (showOutdatedOnly ? L("All Up to Date") : L("No Casks"))
                        : L("No Results"),
                    description: searchText.isEmpty
                        ? (showOutdatedOnly ? L("All installed casks are up to date.") : L("No Homebrew casks are installed."))
                        : L("No casks match your search."),
                    action: searchText.isEmpty && !showOutdatedOnly ? { refresh() } : nil,
                    actionLabel: L("Refresh")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredCasks) { cask in
                            CaskRowView(cask: cask, onAction: { refresh() })
                                .padding(.horizontal, 12).padding(.vertical, 6)
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
                    Text(error).font(.caption).foregroundStyle(.red)
                    Spacer()
                    Button { errorMessage = nil } label: {
                        Image(systemName: "xmark").font(.caption)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.red.opacity(0.08))
            }

            Divider()
            StatusFooter(count: homebrewManager.casks.count, itemLabel: L("casks"), lastUpdate: lastUpdate)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { refresh() } label: {
                    if isRefreshing { ProgressView().controlSize(.small) }
                    else { Label(L("Refresh"), systemImage: "arrow.clockwise") }
                }
                .disabled(isRefreshing)
            }
        }
        .onAppear {
            if let (_, update) = homebrewManager.loadCasksFromCache() {
                lastUpdate = update
            }
            if homebrewManager.casks.isEmpty {
                refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshCasks)) { _ in refresh() }
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true; errorMessage = nil
        Task {
            do { try await homebrewManager.refreshCasks(); lastUpdate = Date() }
            catch { errorMessage = error.localizedDescription }
            isRefreshing = false
        }
    }
}

// MARK: - Cask Row

struct CaskRowView: View {
    let cask: HomebrewCask
    var onAction: (() -> Void)?

    @EnvironmentObject var homebrewManager: HomebrewManager
    @State private var isExpanded = false
    @State private var isUninstalling = false
    @State private var isUpdating = false
    @State private var showUninstallAlert = false
    @State private var actionError: String?
    @State private var appIcon: NSImage? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                }

            VStack(spacing: 0) { detailSection }
                .frame(maxHeight: isExpanded ? .infinity : 0, alignment: .top)
                .clipped()
                .opacity(isExpanded ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .alert(L("Uninstall Cask"), isPresented: $showUninstallAlert) {
            Button(L("Cancel"), role: .cancel) {}
            Button(L("Uninstall"), role: .destructive) { uninstall() }
        } message: {
            Text(String(format: L("Are you sure you want to uninstall '%@'?"), cask.name))
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption2).foregroundStyle(.secondary).frame(width: 10)

            // App icon: use actual app icon if available, fallback to system icon
            Group {
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .interpolation(.high)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "app.badge")
                        .font(.system(size: 16)).foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
            }
            .onAppear { loadAppIcon() }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(cask.name).font(.headline).lineLimit(1)

                    if let version = cask.version, !version.isEmpty {
                        Text(version)
                            .font(.caption2).foregroundStyle(.secondary)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                    }

                    if cask.autoUpdates {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.clockwise").font(.system(size: 8))
                            Text(L("Auto-updates")).font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 3))
                    }
                }

                if let desc = cask.description, !desc.isEmpty {
                    Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Spacer()

            if cask.outdated, let latest = cask.latestVersion, let current = cask.version {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 9))
                    Text("\(current) → \(latest)").font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.orange.opacity(0.12), in: Capsule())
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 9))
                    Text(L("Installed")).font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.green.opacity(0.12), in: Capsule())
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 4)
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.leading, 44)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    if let version = cask.version {
                        DetailRow(key: L("Version"), value: version)
                    }
                    if let latest = cask.latestVersion, cask.outdated {
                        DetailRow(key: L("Latest"), value: latest)
                    }
                    if let desc = cask.description, !desc.isEmpty {
                        DetailRow(key: L("Description"), value: desc)
                    }
                    if let homepage = cask.homepage, !homepage.isEmpty {
                        DetailRow(key: L("Homepage"), value: homepage)
                    }
                    if let tap = cask.tap, !tap.isEmpty {
                        DetailRow(key: L("Tap"), value: tap)
                    }
                    if let path = cask.installedPath, !path.isEmpty {
                        DetailRow(key: L("Installed Path"), value: path)
                    }
                    if let size = cask.installedSize {
                        DetailRow(key: L("Size"), value: ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    }
                    DetailRow(key: L("Auto-updates"), value: cask.autoUpdates ? L("Yes") : L("No"))

                    if let error = actionError {
                        Text(error).font(.caption2).foregroundStyle(.red).padding(.top, 4)
                    }
                }
                .padding(.leading, 44).padding(.vertical, 10)

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if cask.outdated {
                        Button { updateCask() } label: {
                            if isUpdating { ProgressView().controlSize(.mini) }
                            else { Label(L("Update"), systemImage: "arrow.up.circle").font(.caption) }
                        }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                        .disabled(isUpdating || isUninstalling)
                    }

                    // Open button using actual installed path
                    if let path = cask.installedPath {
                        Button {
                            NSWorkspace.shared.open(URL(fileURLWithPath: path))
                        } label: {
                            Label(L("Open"), systemImage: "arrow.up.forward.app").font(.caption)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }

                    if let homepage = cask.homepage, let url = URL(string: homepage) {
                        Link(destination: url) {
                            Label(L("Homepage"), systemImage: "safari").font(.caption)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }

                    Button(role: .destructive) { showUninstallAlert = true } label: {
                        if isUninstalling { ProgressView().controlSize(.mini) }
                        else { Label(L("Uninstall"), systemImage: "trash").font(.caption) }
                    }
                    .buttonStyle(.bordered).controlSize(.small).tint(.red)
                    .disabled(isUpdating || isUninstalling)
                }
                .padding(.trailing, 8).padding(.vertical, 10)
            }
        }
    }

    private func updateCask() {
        isUpdating = true; actionError = nil
        Task {
            do {
                try await homebrewManager.executeBrewCommand("upgrade --cask \(cask.name)")
                try await homebrewManager.refreshCasks()
                onAction?()
            } catch { actionError = error.localizedDescription }
            isUpdating = false
        }
    }

    private func uninstall() {
        isUninstalling = true; actionError = nil
        Task {
            do {
                try await homebrewManager.executeBrewCommand("uninstall --cask \(cask.name)")
                try await homebrewManager.refreshCasks()
                onAction?()
            } catch { actionError = error.localizedDescription }
            isUninstalling = false
        }
    }

    private func loadAppIcon() {
        guard appIcon == nil else { return }
        Task.detached(priority: .utility) {
            var icon: NSImage? = nil
            // Try installed path first
            if let path = cask.installedPath,
               FileManager.default.fileExists(atPath: path) {
                icon = NSWorkspace.shared.icon(forFile: path)
            }
            // Fallback: search /Applications for <name>.app
            if icon == nil {
                let candidates = [
                    "/Applications/\(cask.name).app",
                    (NSHomeDirectory() as NSString).appendingPathComponent("Applications/\(cask.name).app")
                ]
                for path in candidates where FileManager.default.fileExists(atPath: path) {
                    icon = NSWorkspace.shared.icon(forFile: path)
                    break
                }
            }
            if let icon {
                await MainActor.run { appIcon = icon }
            }
        }
    }
}
