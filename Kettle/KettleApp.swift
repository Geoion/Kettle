//
//  KettleApp.swift
//  Kettle
//
//  Created by Eski Yin on 2025/4/27.
//

import SwiftUI

@main
struct KettleApp: App {
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .environmentObject(settings)
                .id(settings.languageRefreshId)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .id(settings.languageRefreshId)
        }
    }
}
