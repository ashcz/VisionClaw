//
// HECAModels.swift
//
// Data models for the High Energy Control Assessment (HECA) feature.
//
// HECA is based on the EEI / Construction Safety Research Alliance (CSRA)
// "Power to Prevent SIF" methodology. The worker captures a job-site image and
// completes a structured assessment against the EEI catalog of high-energy
// hazards (Appendix 3 of the EEI HECA guide). For each high-energy hazard that
// is present, the worker records whether a DIRECT control and/or an INDIRECT
// control is in place, plus comments. The HECA score is the fraction of present
// high-energy hazards that are safeguarded by a direct control.
//

import Foundation
import UIKit

// MARK: - Chat

/// A single message in the optional HECA advisor conversation.
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

/// Whether a present high-energy hazard is safeguarded by a direct control, only
/// an indirect control, or nothing.
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

// MARK: - Hazard catalog (EEI Appendix 3)

/// The 13 categorical high-energy hazards from the EEI HECA guide (Appendix 3),
/// each of which is "almost always in excess of 500 ft-lbs of physical energy".
enum HECAHazardCategory: String, Codable, CaseIterable, Identifiable {
  case suspendedLoad = "suspended_load"
  case fallFromElevation = "fall_from_elevation"
  case mobileEquipment = "mobile_equipment"
  case motorVehicleSpeed = "motor_vehicle_speed"
  case mechanicalRotating = "mechanical_rotating"
  case highTemperature = "high_temperature"
  case steam = "steam"
  case fire = "fire"
  case explosion = "explosion"
  case excavation = "excavation"
  case electricalContact = "electrical_contact"
  case arcFlash = "arc_flash"
  case toxicChemicalRadiation = "toxic_chemical_radiation"

  var id: String { rawValue }

  /// Canonical order, matching the EEI Appendix 3 icon table.
  static var catalog: [HECAHazardCategory] { allCases }

  var displayName: String {
    switch self {
    case .suspendedLoad: return "Suspended Load"
    case .fallFromElevation: return "Fall from Elevation"
    case .mobileEquipment: return "Mobile Equipment / Traffic"
    case .motorVehicleSpeed: return "Motor Vehicle Speed"
    case .mechanicalRotating: return "Heavy Rotating Equipment"
    case .highTemperature: return "High Temperature"
    case .steam: return "Steam"
    case .fire: return "Fire"
    case .explosion: return "Explosion"
    case .excavation: return "Trench / Excavation"
    case .electricalContact: return "Electrical Contact"
    case .arcFlash: return "Arc Flash"
    case .toxicChemicalRadiation: return "Toxic Chemical / Radiation"
    }
  }

  var energySource: HECAEnergySource {
    switch self {
    case .suspendedLoad, .fallFromElevation, .excavation: return .gravity
    case .mobileEquipment, .motorVehicleSpeed: return .motion
    case .mechanicalRotating: return .mechanical
    case .highTemperature, .steam, .fire: return .temperature
    case .explosion: return .pressure
    case .electricalContact, .arcFlash: return .electrical
    case .toxicChemicalRadiation: return .chemical
    }
  }

  /// SF Symbol used as the hazard icon in the grid.
  var systemImage: String {
    switch self {
    case .suspendedLoad: return "shippingbox.fill"
    case .fallFromElevation: return "figure.fall"
    case .mobileEquipment: return "bus.fill"
    case .motorVehicleSpeed: return "car.fill"
    case .mechanicalRotating: return "gearshape.2.fill"
    case .highTemperature: return "thermometer.high"
    case .steam: return "humidity.fill"
    case .fire: return "flame.fill"
    case .explosion: return "burst.fill"
    case .excavation: return "square.3.layers.3d.down.right"
    case .electricalContact: return "bolt.fill"
    case .arcFlash: return "bolt.trianglebadge.exclamationmark.fill"
    case .toxicChemicalRadiation: return "aqi.medium"
    }
  }

