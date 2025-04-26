import Foundation
import SwiftUI
import OSLog

class HomebrewManager: ObservableObject {
    @Published var isHomebrewInstalled = false
    @Published var packages: [HomebrewPackage] = []
    @Published var services: [HomebrewService] = []
    @Published var taps: [HomebrewTap] = []
    
    private let fileManager = FileManager.default
    private let homebrewPath: String = {
        let possiblePaths = [
            "/opt/homebrew/bin/brew",    // Apple Silicon
            "/usr/local/bin/brew"        // Intel
        ]
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "/opt/homebrew/bin/brew" // 默认
    }()
    private let logger = Logger(subsystem: "com.kettle.app", category: "Homebrew")
    
    init() {
        checkHomebrewInstallation()
    }
    
    func checkHomebrewInstallation() {
        print("Checking Homebrew at path: \(homebrewPath)")
        isHomebrewInstalled = fileManager.fileExists(atPath: homebrewPath)
        logger.info("Homebrew installation check: \(self.isHomebrewInstalled ? "installed" : "not installed")")
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
        print("Trying to execute: \(homebrewPath) \(command)")
        guard isHomebrewInstalled else {
            logger.error("Attempted to execute command without Homebrew installed")
            throw HomebrewError.invalidState("Homebrew is not installed")
        }
        logger.debug("Executing command: brew \(command)")
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: homebrewPath)
        process.arguments = command.components(separatedBy: " ")
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if process.terminationStatus != 0 {
                logger.error("Command failed: brew \(command) (exit code: \(process.terminationStatus))")
                logger.error("Output: \(output)")
                throw HomebrewError.commandFailed(command, process.terminationStatus)
            }
            logger.debug("Command output: \(output)")
            return output
        } catch {
            logger.error("Command execution failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func refreshPackages() async throws {
        logger.info("Refreshing packages list")
        do {
            let output = try await executeBrewCommand("list --versions")
            let lines = output.components(separatedBy: .newlines)
            var newPackages: [HomebrewPackage] = []
            for line in lines where !line.isEmpty {
                let components = line.components(separatedBy: " ")
                guard components.count >= 2 else {
                    logger.error("Skipping invalid package line: \(line)")
                    continue
                }
                let name = components[0]
                let version = components[1]
                logger.debug("Processing package: \(name) (\(version))")
                do {
                    let infoOutput = try await executeBrewCommand("info \(name)")
                    let infoLines = infoOutput.components(separatedBy: .newlines)
                    var description: String?
                    var dependencies: [String] = []
                    for infoLine in infoLines {
                        if infoLine.hasPrefix("==> Description:") {
                            description = infoLine.replacingOccurrences(of: "==> Description:", with: "").trimmingCharacters(in: .whitespaces)
                        } else if infoLine.hasPrefix("==> Dependencies") {
                            let deps = infoLine.replacingOccurrences(of: "==> Dependencies:", with: "").trimmingCharacters(in: .whitespaces)
                            dependencies = deps.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
                        }
                    }
                    let package = HomebrewPackage(
                        name: name,
                        version: version,
                        installed: true,
                        dependencies: dependencies,
                        description: description
                    )
                    newPackages.append(package)
                } catch {
                    logger.error("Failed to get info for package \(name): \(error.localizedDescription)")
                    throw HomebrewError.parsingFailed("Failed to parse package info for \(name)")
                }
            }
            await MainActor.run {
                self.packages = newPackages
            }
            logger.info("Successfully refreshed \(self.packages.count) packages")
        } catch {
            logger.error("Failed to refresh packages: \(error.localizedDescription)")
            throw error
        }
    }
    
    func refreshServices() async throws {
        logger.info("Refreshing services list")
        do {
            let output = try await executeBrewCommand("services list")
            let lines = output.components(separatedBy: .newlines)
            var newServices: [HomebrewService] = []
            for line in lines where !line.isEmpty {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard components.count >= 2 else {
                    logger.error("Skipping invalid service line: \(line)")
                    continue
                }
                let name = components[0]
                let statusString = components[1].lowercased()
                logger.debug("Processing service: \(name) (\(statusString))")
                let status: HomebrewService.ServiceStatus
                switch statusString {
                case "started", "running":
                    status = .running
                case "stopped":
                    status = .stopped
                case "error":
                    status = .error
                default:
                    status = .unknown
                }
                do {
                    let configOutput = try await executeBrewCommand("services info \(name)")
                    var configuration: [String: String] = [:]
                    let configLines = configOutput.components(separatedBy: .newlines)
                    for configLine in configLines {
                        if configLine.contains(":") {
                            let parts = configLine.components(separatedBy: ":")
                            if parts.count == 2 {
                                let key = parts[0].trimmingCharacters(in: .whitespaces)
                                let value = parts[1].trimmingCharacters(in: .whitespaces)
                                configuration[key] = value
                            }
                        }
                    }
                    let service = HomebrewService(
                        name: name,
                        status: status,
                        configuration: configuration
                    )
                    newServices.append(service)
                } catch {
                    logger.error("Failed to get info for service \(name): \(error.localizedDescription)")
                    throw HomebrewError.parsingFailed("Failed to parse service info for \(name)")
                }
            }
            await MainActor.run {
                self.services = newServices
            }
            logger.info("Successfully refreshed \(self.services.count) services")
        } catch {
            logger.error("Failed to refresh services: \(error.localizedDescription)")
            throw error
        }
    }
    
    func refreshTaps() async throws {
        logger.info("Refreshing taps list")
        do {
            let output = try await executeBrewCommand("tap")
            let lines = output.components(separatedBy: .newlines)
            var newTaps: [HomebrewTap] = []
            for line in lines where !line.isEmpty {
                let components = line.components(separatedBy: "/")
                guard components.count == 2 else {
                    logger.error("Skipping invalid tap line: \(line)")
                    continue
                }
                let name = components[0]
                let repo = components[1]
                let url = "https://github.com/\(name)/homebrew-\(repo)"
                logger.debug("Processing tap: \(name)/\(repo)")
                let tap = HomebrewTap(
                    name: "\(name)/\(repo)",
                    url: url,
                    installed: true
                )
                newTaps.append(tap)
            }
            await MainActor.run {
                self.taps = newTaps
            }
            logger.info("Successfully refreshed \(self.taps.count) taps")
        } catch {
            logger.error("Failed to refresh taps: \(error.localizedDescription)")
            throw error
        }
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
    
    func startService(_ service: HomebrewService) async throws {
        logger.info("Starting service: \(service.name)")
        do {
            try await executeBrewCommand("services start \(service.name)")
            try await refreshServices()
            logger.info("Successfully started service: \(service.name)")
        } catch {
            logger.error("Failed to start service \(service.name): \(error.localizedDescription)")
            throw error
        }
    }
    
    func stopService(_ service: HomebrewService) async throws {
        logger.info("Stopping service: \(service.name)")
        do {
            try await executeBrewCommand("services stop \(service.name)")
            try await refreshServices()
            logger.info("Successfully stopped service: \(service.name)")
        } catch {
            logger.error("Failed to stop service \(service.name): \(error.localizedDescription)")
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
            return "Homebrew installation failed: \(message)"
        case .commandFailed(let command, let code):
            return "Command '\(command)' failed with exit code \(code)"
        case .parsingFailed(let message):
            return "Failed to parse output: \(message)"
        case .invalidState(let message):
            return "Invalid state: \(message)"
        }
    }
} 
