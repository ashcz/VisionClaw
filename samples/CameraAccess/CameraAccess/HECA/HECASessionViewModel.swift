//
// HECASessionViewModel.swift
//
// Drives the structured HECA grid experience: a persistent live preview, a
// "Perform HECA" action that runs a single-shot assessment of the catalog of
// high-energy hazards, an editable grid the worker reviews and corrects, an
// optional advisor chat, and finishing that saves the report and enables PDF
// export and OpenClaw send.
//

import SwiftUI

@MainActor
final class HECASessionViewModel: ObservableObject {
  enum Phase {
    case idle        // form open, not yet assessed
    case assessing   // running the model
    case reviewing   // results in, worker editing
  }

  // Form / assessment state
  @Published var phase: Phase = .idle
  @Published var report: HECAReport = .blank()
  @Published var capturedImage: UIImage?
  @Published var isAssessing = false
  @Published var showForm = false

  // Advisor chat (secondary panel)
  @Published var showChat = false
  @Published var messages: [HECAChatMessage] = []
  @Published var isChatResponding = false

  @Published var errorMessage: String?

  // OpenClaw send state
  @Published var isSending = false
  @Published var sendStatusMessage: String?

  // PDF share state
  @Published var pdfURL: URL?
  @Published var showShareSheet = false

  private let service = HECAService()
  private let sender = HECASender()

  /// Supplies the current live camera frame (set by StreamView).
  var frameProvider: (() -> UIImage?)?

  var openClawConfigured: Bool { GeminiConfig.isOpenClawConfigured }

  /// Live preview frame if available; otherwise the captured still.
  var previewImage: UIImage? { frameProvider?() ?? capturedImage }

  /// Whether a live camera feed is currently driving the preview.
  var hasLiveFeed: Bool { frameProvider?() != nil }

  // MARK: - Presentation

  /// Open the HECA form against the live feed.
  func openForm() {
    if phase == .idle { report = .blank() }
    showForm = true
  }

  /// Open the HECA form for a still image (e.g. a bundled sample) and show it in
  /// the preview area.
  func openForm(stillImage: UIImage) {
    capturedImage = stillImage
    report = .blank()
    phase = .idle
    showForm = true
  }

  // MARK: - Assessment

  /// Capture the current frame (or a provided still) and run the grid assessment.
  func performHECA(stillImage: UIImage? = nil) {
    let image = stillImage ?? frameProvider?() ?? capturedImage
    guard let image else {
      errorMessage = "No camera frame available yet. Wait for the video to appear and try again."
      return
    }
    guard !isAssessing else { return }

    capturedImage = image
    isAssessing = true
    phase = .assessing
    errorMessage = nil
    service.reset()
    messages = []

    Task {
      do {
        let result = try await service.assessGrid(image: image)
        self.report = HECAReport.from(summary: result.summary, partial: result.assessments)
        self.phase = .reviewing
      } catch {
        self.errorMessage = (error as? LocalizedError)?.errorDescription
          ?? error.localizedDescription
        self.phase = self.report.presentHazards.isEmpty ? .idle : .reviewing
      }
      self.isAssessing = false
    }
  }

  /// Editable binding into a single category's assessment row.
  func binding(for category: HECAHazardCategory) -> Binding<HECACategoryAssessment> {
    Binding(
      get: {
        self.report.assessments.first(where: { $0.category == category })
          ?? .empty(for: category)
      },
      set: { newValue in
        if let idx = self.report.assessments.firstIndex(where: { $0.category == category }) {
          self.report.assessments[idx] = newValue
        }
      }
    )
  }

  // MARK: - Advisor chat

  func sendChat(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !isChatResponding else { return }
    messages.append(HECAChatMessage(role: .user, text: trimmed))
    isChatResponding = true
    let summary = report.summary
    Task {
      do {
        let reply = try await service.chat(text: trimmed, reportSummary: summary)
        self.messages.append(HECAChatMessage(role: .assistant, text: reply))
      } catch {
        let m = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        self.messages.append(HECAChatMessage(role: .system,
                                             text: "Couldn't reach the advisor: \(m)"))
      }
      self.isChatResponding = false
    }
  }

  // MARK: - Finish / export / send

  /// Persist the current report (and transcript, if any) to History.
  func finish() {
    guard let image = capturedImage else {
      errorMessage = "Perform an assessment before saving."
      return
    }
    try? HECAStore.save(report: report, original: image, transcript: transcriptText())
    sendStatusMessage = "Saved to History."
  }

  /// Reset everything (e.g. after closing the form).
  func dismissForm() {
    showForm = false
    showChat = false
    phase = .idle
    capturedImage = nil
    report = .blank()
    messages = []
    sendStatusMessage = nil
  }

  /// Build a PDF and trigger the iOS share sheet.
  func exportPDF() {
    guard let image = capturedImage else {
      errorMessage = "Perform an assessment before exporting."
      return
    }
    do {
      let url = try HECAPDFRenderer.render(report: report, original: image)
      self.pdfURL = url
      self.showShareSheet = true
    } catch {
      self.errorMessage = "Could not create PDF: \(error.localizedDescription)"
    }
  }

  /// Send the report summary to OpenClaw.
  func sendToOpenClaw(destination: String?) {
    guard !isSending else { return }
    isSending = true
    sendStatusMessage = nil
    let report = self.report
    Task {
      do {
        _ = try await sender.send(report: report, destination: destination)
        self.sendStatusMessage = "Sent to OpenClaw."
      } catch {
        self.sendStatusMessage = (error as? LocalizedError)?.errorDescription
          ?? error.localizedDescription
      }
      self.isSending = false
    }
  }

  // MARK: - Helpers

  private func transcriptText() -> String {
    guard !messages.isEmpty else { return "" }
    return messages.map { msg in
      let who: String
      switch msg.role {
      case .user: who = "Worker"
      case .assistant: who = "Advisor"
      case .system: who = "System"
      }
      return "\(who): \(msg.text)"
    }.joined(separator: "\n")
  }
}

