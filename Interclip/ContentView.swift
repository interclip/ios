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

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
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
    @AppStorage("autoShowQRCode") private var autoShowQRCode = false

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
                    .onChange(of: urlString) { oldValue, newValue in
                        if newValue.count - oldValue.count > 1 {
                            dismissKeyboardAndSubmit()
                        }
                    }

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
            .navigationBarTitleDisplayMode(.inline)
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

        Task.detached(priority: .userInitiated) {
            createClip(url: urlString) { result in
                switch result {
                case .success(let code):
                    withAnimation(.spring()) { self.clipCode = code }
                    if self.autoShowQRCode { self.shouldShowQrCodeSheet = true }
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
}

// MARK: - QR Sheet

private struct QRCodeSheet: View {
    let clipCode: String
    @State private var qrCode: UIImage? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            if let qrCode {
                Image(uiImage: qrCode)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 280)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(width: 280, height: 280)
            }
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
    @AppStorage("autoOpenLinks") private var autoOpenLinks = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                OTPInputView(
                    code: $codeString,
                    onComplete: dismissKeyboardAndSubmit
                )

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
                .disabled(isLoading || codeString.count != 5)
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
                            Text(url)
                                .font(.body)
                                .foregroundStyle(.blue)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .onTapGesture {
                                    UIApplication.shared.open(URL(string: url)!)
                                }
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
            .navigationBarTitleDisplayMode(.inline)
            .alert("Link retrieval", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    func dismissKeyboardAndSubmit() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        submitCode()
    }

    func submitCode() {
        guard codeString.count == 5, !isLoading else { return }

        isLoading = true

        Task.detached(priority: .userInitiated) {
            retrieveClip(code: codeString) { result in
                switch result {
                case .success(let url):
                    withAnimation(.spring()) { self.urlOfCode = url }
                    if self.autoOpenLinks, let openURL = URL(string: url) {
                        UIApplication.shared.open(openURL)
                    }
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
}

// MARK: - Settings

struct SettingsView: View {
    @AppStorage("autoOpenLinks") private var autoOpenLinks = false
    @AppStorage("autoShowQRCode") private var autoShowQRCode = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Open links automatically", isOn: $autoOpenLinks)
                } footer: {
                    Text("Automatically open the destination URL in Safari after a code is entered.")
                }

                Section {
                    Toggle("Show QR code after creating clip", isOn: $autoShowQRCode)
                } footer: {
                    Text("Show the QR code sheet as soon as a clip is created.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - OTP Input

private struct OTPInputView: View {
    @Binding var code: String
    var onComplete: (() -> Void)? = nil
    @State private var isEditing = false

    private let length = 5

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<length, id: \.self) { index in
                let char: String? = index < code.count
                    ? String(code[code.index(code.startIndex, offsetBy: index)])
                    : nil
                CharacterBox(
                    char: char,
                    isActive: isEditing && code.count == index
                )
            }
        }
        .overlay {
            // UIViewRepresentable gives us a real UITextField so UIKit handles
            // all native gestures: tap to focus, tap-on-cursor for paste menu,
            // long-press select. tintColor = .clear hides the cursor visually
            // but iOS still shows the paste popup (it's gesture-driven, not
            // cursor-driven).
            InvisibleTextField(
                text: $code,
                isEditing: $isEditing,
                length: length,
                onComplete: { onComplete?() }
            )
        }
    }
}

private struct InvisibleTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isEditing: Bool
    let length: Int
    var onComplete: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.keyboardType = .asciiCapable
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.textContentType = .oneTimeCode
        field.tintColor = .clear
        field.textColor = .clear
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.delegate = context.coordinator
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isEditing: $isEditing, length: length, onComplete: onComplete)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @Binding var isEditing: Bool
        let length: Int
        var onComplete: () -> Void

        init(text: Binding<String>, isEditing: Binding<Bool>, length: Int, onComplete: @escaping () -> Void) {
            _text = text
            _isEditing = isEditing
            self.length = length
            self.onComplete = onComplete
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let current = textField.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return false }
            let updated = current.replacingCharacters(in: swiftRange, with: string)
            let filtered = String(updated.filter { $0.isLetter || $0.isNumber }.prefix(length))
            text = filtered
            textField.text = filtered
            if filtered.count == length {
                DispatchQueue.main.async { self.onComplete() }
            }
            return false
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isEditing = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isEditing = false
        }
    }
}

private struct CharacterBox: View {
    let char: String?
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemFill))
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isActive ? Color.accentColor : Color(UIColor.systemGray4),
                    lineWidth: isActive ? 2 : 1
                )
                .animation(.easeInOut(duration: 0.15), value: isActive)

            if let char {
                Text(char)
                    .font(.system(.title2, design: .monospaced, weight: .semibold))
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            } else if isActive {
                BlinkingCursor()
                    .transition(.opacity)
            }
        }
        .frame(width: 52, height: 60)
        .animation(.spring(duration: 0.2), value: char == nil)
    }
}

private struct BlinkingCursor: View {
    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.accentColor)
            .frame(width: 2, height: 26)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

#Preview {
    ContentView()
}
