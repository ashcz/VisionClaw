//
// HECAHistoryView.swift
//
// Browse previously saved HECA assessments stored on the device, view their
// details, and re-share them as a PDF.
//

import SwiftUI

struct HECAHistoryView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var records: [HECARecord] = []

  var body: some View {
    NavigationView {
      Group {
        if records.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "tray")
              .font(.system(size: 36))
              .foregroundColor(.secondary)
            Text("No saved assessments yet")
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          List {
            ForEach(records) { record in
              NavigationLink {
                HECAHistoryDetailView(record: record)
              } label: {
                row(record)
              }
            }
            .onDelete(perform: deleteRecords)
          }
        }
      }
      .navigationTitle("HECA History")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .onAppear { records = HECAStore.list() }
    }
  }

  private func row(_ record: HECARecord) -> some View {
    HStack(spacing: 12) {
      if let image = HECAStore.annotatedImage(for: record) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: 56, height: 56)
          .clipped()
          .cornerRadius(8)
      }
      VStack(alignment: .leading, spacing: 4) {
        Text(record.report.createdAt, style: .date)
          .font(.system(size: 14, weight: .medium))
        Text("Score \(record.report.hecaScorePercent)% · "
          + "\(record.report.hazards.count) hazard(s)")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }
    }
  }

  private func deleteRecords(at offsets: IndexSet) {
    for index in offsets { HECAStore.delete(records[index]) }
    records.remove(atOffsets: offsets)
  }
}

struct HECAHistoryDetailView: View {
  let record: HECARecord

  @State private var pdfURL: URL?
  @State private var showShareSheet = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let image = HECAStore.annotatedImage(for: record) {
          Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .cornerRadius(10)
        }

        Text("HECA Score \(record.report.hecaScorePercent)%")
          .font(.system(size: 18, weight: .bold))

        if !record.report.summary.isEmpty {
          Text(record.report.summary)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
        }

        ForEach(Array(record.report.hazards.enumerated()), id: \.element.id) { index, hazard in
          VStack(alignment: .leading, spacing: 6) {
            Text("\(index + 1). \(hazard.description)")
              .font(.system(size: 14, weight: .medium))
            Text("\(hazard.energySource.displayName) · "
              + "\(hazard.isHighEnergy ? "High-energy" : "Low-energy") · "
              + "\(hazard.controlStatus.displayName)")
              .font(.system(size: 12))
              .foregroundColor(.secondary)
            if !hazard.recommendation.isEmpty {
              Text("Recommendation: \(hazard.recommendation)")
                .font(.system(size: 12))
            }
          }
          .padding(12)
          .background(Color(.secondarySystemBackground))
          .cornerRadius(10)
        }

        Button {
          exportPDF()
        } label: {
          Label("Export / Share PDF", systemImage: "square.and.arrow.up")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
      }
      .padding()
    }
    .navigationTitle("Assessment")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showShareSheet) {
      if let url = pdfURL {
        HECAShareSheet(items: [url])
      }
    }
  }

  private func exportPDF() {
    let image = HECAStore.originalImage(for: record)
      ?? HECAStore.annotatedImage(for: record)
    guard let image else { return }
    if let url = try? HECAPDFRenderer.render(report: record.report, original: image) {
      pdfURL = url
      showShareSheet = true
    }
  }
}
