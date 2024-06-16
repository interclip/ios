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

public struct QrCodeImage {
    public let context = CIContext()
    
    public init() {}

    public func generateQRCode(from text: String) -> UIImage {
        var qrImage = UIImage(systemName: "xmark.circle") ?? UIImage()
        let data    = Data(text.utf8)
        let filter  = CIFilter.qrCodeGenerator()

        // ref : https://stackoverflow.com/questions/57704885/how-can-i-check-ios-devices-current-userinterfacestyle-programmatically
        var osTheme: UIUserInterfaceStyle { return UIScreen.main.traitCollection.userInterfaceStyle }
        filter.setValue(data, forKey: "inputMessage")

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        if let outputImage = filter.outputImage?.transformed(by: transform) {
            if let image = context.createCGImage(
                outputImage,
                from: outputImage.extent) {

                let maskFilter = CIFilter.blendWithMask()
                maskFilter.maskImage = outputImage.applyingFilter("CIColorInvert")

                maskFilter.inputImage = CIImage(color: .white)

                let darkCIImage = maskFilter.outputImage!
                maskFilter.inputImage = CIImage(color: .black)

                let lightCIImage = maskFilter.outputImage!

                let darkImage   = context.createCGImage(darkCIImage, from: darkCIImage.extent).map(UIImage.init)!
                let lightImage  = context.createCGImage(lightCIImage, from: lightCIImage.extent).map(UIImage.init)!

                qrImage = osTheme == .light ? lightImage : darkImage
            }
        }
        
        return qrImage
    }
}
