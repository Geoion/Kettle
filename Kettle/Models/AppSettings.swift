import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "System"
    case english = "en"
    case simplifiedChinese = "zh"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system: return L10n.Settings.systemLanguage
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }
    
    var locale: Locale {
        switch self {
        case .system: return .current
        case .english: return Locale(identifier: "en")
        case .simplifiedChinese: return Locale(identifier: "zh")
        case .traditionalChinese: return Locale(identifier: "zh-Hant")
        case .japanese: return Locale(identifier: "ja")
        case .korean: return Locale(identifier: "ko")
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system: return NSLocalizedString("Follow System", comment: "")
        case .light: return NSLocalizedString("Light", comment: "")
        case .dark: return NSLocalizedString("Dark", comment: "")
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private static var bundleCache: [String: Bundle] = [:]
    
    @AppStorage("appLanguage") var language: AppLanguage = .system {
        didSet {
            updateLanguage()
        }
    }
    
    private func updateLanguage() {
        let languageIdentifier = language.rawValue == "System" 
            ? Locale.current.language.languageCode?.identifier ?? "en"
            : language.rawValue
            
        UserDefaults.standard.setValue([languageIdentifier], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        if let languageBundlePath = Bundle.main.path(forResource: languageIdentifier, ofType: "lproj"),
           let languageBundle = Bundle(path: languageBundlePath) {
            Self.bundleCache[languageIdentifier] = languageBundle
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("AppLanguageDidChange"), object: nil)
    }
    
    @AppStorage("appAppearance") var appearance: AppAppearance = .system
    @AppStorage("analyticsEnabled") var analyticsEnabled: Bool = false
    @AppStorage("firstLaunch") var isFirstLaunch: Bool = true
    @AppStorage("colorScheme") private var colorScheme: Int = 0 // 0: System, 1: Light, 2: Dark
    
    private init() {}
    
    // 获取当前实际的颜色方案
    var effectiveColorScheme: ColorScheme? {
        switch colorScheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
    
    func setColorScheme(_ scheme: Int) {
        colorScheme = scheme
    }
    
    // Analytics related functions
    func enableAnalytics() {
        analyticsEnabled = true
        // 在这里初始化 Google Analytics
        setupAnalytics()
    }
    
    func disableAnalytics() {
        analyticsEnabled = false
        // 在这里停用 Google Analytics
        teardownAnalytics()
    }
    
    private func setupAnalytics() {
        guard analyticsEnabled else { return }
        // TODO: 初始化 Google Analytics SDK
    }
    
    private func teardownAnalytics() {
        // TODO: 清理 Google Analytics 相关资源
    }
    
    // 记录事件的辅助方法
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        guard analyticsEnabled else { return }
        // TODO: 使用 Google Analytics 记录事件
    }
    
    static func localizedString(forKey key: String, comment: String) -> String {
        let languageIdentifier: String
        switch shared.language {
        case .system:
            languageIdentifier = Locale.current.language.languageCode?.identifier ?? "en"
        case .english:
            languageIdentifier = "en"
        case .simplifiedChinese:
            languageIdentifier = "zh-Hans"
        case .traditionalChinese:
            languageIdentifier = "zh-Hant"
        case .japanese:
            languageIdentifier = "ja"
        case .korean:
            languageIdentifier = "ko"
        }
        
        if let bundle = bundleCache[languageIdentifier] {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        
        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}

extension Bundle {
    func reload() {
        guard let bundlePath = Bundle.main.path(forResource: "Main", ofType: "storyboardc"),
              let bundle = Bundle(path: bundlePath) else {
            return
        }
        
        if let languageCode = UserDefaults.standard.string(forKey: "AppleLanguages") {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
}

// 分析事件名称常量
extension AppSettings {
    enum AnalyticsEvent {
        static let appLaunch = "app_launch"
        static let packageInstall = "package_install"
        static let packageUninstall = "package_uninstall"
        static let packageUpdate = "package_update"
        static let serviceStart = "service_start"
        static let serviceStop = "service_stop"
        static let tapAdd = "tap_add"
        static let tapRemove = "tap_remove"
        static let settingsChanged = "settings_changed"
    }
} 