import Foundation

struct HomebrewPackage: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let version: String
    let installed: Bool
    let dependencies: [String]
    let description: String?
} 