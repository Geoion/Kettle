import SwiftUI

struct ServiceListView: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var lastUpdate: Date?

    var body: some View {
        VStack(spacing: 0) {
            if isRefreshing && homebrewManager.services.isEmpty {
                LoadingView()
            } else if homebrewManager.services.isEmpty {
                EmptyStateView(
                    icon: "server.rack",
                    title: L("No Services"),
                    description: L("No Homebrew services are available."),
                    action: { refresh() },
                    actionLabel: L("Refresh")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(homebrewManager.services) { service in
                            ServiceRowView(service: service, onStatusChanged: { refresh() })
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
                count: homebrewManager.services.count,
                itemLabel: L("services"),
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
        }
        .onAppear {
            if homebrewManager.services.isEmpty {
                if let (_, update) = homebrewManager.loadServicesFromCache() {
                    lastUpdate = update
                }
            }
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshServices)) { _ in
            refresh()
        }
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        Task {
            do {
                try await homebrewManager.refreshServices()
                lastUpdate = Date()
            } catch {
                errorMessage = error.localizedDescription
            }
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
    @State private var showConfirmation = false
    @State private var actionError: String?
    @State private var plistContent: PlistParser.PlistValue?
    @State private var rawXMLContent: String?
    @State private var plistError: String?
    @State private var viewMode: PlistViewMode = .form

    enum PlistViewMode: CaseIterable {
        case form, xml
        var label: String {
            switch self {
            case .form: return L("Summary")
            case .xml: return L("XML")
            }
        }
        var icon: String {
            switch self {
            case .form: return "list.bullet.rectangle"
            case .xml: return "doc.text"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isExpanded && plistContent == nil && rawXMLContent == nil {
                        loadPlistContent()
                    }
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
        .alert(L("Confirm"), isPresented: $showConfirmation) {
            Button(L("OK")) {
                Task { await handleServiceAction() }
            }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            let isStarted = service.status == .started
            Text(isStarted
                ? String(format: L("Are you sure you want to stop %@?"), service.name)
                : String(format: L("Are you sure you want to start %@?"), service.name)
            )
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 10)

            Image(systemName: service.status.icon)
                .font(.system(size: 14))
                .foregroundStyle(service.status.color)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.headline)
                    .lineLimit(1)
                if let user = service.user {
                    Text(user)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            statusBadge

            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    showConfirmation = true
                } label: {
                    Image(systemName: service.status == .started ? "stop.circle" : "play.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(service.status == .started ? .red : .green)
                }
                .buttonStyle(.plain)
                .help(service.status == .started ? L("Stop Service") : L("Start Service"))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }

    private var statusBadge: some View {
        let color: Color
        let label: String
        switch service.status {
        case .started, .running:
            color = .green
            label = L("Running")
        case .stopped:
            color = .secondary
            label = L("Stopped")
        case .error:
            color = .red
            label = L("Error")
        case .unknown:
            color = .orange
            label = L("Unknown")
        }
        return HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
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
                    if let user = service.user {
                        DetailRow(key: L("User"), value: user)
                    }
                    if let path = service.filePath {
                        DetailRow(key: L("File Path"), value: path)
                    }
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
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                            .controlSize(.small)
                        }

                        if let error = plistError {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        } else if viewMode == .form {
                            if let content = plistContent, let dict = content.dictionaryValue {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(Array(dict.keys).sorted(), id: \.self) { key in
                                        if let value = dict[key] {
                                            DetailRow(key: key, value: formatPlistValue(value))
                                        }
                                    }
                                }
                            } else {
                                Text(L("Loading configuration..."))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            if let xml = rawXMLContent {
                                ScrollView([.horizontal], showsIndicators: true) {
                                    Text(xml)
                                        .font(.system(.caption2, design: .monospaced))
                                        .textSelection(.enabled)
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                                .frame(maxHeight: 200)
                            } else {
                                Text(L("No XML content available"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let error = actionError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .padding(.leading, 44)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
        }
        .onChange(of: viewMode) { _ in
            if viewMode == .form && plistContent == nil && rawXMLContent != nil {
                parseXMLContent()
            }
        }
    }

    private func formatPlistValue(_ value: PlistParser.PlistValue) -> String {
        switch value {
        case .string(let s): return s
        case .integer(let n): return "\(n)"
        case .boolean(let b): return b ? "true" : "false"
        case .array(let a): return "[\(a.count) items]"
        case .dictionary(let d): return "{\(d.count) keys}"
        }
    }

    private func handleServiceAction() async {
        isLoading = true
        actionError = nil
        do {
            if service.status == .started {
                try await homebrewManager.stopService(service)
            } else {
                try await homebrewManager.startService(service)
            }
            onStatusChanged?()
        } catch {
            actionError = error.localizedDescription
        }
        isLoading = false
    }

    private func loadPlistContent() {
        guard let path = service.filePath else { return }
        Task {
            do {
                let expandedPath = (path as NSString).expandingTildeInPath
                guard FileManager.default.fileExists(atPath: expandedPath),
                      FileManager.default.isReadableFile(atPath: expandedPath) else {
                    await MainActor.run { plistError = L("Configuration file not readable.") }
                    return
                }
                let xml = try String(contentsOf: URL(fileURLWithPath: expandedPath), encoding: .utf8)
                await MainActor.run {
                    rawXMLContent = xml
                    plistError = nil
                    if viewMode == .form { parseXMLContent() }
                }
            } catch {
                await MainActor.run { plistError = error.localizedDescription }
            }
        }
    }

    private func parseXMLContent() {
        guard let xmlString = rawXMLContent,
              let data = xmlString.data(using: .utf8) else { return }
        do {
            var format = PropertyListSerialization.PropertyListFormat.xml
            guard let plist = try PropertyListSerialization.propertyList(
                from: data, options: .mutableContainersAndLeaves, format: &format
            ) as? [String: Any] else { return }
            plistContent = try convertToPlistValue(plist)
        } catch {
            plistError = error.localizedDescription
        }
    }

    private func convertToPlistValue(_ value: Any) throws -> PlistParser.PlistValue {
        switch value {
        case let s as String: return .string(s)
        case let n as Int: return .integer(n)
        case let n as Int64: return .integer(Int(n))
        case let n as Int32: return .integer(Int(n))
        case let b as Bool: return .boolean(b)
        case let a as [Any]: return .array(try a.map { try convertToPlistValue($0) })
        case let d as [String: Any]:
            var result: [String: PlistParser.PlistValue] = [:]
            for (k, v) in d { result[k] = try convertToPlistValue(v) }
            return .dictionary(result)
        default: return .string(String(describing: value))
        }
    }
}
