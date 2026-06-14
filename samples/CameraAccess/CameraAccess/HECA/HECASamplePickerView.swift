//
// HECASamplePickerView.swift
//
// A grid of bundled job-site sample images. Tapping one runs a HECA assessment
// against it (useful for testing without a live camera).
//

import SwiftUI

struct HECASamplePickerView: View {
  @ObservedObject var hecaVM: HECASessionViewModel
  @Environment(\.dismiss) private var dismiss

  private let columns = [GridItem(.flexible()), GridItem(.flexible())]

  var body: some View {
    NavigationView {
      ScrollView {
        LazyVGrid(columns: columns, spacing: 12) {
          ForEach(HECASampleImage.all) { sample in
            Button {
              dismiss()
              if let image = sample.image {
                hecaVM.performHECA(on: image)
              }
            } label: {
              VStack(spacing: 6) {
                if let image = sample.image {
                  Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(10)
                } else {
                  RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
                }
                Text(sample.title)
                  .font(.system(size: 14, weight: .medium))
                  .foregroundColor(.primary)
              }
            }
          }
        }
        .padding()
      }
      .navigationTitle("HECA Test Images")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }
}
