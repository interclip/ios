//
//  InterclipShortcuts.swift
//  Interclip
//
//  Created by Filip Troníček on 15.06.2024.
//

import Foundation
import AppIntents
import SwiftUI

class InterclipShortcuts: AppShortcutsProvider {
    
    /// The color the system uses to display the App Shortcuts in the Shortcuts app.
    static var shortcutTileColor = ShortcutTileColor.blue

    static var appShortcuts: [AppShortcut] {
        /// `BuyDayPass` allows people to purchase a day pass, as an example of a routine purchase that people may frequently perform.
        AppShortcut(intent: CreateClip(), phrases: [
            "Create an \(.applicationName) clip",
        ],
        shortTitle: "Create a clip",
        systemImageName: "plus")
        AppShortcut(intent: RetrieveClip(), phrases: [
            "Retrieve \(.applicationName) clip",
            "Receive \(.applicationName) clip",
            "Get \(.applicationName) clip",
        ],
        shortTitle: "Receive a clip",
        systemImageName: "square.and.arrow.down")
    }
}
