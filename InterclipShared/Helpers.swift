//
//  Helpers.swift
//  Interclip
//
//  Created by Filip Troníček on 15.06.2024.
//

import SwiftUI

public func triggerHapticFeedback(type: FeedbackType) {
    switch type {
    case .light:
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    case .medium:
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    case .success:
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    case .error:
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}

public enum FeedbackType {
    case light
    case medium
    case success
    case error
}
