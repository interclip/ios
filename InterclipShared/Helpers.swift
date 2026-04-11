//
//  Helpers.swift
//  Interclip
//
//  Created by Filip Troníček on 15.06.2024.
//

import SwiftUI
import Foundation
import CoreImage.CIFilterBuiltins

public func triggerHapticFeedback(type: FeedbackType) {
    switch type {
    case .light:
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    case .medium:
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    case .success:
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    case .error:
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}

public enum FeedbackType {
    case light
    case medium
    case success
    case error
}

public struct QrCodeImage {
    public static let shared = QrCodeImage()

    public let context = CIContext()

    public init() {}

    public func generateQRCode(from text: String, isDark: Bool) -> UIImage {
        let data   = Data(text.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        guard let outputImage = filter.outputImage?.transformed(by: transform) else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }

        let maskFilter = CIFilter.blendWithMask()
        maskFilter.maskImage = outputImage.applyingFilter("CIColorInvert")

        maskFilter.inputImage = CIImage(color: .white)
        let darkCIImage = maskFilter.outputImage!
        maskFilter.inputImage = CIImage(color: .black)
        let lightCIImage = maskFilter.outputImage!

        guard let darkCGImage  = context.createCGImage(darkCIImage,  from: darkCIImage.extent),
              let lightCGImage = context.createCGImage(lightCIImage, from: lightCIImage.extent) else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }

        return isDark ? UIImage(cgImage: darkCGImage) : UIImage(cgImage: lightCGImage)
    }
}
