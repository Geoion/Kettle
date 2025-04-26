import Foundation

struct HomebrewTap: Identifiable, Codable {
    let id = UUID()
    let name: String
    let url: String
    let installed: Bool
} 