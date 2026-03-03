import SwiftUI

struct PackageListView: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var isUpgradingAll = false
    @State private var errorMessage: String?
    @State private var lastUpdate: Date?
    @State private var showOutdatedOnly = false

    private var filteredPackages: [HomebrewPackage] {
        var list = homebrewManager.packages
        if showOutdatedOnly { list = list.filter { $0.outdated } }
        if searchText.isEmpty { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var outdatedCount: Int {
        homebrewManager.packages.filter { $0.outdated }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar row
            HStack(spacing: 12) {
                SearchToolbar(text: $searchText, placeholder: L("Search packages..."))
                    .frame(maxWidth: 260)

                if outdatedCount > 0 {
                    Toggle(isOn: $showOutdatedOnly) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(.orange)
                            Text(String(format: L("%d outdated"), outdatedCount))
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .tint(showOutdatedOnly ? .orange : .secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if isRefreshing && homebrewManager.packages.isEmpty {
                LoadingView()
            } else if filteredPackages.isEmpty {
                EmptyStateView(
                    icon: "shippingbox",
                    title: searchText.isEmpty
                        ? (showOutdatedOnly ? L("All Up to Date") : L("No Packages"))
                        : L("No Results"),
                    description: searchText.isEmpty
                        ? (showOutdatedOnly ? L("All installed packages are up to date.") : L("No Homebrew packages are installed."))
                        : L("No packages match your search."),
                    action: searchText.isEmpty && !showOutdatedOnly ? { refresh() } : nil,
                    actionLabel: L("Refresh")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredPackages) { pkg in
                            PackageRowView(package: pkg, onAction: { refresh() })
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }

            if let error = errorMessage {
                errorBanner(error)
            }

            Divider()
            StatusFooter(
                count: homebrewManager.packages.count,
                itemLabel: L("packages"),
                lastUpdate: lastUpdate
            )
        }
        .toolbar {
            if outdatedCount > 0 {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        upgradeAll()
                    } label: {
                        if isUpgradingAll {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(L("Upgrade All"), systemImage: "arrow.up.circle")
                        }
                    }
                    .disabled(isUpgradingAll || isRefreshing)
                    .help(L("Upgrade all outdated packages and casks"))
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { refresh() } label: {
                    if isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(L("Refresh"), systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing)
            }
        }
        .onAppear {
            if let (_, update) = homebrewManager.loadPackagesFromCache() {
                lastUpdate = update
            }
            if homebrewManager.packages.isEmpty {
                refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshPackages)) { _ in refresh() }
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        Task {
            do {
                try await homebrewManager.refreshPackages()
                lastUpdate = Date()
            } catch {
                errorMessage = error.localizedDescription
            }
            isRefreshing = false
        }
    }

    private func upgradeAll() {
        isUpgradingAll = true
        errorMessage = nil
        Task {
            do {
                try await homebrewManager.upgradeAll()
                lastUpdate = Date()
            } catch {
                errorMessage = error.localizedDescription
            }
            isUpgradingAll = false
        }
    }

    @ViewBuilder
    private func errorBanner(_ msg: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
            Text(msg).font(.caption).foregroundStyle(.red)
            Spacer()
            Button { errorMessage = nil } label: {
                Image(systemName: "xmark").font(.caption)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.red.opacity(0.08))
    }
}

// MARK: - Package Row

struct PackageRowView: View {
    let package: HomebrewPackage
    var onAction: (() -> Void)?

    @EnvironmentObject var homebrewManager: HomebrewManager
    @State private var isExpanded = false
    @State private var isUpdating = false
    @State private var isUninstalling = false
    @State private var showUninstallAlert = false
    @State private var actionError: String?

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
        .alert(L("Uninstall Package"), isPresented: $showUninstallAlert) {
            Button(L("Cancel"), role: .cancel) {}
            Button(L("Uninstall"), role: .destructive) { uninstall() }
        } message: {
            Text(String(format: L("Are you sure you want to uninstall '%@'?"), package.name))
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption2).foregroundStyle(.secondary).frame(width: 10)

            Image(systemName: "shippingbox")
                .font(.system(size: 16)).foregroundStyle(.secondary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(package.name).font(.headline).lineLimit(1)

                    if !package.version.isEmpty {
                        Text(package.version)
                            .font(.caption2).foregroundStyle(.secondary)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                    }

                    if package.installedAsDependency {
                        Text(L("Dependency"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                    }
                }

                if let desc = package.description, !desc.isEmpty {
                    Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Spacer()

            if package.outdated, let latest = package.latestVersion {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 9))
                    Text("\(package.version) → \(latest)")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.orange.opacity(0.12), in: Capsule())
            } else if package.installed {
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
                    if !package.version.isEmpty {
                        DetailRow(key: L("Version"), value: package.version)
                    }
                    if let latest = package.latestVersion, package.outdated {
                        DetailRow(key: L("Latest"), value: latest)
                    }
                    if let desc = package.description, !desc.isEmpty {
                        DetailRow(key: L("Description"), value: desc)
                    }
                    if let homepage = package.homepage, !homepage.isEmpty {
                        DetailRow(key: L("Homepage"), value: homepage)
                    }
                    if let license = package.license, !license.isEmpty {
                        DetailRow(key: L("License"), value: license)
                    }
                    if let tap = package.tap, !tap.isEmpty {
                        DetailRow(key: L("Tap"), value: tap)
                    }
                    if !package.dependencies.isEmpty {
                        DetailRow(key: L("Dependencies"), value: package.dependencies.joined(separator: ", "))
                    }
                    if let size = package.installedSize {
                        DetailRow(key: L("Size"), value: ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    }
                    if let date = package.installDate {
                        DetailRow(key: L("Installed"), value: date.formatted(date: .abbreviated, time: .omitted))
                    }

                    if let error = actionError {
                        Text(error).font(.caption2).foregroundStyle(.red).padding(.top, 4)
                    }
                }
                .padding(.leading, 44).padding(.vertical, 10)

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if package.outdated {
                        Button { update() } label: {
                            if isUpdating {
                                ProgressView().controlSize(.mini)
                            } else {
                                Label(L("Update"), systemImage: "arrow.up.circle")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isUpdating || isUninstalling)
                    }

                    if let homepage = package.homepage, let url = URL(string: homepage) {
                        Link(destination: url) {
                            Label(L("Homepage"), systemImage: "safari")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Button(role: .destructive) { showUninstallAlert = true } label: {
                        if isUninstalling {
                            ProgressView().controlSize(.mini)
                        } else {
                            Label(L("Uninstall"), systemImage: "trash").font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                    .disabled(isUpdating || isUninstalling)
                }
                .padding(.trailing, 8).padding(.vertical, 10)
            }
        }
    }

    private func update() {
        isUpdating = true; actionError = nil
        Task {
            do { try await homebrewManager.updatePackage(package); onAction?() }
            catch { actionError = error.localizedDescription }
            isUpdating = false
        }
    }

    private func uninstall() {
        isUninstalling = true; actionError = nil
        Task {
            do { try await homebrewManager.uninstallPackage(package); onAction?() }
            catch { actionError = error.localizedDescription }
            isUninstalling = false
        }
    }
}
