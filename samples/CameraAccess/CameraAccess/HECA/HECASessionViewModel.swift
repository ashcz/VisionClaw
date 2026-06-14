//
// HECASessionViewModel.swift
//
// Orchestrates a HECA assessment: capture -> assess -> save locally -> publish.
// Also exposes actions to export a PDF (for the iOS share sheet) and to send the
// report to OpenClaw.
//

import SwiftUI

@MainActor
final class HECASessionViewModel: ObservableObject {
  @Published var isAssessing = false
  @Published var report: HECAReport?
  @Published var capturedImage: UIImage?
  @Published var errorMessage: String?
  @Published var showResult = false

  // OpenClaw send state
  @Published var isSending = false
  @Published var sendStatusMessage: String?

  // PDF share state
  @Published var pdfURL: URL?
  @Published var showShareSheet = false

  private let service = HECAService()
  private let sender = HECASender()

  var openClawConfigured: Bool { GeminiConfig.isOpenClawConfigured }

  /// Run a HECA assessment on the given frame.
  func performHECA(on image: UIImage?) {
    guard let image else {
      errorMessage = "No camera frame available yet. Wait for the video to appear and try again."
      return
    }
    guard !isAssessing else { return }

    isAssessing = true
    errorMessage = nil
    capturedImage = image

    Task {
      do {
        let result = try await service.assess(image: image)
        self.report = result
        try? HECAStore.save(report: result, original: image)
        self.showResult = true
      } catch {
        self.errorMessage = (error as? LocalizedError)?.errorDescription
          ?? error.localizedDescription
      }
      self.isAssessing = false
    }
  }

  /// Build a PDF and trigger the iOS share sheet.
  func exportPDF() {
    guard let report, let image = capturedImage else { return }
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
    guard let report, !isSending else { return }
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
}
