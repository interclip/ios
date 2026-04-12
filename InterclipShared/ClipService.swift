//
//  ClipService.swift
//  Interclip
//
//  Created by Filip Troníček on 15.06.2024.
//

import Foundation

public func createClip(url: String, completion: @escaping (Result<String, Error>) -> Void) {
    var urlComponents = URLComponents(string: "https://interclip.app/api/set")
    urlComponents?.queryItems = [URLQueryItem(name: "url", value: url)]

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

public func retrieveClip(code: String, completion: @escaping (Result<String, Error>) -> Void) {
    let endpoint = "https://interclip.app/api/get"

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

// MARK: - ZIP Creation
//
// Builds a ZIP archive using STORE (method 0) — no compression, just the container.
// iOS has no native ZIP-creation API, so we implement the format directly.
// Compression wouldn't help anyway since most shared files are already compressed
// (JPEG, PDF, video). CRC-32 is computed in pure Swift via the standard polynomial.

public struct ZipEntry {
    public let filename: String
    public let data: Data
    public init(filename: String, data: Data) { self.filename = filename; self.data = data }
}

public func createZip(entries: [ZipEntry]) -> Data {
    let crcs = entries.map { zipCRC32($0.data) }
    var archive = Data()
    var localOffsets: [Int] = []

    // Local file headers + file data
    for (i, entry) in entries.enumerated() {
        localOffsets.append(archive.count)
        let name = entry.filename.data(using: .utf8) ?? Data()
        let size = UInt32(entry.data.count)
        archive.appendLE(UInt32(0x04034B50)) // local file header sig
        archive.appendLE(UInt16(20))          // version needed: 2.0
        archive.appendLE(UInt16(0))           // general flags
        archive.appendLE(UInt16(0))           // compression method: STORE
        archive.appendLE(UInt16(0))           // mod time
        archive.appendLE(UInt16(0))           // mod date
        archive.appendLE(crcs[i])             // CRC-32
        archive.appendLE(size)                // compressed size (= uncompressed for STORE)
        archive.appendLE(size)                // uncompressed size
        archive.appendLE(UInt16(name.count))  // filename length
        archive.appendLE(UInt16(0))           // extra field length
        archive.append(name)
        archive.append(entry.data)
    }

    // Central directory
    let cdOffset = archive.count
    var cd = Data()
    for (i, entry) in entries.enumerated() {
        let name = entry.filename.data(using: .utf8) ?? Data()
        let size = UInt32(entry.data.count)
        cd.appendLE(UInt32(0x02014B50))       // central directory sig
        cd.appendLE(UInt16(20))               // version made by
        cd.appendLE(UInt16(20))               // version needed
        cd.appendLE(UInt16(0))                // flags
        cd.appendLE(UInt16(0))                // method: STORE
        cd.appendLE(UInt16(0))                // mod time
        cd.appendLE(UInt16(0))                // mod date
        cd.appendLE(crcs[i])
        cd.appendLE(size)
        cd.appendLE(size)
        cd.appendLE(UInt16(name.count))
        cd.appendLE(UInt16(0))                // extra length
        cd.appendLE(UInt16(0))                // comment length
        cd.appendLE(UInt16(0))                // disk number start
        cd.appendLE(UInt16(0))                // internal attributes
        cd.appendLE(UInt32(0))                // external attributes
        cd.appendLE(UInt32(localOffsets[i]))  // local header offset
        cd.append(name)
    }
    archive.append(cd)

    // End of central directory record
    archive.appendLE(UInt32(0x06054B50))
    archive.appendLE(UInt16(0))               // disk number
    archive.appendLE(UInt16(0))               // central dir start disk
    archive.appendLE(UInt16(entries.count))   // entries on this disk
    archive.appendLE(UInt16(entries.count))   // total entries
    archive.appendLE(UInt32(cd.count))        // central directory size
    archive.appendLE(UInt32(cdOffset))        // central directory offset
    archive.appendLE(UInt16(0))               // comment length

    return archive
}

private func zipCRC32(_ data: Data) -> UInt32 {
    var crc = UInt32(0xFFFF_FFFF)
    for byte in data {
        crc = zipCRCTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
    }
    return crc ^ 0xFFFF_FFFF
}

private let zipCRCTable: [UInt32] = (0..<256).map { i -> UInt32 in
    var c = UInt32(i)
    for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1) }
    return c
}

