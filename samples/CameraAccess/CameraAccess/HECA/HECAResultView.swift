//
// HECAResultView.swift
//
// Presents a completed HECA assessment: the captured image with bounding-box
// overlays, an overall HECA score, the hazard list, and actions to export a PDF
// (iOS share sheet) or send the report to OpenClaw.
//

import SwiftUI

struct HECAResultView: View {
  @ObservedObject var hecaVM: HECASessionViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var destination: String = ""

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if let report = hecaVM.report, let image = hecaVM.capturedImage {
            scoreHeader(report)
            annotatedImage(image: image, report: report)

            if !report.summary.isEmpty {
              Text(report.summary)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            }

            hazardList(report)
            actions(report)
            disclaimer
          } else {
            Text("No assessment available.")
              .foregroundColor(.secondary)
          }
        }
        .padding()
      }
      .navigationTitle("HECA Result")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .sheet(isPresented: $hecaVM.showShareSheet) {
        if let url = hecaVM.pdfURL {
          HECAShareSheet(items: [url])
        }
      }
    }
  }

  // MARK: - Sections

  private func scoreHeader(_ report: HECAReport) -> some View {
    HStack(spacing: 16) {
      ZStack {
        Circle()
          .stroke(scoreColor(report).opacity(0.25), lineWidth: 8)
        Circle()
          .trim(from: 0, to: CGFloat(report.hecaScore))
          .stroke(scoreColor(report), style: StrokeStyle(lineWidth: 8, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Text("\(report.hecaScorePercent)%")
          .font(.system(size: 18, weight: .bold))
      }
      .frame(width: 72, height: 72)

      VStack(alignment: .leading, spacing: 4) {
        Text("HECA Score")
          .font(.system(size: 16, weight: .semibold))
        Text("\(report.directlyControlledHighEnergyHazards.count) of "
          + "\(report.highEnergyHazards.count) high-energy hazards have a direct control")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }
      Spacer()
    }
  }

  private func annotatedImage(image: UIImage, report: HECAReport) -> some View {
    GeometryReader { geo in
      let displaySize = fittedSize(imageSize: image.size, container: geo.size.width)
      ZStack(alignment: .topLeading) {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          .frame(width: displaySize.width, height: displaySize.height)

        ForEach(Array(report.hazards.enumerated()), id: \.element.id) { index, hazard in
          if let box = hazard.box2d, box.count == 4 {
            let rect = boxRect(box, displaySize: displaySize)
            Rectangle()
              .stroke(color(for: hazard.controlStatus), lineWidth: 2)
              .frame(width: rect.width, height: rect.height)
              .overlay(alignment: .topLeading) {
                Text("\(index + 1)")
                  .font(.system(size: 11, weight: .bold))
                  .foregroundColor(.white)
                  .padding(.horizontal, 5)
                  .padding(.vertical, 2)
                  .background(color(for: hazard.controlStatus))
                  .offset(y: -18)
              }
              .offset(x: rect.minX, y: rect.minY)
          }
        }
      }
      .frame(width: geo.size.width, height: displaySize.height, alignment: .topLeading)
    }
    .frame(height: fittedSize(imageSize: (hecaVM.capturedImage ?? image).size,
                              container: UIScreen.main.bounds.width - 32).height)
  }

  private func hazardList(_ report: HECAReport) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Hazards (\(report.hazards.count))")
        .font(.system(size: 16, weight: .semibold))

      if report.hazards.isEmpty {
        Text("No energy-based hazards were identified in this image.")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }

      ForEach(Array(report.hazards.enumerated()), id: \.element.id) { index, hazard in
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            Text("\(index + 1)")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.white)
              .frame(width: 22, height: 22)
              .background(color(for: hazard.controlStatus))
              .clipShape(Circle())
            Text(hazard.description)
              .font(.system(size: 14, weight: .medium))
            Spacer()
          }

          HStack(spacing: 6) {
            badge(hazard.energySource.displayName, color: .blue)
            if hazard.isHighEnergy {
              badge("High-energy", color: .red)
            } else {
              badge("Low-energy", color: .gray)
            }
            badge(hazard.controlStatus.displayName, color: color(for: hazard.controlStatus))
          }

          if !hazard.controlDescription.isEmpty {
            Text("Control: \(hazard.controlDescription)")
              .font(.system(size: 12))
              .foregroundColor(.secondary)
          }
          if !hazard.recommendation.isEmpty {
            Text("Recommendation: \(hazard.recommendation)")
              .font(.system(size: 12))
              .foregroundColor(.primary)
          }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
      }
    }
  }

  private func actions(_ report: HECAReport) -> some View {
    VStack(spacing: 10) {
      Button {
        hecaVM.exportPDF()
      } label: {
        Label("Export / Share PDF", systemImage: "square.and.arrow.up")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)

      VStack(spacing: 6) {
        TextField("Send to (optional email or note)", text: $destination)
          .textFieldStyle(.roundedBorder)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)

        Button {
          hecaVM.sendToOpenClaw(destination: destination.isEmpty ? nil : destination)
        } label: {
          HStack {
            if hecaVM.isSending { ProgressView().scaleEffect(0.8) }
            Label("Send to OpenClaw", systemImage: "paperplane")
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!hecaVM.openClawConfigured || hecaVM.isSending)

        if !hecaVM.openClawConfigured {
          Text("Configure OpenClaw in Settings to enable sending.")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        if let status = hecaVM.sendStatusMessage {
          Text(status)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
      }
    }
    .padding(.top, 4)
  }

  private var disclaimer: some View {
    Text("AI-generated assessment. Verify all findings on site before acting. "
      + "This is not professional safety advice and does not guarantee workplace safety.")
      .font(.system(size: 11))
      .foregroundColor(.secondary)
      .padding(.top, 8)
  }

  // MARK: - Helpers

  private func badge(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .medium))
      .foregroundColor(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(color.opacity(0.15))
      .clipShape(Capsule())
  }

  private func color(for status: HECAControlStatus) -> Color {
    switch status {
    case .direct: return .green
    case .indirect: return .yellow
    case .none: return .red
    }
  }

  private func scoreColor(_ report: HECAReport) -> Color {
    switch report.hecaScore {
    case 0.999...: return .green
    case 0.5..<0.999: return .yellow
    default: return .red
    }
  }

  private func fittedSize(imageSize: CGSize, container: CGFloat) -> CGSize {
    guard imageSize.width > 0 else { return CGSize(width: container, height: container) }
    let aspect = imageSize.height / imageSize.width
    return CGSize(width: container, height: container * aspect)
  }

  private func boxRect(_ box: [Int], displaySize: CGSize) -> CGRect {
    let ymin = CGFloat(box[0]) / 1000 * displaySize.height
    let xmin = CGFloat(box[1]) / 1000 * displaySize.width
    let ymax = CGFloat(box[2]) / 1000 * displaySize.height
    let xmax = CGFloat(box[3]) / 1000 * displaySize.width
    return CGRect(x: xmin, y: ymin, width: max(0, xmax - xmin), height: max(0, ymax - ymin))
  }
}
