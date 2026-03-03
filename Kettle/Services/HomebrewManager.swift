import Foundation
import SwiftUI
import OSLog

// MARK: - TapInfo

struct TapInfo: Codable, Hashable {
    let name: String
    let url: String
    let installed: Bool
    let info: String
    let status: String?
    let commands: String?
    let casks: String?
    let path: String?
    let head: String?
    let lastCommit: String?
    let repoURL: String?
    let branch: String?
    let filesPath: String?
    let filesCount: Int?
    let filesSize: String?
}

// MARK: - HomebrewManager

class HomebrewManager: ObservableObject {
    @Published var isHomebrewInstalled = false
    @Published var packages: [HomebrewPackage] = []
    @Published var casks: [HomebrewCask] = []
    @Published var services: [HomebrewService] = []
    @Published var taps: [HomebrewTap] = []
    @Published var tapInfos: [String: TapInfo] = [:]
    @Published var outdatedPackages: [OutdatedInfo] = []
    @Published var homebrewPath: String? = nil
    @Published var isLoadingTaps = false
    @Published var isLoadingServices = false
    @Published var isLoadingPackages = false
    @Published var isLoadingCasks = false

    private let logger = Logger(subsystem: "com.kettle.app", category: "Homebrew")
    private let cacheDirectory: URL
    private let packagesCacheKey = "cachedPackages"
    private let packagesUpdateKey = "cachedPackagesUpdate"
    private let casksCacheKey = "cachedCasks"
    private let casksUpdateKey = "cachedCasksUpdate"
    private var currentProcess: Process?

    init() {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupportDir.appendingPathComponent("Kettle")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        homebrewPath = findHomebrewPath()
        checkHomebrewInstallation()

        if isHomebrewInstalled {
            loadTapsFromCache()
            loadServicesFromCache()
            loadPackagesFromCache()
            loadCasksFromCache()
        }
    }

    // MARK: - Path Detection

    private func findHomebrewPath() -> String? {
        let standardPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        for path in standardPaths {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        if let pathVar = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathVar.components(separatedBy: ":") {
                let brewPath = (dir as NSString).appendingPathComponent("brew")
                if FileManager.default.fileExists(atPath: brewPath) { return brewPath }
            }
        }
        return nil
    }

    func checkHomebrewInstallation() {
        isHomebrewInstalled = FileManager.default.fileExists(atPath: homebrewPath ?? "")
    }

    func getInstallationPath() -> String {
        homebrewPath ?? "-"
    }

    // MARK: - Command Execution

    func executeBrewCommand(_ command: String) async throws -> String {
        guard let brewPath = homebrewPath else {
            throw HomebrewError.invalidState("Homebrew path not found")
        }
        guard isHomebrewInstalled else {
            throw HomebrewError.invalidState("Homebrew not installed")
        }

        let process = Process()
        currentProcess = process
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = command.components(separatedBy: " ")
        process.standardOutput = pipe
        process.standardError = pipe
        process.environment = brewEnvironment()

        do {
            try process.run()
            process.waitUntilExit()
            currentProcess = nil
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if process.terminationStatus != 0 {
                throw HomebrewError.commandFailed(command, process.terminationStatus)
            }
            return output
        } catch {
            currentProcess = nil
            throw error
        }
    }

    func executeBrewCommandWithArgs(_ args: [String]) async throws -> String {
        guard let brewPath = homebrewPath else {
            throw HomebrewError.invalidState("Homebrew path not found")
        }
        let process = Process()
        currentProcess = process
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = pipe
        process.environment = brewEnvironment()

        do {
            try process.run()
            process.waitUntilExit()
            currentProcess = nil
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if process.terminationStatus != 0 {
                throw HomebrewError.commandFailed(args.joined(separator: " "), process.terminationStatus)
            }
            return output
        } catch {
            currentProcess = nil
            throw error
        }
    }

    func terminateBrewProcess() async throws {
        currentProcess?.terminate()
        currentProcess = nil
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        kill.arguments = ["-f", "brew"]
        try? kill.run()
        kill.waitUntilExit()
    }