// MARK: - File Upload
//
// Flow mirrors the web app (js/file.ts):
//   1. GET iclip.vercel.app/api/uploadFile → presigned S3 { url, fields }
//   2. POST file to the presigned URL with all fields prepended
//   3. Build https://files.interclip.app/<prefix>/<encodedRest> from fields.key
//   4. createClip(url:) with the resulting file URL → returns the 5-char code

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    private let handler: (Double) -> Void

    init(_ handler: @escaping (Double) -> Void) {
        self.handler = handler
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let fraction = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async { self.handler(fraction) }
    }
}

public func uploadFile(
    fileData: Data,
    fileName: String,
    mimeType: String,
    progress: @escaping (Double) -> Void,
    completion: @escaping (Result<String, Error>) -> Void
) {
    // Step 1 — get the presigned S3 URL from iclip.vercel.app
    var components = URLComponents(string: "https://iclip.vercel.app/api/uploadFile")!
    components.queryItems = [
        URLQueryItem(name: "name", value: fileName),
        URLQueryItem(name: "type", value: mimeType),
        URLQueryItem(name: "size", value: String(fileData.count)),
    ]

    guard let presignURL = components.url else {
        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid presign URL"])))
        return
    }

    URLSession.shared.dataTask(with: presignURL) { data, response, error in
        guard let data, error == nil else {
            DispatchQueue.main.async {
                completion(.failure(error ?? NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error"])))
            }
            return
        }

        let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
        if httpStatus >= 400 {
            let message: String
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? String {
                message = result
            } else {
                message = "Upload service returned HTTP \(httpStatus)"
            }
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "", code: httpStatus, userInfo: [NSLocalizedDescriptionKey: message])))
            }
            return
        }

        if let raw = String(data: data, encoding: .utf8) { print("Presign response: \(raw)") }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let presignedURLString = json["url"] as? String,
              let presignedURL = URL(string: presignedURLString),
              let fields = json["fields"] as? [String: String],
              let fieldsKey = fields["key"] else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid presign response"])))
            }
            return
        }

        // Step 2 — POST file to the presigned S3 URL
        //
        // Field order matches the web app: all policy fields first, file last.
        // The file field name is "file" (not "uploaded_file") per the web app.
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        for (key, value) in fields {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendString(value)
            body.appendString("\r\n")
        }
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n--\(boundary)--\r\n")

        let delegate = UploadProgressDelegate(progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        session.uploadTask(with: request, from: body) { _, uploadResponse, uploadError in
            guard uploadError == nil else {
                DispatchQueue.main.async { completion(.failure(uploadError!)) }
                return
            }

            let uploadStatus = (uploadResponse as? HTTPURLResponse)?.statusCode ?? 0
            guard uploadStatus < 400 else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "", code: uploadStatus, userInfo: [NSLocalizedDescriptionKey: "Upload failed with HTTP \(uploadStatus)"])))
                }
                return
            }

            // Step 3 — Build the CDN URL and create an Interclip clip
            //
            // Mirrors JS: const [prefix, ...key] = fields.key.split("/")
            //             `https://files.interclip.app/${prefix}/${encodeURIComponent(key.join("/"))}`
            let keyComponents = fieldsKey.components(separatedBy: "/")
            let fileURL: String
            if keyComponents.count >= 2 {
                let prefix = keyComponents[0]
                let rest = keyComponents.dropFirst().joined(separator: "/")
                // encodeURIComponent encodes everything except: A-Z a-z 0-9 - _ . ! ~ * ' ( )
                var allowed = CharacterSet.alphanumerics
                allowed.insert(charactersIn: "-_.!~*'()")
                let encoded = rest.addingPercentEncoding(withAllowedCharacters: allowed) ?? rest
                fileURL = "https://files.interclip.app/\(prefix)/\(encoded)"
            } else {
                fileURL = "https://files.interclip.app/\(fieldsKey)"
            }

            print("File URL: \(fileURL)")
            createClip(url: fileURL, completion: completion)
        }.resume()
    }.resume()
}

// MARK: - Private helpers

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }

    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: MemoryLayout<T>.size))
    }
}
