//
// HECAShareSheet.swift
//
// Thin SwiftUI wrapper around UIActivityViewController for sharing files
// (e.g. an exported HECA PDF) via AirDrop, Files, Mail, Messages, etc.
//

import SwiftUI
import UIKit

struct HECAShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