  /// The EEI high-energy threshold note for this hazard.
  var threshold: String {
    switch self {
    case .suspendedLoad:
      return "Load > ~500 lbs lifted > 1 ft (gravity + motion)."
    case .fallFromElevation:
      return "Fall > 4 ft (a ~150 lb person exceeds the threshold)."
    case .mobileEquipment:
      return "Mobile equipment / vehicles in motion near a worker on foot."
    case .motorVehicleSpeed:
      return "Vehicle occupants at speeds > ~30 mph."
    case .mechanicalRotating:
      return "Heavy rotating equipment beyond powered hand tools."
    case .highTemperature:
      return "Contact with substances ≥ 150 °F."
    case .steam:
      return "Any release of steam."
    case .fire:
      return "Fire with a sustained source of fuel."
    case .explosion:
      return "Any incident described as an explosion."
    case .excavation:
      return "Unsupported soil in a trench/excavation > 5 ft deep."
    case .electricalContact:
      return "Electrical contact ≥ 50 volts (NFPA 70E)."
    case .arcFlash:
      return "Any arc flash (NFPA 70E / OSHA 1910.333)."
    case .toxicChemicalRadiation:
      return "Toxic chemical or radiation (IDLH, O₂ < 16%, pH < 2 or > 12.5)."
    }
  }

  /// Common DIRECT controls (effective even when a worker makes a mistake).
  var directControlExamples: [String] {
    switch self {
    case .suspendedLoad:
      return ["Engineered rigging & exclusion zone", "Load path barricaded / no workers under load",
              "Certified lifting plan with hard barriers"]
    case .fallFromElevation:
      return ["Personal fall arrest (anchor, lanyard, harness)", "Guardrail system", "Safety net",
              "Engineered hole cover"]
    case .mobileEquipment:
      return ["Hard physical barrier / jersey wall", "Positive separation (equipment locked out of zone)",
              "Engineered exclusion zone"]
    case .motorVehicleSpeed:
      return ["Seat belt + airbags", "Engineered speed control / governor", "Physical road closure"]
    case .mechanicalRotating:
      return ["Fixed machine guarding", "Lockout / Tagout (LOTO)", "Interlocked barrier guard"]
    case .highTemperature:
      return ["Isolation & cool-down / LOTO", "Engineered shielding / insulation",
              "Full-coverage specialized heat PPE"]
    case .steam:
      return ["De-pressurization & isolation (LOTO)", "Engineered blow-down / shielding"]
    case .fire:
      return ["Fuel source removed / isolated", "Engineered fire suppression", "Hot-work fire blanket enclosure"]
    case .explosion:
      return ["Energy isolation / purge & inert", "Blast containment / barricade",
              "Combustible gas isolation (LOTO)"]
    case .excavation:
      return ["Trench shield / box", "Engineered shoring", "Properly benched / sloped per soil"]
    case .electricalContact:
      return ["De-energize, verify & Lockout/Tagout", "Full insulation (gloves AND sleeves)",
              "Engineered cover-up / isolation"]
    case .arcFlash:
      return ["De-energize, verify & LOTO", "Full arc-rated suit at correct cal/cm²",
              "Remote racking / operation"]
    case .toxicChemicalRadiation:
      return ["Source isolation / substitution", "Engineered ventilation to below IDLH",
              "Supplied-air respirator / full encapsulation"]
    }
  }

  /// Common INDIRECT controls (rely on human behavior; vulnerable to error).
  var indirectControlExamples: [String] {
    switch self {
    case .mobileEquipment, .motorVehicleSpeed:
      return ["Spotter / flagger", "Hi-vis clothing", "Signage & training", "Situational awareness"]
    case .electricalContact, .arcFlash:
      return ["Caution signage", "Training & procedures", "Minimum approach distance awareness"]
    default:
      return ["Training & procedures", "Warning signage", "General PPE", "Housekeeping", "Situational awareness"]
    }
  }
}

// MARK: - Assessment

/// Annotated evidence of an unsafe condition for a hazard.
struct HECAEvidence: Codable, Identifiable {
  var id = UUID()
  var note: String
  /// Normalized bounding box [ymin, xmin, ymax, xmax] in 0...1000 (Gemini convention).
  var box2d: [Int]?

  enum CodingKeys: String, CodingKey {
    case note
    case box2d = "box_2d"
  }

  init(note: String, box2d: [Int]? = nil) {
    self.note = note
    self.box2d = box2d
  }
}

