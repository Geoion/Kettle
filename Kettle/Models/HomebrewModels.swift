import Foundation
import SwiftUI

// MARK: - Package (Formula)

public struct HomebrewPackage: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let version: String
    public let installed: Bool
    public let dependencies: [String]
    public let description: String?
    // Extended fields from brew info --json=v2
    public let homepage: String?
    public let license: String?
    public let tap: String?
    public let outdated: Bool
    public let latestVersion: String?
    public let installedAsDependency: Bool
    public let installDate: Date?
    public let installedSize: Int64?  // bytes

    public init(
        name: String,
        version: String,
        installed: Bool,
        dependencies: [String],
        description: String?,
        homepage: String? = nil,
        license: String? = nil,
        tap: String? = nil,
        outdated: Bool = false,
        latestVersion: String? = nil,
        installedAsDependency: Bool = false,
        installDate: Date? = nil,
        installedSize: Int64? = nil
    ) {
        self.name = name
        self.version = version
        self.installed = installed
        self.dependencies = dependencies
        self.description = description
        self.homepage = homepage
        self.license = license
        self.tap = tap
        self.outdated = outdated
        self.latestVersion = latestVersion
        self.installedAsDependency = installedAsDependency
        self.installDate = installDate
        self.installedSize = installedSize
    }
}

// MARK: - Cask

public struct HomebrewCask: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    // Extended fields from brew info --json=v2 --cask
    public let version: String?
    public let description: String?
    public let homepage: String?
    public let tap: String?
    public let outdated: Bool
    public let latestVersion: String?
    public let installedPath: String?
    public let autoUpdates: Bool
    public let installedSize: Int64?  // bytes

    public init(
        name: String,
        version: String? = nil,
        description: String? = nil,
        homepage: String? = nil,
        tap: String? = nil,
        outdated: Bool = false,
        latestVersion: String? = nil,
        installedPath: String? = nil,
        autoUpdates: Bool = false,
        installedSize: Int64? = nil
    ) {
        self.name = name
        self.version = version
        self.description = description
        self.homepage = homepage
        self.tap = tap
        self.outdated = outdated
        self.latestVersion = latestVersion
        self.installedPath = installedPath
        self.autoUpdates = autoUpdates
        self.installedSize = installedSize
    }
}

// MARK: - Tap

public struct HomebrewTap: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let url: String
    public let installed: Bool

    public init(name: String, url: String, installed: Bool) {
        self.name = name
        self.url = url
        self.installed = installed
    }
}

// MARK: - Service

public struct HomebrewService: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let status: ServiceStatus
    public let user: String?
    public let filePath: String?
    public let pid: Int?

    public init(name: String, status: ServiceStatus, user: String?, filePath: String?, pid: Int? = nil) {
        self.name = name
        self.status = status
        self.user = user
        self.filePath = filePath
        self.pid = pid
    }
}

public enum ServiceStatus: String, Codable {
    case started = "started"
    case running = "running"
    case stopped = "stopped"
    case error = "error"
    case unknown = "unknown"

    public var icon: String {
        switch self {
        case .started, .running: return "play.circle.fill"
        case .stopped: return "stop.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .started, .running: return .green
        case .stopped: return .secondary
        case .error: return .red
        case .unknown: return .orange
        }
    }
}

// MARK: - Outdated Info

public struct OutdatedInfo: Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let installedVersion: String
    public let currentVersion: String
    public let isCask: Bool
}

// MARK: - Cleanup Info

public struct CleanupItem: Identifiable {
    public var id: String { "\(name)-\(version)" }
    public let name: String
    public let version: String
    public let path: String
    public let size: Int64?
}

// MARK: - Backup

public struct BackupData: Codable {
    public let packages: [HomebrewPackage]
    public let casks: [HomebrewCask]
    public let services: [HomebrewService]
    public let taps: [HomebrewTap]
    public let exportDate: Date

    public init(packages: [HomebrewPackage], casks: [HomebrewCask], services: [HomebrewService], taps: [HomebrewTap]) {
        self.packages = packages
        self.casks = casks
        self.services = services
        self.taps = taps
        self.exportDate = Date()
    }
}
