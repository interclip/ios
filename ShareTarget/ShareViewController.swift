//
//  ShareViewController.swift
//  ShareTarget
//
//  Created by Filip Troníček on 15.06.2024.
//

import UIKit
import Social
import InterclipShared

class ShareViewController: UIViewController {

    private var url: String?
    
    override func viewDidLoad() {
            // As soon as the share sheet is presented, try to fetch the URL and create a clip
            if let item = self.extensionContext?.inputItems.first as? NSExtensionItem,
               let attachment = item.attachments?.first {
                if attachment.hasItemConformingToTypeIdentifier("public.url") {
                    attachment.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (data, error) in
                        if let url = data as? URL {
                            self?.url = url.absoluteString
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
    
    // Function to create the clip and handle completion
    private func createClipAndComplete() {
        guard let url = self.url else {
            showError(message: "URL is missing")
            return
        }

        createClip(url: url) { [weak self] result in
            guard let self = self else { return } // Ensure self is not nil

            switch result {
            case .success(let clipCode):
                // Notify user of success
                self.showAlert(title: "Success", message: "Clip created: \(clipCode)")
                
            case .failure(let error):
                // Notify user of the error
                self.showError(message: error.localizedDescription)
            }
        }
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

    // Helper function to show alerts
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
