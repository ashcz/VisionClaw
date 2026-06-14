//
// HECAConfig.swift
//
// Configuration, prompt, and response schema for the one-shot HECA vision call.
//
// Unlike the live assistant (which streams over a WebSocket), HECA uses a single
// REST `generateContent` request to a standard multimodal model and asks for a
// structured JSON response.
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

  /// System / task instruction describing the HECA methodology.
  static let systemPrompt = """
    You are a certified occupational safety expert performing a High Energy Control \
    Assessment (HECA) on a job-site photo, following the EEI / Construction Safety \
    Research Alliance (CSRA) "Power to Prevent SIF" methodology.

    Your job: identify hazards in the image that involve a source of energy, judge \
    whether each is HIGH-ENERGY, and determine whether each high-energy hazard is \
    safeguarded by a DIRECT control, only an INDIRECT control, or no control.

    ENERGY SOURCES (energy wheel): gravity, motion, mechanical, electrical, pressure, \
    temperature, chemical, radiation, biological, sound.

    HIGH-ENERGY THRESHOLD: a hazard is high-energy if the energy involved is capable of \
    causing serious injury or fatality (rule of thumb ~1,500 ft-lbf, e.g. a fall above \
    ~4 ft / 1.2 m, a suspended/heavy load, exposed energized electrical conductors, \
    moving heavy equipment, high pressure/temperature, etc.).

    DIRECT CONTROL — a safeguard that meets ALL of these:
      1. specifically targets a recognized high-energy hazard,
      2. remains effective even with unplanned human error or inattention,
      3. remains effective even if the energy is released,
      4. is physically present and verifiable in the image.
      Examples: fall arrest / guardrails, machine guarding, lockout-tagout, hard \
      barriers or covers, trench shoring or boxes, insulating gloves AND sleeves on \
      energized work, isolation.

    INDIRECT CONTROL — relies on human behavior or awareness and does NOT meet the \
    direct-control test. Examples: training, warning signs, procedures, general PPE \
    (hard hat, hi-vis, safety glasses), spotters, housekeeping, caution tape.

    RULES:
    - Only assess what is visibly supported by the image. Do not invent hazards.
    - If the image is not a job-site / work scene, return an empty hazards array and \
      say so in the summary.
    - For every hazard, provide a bounding box (box_2d) as [ymin, xmin, ymax, xmax] \
      normalized to 0-1000 over the image.
    - Be concise and specific in descriptions and recommendations.
    """

  /// JSON schema constraining the model's structured output.
  static func responseSchema() -> [String: Any] {
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
