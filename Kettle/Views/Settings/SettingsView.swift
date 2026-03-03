import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Main View

struct SettingsView: View {
    @EnvironmentObject var homebrewManager: HomebrewManager

    var body: some View {
        TabView {
            StatusTabView()
                .tabItem { Label(L("Status"), systemImage: "info.circle") }

            PreferencesTabView()
                .tabItem { Label(L("Preferences"), systemImage: "gear") }

            ExportTabView()
                .tabItem { Label(L("Export"), systemImage: "square.and.arrow.up") }

            DoctorTabView()
                .tabItem { Label(L("Doctor"), systemImage: "stethoscope") }

            AboutTabView()
                .tabItem { Label(L("About"), systemImage: "questionmark.circle") }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - Status Tab

struct StatusTabView: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @State private var cpuInfo = "..."
    @State private var homebrewVersion = "..."
    @State private var coreInfo = "..."
    @State private var caskInfo = "..."

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(L("CPU Model"))
                    Spacer()
                    Text(cpuInfo)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                HStack {
                    Text(L("Homebrew"))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: homebrewManager.isHomebrewInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(homebrewManager.isHomebrewInstalled ? .green : .red)
                        Text(homebrewManager.isHomebrewInstalled ? L("Installed") : L("Not Installed"))
                            .foregroundStyle(.secondary)
                    }
                }

                if homebrewManager.isHomebrewInstalled {
                    HStack {
                        Text(L("Version"))
                        Spacer()
                        Text(homebrewVersion)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    HStack {
                        Text(L("Installation Path"))
                        Spacer()
                        Text(homebrewManager.getInstallationPath())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            } header: {
                Text(L("System"))
            }

            if homebrewManager.isHomebrewInstalled {
                Section {
                    HStack {
                        Text("homebrew-core")
                        Spacer()
                        Text(coreInfo)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    HStack {
                        Text("homebrew-cask")
                        Spacer()
                        Text(caskInfo)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text(L("Repositories"))
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loadSystemInfo() }
    }

    private func loadSystemInfo() {
        Task {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
            process.arguments = ["-n", "machdep.cpu.brand_string"]
            process.standardOutput = pipe
            try? process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let cpu = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "-"
            await MainActor.run { cpuInfo = cpu.isEmpty ? "-" : cpu }

            guard homebrewManager.isHomebrewInstalled else { return }
            do {
                let output = try await homebrewManager.executeBrewCommand("--version")
                let lines = output.split(separator: "\n").map { String($0) }
                let main = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "-"
                let core = lines.first(where: { $0.contains("homebrew-core") })
                let cask = lines.first(where: { $0.contains("homebrew-cask") })
                await MainActor.run {
                    homebrewVersion = main
                    coreInfo = parseRevision(core) ?? "-"
                    caskInfo = parseRevision(cask) ?? "-"
                }
            } catch {
                await MainActor.run {
                    homebrewVersion = "-"
                    coreInfo = "-"
                    caskInfo = "-"
                }
            }
        }
    }

    private func parseRevision(_ line: String?) -> String? {
        guard let line else { return nil }
        guard let revStart = line.range(of: "(git revision ")?.upperBound,
              let revEnd = line.range(of: ";")?.lowerBound,
              let commitStart = line.range(of: "; last commit ")?.upperBound,
              let commitEnd = line.range(of: ")")?.lowerBound,
              revStart < revEnd, commitStart < commitEnd else { return nil }
        let rev = String(line[revStart..<revEnd])
        let date = String(line[commitStart..<commitEnd])
        return "\(rev) / \(date)"
    }
}

// MARK: - Preferences Tab

struct PreferencesTabView: View {
    @EnvironmentObject var settings: AppSettings

    let finderOptions = ["Finder", "Path Finder"]
    let editorOptions = ["TextEdit", "Visual Studio Code", "Sublime Text", "BBEdit"]

    var body: some View {
        Form {
            Section {
                Picker(L("Language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                Picker(L("Appearance"), selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(L("Interface"))
            } footer: {
                Text(L("Language changes will take effect after restarting the app."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker(L("Default Finder"), selection: $settings.preferredFinder) {
                    ForEach(finderOptions, id: \.self) { Text($0).tag($0) }
                }
                Picker(L("Default Editor"), selection: $settings.preferredEditor) {
                    ForEach(editorOptions, id: \.self) { Text($0).tag($0) }
                }
            } header: {
                Text(L("Applications"))
            } footer: {
                Text(L("These settings will be used when opening files and folders."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Export Tab

struct ExportTabView: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @AppStorage("cachedTapsUpdate") private var lastUpdate: Date?
    @State private var isExporting = false
    @State private var showingError = false
    @State private var errorMessage = ""

    struct ExportData: Codable {
        let taps: [HomebrewTap]
        let tapInfos: [String: TapInfo]
        let exportDate: Date
        let lastUpdateDate: Date?
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Tap List"))
                            .font(.headline)
                        Text(L("Export all installed taps and their metadata as JSON."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        exportTaps()
                    } label: {
                        if isExporting {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(L("Export"), systemImage: "square.and.arrow.up")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isExporting)
                }
                .padding(.vertical, 4)
            } header: {
                Text(L("Homebrew Taps"))
            } footer: {
                if let update = lastUpdate {
                    Text(String(format: L("Last updated: %@"), update.formatted()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .alert(L("Error"), isPresented: $showingError) {
            Button(L("OK"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func exportTaps() {
        isExporting = true
        let panel = NSSavePanel()
        panel.title = L("Export taps panel title")
        panel.nameFieldStringValue = "homebrew-taps-\(DateFormatter.exportFormat.string(from: Date())).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = ExportData(
                        taps: homebrewManager.taps,
                        tapInfos: homebrewManager.tapInfos,
                        exportDate: Date(),
                        lastUpdateDate: lastUpdate
                    )
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dateEncodingStrategy = .iso8601
                    try encoder.encode(data).write(to: url)
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
            isExporting = false
        }
    }
}

private extension DateFormatter {
    static let exportFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f
    }()
}

// MARK: - Doctor Tab

struct DoctorTabView: View {
    @EnvironmentObject var homebrewManager: HomebrewManager
    @State private var output = ""
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    runDoctor()
                } label: {
                    if isRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(L("Run Diagnostics"), systemImage: "stethoscope")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isRunning)
                Spacer()
                if !output.isEmpty {
                    Button {
                        output = ""
                    } label: {
                        Label(L("Clear"), systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(12)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(output.isEmpty
                        ? L("Click \"Run Diagnostics\" to check your Homebrew installation.")
                        : output
                    )
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(output.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("bottom")
                }
                .onChange(of: output) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
    }

    private func runDoctor() {
        isRunning = true
        let runningMsg = L("Running brew doctor...\n")
        output = runningMsg
        homebrewManager.streamBrewCommand(
            "doctor",
            arguments: [],
            onOutput: { chunk in
                if output == runningMsg {
                    output = chunk
                } else {
                    output += chunk
                }
            },
            onErrorOutput: { chunk in output += chunk },
            onCompletion: { code in
                isRunning = false
                if code == 0 && output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    output = L("Your system is ready to brew.")
                }
            }
        )
    }
}

// MARK: - About Tab

struct AboutTabView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var updateService = UpdateService.shared
    @State private var showingChangelog = false
    @State private var showingUpdate = false

    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
    let websiteURL = URL(string: "https://github.com/Geoion/kettle")!
    let emailURL = URL(string: "mailto:eski.yin@gmail.com")!

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(spacing: 4) {
                        Text("Kettle")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Version \(version) (\(build))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section {
                HStack {
                    Label(L("Developer"), systemImage: "person.circle")
                    Spacer()
                    Text("Geoion").foregroundStyle(.secondary)
                }
                HStack {
                    Label(L("Contact"), systemImage: "envelope")
                    Spacer()
                    Button("eski.yin@gmail.com") { openURL(emailURL) }
                        .buttonStyle(.link)
                }
                HStack {
                    Label(L("Repository"), systemImage: "chevron.left.forwardslash.chevron.right")
                    Spacer()
                    Button("github.com") { openURL(websiteURL) }
                        .buttonStyle(.link)
                }
            } header: {
                Text(L("Information"))
            }

            Section {
                Button {
                    openURL(websiteURL)
                } label: {
                    Label(L("View Source Code"), systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.plain)

                Button {
                    showingChangelog = true
                } label: {
                    Label(L("View Changelog"), systemImage: "list.bullet.rectangle.portrait")
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await updateService.checkForUpdates()
                        if case .updateAvailable = updateService.updateStatus {
                            showingUpdate = true
                        }
                    }
                } label: {
                    HStack {
                        if case .checking = updateService.updateStatus {
                            ProgressView().controlSize(.small).frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.down.circle")
                        }
                        Text(L("Check for Updates"))
                        Spacer()
                        if case .updateAvailable = updateService.updateStatus {
                            Circle().fill(.red).frame(width: 8, height: 8)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled({
                    if case .checking = updateService.updateStatus { return true }
                    return false
                }())
            } header: {
                Text(L("Actions"))
            } footer: {
                updateStatusFooter
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingChangelog) { ChangelogView() }
        .sheet(isPresented: $showingUpdate) {
            if case .updateAvailable(let v, let releaseUrl, let downloadUrl) = updateService.updateStatus {
                UpdateDialogView(version: v, releaseUrl: releaseUrl, downloadUrl: downloadUrl)
            }
        }
        .task { await updateService.checkForUpdates() }
    }

    @ViewBuilder
    private var updateStatusFooter: some View {
        switch updateService.updateStatus {
        case .updateAvailable(let v, _, _):
            Text(String(format: L("Version %@ is available."), v))
                .foregroundStyle(.blue)
        case .upToDate:
            Text(L("You're up to date."))
                .foregroundStyle(.secondary)
        case .error(let msg):
            Text(msg).foregroundStyle(.red)
        case .checking:
            Text(L("Checking for updates..."))
                .foregroundStyle(.secondary)
                .italic()
        default:
            EmptyView()
        }
    }
}

// MARK: - Update Dialog

struct UpdateDialogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let version: String
    let releaseUrl: String
    let downloadUrl: String

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text(L("Update Available"))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(String(format: L("Version %@ is now available."), version))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)

            Divider()

            if let release = UpdateService.shared.latestRelease {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("What's New"))
                            .font(.headline)
                        Text(release.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .frame(maxHeight: 180)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button(L("Later")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L("View Release")) {
                    if let url = URL(string: releaseUrl) { openURL(url) }
                }
                Button(L("Download")) {
                    if let url = URL(string: downloadUrl) {
                        openURL(url)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 480)
        .padding(.horizontal)
    }
}

// MARK: - Changelog View

struct ChangelogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content = AttributedString(L("Loading..."))
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Text(L("Changelog"))
                .font(.headline)
                .padding(.vertical, 12)

            Divider()

            ScrollView {
                if let err = error {
                    Text(err).foregroundStyle(.red).padding()
                } else {
                    Text(content)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button(L("Close")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(minWidth: 500, idealWidth: 600, minHeight: 300, idealHeight: 450)
        .onAppear {
            guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md") else {
                error = "CHANGELOG.md not found."
                return
            }
            do {
                let md = try String(contentsOf: url, encoding: .utf8)
                content = (try? AttributedString(
                    markdown: md,
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                )) ?? AttributedString(md)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
