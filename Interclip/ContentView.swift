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
        }
    }
}


struct HomeView: View {
    @State private var urlString: String = ""
    @State private var urlStringRequested: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var clipCode: String?
    @State private var isLoading: Bool = false
    
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
                        .keyboardType(.URL)
                        .focused($isTextFieldFocused)
                        .disableAutocorrection(true)
                        .frame(minWidth: 120, maxWidth: 450)
                        .onSubmit {
                            dismissKeyboardAndSubmit()
                        }
                    Button(action: {
                        isTextFieldFocused = false
                        submitURL()
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Create clip")
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 54)
                        .frame(maxWidth: 230)
                    }
                    .background(isLoading ? Color.gray : Color.blue) // Button color changes if loading
                    .clipShape(Capsule())
                    .padding()
                    .disabled(isLoading)
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
        // Dismiss the keyboard
        isTextFieldFocused = false

        if urlString.isEmpty || urlString == urlStringRequested {
            return
        }

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

        urlStringRequested = urlString
        
        guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
            alertMessage = "Invalid URL. Please enter a valid URL."
            showAlert = true
            
            triggerHapticFeedback(type: .medium)
            return
        }
        
        self.isLoading = true
        
        createClip(url: urlString) { result in
            switch result {
            case .success(let clipCode):
                self.clipCode = clipCode
                
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

struct SearchView: View {
    @State private var codeString: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var urlOfCode: String?
    @State private var isLoading: Bool = false
    
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
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Receive clip")
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 54)
                        .frame(maxWidth: 230)
                    }
                    .background(isLoading ? Color.gray : Color.blue) // Button color changes if loading
                    .clipShape(Capsule())
                    .padding()
                    .disabled(isLoading)
                }
                .padding(.bottom, 50)
                
                if let code = urlOfCode, !code.isEmpty {
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
        
        self.isLoading = true
        
        retrieveClip(code: codeString) { result in
            switch result {
            case .success(let clipCode):
                self.urlOfCode = clipCode
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

struct ProfileView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("This is your profile")
                    .font(.largeTitle)
                    .padding()
                
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

