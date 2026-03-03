import SwiftUI

struct ServiceListView: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var lastUpdate: Date?

    private var filteredServices: [HomebrewService] {
        if searchText.isEmpty { return homebrewManager.services }
        return homebrewManager.services.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SearchToolbar(text: $searchText, placeholder: L("Search services..."))
                    .frame(maxWidth: 260)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            if isRefreshing && homebrewManager.services.isEmpty {
                LoadingView()
            } else if filteredServices.isEmpty {
                EmptyStateView(
                    icon: "server.rack",
                    title: searchText.isEmpty ? L("No Services") : L("No Results"),
                    description: searchText.isEmpty
                        ? L("No Homebrew services are available.")
                        : L("No services match your search."),
                    action: searchText.isEmpty ? { refresh() } : nil,
                    actionLabel: L("Refresh")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredServices) { service in
                            ServiceRowView(service: service, onStatusChanged: { refresh() })
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
            StatusFooter(count: homebrewManager.services.count, itemLabel: L("services"), lastUpdate: lastUpdate)
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
            if let (_, update) = homebrewManager.loadServicesFromCache() {
                lastUpdate = update
            }
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshServices)) { _ in refresh() }
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true; errorMessage = nil
        Task {
            do { try await homebrewManager.refreshServices(); lastUpdate = Date() }
            catch { errorMessage = error.localizedDescription }
            isRefreshing = false
        }
    }
}

// MARK: - Service Row

struct ServiceRowView: View {
    let service: HomebrewService
    var onStatusChanged: (() -> Void)?

    @EnvironmentObject var homebrewManager: HomebrewManager
    @State private var isExpanded = false
    @State private var isLoading = false
    @State private var pendingAction: ServiceAction? = nil
    @State private var actionError: String?
    @State private var plistContent: PlistParser.PlistValue?
    @State private var rawXMLContent: String?
    @State private var plistError: String?
    @State private var viewMode: PlistViewMode = .form

    enum ServiceAction { case start, stop, restart }

    enum PlistViewMode: CaseIterable {
        case form, xml
        var label: String { self == .form ? L("Summary") : L("XML") }
        var icon: String { self == .form ? "list.bullet.rectangle" : "doc.text" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isExpanded && plistContent == nil && rawXMLContent == nil {
                        loadPlistContent()
                    }
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                }

            VStack(spacing: 0) { detailSection }
                .frame(maxHeight: isExpanded ? .infinity : 0, alignment: .top)
                .clipped()
                .opacity(isExpanded ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .alert(confirmTitle, isPresented: Binding(
            get: { pendingAction != nil },
            set: { if !$0 { pendingAction = nil } }
        )) {
            Button(L("OK")) { Task { await executeAction() } }
            Button(L("Cancel"), role: .cancel) { pendingAction = nil }
        } message: {
            Text(confirmMessage)
        }
    }

    private var confirmTitle: String {
        switch pendingAction {
        case .start: return L("Start Service")
        case .stop: return L("Stop Service")
        case .restart: return L("Restart Service")
        case nil: return ""
        }
    }