    @MainActor
    func streamBrewCommand(
        _ command: String,
        arguments: [String] = [],
        onOutput: @escaping (String) -> Void,
        onErrorOutput: @escaping (String) -> Void,
        onCompletion: @escaping (Int32) -> Void
    ) {
        guard let brewPath = homebrewPath else {
            onErrorOutput("Homebrew path not found.\n")
            onCompletion(-1)
            return
        }
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = [command] + arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = brewEnvironment()

        stdoutPipe.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            if !data.isEmpty, let s = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { onOutput(s) }
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            if !data.isEmpty, let s = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { onErrorOutput(s) }
            }
        }
        process.terminationHandler = { p in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { onCompletion(p.terminationStatus) }
        }
        try? process.run()
    }

    private func brewEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        var path = env["PATH"] ?? ""
        if !path.contains("/opt/homebrew/bin") { path = "/opt/homebrew/bin:" + path }
        if !path.contains("/usr/local/bin") { path = "/usr/local/bin:" + path }
        env["PATH"] = path
        return env
    }

    // MARK: - Packages (brew info --json=v2 --installed)

    @MainActor
    func refreshPackages() async throws {
        isLoadingPackages = true
        defer { isLoadingPackages = false }
        do {
            let output = try await executeBrewCommandWithArgs(["info", "--json=v2", "--installed"])
            packages = parsePackagesJSON(output)
            savePackagesToCache(packages)
        } catch {
            logger.error("refreshPackages failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func parsePackagesJSON(_ json: String) -> [HomebrewPackage] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let formulae = root["formulae"] as? [[String: Any]] else {
            // Fallback: parse as plain list
            return json.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .map { HomebrewPackage(name: $0, version: "", installed: true, dependencies: [], description: nil) }
        }

        return formulae.compactMap { formula -> HomebrewPackage? in
            guard let name = formula["name"] as? String else { return nil }
            let desc = formula["desc"] as? String
            let homepage = formula["homepage"] as? String
            let license = formula["license"] as? String
            let tap = formula["tap"] as? String
            let outdated = formula["outdated"] as? Bool ?? false

            // Installed versions
            let installedArr = formula["installed"] as? [[String: Any]] ?? []
            let firstInstalled = installedArr.first
            let version = firstInstalled?["version"] as? String ?? ""
            let installedAsDep = firstInstalled?["installed_as_dependency"] as? Bool ?? false

            // Install date from receipt
            var installDate: Date? = nil
            var installedSize: Int64? = nil
            if let cellarPath = firstInstalled?["cellar"] as? String {
                let versionPath = "\(cellarPath)/\(name)/\(version)"
                let receiptPath = "\(versionPath)/INSTALL_RECEIPT.json"
                if let receiptData = try? Data(contentsOf: URL(fileURLWithPath: receiptPath)),
                   let receipt = try? JSONSerialization.jsonObject(with: receiptData) as? [String: Any],
                   let dateStr = receipt["date_installed"] as? String {
                    let fmt = ISO8601DateFormatter()
                    installDate = fmt.date(from: dateStr)
                }
                if let size = directorySize(at: versionPath) {
                    installedSize = size
                }
            }

            // Dependencies
            let deps = (formula["dependencies"] as? [String]) ?? []

            // Latest version from versions
            let versions = formula["versions"] as? [String: Any]
            let latestVersion = versions?["stable"] as? String

            return HomebrewPackage(
                name: name,
                version: version,
                installed: true,
                dependencies: deps,
                description: desc,
                homepage: homepage,
                license: license,
                tap: tap,
                outdated: outdated,
                latestVersion: latestVersion,
                installedAsDependency: installedAsDep,
                installDate: installDate,
                installedSize: installedSize
            )
        }
    }

    func savePackagesToCache(_ packages: [HomebrewPackage]) {
        if let data = try? JSONEncoder().encode(packages) {
            UserDefaults.standard.set(data, forKey: packagesCacheKey)
            UserDefaults.standard.set(Date(), forKey: packagesUpdateKey)
        }
    }

    @discardableResult
    func loadPackagesFromCache() -> ([HomebrewPackage], Date?)? {
        guard let data = UserDefaults.standard.data(forKey: packagesCacheKey),
              let pkgs = try? JSONDecoder().decode([HomebrewPackage].self, from: data) else { return nil }
        let update = UserDefaults.standard.object(forKey: packagesUpdateKey) as? Date
        Task { @MainActor in self.packages = pkgs }
        return (pkgs, update)
    }

    func updatePackage(_ package: HomebrewPackage) async throws {
        try await executeBrewCommand("upgrade \(package.name)")
        try await refreshPackages()
    }

    func uninstallPackage(_ package: HomebrewPackage) async throws {
        try await executeBrewCommand("uninstall \(package.name)")
        try await refreshPackages()
    }

    func installPackage(_ package: HomebrewPackage) async throws {
        try await executeBrewCommand("install \(package.name)")
        try await refreshPackages()
    }

    @MainActor
    func upgradeAll() async throws {
        try await executeBrewCommand("upgrade")
        try await refreshPackages()
        try await refreshCasks()
    }

    // MARK: - Outdated

    @MainActor
    func refreshOutdated() async throws {
        let output = try await executeBrewCommandWithArgs(["outdated", "--json=v2"])
        outdatedPackages = parseOutdatedJSON(output)
    }

    private func parseOutdatedJSON(_ json: String) -> [OutdatedInfo] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var result: [OutdatedInfo] = []
        if let formulae = root["formulae"] as? [[String: Any]] {
            for f in formulae {
                guard let name = f["name"] as? String,
                      let current = f["current_version"] as? String,
                      let installed = (f["installed_versions"] as? [String])?.first else { continue }
                result.append(OutdatedInfo(name: name, installedVersion: installed, currentVersion: current, isCask: false))
            }
        }
        if let casks = root["casks"] as? [[String: Any]] {
            for c in casks {
                guard let name = c["name"] as? String,
                      let current = c["current_version"] as? String,
                      let installed = c["installed_versions"] as? String else { continue }
                result.append(OutdatedInfo(name: name, installedVersion: installed, currentVersion: current, isCask: true))
            }
        }
        return result
    }

    // MARK: - Casks (brew list --cask → brew info --json=v2 --cask <names>)

    @MainActor
    func refreshCasks() async throws {
        isLoadingCasks = true
        defer { isLoadingCasks = false }
        do {
            // Step 1: get installed cask names
            let listOutput = try await executeBrewCommand("list --cask")
            let names = listOutput.components(separatedBy: .newlines).map {
                $0.trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }

            guard !names.isEmpty else {
                casks = []
                saveCasksToCache(casks)
                return
            }

            // Step 2: fetch full info for all installed casks in one call
            let infoOutput = try await executeBrewCommandWithArgs(
                ["info", "--json=v2", "--cask"] + names
            )
            casks = parseCasksJSON(infoOutput)
            saveCasksToCache(casks)
        } catch {
            logger.error("refreshCasks failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func parseCasksJSON(_ json: String) -> [HomebrewCask] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let casksArr = root["casks"] as? [[String: Any]] else {
            return json.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .map { HomebrewCask(name: $0) }
        }

        return casksArr.compactMap { cask -> HomebrewCask? in
            guard let token = cask["token"] as? String else { return nil }
            let version = cask["version"] as? String
            let desc = cask["desc"] as? String
            let homepage = cask["homepage"] as? String
            let tap = cask["tap"] as? String
            let outdated = cask["outdated"] as? Bool ?? false
            let autoUpdates = cask["auto_updates"] as? Bool ?? false

            // Installed path and size
            var installedPath: String? = nil
            var installedSize: Int64? = nil
            if let artifacts = cask["artifacts"] as? [[String: Any]] {
                for artifact in artifacts {
                    if let appArr = artifact["app"] as? [String], let appName = appArr.first {
                        installedPath = "/Applications/\(appName)"
                        if let size = directorySize(at: "/Applications/\(appName)") {
                            installedSize = size
                        }
                        break
                    }
                }
            }

            // Latest version
            let latestVersion = (cask["version"] as? String)

            return HomebrewCask(
                name: token,
                version: version,
                description: desc,
                homepage: homepage,
                tap: tap,
                outdated: outdated,
                latestVersion: latestVersion,
                installedPath: installedPath,
                autoUpdates: autoUpdates,
                installedSize: installedSize
            )
        }
    }

    func saveCasksToCache(_ casks: [HomebrewCask]) {
        if let data = try? JSONEncoder().encode(casks) {
            UserDefaults.standard.set(data, forKey: casksCacheKey)
            UserDefaults.standard.set(Date(), forKey: casksUpdateKey)
        }
    }

    @discardableResult
    func loadCasksFromCache() -> ([HomebrewCask], Date?)? {
        guard let data = UserDefaults.standard.data(forKey: casksCacheKey),
              let cks = try? JSONDecoder().decode([HomebrewCask].self, from: data) else { return nil }
        let update = UserDefaults.standard.object(forKey: casksUpdateKey) as? Date
        Task { @MainActor in self.casks = cks }
        return (cks, update)
    }

    // MARK: - Services

    @MainActor
    func refreshServices() async throws {
        do {
            let output = try await executeBrewCommand("services list")
            services = parseServicesOutput(output)
            saveServicesToCache(services)
        } catch {
            logger.error("refreshServices failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func parseServicesOutput(_ output: String) -> [HomebrewService] {
        output.components(separatedBy: .newlines)
            .dropFirst()
            .filter { !$0.isEmpty }
            .compactMap { line -> HomebrewService? in
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard parts.count >= 2 else { return nil }
                let name = parts[0]
                let status = ServiceStatus(rawValue: parts[1]) ?? .unknown
                let user = parts.count > 2 ? parts[2] : nil
                let filePath = parts.count > 3 ? parts[3] : nil
                // pid is sometimes in column index 4 in newer brew versions
                let pidStr = parts.count > 4 ? parts[4] : nil
                let pid = pidStr.flatMap { Int($0) }
                return HomebrewService(name: name, status: status, user: user, filePath: filePath, pid: pid)
            }
    }

    func saveServicesToCache(_ services: [HomebrewService]) {
        if let data = try? JSONEncoder().encode(services) {
            UserDefaults.standard.set(data, forKey: "cachedServices")
            UserDefaults.standard.set(Date(), forKey: "cachedServicesUpdate")
        }
    }

    @discardableResult
    func loadServicesFromCache() -> ([HomebrewService], Date?)? {
        guard let data = UserDefaults.standard.data(forKey: "cachedServices"),
              let svcs = try? JSONDecoder().decode([HomebrewService].self, from: data) else { return nil }
        let update = UserDefaults.standard.object(forKey: "cachedServicesUpdate") as? Date
        Task { @MainActor in self.services = svcs }
        return (svcs, update)
    }

    @MainActor
    func startService(_ service: HomebrewService) async throws {
        try await runServiceCommand("start", for: service)
        try await refreshServices()
    }

    @MainActor
    func stopService(_ service: HomebrewService) async throws {
        try await runServiceCommand("stop", for: service)
        try await refreshServices()
    }

    @MainActor
    func restartService(_ service: HomebrewService) async throws {
        try await runServiceCommand("restart", for: service)
        try await refreshServices()
    }

    private func runServiceCommand(_ command: String, for service: HomebrewService) async throws {
        guard let brewPath = homebrewPath else {
            throw HomebrewError.invalidState("Homebrew path not found")
        }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["services", command, service.name]
        process.standardOutput = pipe
        process.standardError = pipe
        process.environment = brewEnvironment()
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "HomebrewManager", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    // MARK: - Taps

    @MainActor
    func refreshTaps() async throws {
        isLoadingTaps = true
        defer { isLoadingTaps = false }
        do {
            let output = try await executeBrewCommand("tap")
            let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            var newTaps: [HomebrewTap] = []
            var newTapInfos: [String: TapInfo] = [:]

            for line in lines {
                let parts = line.components(separatedBy: "/")
                guard parts.count == 2 else { continue }
                let tapName = line.trimmingCharacters(in: .whitespaces)
                let url = "https://github.com/\(parts[0])/homebrew-\(parts[1])"
                newTaps.append(HomebrewTap(name: tapName, url: url, installed: true))

                if let infoOutput = try? await executeBrewCommand("tap-info \(tapName)") {
                    let parsed = parseTapInfo(infoOutput)
                    newTapInfos[tapName] = TapInfo(
                        name: tapName, url: url, installed: true, info: infoOutput,
                        status: parsed.status, commands: parsed.commands, casks: parsed.casks,
                        path: parsed.path, head: parsed.head, lastCommit: parsed.lastCommit,
                        repoURL: parsed.repoURL, branch: parsed.branch,
                        filesPath: parsed.filesPath, filesCount: parsed.filesCount, filesSize: parsed.filesSize
                    )
                } else {
                    newTapInfos[tapName] = TapInfo(
                        name: tapName, url: url, installed: true, info: "",
                        status: nil, commands: nil, casks: nil, path: nil, head: nil,
                        lastCommit: nil, repoURL: nil, branch: nil,
                        filesPath: nil, filesCount: nil, filesSize: nil
                    )
                }
            }
            taps = newTaps
            tapInfos = newTapInfos
            saveTapInfosToCache(newTapInfos)
        } catch {
            logger.error("refreshTaps failed: \(error.localizedDescription)")
            throw error
        }
    }

    func parseTapInfo(_ output: String) -> (status: String?, commands: String?, casks: String?, path: String?, head: String?, lastCommit: String?, repoURL: String?, branch: String?, filesPath: String?, filesCount: Int?, filesSize: String?) {
        var status: String? = nil
        var commands: String? = nil
        var casks: String? = nil
        var path: String? = nil
        var head: String? = nil
        var lastCommit: String? = nil
        var repoURL: String? = nil
        var branch: String? = nil
        var filesPath: String? = nil
        var filesCount: Int? = nil
        var filesSize: String? = nil

        for line in output.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.contains(": Installed") { status = "Installed" }
            else if t.hasSuffix("formulae") || t.hasSuffix("formula") { commands = t }
            else if t.hasSuffix("casks") || t.hasSuffix("cask") { casks = t }
            else if t.hasPrefix("/") {
                let comps = t.components(separatedBy: " (")
                if comps.count == 2 {
                    path = comps[0]
                    filesPath = comps[0]
                    let info = comps[1].replacingOccurrences(of: ")", with: "")
                    let parts = info.components(separatedBy: ", ")
                    if parts.count == 2 {
                        filesCount = Int(parts[0].components(separatedBy: " ").first ?? "")
                        filesSize = parts[1]
                    }
                }
            }
            else if t.hasPrefix("From:") { repoURL = t.replacingOccurrences(of: "From:", with: "").trimmingCharacters(in: .whitespaces) }
            else if t.hasPrefix("HEAD:") { head = t.replacingOccurrences(of: "HEAD:", with: "").trimmingCharacters(in: .whitespaces) }
            else if t.hasPrefix("last commit:") { lastCommit = t.replacingOccurrences(of: "last commit:", with: "").trimmingCharacters(in: .whitespaces) }
            else if t.hasPrefix("branch:") { branch = t.replacingOccurrences(of: "branch:", with: "").trimmingCharacters(in: .whitespaces) }
        }
        return (status, commands, casks, path, head, lastCommit, repoURL, branch, filesPath, filesCount, filesSize)
    }

    func saveTapInfosToCache(_ infos: [String: TapInfo]) {
        if let data = try? JSONEncoder().encode(infos) {
            UserDefaults.standard.set(data, forKey: "cachedTapInfos")
        }
    }

    func loadTapInfosFromCache() -> [String: TapInfo] {
        guard let data = UserDefaults.standard.data(forKey: "cachedTapInfos"),
              let infos = try? JSONDecoder().decode([String: TapInfo].self, from: data) else { return [:] }
        return infos
    }

    func loadTapsFromCache() -> ([HomebrewTap], Date?)? {
        guard let data = UserDefaults.standard.data(forKey: "cachedTaps"),
              let loaded = try? JSONDecoder().decode([HomebrewTap].self, from: data) else { return nil }
        let update = UserDefaults.standard.object(forKey: "cachedTapsUpdate") as? Date
        Task { @MainActor in
            self.taps = loaded
            self.tapInfos = loadTapInfosFromCache()
        }
        return (loaded, update)
    }

    func saveTapsToCache(_ taps: [HomebrewTap], lastUpdate: Date?) {
        if let data = try? JSONEncoder().encode(taps) {
            UserDefaults.standard.set(data, forKey: "cachedTaps")
        }
        if let date = lastUpdate {
            UserDefaults.standard.set(date, forKey: "cachedTapsUpdate")
        }
    }

    func addTap(_ tap: HomebrewTap) async throws {
        let cmd = tap.url.isEmpty ? "tap \(tap.name)" : "tap \(tap.name) \(tap.url)"
        try await executeBrewCommand(cmd)
        try await refreshTaps()
    }

    func removeTap(_ tap: HomebrewTap) async throws {
        try await executeBrewCommand("untap \(tap.name)")
        try await refreshTaps()
    }

    // MARK: - Cleanup

    /// Returns items that would be removed by `brew cleanup`
    func fetchCleanupPreview() async throws -> [CleanupItem] {
        let output = try await executeBrewCommandWithArgs(["cleanup", "--dry-run"])
        return parseCleanupOutput(output)
    }

    func runCleanup() async throws -> String {
        try await executeBrewCommand("cleanup")
    }

    private func parseCleanupOutput(_ output: String) -> [CleanupItem] {
        output.components(separatedBy: .newlines)
            .filter { $0.hasPrefix("Would remove:") || $0.hasPrefix("Removing:") }
            .compactMap { line -> CleanupItem? in
                let path = line
                    .replacingOccurrences(of: "Would remove: ", with: "")
                    .replacingOccurrences(of: "Removing: ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                guard !path.isEmpty else { return nil }
                let url = URL(fileURLWithPath: path)
                let version = url.lastPathComponent
                let name = url.deletingLastPathComponent().lastPathComponent
                let size = directorySize(at: path)
                return CleanupItem(name: name, version: version, path: path, size: size)
            }
    }

    // MARK: - Autoremove

    func fetchAutoremovePreview() async throws -> [String] {
        let output = try await executeBrewCommandWithArgs(["autoremove", "--dry-run"])
        return output.components(separatedBy: .newlines)
            .filter { $0.contains("Would uninstall") || $0.contains("autoremove") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func runAutoremove() async throws -> String {
        try await executeBrewCommand("autoremove")
    }

    // MARK: - Backup / Restore

    func backupConfiguration() async throws -> Data {
        let backup = BackupData(packages: packages, casks: casks, services: services, taps: taps)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    func restoreConfiguration(from data: Data) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupData.self, from: data)
        await MainActor.run {
            packages = backup.packages
            casks = backup.casks
            services = backup.services
            taps = backup.taps
        }
    }

    // MARK: - Helpers

    private func directorySize(at path: String) -> Int64? {
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total > 0 ? total : nil
    }
}

// MARK: - Errors

enum HomebrewError: LocalizedError {
    case installationFailed(String)
    case commandFailed(String, Int32)
    case parsingFailed(String)
    case invalidState(String)

    var errorDescription: String? {
        switch self {
        case .installationFailed(let m): return "Installation failed: \(m)"
        case .commandFailed(let cmd, let code): return "Command '\(cmd)' failed with exit code \(code)"
        case .parsingFailed(let m): return "Parsing failed: \(m)"
        case .invalidState(let m): return "Invalid state: \(m)"
        }
    }
}
