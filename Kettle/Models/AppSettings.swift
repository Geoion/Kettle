import Foundation
import SwiftUI
import AppKit

// MARK: - Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }

    var effectiveCode: String {
        if self != .system { return rawValue }
        let preferred = Locale.preferredLanguages.first ?? "en"
        let supported = ["zh-Hans", "zh-Hant", "ja", "ko", "en"]
        return supported.first(where: { preferred.hasPrefix($0) }) ?? "en"
    }
}

// MARK: - Appearance

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L("Follow System")
        case .light: return L("Light")
        case .dark: return L("Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

// MARK: - AppSettings

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            reloadBundle()
        }
    }

    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance")
            applyAppearance()
        }
    }

    @Published private(set) var bundle: Bundle = .main
    @Published var languageRefreshId = UUID()

    @AppStorage("preferredFinder") var preferredFinder: String = "Finder"
    @AppStorage("preferredEditor") var preferredEditor: String = "TextEdit"

    private init() {
        let savedLang = UserDefaults.standard.string(forKey: "appLanguage")
            .flatMap { AppLanguage(rawValue: $0) } ?? .system
        let savedAppearance = UserDefaults.standard.string(forKey: "appAppearance")
            .flatMap { AppAppearance(rawValue: $0) } ?? .system

        self.language = savedLang
        self.appearance = savedAppearance

        reloadBundle()
        applyAppearance()
    }

    func applyAppearance() {
        NSApp.appearance = appearance.nsAppearance
    }

    private func reloadBundle() {
        let code = language.effectiveCode
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundle = langBundle
        } else {
            bundle = .main
        }
        languageRefreshId = UUID()
    }

    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    var effectiveColorScheme: ColorScheme? {
        appearance.colorScheme
    }
}

// MARK: - Global L() function (matches FrameworkScanner pattern)

func L(_ key: String) -> String {
    AppSettings.shared.localized(key)
}
