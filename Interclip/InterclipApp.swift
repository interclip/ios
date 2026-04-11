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
        // URLSession.shared is lazily initialised — first access triggers CFNetwork
        // and dyld to load their dependencies synchronously on the calling thread.
        // Touching it here on a background thread amortises that cost before the
        // user taps anything, preventing a main-thread fence hang on first request.
        Task.detached(priority: .utility) { _ = URLSession.shared }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

