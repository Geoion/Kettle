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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
