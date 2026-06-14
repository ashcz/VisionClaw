//
// HECAService.swift
//
// Performs a one-shot HECA assessment by sending a captured image to the Gemini
// `generateContent` REST endpoint and decoding the structured JSON response.
//

import UIKit

enum HECAServiceError: LocalizedError {
  case notConfigured
  case encodingFailed
  case http(Int, String)
  case noContent
  case decoding(String)

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "Gemini API key not configured. Add your key in Settings."
    case .encodingFailed:
      return "Could not encode the captured image."
    case .http(let code, let body):
      return "Assessment failed (HTTP \(code)). \(body)"
    case .noContent:
      return "The model returned no content."
    case .decoding(let detail):
      return "Could not read the assessment result. \(detail)"
    }
  }
}

@MainActor
final class HECAService {
  private let session: URLSession

  init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 60
    self.session = URLSession(configuration: config)
  }

  /// Run a HECA assessment on the given image.
  func assess(image: UIImage) async throws -> HECAReport {
    guard let url = HECAConfig.generateContentURL() else {
      throw HECAServiceError.notConfigured
    }
    guard let jpeg = image.jpegData(compressionQuality: HECAConfig.jpegQuality) else {
      throw HECAServiceError.encodingFailed
    }

    let body: [String: Any] = [
      "systemInstruction": [
        "parts": [["text": HECAConfig.systemPrompt]]
      ],
      "contents": [
        [
          "role": "user",
          "parts": [
            ["text": "Perform a HECA on this image and return the structured result."],
            ["inlineData": ["mimeType": "image/jpeg", "data": jpeg.base64EncodedString()]]
          ]
        ]
      ],
      "generationConfig": [
        "temperature": 0.2,
        "responseMimeType": "application/json",
        "responseSchema": HECAConfig.responseSchema()
      ]
    ]

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await session.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw HECAServiceError.http(0, "No response")
    }
    guard (200...299).contains(http.statusCode) else {
      let bodyStr = String(data: data, encoding: .utf8) ?? ""
      throw HECAServiceError.http(http.statusCode, String(bodyStr.prefix(300)))
    }

    let text = try Self.extractText(from: data)
    guard let reportData = text.data(using: .utf8) else {
      throw HECAServiceError.noContent
    }

    do {
      return try JSONDecoder().decode(HECAReport.self, from: reportData)
    } catch {
      throw HECAServiceError.decoding(error.localizedDescription)
    }
  }

  /// Pull the model's text part out of the generateContent response envelope.
  private static func extractText(from data: Data) throws -> String {
    guard
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let candidates = json["candidates"] as? [[String: Any]],
      let first = candidates.first,
      let content = first["content"] as? [String: Any],
      let parts = content["parts"] as? [[String: Any]]
    else {
      throw HECAServiceError.noContent
    }
    let text = parts.compactMap { $0["text"] as? String }.joined()
    guard !text.isEmpty else { throw HECAServiceError.noContent }
    return text
  }
}
