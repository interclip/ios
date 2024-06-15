//
//  InterclipApp.swift
//  Interclip
//
//  Created by Filip Troníček on 12.06.2024.
//

import SwiftUI
import AppIntents

@main
struct InterclipApp: App {
    init() {
        InterclipShortcuts.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

