import Foundation

struct HomebrewService: Identifiable, Codable {
    let id = UUID()
    let name: String
    let status: ServiceStatus
    let configuration: [String: String]
    
    enum ServiceStatus: String, Codable {
        case running
        case stopped
        case error
        case unknown
    }
} 