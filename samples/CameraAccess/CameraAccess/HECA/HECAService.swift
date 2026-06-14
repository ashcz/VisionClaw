//
// HECAService.swift
//
// Drives the interactive HECA conversation against the Gemini `generateContent`
// REST endpoint. It keeps the full conversation history (images + text) so each
// turn refines a single, evolving report. Every assistant turn returns both a
// chat message and the complete, up-to-date structured report.
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

  /// Conversation history in Gemini `contents` format.
  private var contents: [[String: Any]] = []

  init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 60
    self.session = URLSession(configuration: config)
  }

  /// Clear the conversation to begin a fresh assessment.
  func reset() {
    contents = []
  }

  /// Start the assessment with the first captured image.
  func start(image: UIImage) async throws -> HECATurn {
    reset()
    let parts = try Self.imageParts(
      image: image,
      text: "Start a HECA. Here is the first area. Assess it, then check in with me."
    )
    appendUser(parts: parts)
    return try await complete()
  }

  /// Add another captured area to the ongoing assessment.
  func addArea(image: UIImage, note: String?) async throws -> HECATurn {
    let text = note?.isEmpty == false
      ? "Here is another area to assess. Note from me: \(note!)"
      : "Here is another area to assess."
    let parts = try Self.imageParts(image: image, text: text)
    appendUser(parts: parts)
    return try await complete()
  }

  /// Send a text comment / question from the worker.
  func send(text: String) async throws -> HECATurn {
    appendUser(parts: [["text": text]])
    return try await complete()
  }

  // MARK: - Private

  private func appendUser(parts: [[String: Any]]) {
    contents.append(["role": "user", "parts": parts])
  }

  private static func imageParts(image: UIImage, text: String) throws -> [[String: Any]] {
    guard let jpeg = image.jpegData(compressionQuality: HECAConfig.jpegQuality) else {
      throw HECAServiceError.encodingFailed
    }
    return [
      ["text": text],
      ["inlineData": ["mimeType": "image/jpeg", "data": jpeg.base64EncodedString()]]
    ]
  }

  /// Send the current conversation and decode the assistant turn.
  private func complete() async throws -> HECATurn {
    guard let url = HECAConfig.generateContentURL() else {
      throw HECAServiceError.notConfigured
    }

    let body: [String: Any] = [
      "systemInstruction": ["parts": [["text": HECAConfig.systemPrompt]]],
      "contents": contents,
      "generationConfig": [
        "temperature": 0.3,
        "responseMimeType": "application/json",
        "responseSchema": HECAConfig.turnResponseSchema()
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
    guard let turnData = text.data(using: .utf8) else {
      throw HECAServiceError.noContent
    }

    let turn: HECATurn
    do {
      turn = try JSONDecoder().decode(HECATurn.self, from: turnData)
    } catch {
      throw HECAServiceError.decoding(error.localizedDescription)
    }

    // Record the assistant's raw JSON turn so it has context on the next call.
    contents.append(["role": "model", "parts": [["text": text]]])
    return turn
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

