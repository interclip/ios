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

// MARK: - Logo

public struct InterclipLogo: View {
    private let viewBoxSize: CGFloat = 631

    public init() {}

    public var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / viewBoxSize
            context.concatenate(CGAffineTransform(scaleX: scale, y: scale))

            let strokeStyle = StrokeStyle(lineWidth: 12, lineJoin: .round)
            let white     = GraphicsContext.Shading.color(.white)
            let darkBlue  = GraphicsContext.Shading.color(Color(red: 0x3E/255.0, green: 0x86/255.0, blue: 0xCE/255.0))
            let lightBlue = GraphicsContext.Shading.color(Color(red: 0x85/255.0, green: 0xBB/255.0, blue: 0xFB/255.0))
            let medBlue   = GraphicsContext.Shading.color(Color(red: 0x5D/255.0, green: 0xA5/255.0, blue: 0xFB/255.0))

            // Path 1: right bottom – dark blue
            // M537.95 499L315.95 353.66C315.617 333.56 315.283 313.457 314.95 293.35L537.95 499Z
            var p1 = Path()
            p1.move(to: CGPoint(x: 537.95, y: 499))
            p1.addLine(to: CGPoint(x: 315.95, y: 353.66))
            p1.addCurve(to: CGPoint(x: 314.95, y: 293.35),
                        control1: CGPoint(x: 315.617, y: 333.56),
                        control2: CGPoint(x: 315.283, y: 313.457))
            p1.addLine(to: CGPoint(x: 537.95, y: 499))
            p1.closeSubpath()
            context.fill(p1, with: darkBlue)
            context.stroke(p1, with: white, style: strokeStyle)

            // Path 2: left bottom – dark blue
            // M92.96 499L315.96 353.66L315.9 293.35L92.96 499Z
            var p2 = Path()
            p2.move(to: CGPoint(x: 92.96, y: 499))
            p2.addLine(to: CGPoint(x: 315.96, y: 353.66))
            p2.addLine(to: CGPoint(x: 315.9, y: 293.35))
            p2.addLine(to: CGPoint(x: 92.96, y: 499))
            p2.closeSubpath()
            context.fill(p2, with: darkBlue)
            context.stroke(p2, with: white, style: strokeStyle)

            // Path 3: left inner – light blue
            // M315.5 440.37V262L260.5 312.44C278.86 355.08 297.193 397.723 315.5 440.37Z
            var p3 = Path()
            p3.move(to: CGPoint(x: 315.5, y: 440.37))
            p3.addLine(to: CGPoint(x: 315.5, y: 262))
            p3.addLine(to: CGPoint(x: 260.5, y: 312.44))
            p3.addCurve(to: CGPoint(x: 315.5, y: 440.37),
                        control1: CGPoint(x: 278.86, y: 355.08),
                        control2: CGPoint(x: 297.193, y: 397.723))
            p3.closeSubpath()
            context.fill(p3, with: lightBlue)
            context.stroke(p3, with: white, style: strokeStyle)

            // Path 4: right inner – medium blue
            // M315.5 440.37V262L370.25 312.43L315.5 440.37Z
            var p4 = Path()
            p4.move(to: CGPoint(x: 315.5, y: 440.37))
            p4.addLine(to: CGPoint(x: 315.5, y: 262))
            p4.addLine(to: CGPoint(x: 370.25, y: 312.43))
            p4.addLine(to: CGPoint(x: 315.5, y: 440.37))
            p4.closeSubpath()
            context.fill(p4, with: medBlue)
            context.stroke(p4, with: white, style: strokeStyle)

            // Path 5: right main wing – light blue
            // M315.5 132L538.5 499L315.5 293.35V132Z
            var p5 = Path()
            p5.move(to: CGPoint(x: 315.5, y: 132))
            p5.addLine(to: CGPoint(x: 538.5, y: 499))
            p5.addLine(to: CGPoint(x: 315.5, y: 293.35))
            p5.addLine(to: CGPoint(x: 315.5, y: 132))
            p5.closeSubpath()
            context.fill(p5, with: lightBlue)
            context.stroke(p5, with: white, style: strokeStyle)

            // Path 6: left main wing – medium blue
            // M315.5 132L92.5 499L315.5 293.35V132Z
            var p6 = Path()
            p6.move(to: CGPoint(x: 315.5, y: 132))
            p6.addLine(to: CGPoint(x: 92.5, y: 499))
            p6.addLine(to: CGPoint(x: 315.5, y: 293.35))
            p6.addLine(to: CGPoint(x: 315.5, y: 132))
            p6.closeSubpath()
            context.fill(p6, with: medBlue)
            context.stroke(p6, with: white, style: strokeStyle)
        }
        .aspectRatio(1, contentMode: .fit)
    }
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
