import Foundation
import SwiftUI

// MARK: - Models

public struct HomebrewPackage: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let version: String
    public let installed: Bool
    public let dependencies: [String]
    public let description: String?
    
    public init(name: String, version: String, installed: Bool, dependencies: [String], description: String?) {
        self.name = name
        self.version = version
        self.installed = installed
        self.dependencies = dependencies
        self.description = description
    }
}

public struct HomebrewCask: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
}

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

public struct HomebrewService: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let status: ServiceStatus
    public let user: String?
    public let filePath: String?
    
    public init(name: String, status: ServiceStatus, user: String?, filePath: String?) {
        self.name = name
        self.status = status
        self.user = user
        self.filePath = filePath
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
        case .started, .running:
            return "play.circle.fill"
        case .stopped:
            return "stop.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .started, .running:
            return .green
        case .stopped:
            return .secondary
        case .error:
            return .red
        case .unknown:
            return .orange
        }
    }
}

public struct BackupData: Codable {
    public let packages: [HomebrewPackage]
    public let services: [HomebrewService]
    public let taps: [HomebrewTap]
    
    public init(packages: [HomebrewPackage], services: [HomebrewService], taps: [HomebrewTap]) {
        self.packages = packages
        self.services = services
        self.taps = taps
    }
} 