import Foundation

struct HomebrewTap: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let url: String
    let installed: Bool
} 