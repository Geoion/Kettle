import Foundation
import SwiftUI
import OSLog
import Combine
import AppKit

struct TapInfo: Codable, Hashable {
    let name: String
    let url: String
    let installed: Bool
    let info: String
    // 结构化字段
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

class HomebrewManager: ObservableObject {
    @Published var isHomebrewInstalled = false
    @Published var packages: [HomebrewPackage] = []
    @Published var casks: [HomebrewCask] = []
    @Published var services: [HomebrewService] = []
    @Published var taps: [HomebrewTap] = []
    @Published var tapInfos: [String: TapInfo] = [:]
    @Published var homebrewPath: String? = nil
    @Published var isLoadingTaps: Bool = false
    @Published var isLoadingServices: Bool = false
    @Published var isLoadingPackages: Bool = false
    @Published var isLoadingCasks: Bool = false
    
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.kettle.app", category: "Homebrew")
    private var cancellables = Set<AnyCancellable>()
    private let cacheDirectory: URL
    private let tapsCacheFile: URL
    private let servicesCacheFile: URL
    private let packagesCacheKey = "cachedPackages"
    private let packagesUpdateKey = "cachedPackagesUpdate"
    private let casksCacheKey = "cachedCasks"
    private let casksUpdateKey = "cachedCasksUpdate"
    
    init() {
        // Cache setup
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupportDir.appendingPathComponent("Kettle")
        tapsCacheFile = cacheDirectory.appendingPathComponent("taps_cache.json")
        servicesCacheFile = cacheDirectory.appendingPathComponent("services_cache.json")

        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating cache directory: \(error)")
        }

        // Find Homebrew path *before* checking installation
        self.homebrewPath = findHomebrewPath()
        checkHomebrewInstallation()

        if isHomebrewInstalled {
             loadTapsFromCache()
             loadServicesFromCache()
             loadPackagesFromCache()
             loadCasksFromCache()
        }
    }
    
    // --- New/Restored Path Finding Logic --- 
    private func findHomebrewPath() -> String? {
        let fileManager = FileManager.default
        let standardPaths = [
            "/opt/homebrew/bin/brew", // Apple Silicon
            "/usr/local/bin/brew"    // Intel
        ]

        for path in standardPaths {
            if fileManager.fileExists(atPath: path) {
                logger.info("Found brew at standard path: \(path)")
                return path
            }
        }

        // Check PATH environment variable
        if let pathVar = ProcessInfo.processInfo.environment["PATH"] {
            let paths = pathVar.components(separatedBy: ":")
            for dir in paths {
                let brewPath = (dir as NSString).appendingPathComponent("brew")
                if fileManager.fileExists(atPath: brewPath) {
                    logger.info("Found brew in PATH: \(brewPath)")
                    return brewPath
                }
            }
        }
        
        logger.warning("Could not find brew executable.")
        return nil // Return nil if not found
    }
    // --- End Path Finding Logic ---

    func checkHomebrewInstallation() {
        // Now homebrewPath should be set (or nil if not found)
        isHomebrewInstalled = fileManager.fileExists(atPath: homebrewPath ?? "")
        logger.info("Homebrew 安装检查结果: \(self.isHomebrewInstalled ? "已安装，路径：" + (self.homebrewPath ?? "未知") : "未安装")")
    }

    // Add public method to get installation path (modified)
     func getInstallationPath() -> String {
         return homebrewPath ?? NSLocalizedString("path.notAvailable", comment: "Path not available placeholder")
     }
    
