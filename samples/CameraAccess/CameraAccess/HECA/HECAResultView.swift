//
// HECAResultView.swift
//
// Interactive HECA experience. The worker starts an assessment, then has a
// natural back-and-forth with the assessor: confirming findings, adding
// comments, capturing more areas, and finishing when ready. When finished, the
// report can be exported as a PDF or sent to OpenClaw.
//

import SwiftUI

struct HECAResultView: View {
  @ObservedObject var hecaVM: HECASessionViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var inputText: String = ""
  @State private var destination: String = ""
  @State private var showReport = false

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        if hecaVM.phase == .finished {
          finishedView
        } else {
          conversationView
        }
      }
      .navigationTitle(hecaVM.phase == .finished ? "HECA Report" : "HECA")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismiss()
            if hecaVM.phase == .finished { hecaVM.dismissSession() }
          }
        }
        if hecaVM.phase == .conversing, hecaVM.currentReport != nil {
          ToolbarItem(placement: .primaryAction) {
            Button(showReport ? "Hide" : "Report") {
              withAnimation { showReport.toggle() }
            }
          }
        }
      }
      .sheet(isPresented: $hecaVM.showShareSheet) {
        if let url = hecaVM.pdfURL {
          HECAShareSheet(items: [url])
        }
      }
    }
  }

  // MARK: - Conversation phase

  private var conversationView: some View {
    VStack(spacing: 0) {
      if let report = hecaVM.currentReport {
        if showReport, let image = hecaVM.primaryImage {
          ScrollView {
            HECAReportPanel(report: report, image: image)
              .padding()
          }
          .frame(maxHeight: 360)
          .background(Color(.secondarySystemBackground))
          Divider()
        } else {
          scoreStrip(report)
          Divider()
        }
      }

      chatScroll
      inputBar
    }
  }

  private func scoreStrip(_ report: HECAReport) -> some View {
    HStack(spacing: 12) {
      Circle()
        .fill(HECAReportStyle.scoreColor(report))
        .frame(width: 10, height: 10)
      Text("HECA \(report.hecaScorePercent)%")
        .font(.system(size: 13, weight: .semibold))
      Text("·  \(report.highEnergyHazards.count) high-energy · "
        + "\(report.hazards.count) total")
        .font(.system(size: 12))
        .foregroundColor(.secondary)
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  private var chatScroll: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          ForEach(hecaVM.messages) { message in
            messageBubble(message).id(message.id)
          }
          if hecaVM.isResponding {
            typingIndicator.id("typing")
          }
        }
        .padding()
      }
      .onChange(of: hecaVM.messages.count) { _ in
        withAnimation { proxy.scrollTo(hecaVM.messages.last?.id, anchor: .bottom) }
      }
      .onChange(of: hecaVM.isResponding) { responding in
        if responding { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
      }
    }
  }

  private func messageBubble(_ message: HECAChatMessage) -> some View {
    let isUser = message.role == .user
    return HStack {
      if isUser { Spacer(minLength: 40) }
      VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
        if let image = message.image {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: 200, maxHeight: 140)
            .clipped()
            .cornerRadius(12)
        }
        if !message.text.isEmpty {
          Text(message.text)
            .font(.system(size: 14))
            .foregroundColor(textColor(message.role))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bubbleColor(message.role))
            .cornerRadius(14)
        }
      }
      if !isUser { Spacer(minLength: 40) }
    }
  }

  private var typingIndicator: some View {
    HStack(spacing: 6) {
      ProgressView().scaleEffect(0.7)
      Text("Assessing…")
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }
    .padding(.vertical, 4)
  }

  private var inputBar: some View {
    VStack(spacing: 8) {
      HStack(spacing: 10) {
        Button {
          hecaVM.addArea()
        } label: {
          Image(systemName: "camera.fill")
            .font(.system(size: 16))
            .frame(width: 40, height: 40)
            .background(Color(.secondarySystemBackground))
            .clipShape(Circle())
        }
        .disabled(hecaVM.isResponding)

        TextField("Add a comment or question…", text: $inputText, axis: .vertical)
          .textFieldStyle(.roundedBorder)
          .lineLimit(1...3)
          .onSubmit(sendInput)

        Button(action: sendInput) {
          Image(systemName: "arrow.up.circle.fill")
            .font(.system(size: 28))
        }
        .disabled(hecaVM.isResponding
          || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      Button {
        hecaVM.finish()
      } label: {
        Label("Finish & Save", systemImage: "checkmark.seal.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .disabled(hecaVM.currentReport == nil || hecaVM.isResponding)
    }
    .padding(12)
    .background(.bar)
  }

  private func sendInput() {
    let text = inputText
    inputText = ""
    hecaVM.sendUserMessage(text)
  }

  // MARK: - Finished phase

  private var finishedView: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let report = hecaVM.currentReport, let image = hecaVM.primaryImage {
          HECAReportPanel(report: report, image: image)
          actions
          disclaimer
        } else {
          Text("No assessment available.")
            .foregroundColor(.secondary)
        }
      }
      .padding()
    }
  }

  private var actions: some View {
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

  // MARK: - Bubble styling

  private func bubbleColor(_ role: HECAChatMessage.Role) -> Color {
    switch role {
    case .user: return .accentColor
    case .assistant: return Color(.secondarySystemBackground)
    case .system: return Color.red.opacity(0.15)
    }
  }

  private func textColor(_ role: HECAChatMessage.Role) -> Color {
    switch role {
    case .user: return .white
    case .assistant, .system: return .primary
    }
  }
}

// MARK: - Reusable report panel

/// Shared rendering for a HECA report: score header, annotated image, hazards.
struct HECAReportPanel: View {
  let report: HECAReport
  let image: UIImage

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      scoreHeader
      annotatedImage

      if !report.summary.isEmpty {
        Text(report.summary)
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }

      hazardList
    }
  }

  private var scoreHeader: some View {
    HStack(spacing: 16) {
      ZStack {
        Circle()
          .stroke(HECAReportStyle.scoreColor(report).opacity(0.25), lineWidth: 8)
        Circle()
          .trim(from: 0, to: CGFloat(report.hecaScore))
          .stroke(HECAReportStyle.scoreColor(report),
                  style: StrokeStyle(lineWidth: 8, lineCap: .round))
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

  private var annotatedImage: some View {
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
              .stroke(HECAReportStyle.color(for: hazard.controlStatus), lineWidth: 2)
              .frame(width: rect.width, height: rect.height)
              .overlay(alignment: .topLeading) {
                Text("\(index + 1)")
                  .font(.system(size: 11, weight: .bold))
                  .foregroundColor(.white)
                  .padding(.horizontal, 5)
                  .padding(.vertical, 2)
                  .background(HECAReportStyle.color(for: hazard.controlStatus))
                  .offset(y: -18)
              }
              .offset(x: rect.minX, y: rect.minY)
          }
        }
      }
      .frame(width: geo.size.width, height: displaySize.height, alignment: .topLeading)
    }
    .frame(height: fittedSize(imageSize: image.size,
                              container: UIScreen.main.bounds.width - 32).height)
  }

  private var hazardList: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Hazards (\(report.hazards.count))")
        .font(.system(size: 16, weight: .semibold))

      if report.hazards.isEmpty {
        Text("No energy-based hazards were identified yet.")
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
              .background(HECAReportStyle.color(for: hazard.controlStatus))
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
            badge(hazard.controlStatus.displayName,
                  color: HECAReportStyle.color(for: hazard.controlStatus))
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

  private func badge(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .medium))
      .foregroundColor(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(color.opacity(0.15))
      .clipShape(Capsule())
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

// MARK: - Shared styling

enum HECAReportStyle {
  static func color(for status: HECAControlStatus) -> Color {
    switch status {
    case .direct: return .green
    case .indirect: return .yellow
    case .none: return .red
    }
  }

  static func scoreColor(_ report: HECAReport) -> Color {
    switch report.hecaScore {
    case 0.999...: return .green
    case 0.5..<0.999: return .yellow
    default: return .red
    }
  }
}

