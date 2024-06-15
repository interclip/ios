//
//  AppIntents.swift
//  Interclip
//
//  Created by Filip Troníček on 15.06.2024.
//


import AppIntents
import Foundation
import OSLog

struct CreateClip: AppIntent {
    static let title: LocalizedStringResource = "Create a clip from a URL"

    @Parameter(title: "URL", description: "The URL to make a new clip from")
    var url: String
    
    struct Returns: IntentResult {
        var value: String?
        
        init(value: String) {
            self.value = value
        }
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ShowsSnippetView {
        do {
            let code = try await createClipAsync(url: url)
            
            return .result(value: code)
        } catch {
            return .result(value: "Error: \(error.localizedDescription)")
        }
    }
    
    static var parameterSummary: some ParameterSummary {
            Summary("Create a new clip from a \(\.$url)")
    }
    
    static let openAppWhenRun = false
}

struct RetrieveClip: AppIntent {
    static let title: LocalizedStringResource = "Get a URL using a clip code"
    
    @Parameter(title: "Clip code", description: "A 5-character long clip code")
    var code: String
    
    struct Returns: IntentResult {
        var value: String?
        
        init(value: String) {
            self.value = value
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ShowsSnippetView {
        do {
            let code = try await retrieveClipAsync(code: code)
            return .result(value: code)
        } catch {
            return .result(value: "Error: \(error.localizedDescription)")
        }
    }
    
    static var parameterSummary: some ParameterSummary {
        Summary("Retrieve an existing clip from \(\.$code)")
    }
    
    static let openAppWhenRun = false
    

}

func createClipAsync(url: String) async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
        createClip(url: url) { result in
            switch result {
            case .success(let clipCode):
                continuation.resume(returning: clipCode)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}

func retrieveClipAsync(code: String) async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
        retrieveClip(code: code) { result in
            switch result {
            case .success(let clipCode):
                continuation.resume(returning: clipCode)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}
