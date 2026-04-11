//
//  ShareViewController.swift
//  ShareTarget
//
//  Created by Filip Troníček on 15.06.2024.
//

import UIKit
import SwiftUI
import Social
import InterclipShared

// MARK: - Entry point

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = item.attachments?.first,
              attachment.hasItemConformingToTypeIdentifier("public.url") else {
            cancelWithError("No URL found.")
            return
        }

        attachment.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] data, _ in
            guard let self else { return }
            guard let url = data as? URL else {
                DispatchQueue.main.async { self.cancelWithError("Couldn't load the URL.") }
                return
            }
            DispatchQueue.main.async { self.embed(url: url.absoluteString) }
        }
    }

    private func embed(url: String) {
        let viewModel = ShareViewModel(url: url)
        let shareView = ShareView(viewModel: viewModel) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        let host = UIHostingController(rootView: shareView)
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }

    private func cancelWithError(_ message: String) {
        let alert = UIAlertController(title: "Interclip", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(
                withError: NSError(domain: "com.interclip", code: -1,
                                   userInfo: [NSLocalizedDescriptionKey: message])
            )
        })
        present(alert, animated: true)
    }
}

// MARK: - View model

final class ShareViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var clipCode: String?
    @Published var errorMessage: String?

    let url: String

    init(url: String) {
        self.url = url
        Task.detached(priority: .userInitiated) {
            createClip(url: url) { [weak self] result in
                // ClipService dispatches completion on the main thread
                switch result {
                case .success(let code):
                    self?.clipCode = code
                    self?.isLoading = false
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                }
            }
        }
    }
}

// MARK: - SwiftUI view

private struct ShareView: View {
    @ObservedObject var viewModel: ShareViewModel
    var onDone: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @State private var qrCode: UIImage = UIImage(systemName: "qrcode")!
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(UIColor.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    InterclipLogo()
                        .frame(width: 22, height: 22)
                    Text("Interclip")
                        .font(.headline)
                }
                Text(viewModel.url)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal)
            .padding(.bottom, 28)

            // Content
            if viewModel.isLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text("Creating clip…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
                doneButton.padding(.horizontal).padding(.bottom, 8)

            } else if let code = viewModel.clipCode {
                Image(uiImage: qrCode)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 200)
                    .padding(.bottom, 20)

                GroupBox {
                    VStack(spacing: 8) {
                        Label("Your code", systemImage: "tag")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(code)
                            .font(.system(.title, design: .monospaced, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = code
                        triggerHapticFeedback(type: .success)
                        withAnimation(.spring(duration: 0.3)) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.spring(duration: 0.3)) { copied = false }
                        }
                    } label: {
                        Label(
                            copied ? "Copied!" : "Copy code",
                            systemImage: copied ? "checkmark" : "doc.on.doc"
                        )
                        .frame(maxWidth: .infinity)
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(copied ? .green : .blue)
                    .animation(.spring(duration: 0.3), value: copied)

                    doneButton
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.systemBackground))
        .onChange(of: viewModel.clipCode) { generateQRCode() }
        .onChange(of: colorScheme) { generateQRCode() }
    }

    private var doneButton: some View {
        Button(action: onDone) {
            Text("Done").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func generateQRCode() {
        guard let code = viewModel.clipCode else { return }
        let isDark = colorScheme == .dark
        Task.detached(priority: .userInitiated) {
            let image = QrCodeImage.shared.generateQRCode(
                from: "https://interclip.app/\(code)", isDark: isDark
            )
            await MainActor.run { qrCode = image }
        }
    }
}