    private var confirmMessage: String {
        switch pendingAction {
        case .start: return String(format: L("Are you sure you want to start %@?"), service.name)
        case .stop: return String(format: L("Are you sure you want to stop %@?"), service.name)
        case .restart: return String(format: L("Are you sure you want to restart %@?"), service.name)
        case nil: return ""
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption2).foregroundStyle(.secondary).frame(width: 10)

            Image(systemName: service.status.icon)
                .font(.system(size: 14)).foregroundStyle(service.status.color)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(service.name).font(.headline).lineLimit(1)
                    if let pid = service.pid {
                        Text("PID \(pid)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
                if let user = service.user {
                    Text(user).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            statusBadge

            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                HStack(spacing: 6) {
                    // Restart button (only when running)
                    if service.status == .started || service.status == .running {
                        Button { pendingAction = .restart } label: {
                            Image(systemName: "arrow.clockwise.circle")
                                .font(.system(size: 15))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .help(L("Restart Service"))
                    }

                    // Start / Stop toggle
                    Button { pendingAction = (service.status == .started || service.status == .running) ? .stop : .start } label: {
                        Image(systemName: (service.status == .started || service.status == .running) ? "stop.circle" : "play.circle")
                            .font(.system(size: 16))
                            .foregroundStyle((service.status == .started || service.status == .running) ? .red : .green)
                    }
                    .buttonStyle(.plain)
                    .help((service.status == .started || service.status == .running) ? L("Stop Service") : L("Start Service"))
                }
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 4)
    }

    private var statusBadge: some View {
        let color: Color
        let label: String
        switch service.status {
        case .started, .running: color = .green; label = L("Running")
        case .stopped: color = .secondary; label = L("Stopped")
        case .error: color = .red; label = L("Error")
        case .unknown: color = .orange; label = L("Unknown")
        }
        return HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(color.opacity(0.12), in: Capsule())
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.leading, 44)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    DetailSectionHeader(title: L("Service Info"))
                    DetailRow(key: L("Name"), value: service.name)
                    DetailRow(key: L("Status"), value: service.status.rawValue)
                    if let user = service.user { DetailRow(key: L("User"), value: user) }
                    if let pid = service.pid { DetailRow(key: "PID", value: "\(pid)") }
                    if let path = service.filePath { DetailRow(key: L("File Path"), value: path) }
                }

                if service.filePath != nil {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            DetailSectionHeader(title: L("Configuration"))
                            Spacer()
                            Picker("", selection: $viewMode) {
                                ForEach(PlistViewMode.allCases, id: \.self) { mode in
                                    Label(mode.label, systemImage: mode.icon).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented).frame(width: 160).controlSize(.small)
                        }

                        if let error = plistError {
                            Text(error).font(.caption2).foregroundStyle(.red)
                        } else if viewMode == .form {
                            if let content = plistContent, let dict = content.dictionaryValue {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(dict.keys).sorted(), id: \.self) { key in
                                        if let value = dict[key] {
                                            PlistEntryView(key: key, value: value)
                                        }
                                    }
                                }
                            } else {
                                Text(L("Loading configuration...")).font(.caption2).foregroundStyle(.secondary)
                            }
                        } else {
                            if let xml = rawXMLContent {
                                Text(xml)
                                    .font(.system(.caption2, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                            } else {
                                Text(L("No XML content available")).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let error = actionError {
                    Text(error).font(.caption2).foregroundStyle(.red)
                }
            }
            .padding(.leading, 44).padding(.trailing, 12).padding(.vertical, 10)
        }
        .onChange(of: viewMode) { _ in
            if viewMode == .form && plistContent == nil && rawXMLContent != nil { parseXMLContent() }
        }
    }

    private func formatPlistScalar(_ value: PlistParser.PlistValue) -> String? {
        switch value {
        case .string(let s): return s
        case .integer(let n): return "\(n)"
        case .boolean(let b): return b ? "true" : "false"
        default: return nil
        }
    }

    private func executeAction() async {
        guard let action = pendingAction else { return }
        pendingAction = nil
        isLoading = true; actionError = nil
        do {
            switch action {
            case .start: try await homebrewManager.startService(service)
            case .stop: try await homebrewManager.stopService(service)
            case .restart: try await homebrewManager.restartService(service)
            }
            onStatusChanged?()
        } catch { actionError = error.localizedDescription }
        isLoading = false
    }

    private func loadPlistContent() {
        guard let path = service.filePath else { return }
        Task {
            do {
                let expanded = (path as NSString).expandingTildeInPath
                guard FileManager.default.fileExists(atPath: expanded),
                      FileManager.default.isReadableFile(atPath: expanded) else {
                    await MainActor.run { plistError = L("Configuration file not readable.") }
                    return
                }
                let xml = try String(contentsOf: URL(fileURLWithPath: expanded), encoding: .utf8)
                await MainActor.run {
                    rawXMLContent = xml; plistError = nil
                    if viewMode == .form { parseXMLContent() }
                }
            } catch {
                await MainActor.run { plistError = error.localizedDescription }
            }
        }
    }

    private func parseXMLContent() {
        guard let xml = rawXMLContent, let data = xml.data(using: .utf8) else { return }
        do {
            var fmt = PropertyListSerialization.PropertyListFormat.xml
            guard let plist = try PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: &fmt) as? [String: Any] else { return }
            plistContent = try convertToPlistValue(plist)
        } catch { plistError = error.localizedDescription }
    }

    private func convertToPlistValue(_ v: Any) throws -> PlistParser.PlistValue {
        switch v {
        case let s as String: return .string(s)
        case let n as Int: return .integer(n)
        case let n as Int64: return .integer(Int(n))
        case let n as Int32: return .integer(Int(n))
        case let b as Bool: return .boolean(b)
        case let a as [Any]: return .array(try a.map { try convertToPlistValue($0) })
        case let d as [String: Any]:
            var r: [String: PlistParser.PlistValue] = [:]
            for (k, val) in d { r[k] = try convertToPlistValue(val) }
            return .dictionary(r)
        default: return .string(String(describing: v))
        }
    }
}

// MARK: - Plist Entry View (fully expanded, no truncation)

private struct PlistEntryView: View {
    let key: String
    let value: PlistParser.PlistValue

    var body: some View {
        switch value {
        case .string(let s):
            DetailRow(key: key, value: s)
        case .integer(let n):
            DetailRow(key: key, value: "\(n)")
        case .boolean(let b):
            HStack(alignment: .top, spacing: 4) {
                Text(key)
                    .font(.caption2).foregroundStyle(.tertiary)
                    .frame(width: 100, alignment: .trailing)
                Image(systemName: b ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(b ? .green : .red)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 1)
        case .array(let items):
            VStack(alignment: .leading, spacing: 0) {
                // Key header row
                HStack(alignment: .top, spacing: 4) {
                    Text(key)
                        .font(.caption2).foregroundStyle(.tertiary)
                        .frame(width: 100, alignment: .trailing)
                    Text("[\(items.count)]")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 1)
                // All array items indented
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 4) {
                        Text("[\(idx)]")
                            .font(.caption2).foregroundStyle(.tertiary)
                            .frame(width: 100, alignment: .trailing)
                        Text(scalarString(item))
                            .font(.caption2).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 1)
                }
            }
        case .dictionary(let dict):
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 4) {
                    Text(key)
                        .font(.caption2).foregroundStyle(.tertiary)
                        .frame(width: 100, alignment: .trailing)
                    Text("{\(dict.count)}")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 1)
                ForEach(Array(dict.keys).sorted(), id: \.self) { subKey in
                    if let subVal = dict[subKey] {
                        HStack(alignment: .top, spacing: 4) {
                            Text("  \(subKey)")
                                .font(.caption2).foregroundStyle(.tertiary)
                                .frame(width: 100, alignment: .trailing)
                            Text(scalarString(subVal))
                                .font(.caption2).foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
    }

    private func scalarString(_ v: PlistParser.PlistValue) -> String {
        switch v {
        case .string(let s): return s
        case .integer(let n): return "\(n)"
        case .boolean(let b): return b ? "true" : "false"
        case .array(let a): return "[\(a.count) items]"
        case .dictionary(let d): return "{\(d.count) keys}"
        }
    }
}
