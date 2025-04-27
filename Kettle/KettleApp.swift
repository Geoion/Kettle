//
//  KettleApp.swift
//  Kettle
//
//  Created by Eski Yin on 2025/4/27.
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct KettleApp: App {
    @StateObject private var settings = AppSettings.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .environment(\.locale, settings.language.locale)
                .environmentObject(settings)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
