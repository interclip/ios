//
//  ContentView.swift
//  Interclip
//
//  Created by Filip Troníček on 12.06.2024.
//

import SwiftUI
import InterclipShared
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    var body: some View {
        TabView {
            CreateClipView()
                .tabItem {
                    Image(systemName: "paperplane.fill")
                    Text("Send")
                }

            UploadFileView()
                .tabItem {
                    Image(systemName: "arrow.up.doc.fill")
                    Text("Files")
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
                    ClipCodeBox(code: clipCode, onShowQRCode: { shouldShowQrCodeSheet = true })
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { isTextFieldFocused = false }
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

// MARK: - Clip Code Box

private struct ClipCodeBox: View {
    let code: String
    var onShowQRCode: (() -> Void)? = nil

    var body: some View {
        GroupBox {
            VStack(spacing: 2) {
                Text("interclip.app/")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(code)
                    .font(.system(.title, design: .monospaced, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .textSelection(.enabled)
                    .contentTransition(.numericText())
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = code
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            if let onShowQRCode {
                Button(action: onShowQRCode) {
                    Label("Show QR code", systemImage: "qrcode")
                }
            }
            Button {
                let url = URL(string: "https://interclip.app/\(code)")!
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
}

// MARK: - File Preview Box

private struct FilePreviewBox: View {
    let fileURL: URL

    private var fileName: String { fileURL.lastPathComponent }

    private var systemIcon: String {
        guard !fileURL.pathExtension.isEmpty,
              let type = UTType(filenameExtension: fileURL.pathExtension) else { return "doc.fill" }
        if type.conforms(to: .image)   { return "photo.fill" }
        if type.conforms(to: .audio)   { return "music.note" }
        if type.conforms(to: .movie)   { return "film.fill" }
        if type.conforms(to: .pdf)     { return "doc.richtext.fill" }
        if type.conforms(to: .archive) { return "archivebox.fill" }
        if type.conforms(to: .text)    { return "doc.text.fill" }
        return "doc.fill"
    }

    private var typeDescription: String {
        guard !fileURL.pathExtension.isEmpty,
              let type = UTType(filenameExtension: fileURL.pathExtension) else { return "File" }
        return type.localizedDescription ?? "File"
    }

    var body: some View {
        GroupBox {
            VStack(spacing: 16) {
                Image(systemName: systemIcon)
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                    .padding(.top, 4)

                VStack(spacing: 4) {
                    Text(fileName)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                    Text(typeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button {
                        UIApplication.shared.open(fileURL)
                    } label: {
                        Label("Open", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button {
                        let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = scene.windows.first(where: { $0.isKeyWindow }) {
                            window.rootViewController?.present(activity, animated: true)
                        }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = fileURL.absoluteString
            } label: {
                Label("Copy link", systemImage: "doc.on.doc")
            }
            Button {
                UIApplication.shared.open(fileURL)
            } label: {
                Label("Open in Safari", systemImage: "safari")
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
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

                if let urlString = urlOfCode, !urlString.isEmpty {
                    if urlString.hasPrefix("https://files.interclip.app/"),
                       let fileURL = URL(string: urlString) {
                        FilePreviewBox(fileURL: fileURL)
                    } else if let parsed = URL(string: urlString) {
                        GroupBox {
                            VStack(spacing: 8) {
                                Label("Destination URL", systemImage: "link")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(urlString)
                                    .font(.body)
                                    .foregroundStyle(.blue)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                    .onTapGesture {
                                        UIApplication.shared.open(parsed)
                                    }
                            }
                        }
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = urlString
                            } label: {
                                Label("Copy link", systemImage: "doc.on.doc")
                            }
                            Button {
                                UIApplication.shared.open(parsed)
                            } label: {
                                Label("Open in Safari", systemImage: "safari")
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
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

// MARK: - Upload

private struct SelectedFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var systemIcon: String {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return "doc" }
        if type.conforms(to: .image)   { return "photo" }
        if type.conforms(to: .audio)   { return "music.note" }
        if type.conforms(to: .movie)   { return "film" }
        if type.conforms(to: .pdf)     { return "doc.richtext" }
        if type.conforms(to: .archive) { return "archivebox" }
        if type.conforms(to: .text)    { return "doc.text" }
        return "doc"
    }
}

struct UploadFileView: View {
    @State private var selectedFiles: [SelectedFile] = []
    @State private var isShowingDocumentPicker = false
    @State private var isShowingPhotoPicker = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var clipCode: String?
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var shouldShowQrCodeSheet: Bool = false
    @AppStorage("autoShowQRCode") private var autoShowQRCode = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                if selectedFiles.isEmpty {
                    emptyState
                } else {
                    fileListView
                }

                if !selectedFiles.isEmpty, clipCode == nil {
                    if isUploading, uploadProgress > 0 {
                        ProgressView(value: uploadProgress).tint(.blue)
                    }

                    Button {
                        performUpload()
                    } label: {
                        Text(uploadButtonLabel)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .opacity(isUploading ? 0 : 1)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isUploading)
                    .overlay {
                        if isUploading { ProgressView().tint(.white) }
                    }
                }

                if let clipCode {
                    ClipCodeBox(code: clipCode, onShowQRCode: { shouldShowQrCodeSheet = true })
                    Button {
                        clearAll()
                    } label: {
                        Text("New upload").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            .navigationTitle("Upload a file")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingDocumentPicker) {
                DocumentPickerView { urls in loadFiles(from: urls) }
            }
            .sheet(isPresented: $isShowingPhotoPicker) {
                PhotoPickerView { photos in loadPhotos(photos) }
            }
            .sheet(isPresented: $shouldShowQrCodeSheet) {
                if let clipCode {
                    QRCodeSheet(clipCode: clipCode)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
            .alert("Upload Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        HStack(spacing: 12) {
            pickerOption(icon: "doc.fill", title: "Files") {
                isShowingDocumentPicker = true
            }
            pickerOption(icon: "photo.fill", title: "Photos") {
                isShowingPhotoPicker = true
            }
        }
    }

    private func pickerOption(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Color(UIColor.secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(UIColor.systemGray4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: File list

    private var fileListView: some View {
        VStack(spacing: 8) {
            GroupBox {
                VStack(spacing: 0) {
                    ForEach(Array(selectedFiles.enumerated()), id: \.element.id) { index, file in
                        if index > 0 { Divider().padding(.leading, 44) }
                        fileRow(file: file, index: index)
                    }
                }
            }

            if !isUploading {
                Menu {
                    Button {
                        isShowingDocumentPicker = true
                    } label: {
                        Label("Files", systemImage: "doc.badge.plus")
                    }
                    Button {
                        isShowingPhotoPicker = true
                    } label: {
                        Label("Photos", systemImage: "photo.badge.plus")
                    }
                } label: {
                    Label("Add more", systemImage: "plus")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func fileRow(file: SelectedFile, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: file.systemIcon)
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(file.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !isUploading {
                Button {
                    withAnimation(.spring()) {
                        try? FileManager.default.removeItem(at: file.url)
                        selectedFiles.remove(at: index)
                        if selectedFiles.isEmpty { clipCode = nil }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: Computed

    private var uploadButtonLabel: String {
        selectedFiles.count == 1 ? "Upload file" : "Upload \(selectedFiles.count) files as ZIP"
    }

    // MARK: File loading

    private func loadFiles(from urls: [URL]) {
        var newFiles: [SelectedFile] = []
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            let name = url.lastPathComponent
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = Int64((attrs?[.size] as? Int) ?? 0)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "_" + name)
            guard (try? FileManager.default.copyItem(at: url, to: tempURL)) != nil else {
                url.stopAccessingSecurityScopedResource()
                continue
            }
            url.stopAccessingSecurityScopedResource()
            newFiles.append(SelectedFile(url: tempURL, name: name, size: size))
        }
        withAnimation(.spring()) {
            selectedFiles.append(contentsOf: newFiles)
            clipCode = nil
        }
    }

    private func loadPhotos(_ photos: [(name: String, data: Data)]) {
        var newFiles: [SelectedFile] = []
        for (name, data) in photos {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "_" + name)
            guard (try? data.write(to: tempURL)) != nil else { continue }
            newFiles.append(SelectedFile(url: tempURL, name: name, size: Int64(data.count)))
        }
        withAnimation(.spring()) {
            selectedFiles.append(contentsOf: newFiles)
            clipCode = nil
        }
    }

    // MARK: Upload

    private func performUpload() {
        guard !selectedFiles.isEmpty else { return }

        let uploadData: Data
        let uploadName: String
        let uploadMime: String

        if selectedFiles.count == 1 {
            let file = selectedFiles[0]
            guard let data = try? Data(contentsOf: file.url) else {
                alertMessage = "Failed to read file."
                showAlert = true
                return
            }
            uploadData = data
            uploadName = file.name
            uploadMime = mimeType(for: file.url)
        } else {
            // Build a ZIP of all selected files
            let entries: [ZipEntry] = selectedFiles.compactMap { file in
                guard let data = try? Data(contentsOf: file.url) else { return nil }
                return ZipEntry(filename: file.name, data: data)
            }
            guard entries.count == selectedFiles.count else {
                alertMessage = "Failed to read one or more files."
                showAlert = true
                return
            }
            uploadData = createZip(entries: entries)
            uploadName = "interclip-files.zip"
            uploadMime = "application/zip"
        }

        isUploading = true
        uploadProgress = 0

        uploadFile(
            fileData: uploadData,
            fileName: uploadName,
            mimeType: uploadMime,
            progress: { p in DispatchQueue.main.async { self.uploadProgress = p } },
            completion: { result in
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
                self.isUploading = false
            }
        )
    }

    private func clearAll() {
        for file in selectedFiles {
            try? FileManager.default.removeItem(at: file.url)
        }
        withAnimation(.spring()) {
            selectedFiles = []
            clipCode = nil
            uploadProgress = 0
        }
    }

    private func mimeType(for url: URL) -> String {
        guard !url.pathExtension.isEmpty,
              let type = UTType(filenameExtension: url.pathExtension),
              let mime = type.preferredMIMEType else {
            return "application/octet-stream"
        }
        return mime
    }
}

// MARK: - Pickers

private struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: false)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}

private struct PhotoPickerView: UIViewControllerRepresentable {
    let onPick: ([(name: String, data: Data)]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0   // 0 = unlimited
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: ([(name: String, data: Data)]) -> Void
        init(onPick: @escaping ([(name: String, data: Data)]) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }

            let group = DispatchGroup()
            let lock = NSLock()
            var picked: [(index: Int, name: String, data: Data)] = []

            for (i, result) in results.enumerated() {
                guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    guard let image = object as? UIImage,
                          let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
                    let name = result.itemProvider.suggestedName.map { "\($0).jpg" }
                        ?? "photo_\(i + 1).jpg"
                    lock.lock()
                    picked.append((i, name, jpeg))
                    lock.unlock()
                }
            }

            group.notify(queue: .main) {
                let sorted = picked.sorted { $0.index < $1.index }
                    .map { (name: $0.name, data: $0.data) }
                self.onPick(sorted)
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

                Section {
                    NavigationLink("About") { AboutView() }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - About

private struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    private let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // Full app icon: logo paths on the branded blue background
                InterclipLogo()
                    .padding(22)
                    .frame(width: 110, height: 110)
                    .background(
                        RoundedRectangle(cornerRadius: 35, style: .continuous)
                            .fill(Color(red: 0x15 / 255.0, green: 0x7E / 255.0, blue: 0xFB / 255.0))
                    )

                VStack(spacing: 4) {
                    Text("Interclip")
                        .font(.title2.weight(.bold))
                    Text("Version \(version) (\(build))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Link(destination: URL(string: "https://interclip.app")!) {
                Label("Open interclip.app", systemImage: "globe")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 32)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
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
