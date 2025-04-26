import Foundation

struct BackupData: Codable {
    let packages: [HomebrewPackage]
    let services: [HomebrewService]
    let taps: [HomebrewTap]
} 