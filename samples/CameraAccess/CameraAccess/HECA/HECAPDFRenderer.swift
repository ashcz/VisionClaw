//
// HECAPDFRenderer.swift
//
// Renders a HECA report to a shareable PDF (annotated image + hazard table +
// HECA score + disclaimer).
//

import UIKit

enum HECAPDFRenderer {
  private static let pageSize = CGSize(width: 612, height: 792) // US Letter @72dpi
  private static let margin: CGFloat = 36

  /// Render the report to a PDF file in the temporary directory and return its URL.
  static func render(report: HECAReport, original: UIImage) throws -> URL {
    let annotated = HECAStore.annotatedImage(report: report, original: original)
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("HECA_\(Int(report.createdAt.timeIntervalSince1970)).pdf")

    try renderer.writePDF(to: url) { ctx in
      ctx.beginPage()
      var y = margin

      y = drawTitle(report: report, atY: y)
      y = drawImage(annotated, atY: y + 8)
      _ = drawHazards(report.hazards, startY: y + 12, ctx: ctx)
      drawDisclaimer()
    }
    return url
  }

  // MARK: - Sections

  private static func drawTitle(report: HECAReport, atY y: CGFloat) -> CGFloat {
    let contentWidth = pageSize.width - margin * 2
    let title = "High Energy Control Assessment"
    title.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 24),
               withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.black
               ])

    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .short
    let meta = "\(df.string(from: report.createdAt))    "
      + "HECA score: \(report.hecaScorePercent)%    "
      + "High-energy hazards: \(report.highEnergyHazards.count)"
    meta.draw(in: CGRect(x: margin, y: y + 26, width: contentWidth, height: 18),
              withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray
              ])

    let summary = report.summary
    let summaryRect = CGRect(x: margin, y: y + 46, width: contentWidth, height: 40)
    (summary as NSString).draw(in: summaryRect, withAttributes: [
      .font: UIFont.systemFont(ofSize: 11),
      .foregroundColor: UIColor.black
    ])
    return y + 90
  }

  private static func drawImage(_ image: UIImage, atY y: CGFloat) -> CGFloat {
    let contentWidth = pageSize.width - margin * 2
    let maxHeight: CGFloat = 240
    let aspect = image.size.height / max(1, image.size.width)
    var drawW = contentWidth
    var drawH = drawW * aspect
    if drawH > maxHeight {
      drawH = maxHeight
      drawW = drawH / aspect
    }
    let x = margin + (contentWidth - drawW) / 2
    image.draw(in: CGRect(x: x, y: y, width: drawW, height: drawH))
    return y + drawH
  }

  private static func drawHazards(_ hazards: [HECAHazard], startY: CGFloat,
                                  ctx: UIGraphicsPDFRendererContext) -> CGFloat {
    let contentWidth = pageSize.width - margin * 2
    var y = startY

    "Hazards".draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 18),
                   withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 13),
                    .foregroundColor: UIColor.black
                   ])
    y += 22

    for (index, hazard) in hazards.enumerated() {
      if y > pageSize.height - margin - 60 {
        ctx.beginPage()
        y = margin
      }

      let swatch = CGRect(x: margin, y: y + 2, width: 10, height: 10)
      HECAStore.color(for: hazard.controlStatus).setFill()
      UIBezierPath(rect: swatch).fill()

      let header = "\(index + 1). \(hazard.description)"
      header.draw(in: CGRect(x: margin + 16, y: y, width: contentWidth - 16, height: 16),
                  withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 11),
                    .foregroundColor: UIColor.black
                  ])
      y += 16

      let energyLabel = hazard.isHighEnergy ? "HIGH-ENERGY" : "low-energy"
      let detail = "\(hazard.energySource.displayName) · \(energyLabel) · "
        + "\(hazard.controlStatus.displayName): \(hazard.controlDescription)"
      let detailRect = CGRect(x: margin + 16, y: y, width: contentWidth - 16, height: 28)
      (detail as NSString).draw(in: detailRect, withAttributes: [
        .font: UIFont.systemFont(ofSize: 10),
        .foregroundColor: UIColor.darkGray
      ])
      y += 28

      let rec = "Recommendation: \(hazard.recommendation)"
      let recRect = CGRect(x: margin + 16, y: y, width: contentWidth - 16, height: 28)
      (rec as NSString).draw(in: recRect, withAttributes: [
        .font: UIFont.italicSystemFont(ofSize: 10),
        .foregroundColor: UIColor.black
      ])
      y += 34
    }
    return y
  }

  private static func drawDisclaimer() {
    let contentWidth = pageSize.width - margin * 2
    let text = "AI-generated assessment. Verify all findings on site before acting. "
      + "This is not professional safety advice and does not guarantee workplace safety."
    let rect = CGRect(x: margin, y: pageSize.height - margin - 24, width: contentWidth, height: 24)
    (text as NSString).draw(in: rect, withAttributes: [
      .font: UIFont.italicSystemFont(ofSize: 8),
      .foregroundColor: UIColor.gray
    ])
  }
}
