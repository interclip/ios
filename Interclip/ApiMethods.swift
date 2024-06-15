//
//  ApiMethods.swift
//  Interclip
//
//  Created by Filip Troníček on 15.06.2024.

import SwiftUI

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
