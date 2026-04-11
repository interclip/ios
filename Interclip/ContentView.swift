//
//  ContentView.swift
//  Interclip
//
//  Created by Filip Troníček on 12.06.2024.
//

import SwiftUI
import InterclipShared

struct ContentView: View {
    var body: some View {
        TabView {
            CreateClipView()
                .tabItem {
                    Image(systemName: "paperplane.fill")
                    Text("Send")
                }

            ReceiveLinkView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Receive")
                }
        }
        .tint(.blue)
    }
}

// MARK: - Create

struct CreateClipView: View {
    @State private var urlString: String = ""
    @State private var urlStringRequested: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var clipCode: String?
    @State private var isLoading: Bool = false
    @State private var shouldShowQrCodeSheet: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                TextField("https://...", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .disableAutocorrection(true)
                    .focused($isTextFieldFocused)
                    .onSubmit { dismissKeyboardAndSubmit() }
                    .submitLabel(.go)

                Button {
                    isTextFieldFocused = false
                    submitURL()
                } label: {
                    Text("Create clip")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .opacity(isLoading ? 0 : 1)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading || urlString.isEmpty)
                .overlay {
                    if isLoading { ProgressView().tint(.white) }
                }

                if let clipCode {
                    GroupBox {
                        VStack(spacing: 8) {
                            Label("Your code", systemImage: "tag")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(clipCode)
                                .font(.system(.title, design: .monospaced, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .textSelection(.enabled)
                                .contentTransition(.numericText())
                        }
                    }
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = clipCode
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        Button {
                            shouldShowQrCodeSheet = true
                        } label: {
                            Label("Show QR code", systemImage: "qrcode")
                        }
                        Button {
                            let url = URL(string: "https://interclip.app/\(clipCode)")!
                            let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = scene.windows.first(where: { $0.isKeyWindow }) {
                                window.rootViewController?.present(activity, animated: true)
                            }
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Create a clip")
            .navigationBarTitleDisplayMode(.large)
            .alert("URL Submission", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $shouldShowQrCodeSheet) {
                if let clipCode {
                    QRCodeSheet(clipCode: clipCode)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    func dismissKeyboardAndSubmit() {
        isTextFieldFocused = false
        if urlString.isEmpty || urlString == urlStringRequested { return }
        submitURL()
    }

    func submitURL() {
        if urlString.isEmpty {
            triggerHapticFeedback(type: .light)
            return
        }

        urlStringRequested = urlString

        guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
            alertMessage = "Invalid URL. Please enter a valid URL."
            showAlert = true
            triggerHapticFeedback(type: .medium)
            return
        }

        isLoading = true

        createClip(url: urlString) { result in
            switch result {
            case .success(let code):
                withAnimation(.spring()) { self.clipCode = code }
                triggerHapticFeedback(type: .success)
            case .failure(let error):
                self.alertMessage = "Error: \(error.localizedDescription)"
                self.showAlert = true
                triggerHapticFeedback(type: .error)
            }
            self.isLoading = false
        }
    }
}

// MARK: - QR Sheet

private struct QRCodeSheet: View {
    let clipCode: String
    @State private var qrCode: UIImage = UIImage(systemName: "xmark.circle")!
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(uiImage: qrCode)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(maxWidth: 280)
            Text(clipCode)
                .font(.system(.title, design: .monospaced, weight: .semibold))
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .onAppear { generateQRCode() }
        .onChange(of: colorScheme) { generateQRCode() }
    }

    private func generateQRCode() {
        let isDark = colorScheme == .dark
        let code = clipCode
        Task.detached(priority: .userInitiated) {
            let image = QrCodeImage.shared.generateQRCode(from: "https://interclip.app/\(code)", isDark: isDark)
            await MainActor.run { qrCode = image }
        }
    }
}

// MARK: - Receive

struct ReceiveLinkView: View {
    @State private var codeString: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var urlOfCode: String?
    @State private var isLoading: Bool = false
    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                TextField("Enter 5 chars", text: Binding(
                    get: { codeString },
                    set: { codeString = String($0.prefix(5)) }
                ))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                .disableAutocorrection(true)
                .focused($isCodeFieldFocused)
                .onSubmit { dismissKeyboardAndSubmit() }
                .submitLabel(.go)
                .onChange(of: codeString) {
                    if codeString.count == 5 { dismissKeyboardAndSubmit() }
                }

                Button {
                    dismissKeyboardAndSubmit()
                } label: {
                    Text("Receive clip")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .opacity(isLoading ? 0 : 1)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading || codeString.isEmpty)
                .overlay {
                    if isLoading { ProgressView().tint(.white) }
                }

                if let url = urlOfCode, !url.isEmpty {
                    GroupBox {
                        VStack(spacing: 8) {
                            Label("Destination URL", systemImage: "link")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Link(url, destination: URL(string: url)!)
                                .font(.body)
                                .foregroundStyle(.blue)
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = url
                        } label: {
                            Label("Copy link", systemImage: "doc.on.doc")
                        }
                        Button {
                            UIApplication.shared.open(URL(string: url)!)
                        } label: {
                            Label("Open in Safari", systemImage: "safari")
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Receive a clip")
            .navigationBarTitleDisplayMode(.large)
            .alert("Link retrieval", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    func dismissKeyboardAndSubmit() {
        isCodeFieldFocused = false
        submitCode()
    }

    func submitCode() {
        guard !codeString.isEmpty else {
            triggerHapticFeedback(type: .light)
            return
        }

        isLoading = true

        retrieveClip(code: codeString) { result in
            switch result {
            case .success(let url):
                withAnimation(.spring()) { self.urlOfCode = url }
                triggerHapticFeedback(type: .success)
            case .failure(let error):
                self.alertMessage = "Error: \(error.localizedDescription)"
                self.showAlert = true
                triggerHapticFeedback(type: .error)
            }
            self.isLoading = false
        }
    }
}

#Preview {
    ContentView()
}
