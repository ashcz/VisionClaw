//
// HECASender.swift
//
// Sends a HECA report summary to the OpenClaw gateway so the agent can file or
// route it (e.g. email it, post to a channel, append to a log).
//
// The chat-completions endpoint accepts text only, so we send a compact text
// summary of the report. The locally-saved PDF/JSON remain available for manual
// sharing via the iOS share sheet.
//

import Foundation

enum HECASenderError: LocalizedError {
  case notConfigured
  case invalidURL
  case http(Int, String)

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "OpenClaw is not configured. Set the gateway host and token in Settings."
    case .invalidURL:
      return "Invalid OpenClaw gateway URL."
    case .http(let code, let body):
      return "OpenClaw returned HTTP \(code). \(body)"
    }
  }
}

@MainActor
final class HECASender {
  private let session: URLSession

  init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 120
    self.session = URLSession(configuration: config)
  }

  /// Send the report summary to OpenClaw. `destination` is an optional routing hint
  /// (e.g. an email address) appended to the instruction.
  @discardableResult
  func send(report: HECAReport, destination: String?) async throws -> String {
    guard GeminiConfig.isOpenClawConfigured else {
      throw HECASenderError.notConfigured
    }
    guard let url = URL(string:
      "\(GeminiConfig.openClawHost):\(GeminiConfig.openClawPort)/v1/chat/completions")
    else {
      throw HECASenderError.invalidURL
    }

    let content = Self.instruction(for: report, destination: destination)

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(GeminiConfig.openClawGatewayToken)",
                     forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("agent:main:glass", forHTTPHeaderField: "x-openclaw-session-key")
    request.setValue("glass", forHTTPHeaderField: "x-openclaw-message-channel")

    let body: [String: Any] = [
      "model": "openclaw",
      "messages": [["role": "user", "content": content]],
      "stream": false
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      let code = (response as? HTTPURLResponse)?.statusCode ?? 0
      let bodyStr = String(data: data, encoding: .utf8) ?? ""
      throw HECASenderError.http(code, String(bodyStr.prefix(300)))
    }

    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let choices = json["choices"] as? [[String: Any]],
       let first = choices.first,
       let message = first["message"] as? [String: Any],
       let result = message["content"] as? String {
      return result
    }
    return "Sent."
  }

  /// Build a plain-text instruction + summary for the agent.
  static func instruction(for report: HECAReport, destination: String?) -> String {
    var lines: [String] = []
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .short

    if let destination, !destination.isEmpty {
      lines.append("Please file or send the following High Energy Control Assessment "
        + "(HECA) report to: \(destination).")
    } else {
      lines.append("Please file the following High Energy Control Assessment (HECA) report.")
    }
    lines.append("")
    lines.append("HECA Report — \(df.string(from: report.createdAt))")
    lines.append("Summary: \(report.summary)")
    lines.append("HECA score: \(report.hecaScorePercent)% "
      + "(\(report.directlyControlledHazards.count) of "
      + "\(report.presentHazards.count) present high-energy hazards have a direct control)")
    lines.append("")
    lines.append("Present high-energy hazards:")
    let present = report.presentHazards
    if present.isEmpty {
      lines.append("None marked present.")
    } else {
      for (index, h) in present.enumerated() {
        let direct = h.hasDirectControl
          ? "Direct: \(h.directControl.isEmpty ? "yes" : h.directControl)"
          : "Direct: none"
        let indirect = h.hasIndirectControl
          ? "Indirect: \(h.indirectControl.isEmpty ? "yes" : h.indirectControl)"
          : "Indirect: none"
        var line = "\(index + 1). \(h.category.displayName) "
          + "[\(h.category.energySource.displayName)] — \(direct); \(indirect)."
        if !h.comments.isEmpty { line += " Comments: \(h.comments)" }
        lines.append(line)
      }
    }
    return lines.joined(separator: "\n")
  }
}
