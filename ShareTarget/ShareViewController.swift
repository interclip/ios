//
//  ShareViewController.swift
//  ShareTarget
//
//  Created by Filip Troníček on 15.06.2024.
//

import UIKit
import Social
import InterclipShared
import CoreImage.CIFilterBuiltins

extension UIImage {
    // Helper function to create a high-resolution image from a CIImage
    func createNonInterpolatedUIImage(from ciImage: CIImage, with scale: CGFloat) -> UIImage? {
        let size = CGSize(width: ciImage.extent.size.width * scale, height: ciImage.extent.size.height * scale)
        UIGraphicsBeginImageContext(size)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent)
        context.interpolationQuality = .none
        context.draw(cgImage!, in: CGRect(origin: .zero, size: size))

        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return scaledImage
    }
}

class ShareViewController: UIViewController {

    private var url: String?
    private var clipCode: String?

    private let urlLabel = UILabel()
    private let clipCodeLabel = UILabel()
    private let qrCodeImageView = UIImageView()
    private let copyButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        setupUI()

        // As soon as the share sheet is presented, try to fetch the URL and create a clip
        if let item = self.extensionContext?.inputItems.first as? NSExtensionItem,
           let attachment = item.attachments?.first {
            if attachment.hasItemConformingToTypeIdentifier("public.url") {
                attachment.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (data, error) in
                    if let url = data as? URL {
                        self?.url = url.absoluteString
                        self?.urlLabel.text = url.absoluteString
                        self?.generateQRCodeAndDisplay(for: url.absoluteString)
                        self?.createClipAndComplete()
                    } else {
                        self?.showError(message: "Failed to retrieve URL")
                    }
                }
            } else {
                showError(message: "No valid URL found")
            }
        } else {
            showError(message: "No input items found")
        }
    }

    // Setup UI components
    private func setupUI() {
        // Create a stack view for vertical layout
        let stackView = UIStackView(arrangedSubviews: [urlLabel, qrCodeImageView, clipCodeLabel, copyButton])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        // URL Label
        urlLabel.textAlignment = .center
        urlLabel.textColor = .black
        urlLabel.numberOfLines = 2

        // QR Code Image View
        qrCodeImageView.contentMode = .scaleAspectFit
        qrCodeImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6).isActive = true
        qrCodeImageView.heightAnchor.constraint(equalTo: qrCodeImageView.widthAnchor).isActive = true

        // Clip Code Label
        clipCodeLabel.textAlignment = .center
        clipCodeLabel.font = UIFont.boldSystemFont(ofSize: 24)
        clipCodeLabel.textColor = .black
        clipCodeLabel.numberOfLines = 1

        // Copy Button
        copyButton.setTitle("Copy Code", for: .normal)
        copyButton.addTarget(self, action: #selector(copyCode), for: .touchUpInside)
        copyButton.isHidden = true
        
        // Activity Indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()

        // Layout constraints for centering the stack view
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // Function to create the clip and handle completion
    private func createClipAndComplete() {
        guard let url = self.url else {
            showError(message: "URL is missing")
            return
        }

        createClip(url: url) { [weak self] result in
            guard let self = self else { return } // Ensure self is not nil

            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
            }

            switch result {
            case .success(let clipCode):
                // Update the UI with the clip code
                DispatchQueue.main.async {
                    self.clipCode = clipCode
                    self.clipCodeLabel.text = clipCode
                    self.copyButton.isHidden = false
                }

            case .failure(let error):
                // Notify user of the error
                self.showError(message: error.localizedDescription)
            }
        }
    }

    // Action for copying the code to the clipboard
    @objc private func copyCode() {
        guard let clipCode = clipCode else { return }
        UIPasteboard.general.string = clipCode

        triggerHapticFeedback(type: .success)
    }

    // Helper function to show error messages
    private func showError(message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                self.extensionContext?.cancelRequest(withError: NSError(domain: "com.interclip", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func generateQRCodeAndDisplay(for urlString: String) {
        let qrGenerator = QrCodeImage()

        let qrImage = qrGenerator.generateQRCode(from: urlString)
        DispatchQueue.main.async {
            self.qrCodeImageView.image = qrImage
        }
    }
}
