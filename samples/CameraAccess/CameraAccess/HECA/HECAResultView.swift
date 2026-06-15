//
// HECAResultView.swift
//
// The structured HECA experience. The top third is a persistent live preview.
// "Perform HECA" runs a single-shot assessment of the EEI catalog of 13
// high-energy hazards; the worker then reviews and edits a grid of hazards (with
// direct/indirect controls and comments) and the annotated unsafe conditions.
// An optional advisor chat is available, and the report can be saved, exported as
// a PDF, or sent to OpenClaw.
//

import SwiftUI

struct HECAFormView: View {
  @ObservedObject var hecaVM: HECASessionViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var destination: String = ""

  var body: some View {
    NavigationView {
      GeometryReader { geo in
        let previewHeight = max(180, geo.size.height * 0.34)
        VStack(spacing: 0) {
          previewSection(height: previewHeight)
          Divider()
          ScrollView {
            VStack(spacing: 16) {
              performBar
              if hecaVM.phase == .reviewing || !hecaVM.report.presentHazards.isEmpty {
                scoreCard
              }
              gridSection
              if !hecaVM.report.allEvidence.isEmpty {
                unsafeConditionsSection
              }
              actionsSection
              disclaimer
            }
            .padding(16)
          }
        }
      }
      .navigationTitle("HECA")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismiss()
            hecaVM.dismissForm()
          }
        }
        ToolbarItem(placement: .primaryAction) {
          Button {
            hecaVM.showChat = true
          } label: {
            Image(systemName: "bubble.left.and.bubble.right")
          }
        }
      }
      .sheet(isPresented: $hecaVM.showChat) {
        HECAChatPanel(hecaVM: hecaVM)
      }
      .sheet(isPresented: $hecaVM.showShareSheet) {
        if let url = hecaVM.pdfURL {
          HECAShareSheet(items: [url])
        }
      }
    }
  }

  // MARK: - Live preview

  private func previewSection(height: CGFloat) -> some View {
    ZStack {
      Color.black
      TimelineView(.periodic(from: .now, by: 0.1)) { _ in
        Group {
          if let img = hecaVM.previewImage {
            Image(uiImage: img)
              .resizable()
              .scaledToFill()
          } else {
            VStack(spacing: 8) {
              ProgressView().tint(.white)
              Text("Waiting for video…")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
            }
          }
        }
      }

      VStack {
        HStack {
          previewPill
          Spacer()
          if hecaVM.isAssessing {
            HStack(spacing: 6) {
              ProgressView().scaleEffect(0.7).tint(.white)
              Text("Assessing…")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
          }
        }
        Spacer()
      }
      .padding(10)
    }
    .frame(height: height)
    .clipped()
  }

  private var previewPill: some View {
    let live = hecaVM.hasLiveFeed
    return HStack(spacing: 5) {
      Circle()
        .fill(live ? Color.red : Color.gray)
        .frame(width: 7, height: 7)
      Text(live ? "LIVE" : "CAPTURED")
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(.white)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 5)
    .background(.ultraThinMaterial, in: Capsule())
  }

  // MARK: - Perform

  private var performBar: some View {
    VStack(spacing: 6) {
      Button {
        hecaVM.performHECA()
      } label: {
        HStack(spacing: 8) {
          if hecaVM.isAssessing {
            ProgressView().tint(.white)
          } else {
            Image(systemName: "shield.lefthalf.filled")
          }
          Text(hecaVM.phase == .reviewing ? "Re-run HECA" : "Perform HECA")
            .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(hecaVM.isAssessing)

      if hecaVM.phase == .idle && !hecaVM.isAssessing {
        Text("Captures the current frame and assesses it against the 13 EEI high-energy hazards.")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
    }
  }

  // MARK: - Score

  private var scoreCard: some View {
    let report = hecaVM.report
    return HStack(spacing: 16) {
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
      .frame(width: 64, height: 64)

      VStack(alignment: .leading, spacing: 4) {
        Text("HECA Score")
          .font(.system(size: 16, weight: .semibold))
        Text("\(report.directlyControlledHazards.count) of \(report.presentHazards.count) "
          + "present high-energy hazards have a direct control")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
        if !report.summary.isEmpty {
          Text(report.summary)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .padding(.top, 2)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .background(Color(.secondarySystemBackground))
    .cornerRadius(12)
  }

  // MARK: - Grid

  private var gridSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("High-Energy Hazards")
          .font(.system(size: 17, weight: .semibold))
        Spacer()
        Text("\(hecaVM.report.presentHazards.count) present")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }
      Text("Tap a hazard to mark it present, then record its controls.")
        .font(.system(size: 12))
        .foregroundColor(.secondary)

      ForEach(HECAHazardCategory.catalog) { category in
        HECACategoryCard(assessment: hecaVM.binding(for: category))
      }
    }
  }

  // MARK: - Unsafe conditions

  private var unsafeConditionsSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Unsafe Conditions")
        .font(.system(size: 17, weight: .semibold))

      if let image = hecaVM.capturedImage {
        HECAAnnotatedImage(image: image, report: hecaVM.report)
          .cornerRadius(10)
      }

      ForEach(Array(hecaVM.report.allEvidence.enumerated()), id: \.offset) { idx, item in
        HStack(alignment: .top, spacing: 10) {
          Text("\(idx + 1)")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 22, height: 22)
            .background(Color.orange)
            .clipShape(Circle())
          VStack(alignment: .leading, spacing: 2) {
            Text(item.category.displayName)
              .font(.system(size: 13, weight: .semibold))
            Text(item.evidence.note)
              .font(.system(size: 12))
              .foregroundColor(.secondary)
          }
          Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
      }
    }
  }

  // MARK: - Actions

  private var actionsSection: some View {
    VStack(spacing: 10) {
      Button {
        hecaVM.finish()
      } label: {
        Label("Finish & Save", systemImage: "checkmark.seal.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .disabled(hecaVM.capturedImage == nil)

      Button {
        hecaVM.exportPDF()
      } label: {
        Label("Export / Share PDF", systemImage: "square.and.arrow.up")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .disabled(hecaVM.capturedImage == nil)

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
        .disabled(!hecaVM.openClawConfigured || hecaVM.isSending || hecaVM.capturedImage == nil)

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
      .padding(.top, 4)
  }
}

// MARK: - Hazard card

/// One editable hazard row: icon + name + present toggle, and (when present)
/// direct control, indirect control, comments, and unsafe-condition notes.
struct HECACategoryCard: View {
  @Binding var assessment: HECACategoryAssessment

  private var category: HECAHazardCategory { assessment.category }
  private var statusColor: Color {
    assessment.isPresent ? HECAReportStyle.color(for: assessment.controlStatus) : .secondary
  }

  var body: some View {
    VStack(spacing: 0) {
      header

      if assessment.isPresent {
        VStack(alignment: .leading, spacing: 12) {
          Divider()
          controlRow(
            title: "Direct control",
            systemImage: "checkmark.shield.fill",
            has: $assessment.hasDirectControl,
            name: $assessment.directControl,
            options: category.directControlExamples,
            accent: .green
          )
          controlRow(
            title: "Indirect control",
            systemImage: "exclamationmark.shield.fill",
            has: $assessment.hasIndirectControl,
            name: $assessment.indirectControl,
            options: category.indirectControlExamples,
            accent: .orange
          )
          commentsField
          if !assessment.evidence.isEmpty { evidenceList }
        }
        .padding(12)
      }
    }
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(assessment.isPresent ? statusColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
    )
  }

  private var header: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.15)) { assessment.isPresent.toggle() }
    } label: {
      HStack(spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 10)
            .fill(category.energySourceColor.opacity(assessment.isPresent ? 0.9 : 0.18))
          Image(systemName: category.systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(assessment.isPresent ? .white : category.energySourceColor)
        }
        .frame(width: 42, height: 42)

        VStack(alignment: .leading, spacing: 2) {
          Text(category.displayName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.primary)
          Text(category.threshold)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
        }

        Spacer(minLength: 8)

        Image(systemName: assessment.isPresent ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 22))
          .foregroundColor(assessment.isPresent ? statusColor : Color.secondary.opacity(0.5))
      }
      .padding(12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func controlRow(
    title: String,
    systemImage: String,
    has: Binding<Bool>,
    name: Binding<String>,
    options: [String],
    accent: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: systemImage)
          .font(.system(size: 13))
          .foregroundColor(accent)
        Text(title)
          .font(.system(size: 13, weight: .medium))
        Spacer()
        Button {
          has.wrappedValue.toggle()
        } label: {
          Image(systemName: has.wrappedValue ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: 23))
            .foregroundColor(has.wrappedValue ? .green : .red)
        }
        .buttonStyle(.plain)
      }

      if has.wrappedValue {
        Menu {
          ForEach(options, id: \.self) { option in
            Button(option) { name.wrappedValue = option }
          }
        } label: {
          HStack {
            Text(name.wrappedValue.isEmpty ? "Choose a control…" : name.wrappedValue)
              .font(.system(size: 13))
              .foregroundColor(name.wrappedValue.isEmpty ? .secondary : .primary)
              .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
              .font(.system(size: 11))
              .foregroundColor(.secondary)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .background(Color(.tertiarySystemBackground))
          .cornerRadius(8)
        }

        TextField("Or type the specific control…", text: name)
          .textFieldStyle(.roundedBorder)
          .font(.system(size: 13))
      }
    }
  }

  private var commentsField: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Comments")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.secondary)
      TextField("Notes for this hazard…", text: $assessment.comments, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(1...4)
        .font(.system(size: 13))
    }
  }

  private var evidenceList: some View {
    VStack(alignment: .leading, spacing: 4) {
      Label("Unsafe conditions", systemImage: "exclamationmark.triangle.fill")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.orange)
      ForEach(assessment.evidence) { ev in
        Text("•  \(ev.note)")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }
    }
  }
}

