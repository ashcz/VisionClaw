//
// HECASampleImages.swift
//
// Bundled job-site sample images (from the ChatSafetyAI repository) for testing
// the HECA flow without a live camera.
//
// Source: https://github.com/safetyAI/ChatSafetyAI (job-site sample photos).
//

import UIKit

struct HECASampleImage: Identifiable {
  let id: String          // asset name in Assets.xcassets
  let title: String

  var image: UIImage? { UIImage(named: id) }

  static let all: [HECASampleImage] = [
    HECASampleImage(id: "heca_scaffold", title: "Scaffold"),
    HECASampleImage(id: "heca_manhole", title: "Manhole"),
    HECASampleImage(id: "heca_hotwork", title: "Hot Work"),
    HECASampleImage(id: "heca_formwork", title: "Formwork"),
    HECASampleImage(id: "heca_manlift", title: "Man Lift"),
    HECASampleImage(id: "heca_shotcrete", title: "Shotcrete")
  ]
}
