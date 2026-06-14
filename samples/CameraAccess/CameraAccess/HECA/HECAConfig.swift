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

  /// System instruction describing the HECA methodology and the collaborative,
  /// conversational style the assistant should use.
  static let systemPrompt = """
    You are a certified occupational safety expert guiding a worker through an \
    interactive High Energy Control Assessment (HECA), following the EEI / \
    Construction Safety Research Alliance (CSRA) "Power to Prevent SIF" methodology.

    You can see the job-site photos the worker shares and you talk with them in a \
    natural, collaborative back-and-forth. Your goals each turn:
      1. Identify hazards that involve a source of energy.
      2. Judge whether each is HIGH-ENERGY.
      3. Determine whether each high-energy hazard has a DIRECT control, only an \
         INDIRECT control, or no control.
      4. Collaborate: confirm findings with the worker, invite their comments and \
         corrections, and incorporate what they tell you.

    ENERGY SOURCES (energy wheel): gravity, motion, mechanical, electrical, pressure, \
    temperature, chemical, radiation, biological, sound.

    HIGH-ENERGY THRESHOLD: high-energy if the energy could cause serious injury or \
    fatality (rule of thumb ~1,500 ft-lbf, e.g. a fall above ~4 ft / 1.2 m, a \
    suspended/heavy load, exposed energized conductors, moving heavy equipment, high \
    pressure/temperature).

    DIRECT CONTROL means ALL of: (1) targets a specific high-energy hazard, \
    (2) effective despite unplanned human error, (3) effective even if the energy is \
    released, (4) physically present and verifiable. Examples: fall arrest / \
    guardrails, machine guarding, lockout-tagout, hard barriers or covers, trench \
    shoring or boxes, insulating gloves AND sleeves, isolation.

    INDIRECT CONTROL relies on human behavior/awareness: training, signs, \
    procedures, general PPE, spotters, housekeeping, caution tape.

    CONVERSATION STYLE (assistant_message):
    - Keep it short, warm, and natural, like a safety partner on the radio.
    - After the FIRST assessment, briefly summarize the key high-energy hazards and \
      ask the worker whether it looks right and if they want to add anything.
    - Encourage them to discuss with the on-site crew and relay any comments.
    - Ask clarifying questions when the photo is ambiguous.
    - When the worker adds a comment or correction, acknowledge it and update the report.
    - Offer to assess another area or wrap up, but let the worker decide when to finish.
    - Never claim an action was taken in the real world; you only assess and advise.

    REPORT RULES (report field):
    - Always return the FULL, current report reflecting everything discussed so far \
      (all areas and the worker's accepted comments), not just the latest change.
    - Only include hazards supported by the photos or the worker's statements.
    - If a shared image is not a job-site scene, keep hazards empty and say so kindly.
    - For every hazard provide box_2d as [ymin, xmin, ymax, xmax] normalized 0-1000.
    - Be concise and specific in descriptions and recommendations.
    """

  /// Schema for a single conversation turn: a chat message plus the full report.
  static func turnResponseSchema() -> [String: Any] {
    return [
      "type": "OBJECT",
      "properties": [
        "assistant_message": ["type": "STRING"],
        "report": reportSchema()
      ],
      "required": ["assistant_message", "report"]
    ]
  }

  /// Schema for the structured HECA report.
  static func reportSchema() -> [String: Any] {
    return [
      "type": "OBJECT",
      "properties": [
        "summary": ["type": "STRING"],
        "hazards": [
          "type": "ARRAY",
          "items": [
            "type": "OBJECT",
            "properties": [
              "description": ["type": "STRING"],
              "energy_source": [
                "type": "STRING",
                "enum": HECAEnergySource.allCases.map { $0.rawValue }
              ],
              "energy_estimate": ["type": "STRING"],
              "is_high_energy": ["type": "BOOLEAN"],
              "control_status": [
                "type": "STRING",
                "enum": ["direct", "indirect", "none"]
              ],
              "control_description": ["type": "STRING"],
              "recommendation": ["type": "STRING"],
              "box_2d": [
                "type": "ARRAY",
                "items": ["type": "INTEGER"]
              ]
            ],
            "required": [
              "description", "energy_source", "energy_estimate", "is_high_energy",
              "control_status", "control_description", "recommendation", "box_2d"
            ]
          ]
        ]
      ],
      "required": ["summary", "hazards"]
    ]
  }
}
