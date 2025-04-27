import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "System"
    case english = "English"
    case simplifiedChinese = "简体中文"
    case traditionalChinese = "繁體中文"
    case japanese = "日本語"
    case korean = "한국어"
    
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
        case .simplifiedChinese: return Locale(identifier: "zh-Hans")
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
            objectWillChange.send()
            
            // 获取正确的语言标识符
            let languageIdentifier: String
            switch language {
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
            
            // 更新语言设置
            UserDefaults.standard.setValue([languageIdentifier], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            
            // 强制重新加载本地化资源
            if let languageBundlePath = Bundle.main.path(forResource: languageIdentifier, ofType: "lproj"),
               let languageBundle = Bundle(path: languageBundlePath) {
                AppSettings.bundleCache[languageIdentifier] = languageBundle
            }
            
            // 发送通知以刷新所有视图
            NotificationCenter.default.post(name: NSNotification.Name("AppLanguageDidChange"), object: nil)
            
            // 强制更新所有绑定
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    @AppStorage("appAppearance") var appearance: AppAppearance = .system {
        didSet {
            objectWillChange.send()
        }
    }
    
    private init() {}
    
    // 获取当前实际的颜色方案
    var effectiveColorScheme: ColorScheme? {
        if appearance == .system {
            // 获取系统当前的外观模式
            let currentAppearance = NSApp.effectiveAppearance
            if currentAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return .dark
            }
            return .light
        }
        return appearance.colorScheme
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