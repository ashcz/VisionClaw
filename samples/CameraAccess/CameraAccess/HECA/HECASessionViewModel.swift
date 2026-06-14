//
// HECASessionViewModel.swift
//
// Drives the interactive HECA conversation: start with a captured frame, then a
// natural back-and-forth where the worker can comment, ask questions, add more
// areas, and finish when ready. Finishing saves the report and exposes the
// existing PDF export and OpenClaw send actions.
//

import SwiftUI

@MainActor
final class HECASessionViewModel: ObservableObject {
  enum Phase {
    case idle
    case conversing
    case finished
  }

  // Conversation state
  @Published var phase: Phase = .idle
  @Published var messages: [HECAChatMessage] = []
  @Published var currentReport: HECAReport?
  @Published var isResponding = false
  @Published var showChat = false

  // Most recent captured frame for the report image (first area).
  @Published var primaryImage: UIImage?

  @Published var errorMessage: String?

  // OpenClaw send state
  @Published var isSending = false
  @Published var sendStatusMessage: String?

  // PDF share state
  @Published var pdfURL: URL?
  @Published var showShareSheet = false

  private let service = HECAService()
  private let sender = HECASender()

  /// Supplies the current camera frame when the worker captures another area.
  var frameProvider: (() -> UIImage?)?

  var openClawConfigured: Bool { GeminiConfig.isOpenClawConfigured }

  // MARK: - Conversation

  /// Begin an interactive HECA with the first captured frame.
  func startHECA(on image: UIImage?) {
    guard let image else {
      errorMessage = "No camera frame available yet. Wait for the video to appear and try again."
      return
    }
    guard !isResponding else { return }

    service.reset()
    messages = [HECAChatMessage(role: .user, text: "Starting HECA for this area.", image: image)]
    primaryImage = image
    currentReport = nil
    phase = .conversing
    showChat = true
    isResponding = true
    errorMessage = nil

    Task {
      do {
        let turn = try await service.start(image: image)
        self.apply(turn)
      } catch {
        self.handle(error)
      }
      self.isResponding = false
    }
  }

  /// Send a typed comment or question from the worker.
  func sendUserMessage(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !isResponding else { return }
    messages.append(HECAChatMessage(role: .user, text: trimmed))
    isResponding = true
    Task {
      do {
        let turn = try await service.send(text: trimmed)
        self.apply(turn)
      } catch {
        self.handle(error)
      }
      self.isResponding = false
    }
  }

  /// Capture another area (current camera frame) and fold it into the assessment.
  func addArea(note: String? = nil) {
    guard let image = frameProvider?() else {
      errorMessage = "No camera frame available to capture."
      return
    }
    guard !isResponding else { return }
    if primaryImage == nil { primaryImage = image }
    let label = note?.isEmpty == false ? "Added another area. \(note!)" : "Added another area."
    messages.append(HECAChatMessage(role: .user, text: label, image: image))
    isResponding = true
    Task {
      do {
        let turn = try await service.addArea(image: image, note: note)
        self.apply(turn)
      } catch {
        self.handle(error)
      }
      self.isResponding = false
    }
  }

  /// Finish the assessment: persist the final report + transcript.
  func finish() {
    guard let report = currentReport else {
      phase = .finished
      return
    }
    phase = .finished
    let image = primaryImage
    if let image {
      try? HECAStore.save(report: report, original: image, transcript: transcriptText())
    }
  }

  /// Reset everything (e.g. after closing the finished sheet).
  func dismissSession() {
    phase = .idle
    messages = []
    currentReport = nil
    primaryImage = nil
    sendStatusMessage = nil
    showChat = false
  }

  // MARK: - Export & send (finished report)

  /// Build a PDF and trigger the iOS share sheet.
  func exportPDF() {
    guard let report = currentReport, let image = primaryImage else { return }
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
    guard let report = currentReport, !isSending else { return }
    isSending = true
    sendStatusMessage = nil
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

  private func apply(_ turn: HECATurn) {
    currentReport = turn.report
    messages.append(HECAChatMessage(role: .assistant, text: turn.assistantMessage))
  }

  private func handle(_ error: Error) {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    errorMessage = message
    messages.append(HECAChatMessage(role: .system, text: "Couldn't reach the assessor: \(message)"))
  }

  private func transcriptText() -> String {
    messages.map { msg in
      let who: String
      switch msg.role {
      case .user: who = "Worker"
      case .assistant: who = "Assessor"
      case .system: who = "System"
      }
      return "\(who): \(msg.text)"
    }.joined(separator: "\n")
  }
}

