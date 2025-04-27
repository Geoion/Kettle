import SwiftUI

struct HomebrewService: Identifiable, Codable {
    let id: String
    let name: String
    let status: ServiceStatus
    let user: String?
    let filePath: String?
    
    init(name: String, status: ServiceStatus, user: String? = nil, filePath: String? = nil) {
        self.id = name
        self.name = name
        self.status = status
        self.user = user
        self.filePath = filePath
    }
}

enum ServiceStatus: String, Codable {
    case running = "started"
    case stopped = "none"
    case error = "error"
    case unknown = "unknown"
    
    var icon: String {
        switch self {
        case .running:
            return "play.circle.fill"
        case .stopped:
            return "stop.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .running:
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