// MARK: - Annotated image

/// Draws the captured image with numbered evidence boxes, matching the
/// numbering of the unsafe-conditions list.
struct HECAAnnotatedImage: View {
  let image: UIImage
  let report: HECAReport

  var body: some View {
    GeometryReader { geo in
      let displaySize = fittedSize(imageSize: image.size, container: geo.size.width)
      ZStack(alignment: .topLeading) {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          .frame(width: displaySize.width, height: displaySize.height)

        ForEach(Array(report.allEvidence.enumerated()), id: \.offset) { index, item in
          if let box = item.evidence.box2d, box.count == 4 {
            let rect = boxRect(box, displaySize: displaySize)
            Rectangle()
              .stroke(Color.orange, lineWidth: 2)
              .frame(width: rect.width, height: rect.height)
              .overlay(alignment: .topLeading) {
                Text("\(index + 1)")
                  .font(.system(size: 11, weight: .bold))
                  .foregroundColor(.white)
                  .padding(.horizontal, 5)
                  .padding(.vertical, 2)
                  .background(Color.orange)
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

// MARK: - Advisor chat panel

/// Optional secondary panel: a natural-language safety advisor seeded with the
/// assessed image.
struct HECAChatPanel: View {
  @ObservedObject var hecaVM: HECASessionViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var inputText: String = ""

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
              if hecaVM.messages.isEmpty {
                Text("Ask the safety advisor about controls, the score, or how to "
                  + "establish a direct control for any hazard.")
                  .font(.system(size: 13))
                  .foregroundColor(.secondary)
                  .padding(.top, 8)
              }
              ForEach(hecaVM.messages) { message in
                messageBubble(message).id(message.id)
              }
              if hecaVM.isChatResponding {
                HStack(spacing: 6) {
                  ProgressView().scaleEffect(0.7)
                  Text("Thinking…")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }
                .id("typing")
              }
            }
            .padding()
          }
          .onChange(of: hecaVM.messages.count) { _ in
            withAnimation { proxy.scrollTo(hecaVM.messages.last?.id, anchor: .bottom) }
          }
        }
        inputBar
      }
      .navigationTitle("Safety Advisor")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  private func messageBubble(_ message: HECAChatMessage) -> some View {
    let isUser = message.role == .user
    return HStack {
      if isUser { Spacer(minLength: 40) }
      Text(message.text)
        .font(.system(size: 14))
        .foregroundColor(isUser ? .white : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(bubbleColor(message.role))
        .cornerRadius(14)
      if !isUser { Spacer(minLength: 40) }
    }
  }

  private var inputBar: some View {
    HStack(spacing: 10) {
      TextField("Ask the advisor…", text: $inputText, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(1...3)
        .onSubmit(send)
      Button(action: send) {
        Image(systemName: "arrow.up.circle.fill")
          .font(.system(size: 28))
      }
      .disabled(hecaVM.isChatResponding
        || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    .padding(12)
    .background(.bar)
  }

  private func send() {
    let text = inputText
    inputText = ""
    hecaVM.sendChat(text)
  }

  private func bubbleColor(_ role: HECAChatMessage.Role) -> Color {
    switch role {
    case .user: return .accentColor
    case .assistant: return Color(.secondarySystemBackground)
    case .system: return Color.red.opacity(0.15)
    }
  }
}

// MARK: - Shared styling

extension HECAHazardCategory {
  /// Accent color derived from the hazard's energy source.
  var energySourceColor: Color {
    switch energySource {
    case .gravity: return .blue
    case .motion: return .teal
    case .mechanical: return .purple
    case .electrical: return .yellow
    case .pressure: return .indigo
    case .temperature: return .orange
    case .chemical: return .green
    case .radiation: return .pink
    case .biological: return .mint
    case .sound: return .cyan
    case .other: return .gray
    }
  }
}

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

