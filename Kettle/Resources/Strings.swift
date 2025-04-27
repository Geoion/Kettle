import Foundation

enum Settings {
    static let preferences = NSLocalizedString("settings.preferences", comment: "Preferences")
    static let preferencesDesc = NSLocalizedString("settings.preferences.desc", comment: "Configure your preferred applications and appearance")
    
    // System Info
    static let systemInfo = NSLocalizedString("settings.systemInfo", comment: "System Information")
    static let systemInfoDesc = NSLocalizedString("settings.systemInfoDesc", comment: "View system and Homebrew installation details")
    static let cpuModel = NSLocalizedString("settings.cpuModel", comment: "CPU Model")
    static let homebrewStatus = NSLocalizedString("settings.homebrewStatus", comment: "Homebrew Status")
    static let installed = NSLocalizedString("settings.installed", comment: "Installed")
    static let notInstalled = NSLocalizedString("settings.notInstalled", comment: "Not Installed")
    static let installPath = NSLocalizedString("settings.installPath", comment: "Installation Path")
    static let status = NSLocalizedString("settings.status", comment: "Status")
} 