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
      _ = drawHazards(report, startY: y + 12, ctx: ctx)
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
      + "Present high-energy hazards: \(report.presentHazards.count)"
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

  private static func drawHazards(_ report: HECAReport, startY: CGFloat,
                                  ctx: UIGraphicsPDFRendererContext) -> CGFloat {
    let contentWidth = pageSize.width - margin * 2
    var y = startY

    let present = report.presentHazards
    "Present High-Energy Hazards".draw(
      in: CGRect(x: margin, y: y, width: contentWidth, height: 18),
      withAttributes: [
        .font: UIFont.boldSystemFont(ofSize: 13),
        .foregroundColor: UIColor.black
      ])
    y += 22

    if present.isEmpty {
      "No high-energy hazards were marked present.".draw(
        in: CGRect(x: margin, y: y, width: contentWidth, height: 16),
        withAttributes: [
          .font: UIFont.systemFont(ofSize: 11),
          .foregroundColor: UIColor.darkGray
        ])
      return y + 18
    }

    for (index, hazard) in present.enumerated() {
      if y > pageSize.height - margin - 70 {
        ctx.beginPage()
        y = margin
      }

      let swatch = CGRect(x: margin, y: y + 2, width: 10, height: 10)
      HECAStore.color(for: hazard.controlStatus).setFill()
      UIBezierPath(rect: swatch).fill()

      let header = "\(index + 1). \(hazard.category.displayName)"
      header.draw(in: CGRect(x: margin + 16, y: y, width: contentWidth - 16, height: 16),
                  withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 11),
                    .foregroundColor: UIColor.black
                  ])
      y += 16

      let direct = hazard.hasDirectControl
        ? "Direct: \(hazard.directControl.isEmpty ? "yes" : hazard.directControl)"
        : "Direct: none"
      let indirect = hazard.hasIndirectControl
        ? "Indirect: \(hazard.indirectControl.isEmpty ? "yes" : hazard.indirectControl)"
        : "Indirect: none"
      let detail = "\(hazard.category.energySource.displayName) · \(direct) · \(indirect)"
      let detailRect = CGRect(x: margin + 16, y: y, width: contentWidth - 16, height: 28)
      (detail as NSString).draw(in: detailRect, withAttributes: [
        .font: UIFont.systemFont(ofSize: 10),
        .foregroundColor: UIColor.darkGray
      ])
      y += 28

      if !hazard.comments.isEmpty {
        let comment = "Comments: \(hazard.comments)"
        let commentRect = CGRect(x: margin + 16, y: y, width: contentWidth - 16, height: 28)
        (comment as NSString).draw(in: commentRect, withAttributes: [
          .font: UIFont.italicSystemFont(ofSize: 10),
          .foregroundColor: UIColor.black
        ])
        y += 28
      }
      y += 6
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
