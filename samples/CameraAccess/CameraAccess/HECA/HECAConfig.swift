//
// HECAConfig.swift
//
// Configuration, prompt, and response schema for the interactive HECA conversation.
//
// HECA runs as a multi-turn conversation against a standard multimodal model via
// the REST `generateContent` endpoint. Each turn returns BOTH a short conversational
// message (to show in the chat) and the full, up-to-date structured report.
//

import Foundation

enum HECAConfig {
  /// Standard multimodal model for one-shot structured vision.
  static let model = "gemini-2.5-flash"

  /// JPEG quality used when encoding the captured frame for upload.
  static let jpegQuality: CGFloat = 0.7

  static func generateContentURL() -> URL? {
    let apiKey = GeminiConfig.apiKey
    guard apiKey != "YOUR_GEMINI_API_KEY", !apiKey.isEmpty else { return nil }
    return URL(string:
      "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")
  }

  /// Catalog reference injected into the prompt so the model uses the exact
  /// category identifiers the app expects.
  private static var categoryReference: String {
    HECAHazardCategory.catalog.map { c in
      "- \(c.rawValue): \(c.displayName) — \(c.threshold)"
    }.joined(separator: "\n")
  }

  /// System instruction for the structured grid assessment.
  static var gridSystemPrompt: String {
    """
    You are a certified occupational safety expert performing a High-Energy \
    Control Assessment (HECA) following the EEI / Construction Safety Research \
    Alliance (CSRA) "Power to Prevent SIF" methodology.

    You are given one job-site photo. Assess it against the EEI catalog of 13 \
    high-energy hazards below. For EVERY one of the 13 categories, decide whether \
    that high-energy hazard is PRESENT in the scene.

    THE 13 HIGH-ENERGY HAZARD CATEGORIES (use these exact category ids):
    \(categoryReference)

    A hazard is HIGH-ENERGY when contact could cause a serious injury or fatality \
    (> ~500 ft-lbs / 1,500 J). Only mark is_present = true when the photo (or the \
    worker's notes) supports it.

    For each PRESENT hazard, judge controls:
    - DIRECT control (has_direct_control): a safeguard that (1) is specifically \
      targeted to that high-energy hazard, (2) eliminates or mitigates the energy \
      below the threshold when installed, verified, and used properly, and (3) \
      remains effective EVEN IF a worker makes an unintentional mistake. Examples: \
      fall arrest systems, fixed machine guarding, de-energization + lockout/tagout, \
      trench shields/shoring, engineered hard barriers, full arc-rated suits.
    - INDIRECT control (has_indirect_control): relies on human behavior/awareness \
      and is vulnerable to error. Examples: training, signage, procedures, general \
      PPE, spotters, hi-vis clothing, housekeeping, situational awareness.
    A hazard can have both, one, or neither. Put the specific control name in \
    direct_control / indirect_control (empty string if none).

    EVIDENCE: when you see a specific UNSAFE condition for a present hazard, add an \
    evidence item with a short note and box_2d = [ymin, xmin, ymax, xmax] normalized \
    0-1000 locating it in the image. Omit evidence when nothing specific is visible.

    RULES:
    - Return ALL 13 categories. For categories not present, set is_present = false \
      and leave controls/comments empty.
    - Be specific and concise in comments and control names.
    - If the image is not a job-site scene, mark everything not present and say so \
      in the summary.
    - The summary is one or two sentences describing the scene and the key SIF risks.
    """
  }

  /// System instruction for the optional advisor chat.
  static let chatSystemPrompt = """
    You are a certified occupational safety expert acting as a calm, collaborative \
    safety partner during a High-Energy Control Assessment (HECA). You can see the \
    job-site photo the worker assessed. Answer their questions, help them decide \
    whether a control qualifies as a DIRECT control (targeted, effective when used \
    properly, and resilient to human error), and suggest specific direct controls. \
    Keep replies short, warm, and practical, like talking on the radio. Never claim \
    an action was taken in the real world; you only assess and advise.
    """

  /// Schema for the single-shot grid assessment response.
  static func gridResponseSchema() -> [String: Any] {
    return [
      "type": "OBJECT",
      "properties": [
        "summary": ["type": "STRING"],
        "assessments": [
          "type": "ARRAY",
          "items": [
            "type": "OBJECT",
            "properties": [
              "category": [
                "type": "STRING",
                "enum": HECAHazardCategory.catalog.map { $0.rawValue }
              ],
              "is_present": ["type": "BOOLEAN"],
              "has_direct_control": ["type": "BOOLEAN"],
              "direct_control": ["type": "STRING"],
              "has_indirect_control": ["type": "BOOLEAN"],
              "indirect_control": ["type": "STRING"],
              "comments": ["type": "STRING"],
              "evidence": [
                "type": "ARRAY",
                "items": [
                  "type": "OBJECT",
                  "properties": [
                    "note": ["type": "STRING"],
                    "box_2d": [
                      "type": "ARRAY",
                      "items": ["type": "INTEGER"]
                    ]
                  ],
                  "required": ["note", "box_2d"]
                ]
              ]
            ],
            "required": [
              "category", "is_present", "has_direct_control", "direct_control",
              "has_indirect_control", "indirect_control", "comments", "evidence"
            ]
          ]
        ]
      ],
      "required": ["summary", "assessments"]
    ]
  }
}