    func installHomebrew() async throws {
        logger.info("Starting Homebrew installation")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                logger.info("Homebrew installation completed successfully")
                await MainActor.run {
                    isHomebrewInstalled = true
                }
            } else {
                logger.error("Homebrew installation failed with exit code \(process.terminationStatus)")
                throw HomebrewError.installationFailed("Exit code: \(process.terminationStatus)")
            }
        } catch {
            logger.error("Homebrew installation failed: \(error.localizedDescription)")
            throw HomebrewError.installationFailed(error.localizedDescription)
        }
    }
    
    func executeBrewCommand(_ command: String) async throws -> String {
        // Use the found path
        guard let currentBrewPath = self.homebrewPath else {
            logger.error("Homebrew path is not set, cannot execute command.")
            throw HomebrewError.invalidState("Homebrew path not found")
        }
        print("尝试执行命令: \(currentBrewPath) \(command)") // Log the actual path used
        guard isHomebrewInstalled else {
            logger.error("尝试在未安装 Homebrew 的情况下执行命令")
            throw HomebrewError.invalidState("Homebrew 未安装")
        }
        logger.debug("执行命令: brew \(command)")
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: currentBrewPath) // Use found path
        process.arguments = command.components(separatedBy: " ")
        process.standardOutput = pipe
        process.standardError = pipe
        
        // 设置环境变量
        var env = ProcessInfo.processInfo.environment
        if var path = env["PATH"] {
            // 确保 /opt/homebrew/bin 和 /usr/local/bin 在 PATH 中
            if !path.contains("/opt/homebrew/bin") {
                path = "/opt/homebrew/bin:" + path
            }
            if !path.contains("/usr/local/bin") {
                path = "/usr/local/bin:" + path
            }
            env["PATH"] = path
        } else {
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        }
        process.environment = env
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if process.terminationStatus != 0 {
                logger.error("命令执行失败: brew \(command) (退出码: \(process.terminationStatus))")
                logger.error("输出: \(output)")
                throw HomebrewError.commandFailed(command, process.terminationStatus)
            }
            logger.debug("命令输出: \(output)")
            return output
        } catch {
            logger.error("命令执行失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    func executeSudoCommand(_ command: String, _ args: [String]) async throws -> String {
        print("尝试执行 sudo 命令: \(command) \(args.joined(separator: " "))")
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        var arguments = ["-n"] // -n 表示不提示输入密码，如果需要密码则直接返回错误
        arguments.append(command)
        arguments.append(contentsOf: args)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus != 0 {
                print("sudo 命令执行失败: \(output)")
                throw NSError(domain: "HomebrewManager",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: "需要管理员权限: \(output)"])
            }
            return output
        } catch {
            print("sudo 命令执行错误: \(error)")
            throw error
        }
    }
    
    @MainActor
    func refreshPackages() async throws {
        logger.info("Refreshing packages list using 'brew list --formula'")
        isLoadingPackages = true
        do {
            let output = try await executeBrewCommand("list --formula")
            let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            // Create basic package objects - details would require `brew info` per package (slow)
            self.packages = lines.map { name in 
                HomebrewPackage(name: name, version: "", installed: true, dependencies: [], description: nil)
            }
            savePackagesToCache(self.packages)
            logger.info("Successfully refreshed \(self.packages.count) packages (names only)")
        } catch {
            logger.error("Failed to refresh packages: \(error.localizedDescription)")
            // Don't clear existing packages on failure, maybe show error in UI
            throw error
        }
        isLoadingPackages = false
    }
    
    func savePackagesToCache(_ packages: [HomebrewPackage]) {
        if let data = try? JSONEncoder().encode(packages) {
            UserDefaults.standard.set(data, forKey: packagesCacheKey)
            UserDefaults.standard.set(Date(), forKey: packagesUpdateKey)
        } else {
             logger.error("Failed to encode packages for caching.")
        }
    }
    
    func loadPackagesFromCache() -> ([HomebrewPackage], Date?)? {
        guard let data = UserDefaults.standard.data(forKey: packagesCacheKey),
              let pkgs = try? JSONDecoder().decode([HomebrewPackage].self, from: data) else { 
            logger.info("No package cache found or failed to decode.")
            return nil 
        }
        let update = UserDefaults.standard.object(forKey: packagesUpdateKey) as? Date
        logger.info("Loaded \(pkgs.count) packages from cache.")
        // Update published property on load
        Task { @MainActor in 
            self.packages = pkgs
        }
        return (pkgs, update)
    }
    
    @MainActor
    func refreshServices() async throws {
        logger.info("Refreshing services list")
        do {
            let output = try await executeBrewCommand("services list")
            self.services = parseServicesOutput(output)
            saveServicesToCache(self.services)
            logger.info("Successfully refreshed \(self.services.count) services")
        } catch {
            logger.error("Failed to refresh services: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func parseServicesOutput(_ output: String) -> [HomebrewService] {
        var services: [HomebrewService] = []
        let lines = output.components(separatedBy: .newlines)
        
        // Skip header line and empty lines
        for line in lines.dropFirst() where !line.isEmpty {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 2 else { continue }
            
            let name = components[0]
            let status = ServiceStatus(rawValue: components[1]) ?? .unknown
            let user = components.count > 2 ? components[2] : nil
            let filePath = components.count > 3 ? components[3] : nil
            
            services.append(HomebrewService(name: name, status: status, user: user, filePath: filePath))
        }
        
        return services
    }
    
    func saveServicesToCache(_ services: [HomebrewService]) {
        if let data = try? JSONEncoder().encode(services) {
            UserDefaults.standard.set(data, forKey: "cachedServices")
            UserDefaults.standard.set(Date(), forKey: "cachedServicesUpdate")
        }
    }
    
    func loadServicesFromCache() -> ([HomebrewService], Date?)? {
        guard let data = UserDefaults.standard.data(forKey: "cachedServices"),
              let services = try? JSONDecoder().decode([HomebrewService].self, from: data) else { return nil }
        let update = UserDefaults.standard.object(forKey: "cachedServicesUpdate") as? Date
        return (services, update)
    }
    
    func refreshTaps() async throws {
        logger.info("Refreshing taps list")
        do {
            let output = try await executeBrewCommand("tap")
            let lines = output.components(separatedBy: .newlines)
            var newTaps: [HomebrewTap] = []
            var newTapInfos: [String: TapInfo] = [:]
            for line in lines where !line.isEmpty {
                let components = line.components(separatedBy: "/")
                guard components.count == 2 else {
                    logger.warning("Skipping invalid tap line: \(line)")
                    continue
                }
                let name = components[0]
                let repo = components[1]
                let tapName = "\(name)/\(repo)"
                let url = "https://github.com/\(name)/homebrew-\(repo)"
                logger.debug("Processing tap: \(tapName)")
                let tap = HomebrewTap(
                    name: tapName,
                    url: url,
                    installed: true
                )
                newTaps.append(tap)
                // 获取 tap-info
                do {
                    let infoOutput = try await executeBrewCommand("tap-info \(tapName)")
                    let parsed = parseTapInfo(infoOutput)
                    let tapInfo = TapInfo(
                        name: tapName,
                        url: url,
                        installed: true,
                        info: infoOutput,
                        status: parsed.status,
                        commands: parsed.commands,
                        casks: parsed.casks,
                        path: parsed.path,
                        head: parsed.head,
                        lastCommit: parsed.lastCommit,
                        repoURL: parsed.repoURL,
                        branch: parsed.branch,
                        filesPath: parsed.filesPath,
                        filesCount: parsed.filesCount,
                        filesSize: parsed.filesSize
                    )
                    newTapInfos[tapName] = tapInfo
                } catch {
                    logger.error("Failed to get tap-info for \(tapName): \(error.localizedDescription)")
                }
            }
            await MainActor.run {
                self.taps = newTaps
                self.tapInfos = newTapInfos
            }
            saveTapInfosToCache(newTapInfos)
            logger.info("Successfully refreshed \(self.taps.count) taps and tapInfos")
        } catch {
            logger.error("Failed to refresh taps: \(error.localizedDescription)")
            throw error
        }
    }
    
    // 解析 tap-info 输出
    func parseTapInfo(_ output: String) -> (status: String?, commands: String?, casks: String?, path: String?, head: String?, lastCommit: String?, repoURL: String?, branch: String?, filesPath: String?, filesCount: Int?, filesSize: String?) {
        let lines = output.components(separatedBy: .newlines)
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
        
        for line in lines {
            if line.contains(": Installed") || line.contains(": Not installed") {
                status = line
            } else if line.contains("commands") || line.contains("casks") {
                let parts = line.components(separatedBy: ",")
                if parts.count == 2 {
                    commands = parts[0].trimmingCharacters(in: .whitespaces)
                    casks = parts[1].trimmingCharacters(in: .whitespaces)
                }
            } else if line.hasPrefix("/") {
                // 解析路径行，格式如：/opt/homebrew/Library/Taps/xcodesorg/homebrew-made (27 files, 15.9KB)
                if let pathEndIndex = line.firstIndex(of: "(") {
                    let pathPart = line[..<pathEndIndex].trimmingCharacters(in: .whitespaces)
                    filesPath = String(pathPart)
                    
                    // 解析括号内的文件信息
                    let infoStart = line.index(after: pathEndIndex)
                    if let infoEnd = line.lastIndex(of: ")"),
                       infoEnd > infoStart {
                        let infoString = line[infoStart..<infoEnd]
                        let infoParts = infoString.components(separatedBy: ",")
                        
                        if infoParts.count == 2 {
                            // 解析文件数量
                            let filesString = infoParts[0].trimmingCharacters(in: .whitespaces)
                            if let count = Int(filesString.components(separatedBy: " ")[0]) {
                                filesCount = count
                            }
                            
                            // 解析文件大小
                            filesSize = infoParts[1].trimmingCharacters(in: .whitespaces)
                        }
                    }
                } else {
                    // 如果没有括号，就把整行当作路径
                    filesPath = line
                }
            } else if line.hasPrefix("From: ") {
                repoURL = line.replacingOccurrences(of: "From: ", with: "")
            } else if line.hasPrefix("HEAD: ") {
                head = line.replacingOccurrences(of: "HEAD: ", with: "")
            } else if line.hasPrefix("last commit: ") {
                lastCommit = line.replacingOccurrences(of: "last commit: ", with: "")
            } else if line.contains("branch: ") {
                branch = line.replacingOccurrences(of: "branch: ", with: "").trimmingCharacters(in: .whitespaces)
            }
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
    
    func updatePackage(_ package: HomebrewPackage) async throws {
        logger.info("Updating package: \(package.name)")
        do {
            try await executeBrewCommand("upgrade \(package.name)")
            try await refreshPackages()
            logger.info("Successfully updated package: \(package.name)")
        } catch {
            logger.error("Failed to update package \(package.name): \(error.localizedDescription)")
            throw error
        }
    }
    
    func installPackage(_ package: HomebrewPackage) async throws {
        logger.info("Installing package: \(package.name)")
        do {
            try await executeBrewCommand("install \(package.name)")
            try await refreshPackages()
            logger.info("Successfully installed package: \(package.name)")
        } catch {
            logger.error("Failed to install package \(package.name): \(error.localizedDescription)")
            throw error
        }
    }
    
    func uninstallPackage(_ package: HomebrewPackage) async throws {
        logger.info("Uninstalling package: \(package.name)")
        do {
            try await executeBrewCommand("uninstall \(package.name)")
            try await refreshPackages()
            logger.info("Successfully uninstalled package: \(package.name)")
        } catch {
            logger.error("Failed to uninstall package \(package.name): \(error.localizedDescription)")
            throw error
        }
    }
    
    func addTap(_ tap: HomebrewTap) async throws {
        logger.info("Adding tap: \(tap.name)")
        do {
            try await executeBrewCommand("tap \(tap.name) \(tap.url)")
            try await refreshTaps()
            logger.info("Successfully added tap: \(tap.name)")
        } catch {
            logger.error("Failed to add tap \(tap.name): \(error.localizedDescription)")
            throw error
        }
    }
    
    func removeTap(_ tap: HomebrewTap) async throws {
        logger.info("Removing tap: \(tap.name)")
        do {
            try await executeBrewCommand("untap \(tap.name)")
            try await refreshTaps()
            logger.info("Successfully removed tap: \(tap.name)")
        } catch {
            logger.error("Failed to remove tap \(tap.name): \(error.localizedDescription)")
            throw error
        }
    }
    
    @MainActor
    func startService(_ service: HomebrewService) async throws {
        print("开始启动服务: \(service.name)")
        try await runServiceCommand("start", for: service)
        try await refreshServices()
        print("服务启动完成: \(service.name)")
    }
    
    @MainActor
    func stopService(_ service: HomebrewService) async throws {
        print("开始停止服务: \(service.name)")
        try await runServiceCommand("stop", for: service)
        try await refreshServices()
        print("服务停止完成: \(service.name)")
    }
    
    private func runServiceCommand(_ command: String, for service: HomebrewService) async throws {
        guard let currentBrewPath = self.homebrewPath else { // Use found path
             logger.error("Homebrew path is not set, cannot run service command.")
             throw HomebrewError.invalidState("Homebrew path not found")
         }
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: currentBrewPath) // Use found path
        process.arguments = ["services", command, service.name]
        process.standardOutput = pipe
        process.standardError = pipe
        
        // 设置环境变量
        var env = ProcessInfo.processInfo.environment
        if var path = env["PATH"] {
            // 确保 /opt/homebrew/bin 和 /usr/local/bin 在 PATH 中
            if !path.contains("/opt/homebrew/bin") {
                path = "/opt/homebrew/bin:" + path
            }
            if !path.contains("/usr/local/bin") {
                path = "/usr/local/bin:" + path
            }
            env["PATH"] = path
        } else {
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        }
        process.environment = env
        
        do {
            print("执行服务命令: brew services \(command) \(service.name)")
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let error = String(data: data, encoding: .utf8) {
                    print("服务命令执行失败: \(error)")
                    throw NSError(domain: "HomebrewManager",
                                code: Int(process.terminationStatus),
                                userInfo: [NSLocalizedDescriptionKey: error])
                }
            }
            print("服务命令执行成功")
        } catch {
            print("服务命令执行错误: \(error)")
            throw error
        }
    }
    
    func backupConfiguration() async throws -> Data {
        logger.info("Creating configuration backup")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let backup = BackupData(
                packages: packages,
                services: services,
                taps: taps
            )
            let data = try encoder.encode(backup)
            logger.info("Successfully created configuration backup")
            return data
        } catch {
            logger.error("Failed to create configuration backup: \(error.localizedDescription)")
            throw error
        }
    }
    
    func restoreConfiguration(from data: Data) async throws {
        logger.info("Restoring configuration from backup")
        do {
            let decoder = JSONDecoder()
            let backup = try decoder.decode(BackupData.self, from: data)
            await MainActor.run {
                packages = backup.packages
                services = backup.services
                taps = backup.taps
            }
            logger.info("Successfully restored configuration from backup")
        } catch {
            logger.error("Failed to restore configuration from backup: \(error.localizedDescription)")
            throw error
        }
    }
    
    func loadTapsFromCache() -> ([HomebrewTap], Date?)? {
        guard let data = UserDefaults.standard.data(forKey: "cachedTaps"),
              let loadedTaps = try? JSONDecoder().decode([HomebrewTap].self, from: data) else { return nil }
        let update = UserDefaults.standard.object(forKey: "cachedTapsUpdate") as? Date
         Task { @MainActor in 
            self.taps = loadedTaps
            self.tapInfos = loadTapInfosFromCache()
         }
        return (loadedTaps, update)
    }

    func saveTapsToCache(_ taps: [HomebrewTap], lastUpdate: Date?) {
        if let data = try? JSONEncoder().encode(taps) {
            UserDefaults.standard.set(data, forKey: "cachedTaps")
        }
        if let date = lastUpdate {
            UserDefaults.standard.set(date, forKey: "cachedTapsUpdate")
        }
    }

    // --- New Streaming Method --- 
    @MainActor // Ensure callbacks updating UI happen on main thread if possible
    func streamBrewCommand(
        _ command: String,
        arguments: [String] = [],
        onOutput: @escaping (String) -> Void, // stdout chunks
        onErrorOutput: @escaping (String) -> Void, // stderr chunks
        onCompletion: @escaping (Int32) -> Void // terminationStatus
    ) {
        guard let currentBrewPath = self.homebrewPath else { // Use found path
            onErrorOutput("Homebrew path not found.\n")
            onCompletion(-1) 
            return
        }
        
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: currentBrewPath) // Use found path
        var allArguments = [command]
        allArguments.append(contentsOf: arguments)
        process.arguments = allArguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        // Make sure handlers are released
        var stdoutHandler: NSObjectProtocol?
        
        stdoutPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if data.isEmpty { // EOF
                // print("STDOUT EOF") // Debug
                // No need to call onCompletion here, terminationHandler handles it
                // stdoutPipe.fileHandleForReading.readabilityHandler = nil
                // if let handler = stdoutHandler { NotificationCenter.default.removeObserver(handler) }
            } else {
                if let output = String(data: data, encoding: .utf8) {
                    // print("STDOUT Chunk: \(output.prefix(50))...") // Debug
                    DispatchQueue.main.async {
                        onOutput(output)
                    }
                }
            }
        }
        
        stderrPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if data.isEmpty { // EOF
                 // print("STDERR EOF") // Debug
                 // stderrPipe.fileHandleForReading.readabilityHandler = nil
                 // if let handler = stderrHandler { NotificationCenter.default.removeObserver(handler) }
            } else {
                if let errorOutput = String(data: data, encoding: .utf8) {
                    // print("STDERR Chunk: \(errorOutput.prefix(50))...") // Debug
                     DispatchQueue.main.async {
                         onErrorOutput(errorOutput)
                     }
                }
            }
        }
        
        process.terminationHandler = { terminatedProcess in
            // Ensure handlers are removed *after* termination
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            if let handler = stdoutHandler { NotificationCenter.default.removeObserver(handler) }
            // print("Process terminated with status: \(terminatedProcess.terminationStatus)") // Debug
            DispatchQueue.main.async {
                 onCompletion(terminatedProcess.terminationStatus)
            }
        }
        
        do {
            try process.run()
            // Add observers for background notifications if needed, though readabilityHandler is usually sufficient
            // stdoutHandler = NotificationCenter.default.addObserver(forName: .NSFileHandleReadCompletion, object: stdoutPipe.fileHandleForReading, queue: nil) { _ in stdoutPipe.fileHandleForReading.readInBackgroundAndNotify() }
            // stderrHandler = NotificationCenter.default.addObserver(forName: .NSFileHandleReadCompletion, object: stderrPipe.fileHandleForReading, queue: nil) { _ in stderrPipe.fileHandleForReading.readInBackgroundAndNotify() }
            // stdoutPipe.fileHandleForReading.readInBackgroundAndNotify()
            // stderrPipe.fileHandleForReading.readInBackgroundAndNotify()

        } catch {
            DispatchQueue.main.async {
                 onErrorOutput("Failed to launch process: \(error.localizedDescription)\n")
                 onCompletion(-1) // Indicate an error
            }
        }
    }
    // --- End New Streaming Method ---

    @MainActor
    func refreshCasks() async throws {
        logger.info("Refreshing casks list using 'brew list --cask'")
        isLoadingCasks = true
        do {
            let output = try await executeBrewCommand("list --cask")
            let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            self.casks = lines.map { HomebrewCask(name: $0) }
            saveCasksToCache(self.casks)
            logger.info("Successfully refreshed \(self.casks.count) casks")
        } catch {
             logger.error("Failed to refresh casks: \(error.localizedDescription)")
             throw error
        }
        isLoadingCasks = false
    }

    func saveCasksToCache(_ casks: [HomebrewCask]) {
        if let data = try? JSONEncoder().encode(casks) {
            UserDefaults.standard.set(data, forKey: casksCacheKey)
            UserDefaults.standard.set(Date(), forKey: casksUpdateKey)
        } else {
             logger.error("Failed to encode casks for caching.")
        }
    }

    func loadCasksFromCache() -> ([HomebrewCask], Date?)? {
         guard let data = UserDefaults.standard.data(forKey: casksCacheKey),
              let cks = try? JSONDecoder().decode([HomebrewCask].self, from: data) else { 
            logger.info("No cask cache found or failed to decode.")
            return nil 
        }
        let update = UserDefaults.standard.object(forKey: casksUpdateKey) as? Date
        logger.info("Loaded \(cks.count) casks from cache.")
         Task { @MainActor in 
            self.casks = cks
        }
        return (cks, update)
    }
}

// 错误类型

enum HomebrewError: LocalizedError {
    case installationFailed(String)
    case commandFailed(String, Int32)
    case parsingFailed(String)
    case invalidState(String)
    
    var errorDescription: String? {
        switch self {
        case .installationFailed(let message):
            return "Homebrew 安装失败: \(message)"
        case .commandFailed(let command, let code):
            return "命令 '\(command)' 执行失败，退出码 \(code)"
        case .parsingFailed(let message):
            return "解析输出失败: \(message)"
        case .invalidState(let message):
            return "无效状态: \(message)"
        }
    }
} 
