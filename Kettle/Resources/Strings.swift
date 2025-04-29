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
    
    // Updates
    static let updateAvailable = NSLocalizedString("settings.update.available", comment: "Update available")
    static let updateNotAvailable = NSLocalizedString("settings.update.notAvailable", comment: "No updates available")
    static let updateError = NSLocalizedString("settings.update.error", comment: "Error checking for updates")
    static let updateChecking = NSLocalizedString("settings.update.checking", comment: "Checking for updates")
    static let updateDownload = NSLocalizedString("settings.update.download", comment: "Download update")
    static let updateViewRelease = NSLocalizedString("settings.update.viewRelease", comment: "View release")
    static let updateClose = NSLocalizedString("settings.update.close", comment: "Close update dialog")
    static let updateWhatsNew = NSLocalizedString("settings.update.whatsNew", comment: "What's new")
    static let updateHeader = NSLocalizedString("settings.update.header", comment: "Update available dialog header")
    static let updateVersionAvailable = NSLocalizedString("settings.update.versionAvailable", comment: "Version is now available")
} 