/// The worker's (AI-assisted) assessment of a single hazard category.
struct HECACategoryAssessment: Codable, Identifiable {
  let category: HECAHazardCategory
  /// Whether this high-energy hazard is present in the assessed scene.
  var isPresent: Bool
  /// Whether a qualifying DIRECT control is in place.
  var hasDirectControl: Bool
  /// The specific direct control in place (free text / picker selection).
  var directControl: String
  /// Whether an INDIRECT control is in place.
  var hasIndirectControl: Bool
  /// The specific indirect control in place.
  var indirectControl: String
  /// Free-text comments for this hazard.
  var comments: String
  /// Annotated evidence of unsafe conditions.
  var evidence: [HECAEvidence]

  var id: String { category.rawValue }

  /// Effective control status used for scoring and color coding.
  var controlStatus: HECAControlStatus {
    if hasDirectControl { return .direct }
    if hasIndirectControl { return .indirect }
    return .none
  }

  enum CodingKeys: String, CodingKey {
    case category
    case isPresent = "is_present"
    case hasDirectControl = "has_direct_control"
    case directControl = "direct_control"
    case hasIndirectControl = "has_indirect_control"
    case indirectControl = "indirect_control"
    case comments
    case evidence
  }

  /// An empty (not-present) assessment for a category.
  static func empty(for category: HECAHazardCategory) -> HECACategoryAssessment {
    HECACategoryAssessment(
      category: category,
      isPresent: false,
      hasDirectControl: false,
      directControl: "",
      hasIndirectControl: false,
      indirectControl: "",
      comments: "",
      evidence: []
    )
  }
}

// MARK: - Report

/// A full HECA assessment for one captured image: all 13 hazard categories in
/// canonical EEI order, plus an overall summary.
struct HECAReport: Codable, Identifiable {
  var id = UUID()
  var createdAt: Date = Date()
  var summary: String
  /// Always the full 13-row catalog, in canonical order.
  var assessments: [HECACategoryAssessment]

  enum CodingKeys: String, CodingKey {
    case createdAt
    case summary
    case assessments
  }

  /// A blank report with all 13 categories present-flagged false.
  static func blank() -> HECAReport {
    HECAReport(
      summary: "",
      assessments: HECAHazardCategory.catalog.map { .empty(for: $0) }
    )
  }

  /// Build a full 13-row report by overlaying a partial set of assessments
  /// (e.g. from the AI) onto the blank catalog, preserving canonical order.
  static func from(summary: String, partial: [HECACategoryAssessment]) -> HECAReport {
    var byCategory: [HECAHazardCategory: HECACategoryAssessment] = [:]
    for a in partial { byCategory[a.category] = a }
    let merged = HECAHazardCategory.catalog.map { category in
      byCategory[category] ?? .empty(for: category)
    }
    return HECAReport(summary: summary, assessments: merged)
  }

  /// Present high-energy hazards.
  var presentHazards: [HECACategoryAssessment] {
    assessments.filter { $0.isPresent }
  }

  /// Present high-energy hazards that have a direct control in place.
  var directlyControlledHazards: [HECACategoryAssessment] {
    presentHazards.filter { $0.hasDirectControl }
  }

  /// Present high-energy hazards with no direct control (exposures).
  var exposedHazards: [HECACategoryAssessment] {
    presentHazards.filter { !$0.hasDirectControl }
  }

  /// HECA score: fraction (0...1) of present high-energy hazards with a direct
  /// control. Returns 1.0 when nothing is present (nothing left exposed).
  var hecaScore: Double {
    let total = presentHazards.count
    guard total > 0 else { return 1.0 }
    return Double(directlyControlledHazards.count) / Double(total)
  }

  /// HECA score formatted as a whole-number percentage.
  var hecaScorePercent: Int {
    Int((hecaScore * 100).rounded())
  }

  /// All evidence across present hazards, paired with its category.
  var allEvidence: [(category: HECAHazardCategory, evidence: HECAEvidence)] {
    presentHazards.flatMap { a in a.evidence.map { (a.category, $0) } }
  }

  /// The effective control status for a given category in this report.
  func controlStatus(for category: HECAHazardCategory) -> HECAControlStatus {
    assessments.first(where: { $0.category == category })?.controlStatus ?? .none
  }
}
