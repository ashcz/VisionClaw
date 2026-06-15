//
// HECAService.swift
//
// Drives the structured HECA grid assessment (a single-shot, structured vision
// call) and the optional advisor chat against the Gemini `generateContent` REST
// endpoint. The grid call returns the full EEI catalog of 13 high-energy hazards
// with their controls, comments, and annotated evidence. The chat is seeded with
// the assessed image so the advisor can answer follow-up questions.
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

/// Transport result of a single-shot grid assessment.
struct HECAGridResult: Codable {
  let summary: String
  let assessments: [HECACategoryAssessment]
}

@MainActor
final class HECAService {
  private let session: URLSession

  /// Advisor chat history (seeded with the assessed image).
  private var chatContents: [[String: Any]] = []
  private var chatSeeded = false

  init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 60
    self.session = URLSession(configuration: config)
  }

  /// Clear the advisor chat to begin fresh.
  func reset() {
    chatContents = []
    chatSeeded = false
  }

  // MARK: - Grid assessment

  /// Run a single-shot structured HECA assessment of the captured image.
  func assessGrid(image: UIImage) async throws -> HECAGridResult {
    guard let url = HECAConfig.generateContentURL() else {
      throw HECAServiceError.notConfigured
    }
    guard let jpeg = image.jpegData(compressionQuality: HECAConfig.jpegQuality) else {
      throw HECAServiceError.encodingFailed
    }

    let userParts: [[String: Any]] = [
      ["text": "Assess this job-site photo for high-energy hazards and their controls."],
      ["inlineData": ["mimeType": "image/jpeg", "data": jpeg.base64EncodedString()]]
    ]
    let contents: [[String: Any]] = [["role": "user", "parts": userParts]]

    let body: [String: Any] = [
      "systemInstruction": ["parts": [["text": HECAConfig.gridSystemPrompt]]],
      "contents": contents,
      "generationConfig": [
        "temperature": 0.2,
        "responseMimeType": "application/json",
        "responseSchema": HECAConfig.gridResponseSchema()
      ]
    ]

    let text = try await post(url: url, body: body)
    guard let data = text.data(using: .utf8) else {
      throw HECAServiceError.noContent
    }
    let result: HECAGridResult
    do {
      result = try JSONDecoder().decode(HECAGridResult.self, from: data)
    } catch {
      throw HECAServiceError.decoding(error.localizedDescription)
    }

    // Seed the advisor chat with the same image for follow-up questions.
    chatContents = contents
    chatSeeded = true
    return result
  }

  // MARK: - Advisor chat

  /// Send an advisor chat message; returns the assistant's plain-text reply.
  func chat(text: String, reportSummary: String) async throws -> String {
    guard let url = HECAConfig.generateContentURL() else {
      throw HECAServiceError.notConfigured
    }
    if !chatSeeded {
      chatContents = [[
        "role": "user",
        "parts": [["text": "Job-site context for this HECA: \(reportSummary)"]]
      ]]
      chatSeeded = true
    }
    chatContents.append(["role": "user", "parts": [["text": text]]])

    let body: [String: Any] = [
      "systemInstruction": ["parts": [["text": HECAConfig.chatSystemPrompt]]],
      "contents": chatContents,
      "generationConfig": ["temperature": 0.4]
    ]

    let reply = try await post(url: url, body: body)
    chatContents.append(["role": "model", "parts": [["text": reply]]])
    return reply
  }

  // MARK: - Private

  /// POST the request body and return the model's concatenated text part.
  private func post(url: URL, body: [String: Any]) async throws -> String {
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
    return try Self.extractText(from: data)
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

