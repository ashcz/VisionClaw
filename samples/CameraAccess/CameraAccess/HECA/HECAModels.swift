//
// HECAModels.swift
//
// Data models for the High Energy Control Assessment (HECA) feature.
//
// HECA is based on the EEI / Construction Safety Research Alliance (CSRA)
// "Power to Prevent SIF" methodology. The app captures a job-site image,
// asks a vision model to identify energy-based hazards, and classifies whether
// each high-energy hazard has a *direct control* (vs. an indirect control or
// no control). The HECA score is the fraction of high-energy hazards that are
// safeguarded by a direct control.
//

import Foundation
import UIKit

/// A single message in the interactive HECA conversation.
struct HECAChatMessage: Identifiable {
  enum Role {
    case user
    case assistant
    case system
  }

  let id = UUID()
  let role: Role
  let text: String
  /// Optional image attached to this message (e.g. a captured job-site area).
  let image: UIImage?
  let timestamp = Date()

  init(role: Role, text: String, image: UIImage? = nil) {
    self.role = role
    self.text = text
    self.image = image
  }
}

/// One assistant turn: a conversational message plus the full updated report.
struct HECATurn: Codable {
  let assistantMessage: String
  let report: HECAReport

  enum CodingKeys: String, CodingKey {
    case assistantMessage = "assistant_message"
    case report
  }
}


/// The energy sources from the EEI/CSRA "energy wheel".
enum HECAEnergySource: String, Codable, CaseIterable {
  case gravity
  case motion
  case mechanical
  case electrical
  case pressure
  case temperature
  case chemical
  case radiation
  case biological
  case sound
  case other

  var displayName: String {
    rawValue.prefix(1).uppercased() + rawValue.dropFirst()
  }
}

/// Whether a hazard is safeguarded by a direct control, an indirect control, or nothing.
///
/// A *direct control* (per EEI/CSRA) must: target a specific high-energy hazard,
/// remain effective despite unplanned human error, remain effective if the energy is
/// released, and be physically present / verifiable (e.g. fall arrest, machine guarding,
/// lockout-tagout, trench shoring, hard barriers, insulating gloves & sleeves).
///
/// An *indirect control* relies on human behavior (training, signs, procedures,
/// general PPE, spotters, hi-vis, housekeeping).
enum HECAControlStatus: String, Codable {
  case direct
  case indirect
  case none

  var displayName: String {
    switch self {
    case .direct: return "Direct control"
    case .indirect: return "Indirect control"
    case .none: return "No control"
    }
  }
}

/// A single hazard identified in the scene.
struct HECAHazard: Codable, Identifiable {
  var id = UUID()
  let description: String
  let energySource: HECAEnergySource
  /// Free-text estimate of the energy magnitude (e.g. "fall from ~4 m", ">1500 ft-lbf").
  let energyEstimate: String
  /// True if the hazard is capable of causing a serious injury or fatality
  /// (high-energy threshold ~1,500 ft-lbf).
  let isHighEnergy: Bool
  let controlStatus: HECAControlStatus
  /// Description of the control that is present (or absent).
  let controlDescription: String
  /// Recommended action to establish or improve a direct control.
  let recommendation: String
  /// Normalized bounding box [ymin, xmin, ymax, xmax] in 0...1000 (Gemini convention).
  let box2d: [Int]?

  enum CodingKeys: String, CodingKey {
    case description
    case energySource = "energy_source"
    case energyEstimate = "energy_estimate"
    case isHighEnergy = "is_high_energy"
    case controlStatus = "control_status"
    case controlDescription = "control_description"
    case recommendation
    case box2d = "box_2d"
  }
}

/// A full HECA assessment for one captured image.
struct HECAReport: Codable, Identifiable {
  var id = UUID()
  var createdAt: Date = Date()
  let hazards: [HECAHazard]
  /// One- or two-sentence overall summary of the scene and key risks.
  let summary: String

  enum CodingKeys: String, CodingKey {
    case hazards
    case summary
  }

  /// High-energy hazards only.
  var highEnergyHazards: [HECAHazard] {
    hazards.filter { $0.isHighEnergy }
  }

  /// High-energy hazards that have a direct control in place.
  var directlyControlledHighEnergyHazards: [HECAHazard] {
    highEnergyHazards.filter { $0.controlStatus == .direct }
  }

  /// HECA score: fraction (0...1) of high-energy hazards with a direct control.
  /// Returns 1.0 when there are no high-energy hazards (nothing left exposed).
  var hecaScore: Double {
    let total = highEnergyHazards.count
    guard total > 0 else { return 1.0 }
    return Double(directlyControlledHighEnergyHazards.count) / Double(total)
  }

  /// HECA score formatted as a whole-number percentage.
  var hecaScorePercent: Int {
    Int((hecaScore * 100).rounded())
  }
}
