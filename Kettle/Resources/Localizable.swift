import Foundation

enum L10n {
    enum Common {
        static let ok = AppSettings.localizedString(forKey: "OK", comment: "OK button")
        static let cancel = AppSettings.localizedString(forKey: "Cancel", comment: "Cancel button")
        static let error = AppSettings.localizedString(forKey: "Error", comment: "Error title")
        static let confirm = AppSettings.localizedString(forKey: "Confirm", comment: "Confirm title")
        static let warning = AppSettings.localizedString(forKey: "Warning", comment: "Warning title")
        static let refresh = AppSettings.localizedString(forKey: "Refresh", comment: "Refresh button")
        static let add = AppSettings.localizedString(forKey: "Add", comment: "Add button")
    }
    
    enum MainMenu {
        static let taps = AppSettings.localizedString(forKey: "menu.taps", comment: "Taps menu item")
        static let packages = AppSettings.localizedString(forKey: "menu.packages", comment: "Packages menu item")
        static let services = AppSettings.localizedString(forKey: "menu.services", comment: "Services menu item")
        static let settings = AppSettings.localizedString(forKey: "menu.settings", comment: "Settings menu item")
        
        static let noTapSelected = AppSettings.localizedString(forKey: "menu.taps.noSelection", comment: "No tap selected message")
        static let noPackageSelected = AppSettings.localizedString(forKey: "menu.packages.noSelection", comment: "No package selected message")
        static let noServiceSelected = AppSettings.localizedString(forKey: "menu.services.noSelection", comment: "No service selected message")
        static let noSettingSelected = AppSettings.localizedString(forKey: "menu.settings.noSelection", comment: "No setting selected message")
    }
    
    enum Settings {
        // Sections
        static let title = AppSettings.localizedString(forKey: "Settings", comment: "Settings title")
        static let preferences = AppSettings.localizedString(forKey: "settings.preferences", comment: "Preferences section")
        static let preferencesDesc = AppSettings.localizedString(forKey: "settings.preferences.desc", comment: "Configure your preferred applications and appearance")
        static let about = AppSettings.localizedString(forKey: "settings.about", comment: "About section")
        static let export = AppSettings.localizedString(forKey: "settings.export", comment: "Export section")
        static let status = AppSettings.localizedString(forKey: "settings.status", comment: "Status section")
        
        // Interface
        static let interface = AppSettings.localizedString(forKey: "Interface", comment: "Interface section")
        static let applications = AppSettings.localizedString(forKey: "Applications", comment: "Applications section")
        static let language = AppSettings.localizedString(forKey: "Language", comment: "Language setting")
        static let appearance = AppSettings.localizedString(forKey: "Appearance", comment: "Appearance setting")
        static let languageChangeNote = AppSettings.localizedString(forKey: "Language changes will take effect after restarting the app.", comment: "Language change note")
        static let defaultFinder = AppSettings.localizedString(forKey: "Default Finder", comment: "Default finder setting")
        static let defaultEditor = AppSettings.localizedString(forKey: "Default Editor", comment: "Default editor setting")
        static let applicationsNote = AppSettings.localizedString(forKey: "These settings will be used when opening files and folders.", comment: "Applications settings note")
        static let systemLanguage = AppSettings.localizedString(forKey: "System Default", comment: "System default language")
        
        // System Info
        static let systemInfo = AppSettings.localizedString(forKey: "settings.systemInfo", comment: "System Information")
        static let systemInfoDesc = AppSettings.localizedString(forKey: "settings.systemInfoDesc", comment: "View system and Homebrew installation details")
        static let cpuModel = AppSettings.localizedString(forKey: "settings.cpuModel", comment: "CPU Model")
        static let homebrewStatus = AppSettings.localizedString(forKey: "settings.homebrewStatus", comment: "Homebrew Status")
        static let installed = AppSettings.localizedString(forKey: "settings.installed", comment: "Installed")
        static let notInstalled = AppSettings.localizedString(forKey: "settings.notInstalled", comment: "Not Installed")
        static let installPath = AppSettings.localizedString(forKey: "settings.installPath", comment: "Installation Path")
        
