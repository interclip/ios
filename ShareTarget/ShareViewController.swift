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

extension UIColor {
    static var userBackground: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.black
            default:
                return UIColor.white
            }
        }
    }

    static var userText: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.white
            default:
                return UIColor.black
            }
        }
    }

    static var userAccent: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.systemBlue
            default:
                return UIColor.systemBlue
            }
        }
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

        view.backgroundColor = .userBackground
        setupUI()

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

    private func setupUI() {
        let stackView = UIStackView(arrangedSubviews: [urlLabel, qrCodeImageView, clipCodeLabel, copyButton])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        urlLabel.textAlignment = .center
        urlLabel.textColor = .userText
        urlLabel.numberOfLines = 2

        qrCodeImageView.contentMode = .scaleAspectFit
        qrCodeImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6).isActive = true
        qrCodeImageView.heightAnchor.constraint(equalTo: qrCodeImageView.widthAnchor).isActive = true

        clipCodeLabel.textAlignment = .center
        clipCodeLabel.font = UIFont.boldSystemFont(ofSize: 24)
        clipCodeLabel.textColor = .userText
        clipCodeLabel.numberOfLines = 1

        copyButton.setTitle("Copy Code", for: .normal)
        copyButton.tintColor = .userAccent
        copyButton.addTarget(self, action: #selector(copyCode), for: .touchUpInside)
        copyButton.isHidden = true

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        activityIndicator.color = .userAccent

        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func createClipAndComplete() {
        guard let url = self.url else {
            showError(message: "URL is missing")
            return
        }

        createClip(url: url) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
            }

            switch result {
            case .success(let clipCode):
                DispatchQueue.main.async {
                    self.clipCode = clipCode
                    self.clipCodeLabel.text = clipCode
                    self.copyButton.isHidden = false
                }

            case .failure(let error):
                self.showError(message: error.localizedDescription)
            }
        }
    }

    @objc private func copyCode() {
        guard let clipCode = clipCode else { return }
        UIPasteboard.general.string = clipCode

        triggerHapticFeedback(type: .success)
    }

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
