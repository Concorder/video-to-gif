import Foundation

enum ImportError: LocalizedError {
    case invalid, service, response
    var errorDescription: String? {
        switch self {
        case .invalid: return "Enter a valid HTTPS video link."
        case .service: return "Add an import service in Settings to download YouTube or TikTok videos."
        case .response: return "The import service did not return a downloadable video."
        }
    }
}
enum VideoImporter {
    static func load(_ value: String, resolver: String) async throws -> URL {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme == "https", let host = url.host else { throw ImportError.invalid }
        let social = ["youtube.com", "youtu.be", "tiktok.com"].contains { host == $0 || host.hasSuffix("." + $0) }
        var download = url
        if social {
            guard let service = URL(string: resolver), service.scheme == "https" else { throw ImportError.service }
            var request = URLRequest(url: service); request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["url": url.absoluteString])
            let (data, response) = try await URLSession.shared.data(for: request)
            struct Result: Decodable { let videoURL: URL }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ImportError.response }
            download = try JSONDecoder().decode(Result.self, from: data).videoURL
            guard download.scheme == "https" else { throw ImportError.response }
        }
        let (temporary, response) = try await URLSession.shared.download(from: download)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode), response.mimeType?.hasPrefix("video/") == true else { throw ImportError.response }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }
}