        // Version Info
        static let version = AppSettings.localizedString(forKey: "Version %@", comment: "Version with placeholder")
        static let developer = AppSettings.localizedString(forKey: "Developer", comment: "Developer label")
        static let contact = AppSettings.localizedString(forKey: "Contact", comment: "Contact label")
        static let repository = AppSettings.localizedString(forKey: "Repository", comment: "Repository label")
        static let openSource = AppSettings.localizedString(forKey: "This is an open source project.", comment: "Open source note")
        static let viewSourceCode = AppSettings.localizedString(forKey: "View Source Code", comment: "View source code button")
        static let checkUpdates = AppSettings.localizedString(forKey: "Check for Updates", comment: "Check updates button")
        static let madeBy = AppSettings.localizedString(forKey: "Made with ❤️ by Geoion", comment: "Made by text")
        
        // Export
        static let tapList = AppSettings.localizedString(forKey: "settings.tapList", comment: "Tap list title")
        static let exportDesc = AppSettings.localizedString(forKey: "settings.exportDesc", comment: "Export description")
        static let exportTaps = AppSettings.localizedString(forKey: "settings.exportTaps", comment: "Export taps button")
        static let exportNote = AppSettings.localizedString(forKey: "settings.exportNote", comment: "Export note")
    }
    
    enum Services {
        static let title = AppSettings.localizedString(forKey: "Services", comment: "Services title")
        static let noSelection = AppSettings.localizedString(forKey: "Please select a service", comment: "No service selected")
        static let status = AppSettings.localizedString(forKey: "Status", comment: "Service status")
        static let name = AppSettings.localizedString(forKey: "Name", comment: "Service name")
        static let user = AppSettings.localizedString(forKey: "User", comment: "Service user")
        static let filePath = AppSettings.localizedString(forKey: "File Path", comment: "Service file path")
        static let configuration = AppSettings.localizedString(forKey: "Service Configuration", comment: "Service configuration")
        static let startService = AppSettings.localizedString(forKey: "Start Service", comment: "Start service button")
        static let stopService = AppSettings.localizedString(forKey: "Stop Service", comment: "Stop service button")
        static let confirmStart = AppSettings.localizedString(forKey: "Are you sure you want to start %@?", comment: "Confirm start service")
        static let confirmStop = AppSettings.localizedString(forKey: "Are you sure you want to stop %@?", comment: "Confirm stop service")
    }
    
    enum Taps {
        static let title = AppSettings.localizedString(forKey: "Taps", comment: "Taps title")
        static let noSelection = AppSettings.localizedString(forKey: "Please select a tap", comment: "No tap selected")
        static let search = AppSettings.localizedString(forKey: "Search Tap", comment: "Search tap placeholder")
        static let noTaps = AppSettings.localizedString(forKey: "No taps available", comment: "No taps message")
        static let noResults = AppSettings.localizedString(forKey: "No results found", comment: "No search results")
        static let lastUpdated = AppSettings.localizedString(forKey: "Last updated: %@", comment: "Last updated time")
        static let unknown = AppSettings.localizedString(forKey: "Unknown", comment: "Unknown value")
        static let openInFinder = AppSettings.localizedString(forKey: "Open in Finder", comment: "Open in Finder button")
        static let visitRepo = AppSettings.localizedString(forKey: "Visit Repository", comment: "Visit repository button")
        static let removeTap = AppSettings.localizedString(forKey: "Remove Tap", comment: "Remove tap button")
        static let installTap = AppSettings.localizedString(forKey: "Install Tap", comment: "Install tap button")
        static let confirmRemove = AppSettings.localizedString(forKey: "Are you sure you want to remove '%@'?", comment: "Confirm remove tap")
    }
    
    enum Packages {
        static let title = AppSettings.localizedString(forKey: "Packages", comment: "Packages title")
        static let noSelection = AppSettings.localizedString(forKey: "Please select a package", comment: "No package selected")
        static let packageInfo = AppSettings.localizedString(forKey: "Package Information", comment: "Package information")
        static let name = AppSettings.localizedString(forKey: "Name", comment: "Package name")
        static let version = AppSettings.localizedString(forKey: "Version", comment: "Package version")
        static let description = AppSettings.localizedString(forKey: "Description", comment: "Package description")
    }
} 