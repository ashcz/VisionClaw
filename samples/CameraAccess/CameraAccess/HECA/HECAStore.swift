//
// HECAStore.swift
//
// Persists HECA reports to the app's Documents directory and renders annotated
// images (bounding boxes burned into the photo) for saving, PDF export, and sharing.
//

import UIKit

/// A saved HECA assessment on disk.
struct HECARecord: Identifiable {
  let id: String          // timestamp-based folder name
  let directory: URL
  let report: HECAReport
}

enum HECAStore {
  private static let folderName = "HECAReports"

  private static var rootDirectory: URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return docs.appendingPathComponent(folderName, isDirectory: true)
  }

  // MARK: - Save

  /// Save a report plus its original and annotated images. Returns the record directory.
  @discardableResult
  static func save(report: HECAReport, original: UIImage, transcript: String? = nil) throws -> URL {
    let stamp = Self.timestamp(report.createdAt)
    let dir = rootDirectory.appendingPathComponent(stamp, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    // report.json
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let json = try encoder.encode(report)
    try json.write(to: dir.appendingPathComponent("report.json"))

    // transcript.txt (conversation log, when provided)
    if let transcript, !transcript.isEmpty {
      try? transcript.write(to: dir.appendingPathComponent("transcript.txt"),
                            atomically: true, encoding: .utf8)
    }

    // original.jpg
    if let jpeg = original.jpegData(compressionQuality: 0.85) {
      try jpeg.write(to: dir.appendingPathComponent("original.jpg"))
    }

    // annotated.png
    let annotated = annotatedImage(report: report, original: original)
    if let png = annotated.pngData() {
      try png.write(to: dir.appendingPathComponent("annotated.png"))
    }

    return dir
  }

  // MARK: - Load

  static func list() -> [HECARecord] {
    let fm = FileManager.default
    guard let dirs = try? fm.contentsOfDirectory(
      at: rootDirectory, includingPropertiesForKeys: nil
    ) else { return [] }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    return dirs.compactMap { dir -> HECARecord? in
      let reportURL = dir.appendingPathComponent("report.json")
      guard
        let data = try? Data(contentsOf: reportURL),
        let report = try? decoder.decode(HECAReport.self, from: data)
      else { return nil }
      return HECARecord(id: dir.lastPathComponent, directory: dir, report: report)
    }
    .sorted { $0.report.createdAt > $1.report.createdAt }
  }

  /// Load the annotated image saved for a record, if present.
  static func annotatedImage(for record: HECARecord) -> UIImage? {
    let url = record.directory.appendingPathComponent("annotated.png")
    guard let data = try? Data(contentsOf: url) else { return nil }
    return UIImage(data: data)
  }

  /// Load the original (un-annotated) image saved for a record, if present.
  static func originalImage(for record: HECARecord) -> UIImage? {
    let url = record.directory.appendingPathComponent("original.jpg")
    guard let data = try? Data(contentsOf: url) else { return nil }
    return UIImage(data: data)
  }

  /// Delete a saved record and its files.
  static func delete(_ record: HECARecord) {
    try? FileManager.default.removeItem(at: record.directory)
  }

  // MARK: - Annotated image

  /// Draw labeled bounding boxes for each unsafe-condition evidence onto a copy
  /// of the original image, numbered to match the report's evidence order.
  static func annotatedImage(report: HECAReport, original: UIImage) -> UIImage {
    let size = original.size
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
      original.draw(in: CGRect(origin: .zero, size: size))
      let cg = ctx.cgContext
      let lineWidth = max(2, size.width * 0.005)

      for (index, item) in report.allEvidence.enumerated() {
        guard let box = item.evidence.box2d, box.count == 4 else { continue }
        let rect = Self.rect(fromBox2d: box, imageSize: size)
        let color = Self.color(for: report.controlStatus(for: item.category))

        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(lineWidth)
        cg.stroke(rect)

        // Label
        let label = "\(index + 1). \(item.category.displayName)"
        let fontSize = max(12, size.width * 0.025)
        let attrs: [NSAttributedString.Key: Any] = [
          .font: UIFont.boldSystemFont(ofSize: fontSize),
          .foregroundColor: UIColor.white
        ]
        let textSize = (label as NSString).size(withAttributes: attrs)
        let padding: CGFloat = 4
        let labelRect = CGRect(
          x: rect.minX,
          y: max(0, rect.minY - textSize.height - padding * 2),
          width: textSize.width + padding * 2,
          height: textSize.height + padding * 2
        )
        cg.setFillColor(color.cgColor)
        cg.fill(labelRect)
        (label as NSString).draw(
          at: CGPoint(x: labelRect.minX + padding, y: labelRect.minY + padding),
          withAttributes: attrs
        )
      }
    }
  }

  /// Convert a Gemini box_2d [ymin, xmin, ymax, xmax] (0...1000) to image-space CGRect.
  static func rect(fromBox2d box: [Int], imageSize: CGSize) -> CGRect {
    let ymin = CGFloat(box[0]) / 1000 * imageSize.height
    let xmin = CGFloat(box[1]) / 1000 * imageSize.width
    let ymax = CGFloat(box[2]) / 1000 * imageSize.height
    let xmax = CGFloat(box[3]) / 1000 * imageSize.width
    return CGRect(x: xmin, y: ymin, width: max(0, xmax - xmin), height: max(0, ymax - ymin))
  }

  static func color(for status: HECAControlStatus) -> UIColor {
    switch status {
    case .direct: return UIColor.systemGreen
    case .indirect: return UIColor.systemYellow
    case .none: return UIColor.systemRed
    }
  }

  private static func timestamp(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f.string(from: date)
  }
}
