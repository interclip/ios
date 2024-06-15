//
//  ContentView.swift
//  Interclip
//
//  Created by Filip Troníček on 12.06.2024.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "paperplane.fill")
                    Text("Send")
                }
            
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Receive")
                }
            
//            ProfileView()
//                .tabItem {
//                    Image(systemName: "gearshape.fill")
//                    Text("Settings")
//                }
        }
    }
}

func createClip(url: String, completion: @escaping (Result<String, Error>) -> Void) {
    let endpoint = "https://server.interclip.app/api/clip"
    
    guard let requestURL = URL(string: endpoint) else {
        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid endpoint URL"])))
        return
    }
    
    var request = URLRequest(url: requestURL)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
    
    // Encode URL parameter
    let bodyData = "url=\(url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    request.httpBody = bodyData.data(using: .utf8)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            completion(.failure(error ?? NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])))
            return
        }
        
        // Debugging: Log raw response data
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Raw response: \(rawResponse)")
        }
        
        do {
            // Ensure we handle JSON response correctly
            let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            guard let responseDict = jsonResponse else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
            }
            
            if let status = responseDict["status"] as? String, status == "success", let result = responseDict["result"] as? String {
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } else if let message = responseDict["result"] as? String {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
            } else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }.resume()
}

func retrieveClip(code: String, completion: @escaping (Result<String, Error>) -> Void) {
    let endpoint = "https://server.interclip.app/api/clip"
    
    // Construct URLComponents to handle query parameters
    var urlComponents = URLComponents(string: endpoint)
    urlComponents?.queryItems = [URLQueryItem(name: "code", value: code)]
    
    guard let requestURL = urlComponents?.url else {
        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid endpoint URL"])))
        return
    }
    
    var request = URLRequest(url: requestURL)
    request.httpMethod = "GET"
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            completion(.failure(error ?? NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])))
            return
        }
        
        // Debugging: Log raw response data
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("Raw response: \(rawResponse)")
        }
        
        do {
            // Ensure we handle JSON response correctly
            let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            guard let responseDict = jsonResponse else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
            }
            
            if let status = responseDict["status"] as? String, status == "success", let result = responseDict["result"] as? String {
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } else if let message = responseDict["result"] as? String {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
            } else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }.resume()
}

struct HomeView: View {
    @State private var urlString: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var clipCode: String?
    
    @FocusState private var isTextFieldFocused: Bool
    
    @Environment(\.sizeCategory) var sizeCategory // Get current size category for debugging
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                Text("Paste a URL below to get a code")
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.bottom, 12)
                
                VStack {
                    TextField("https://...", text: $urlString)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                        .shadow(color: Color(UIColor.label).opacity(0.15), radius: 2)
                        .autocapitalization(.none)
                    //                    .keyboardType(.URL)
                        .focused($isTextFieldFocused)
                        .disableAutocorrection(true)
                        .frame(minWidth: 120, maxWidth: 450)
                        .onSubmit {
                            dismissKeyboardAndSubmit()
                        }
                    Button(action: {
                        dismissKeyboardAndSubmit()
                    }, label: {
                        Spacer()
                        Text("Create clip")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                    })
                    .padding(15)
                    .frame(minWidth: 120, maxWidth: 230)
                    .background(Color.blue)
                    .clipShape(Capsule())
                    .padding()
                }
                .padding(.bottom, 50)
                
                Text(clipCode ?? " ")
                    .font(.title2)
                    .padding()
                    .textSelection(.enabled)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.systemGray6))
            .navigationBarTitle("Create a clip", displayMode: .large)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("URL Submission"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    func dismissKeyboardAndSubmit() {
        // Dismiss the
        isTextFieldFocused = false
        submitURL()
    }
    
    // Function to handle URL submission
    func submitURL() {
        if urlString.isEmpty {
            // Light haptic feedback for minor alert
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            return
        }
        
        guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
            alertMessage = "Invalid URL. Please enter a valid URL."
            showAlert = true
            
            // Medium haptic feedback for warning
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            return
        }
        
        createClip(url: urlString) { result in
            switch result {
            case .success(let clipCode):
                self.clipCode = clipCode
                
                // Success haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
            case .failure(let error):
                self.alertMessage = "Error: \(error.localizedDescription)"
                self.showAlert = true
                
                // Error haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
}

struct SearchView: View {
    @State private var codeString: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var clipCode: String?
    
    @Environment(\.sizeCategory) var sizeCategory // Get current size category for debugging
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                VStack {
                    Text("Paste a code below to get its link")
                        .font(.body)
                        .foregroundColor(.gray)
                        .padding(.bottom, 12)
                    
                    
                    TextField("Enter 5 chars", text: Binding(
                        get: {
                            self.codeString
                        },
                        set: {
                            self.codeString = String($0.prefix(5))
                        }
                    ))
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 120, maxWidth: 150)
                    .padding(10)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .padding(.bottom, 20)
                    .shadow(color: Color(UIColor.label).opacity(0.15), radius: 2)
                    .autocapitalization(.none)
                    .keyboardType(.asciiCapable)
                    .disableAutocorrection(true)
                    .onSubmit {
                        dismissKeyboardAndSubmit()
                    }
                    .onChange(of: codeString) {
                        if codeString.count == 5 {
                            dismissKeyboardAndSubmit()
                        }
                    }
                    .textFieldStyle(PlainTextFieldStyle())
                    
                    Button(action: {
                        dismissKeyboardAndSubmit()
                    }, label: {
                        Spacer()
                        Text("Receive clip")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                    })
                    .padding(15)
                    .frame(minWidth: 120, maxWidth: 230)
                    .background(Color.blue)
                    .clipShape(Capsule())
                    .padding()
                }
                .padding(.bottom, 50)
                
                if let code = clipCode, !code.isEmpty {
                    Link(code, destination: URL(string: code)!)
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .textSelection(.enabled)
                } else {
                    Text(" ")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .navigationBarTitle("Receive a clip", displayMode: .large)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Link retrieval"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    func dismissKeyboardAndSubmit() {
        // Dismiss the keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        submitCode()
    }
    
    // Function to handle URL submission
    func submitCode() {
        guard !codeString.isEmpty else {
            triggerHapticFeedback(type: .light)
            return
        }
        
        retrieveClip(code: codeString) { result in
            switch result {
            case .success(let clipCode):
                self.clipCode = clipCode
                self.triggerHapticFeedback(type: .success)
                
            case .failure(let error):
                self.alertMessage = "Error: \(error.localizedDescription)"
                self.showAlert = true
                self.triggerHapticFeedback(type: .error)
            }
        }
    }

    // Helper method for haptic feedback
    private func triggerHapticFeedback(type: FeedbackType) {
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

    // Enum for feedback types
    private enum FeedbackType {
        case light
        case medium
        case success
        case error
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("This is your profile")
                    .font(.largeTitle)
                    .padding()
                
                // Add profile details here
            }
            .navigationTitle("Profile")
        }
    }
}

struct DetailsView: View {
    var body: some View {
        Text("This is the details page")
            .font(.title)
            .padding()
    }
}

#Preview {
    ContentView()
}

