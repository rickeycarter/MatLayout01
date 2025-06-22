//
//  ProductionInstructionsView.swift
//  MatLayout01
//
//  Created by Rickey Carter on 6/21/25.
//

import SwiftUI

struct ProductionInstructionsView: View {
    let artwork: ArtworkConfiguration

    var body: some View {
        Form {
            Section(header: Text("Artwork Details")) {
                LabeledContent("Name", value: artwork.artworkName)
                LabeledContent("Print Size", value: "\(String(format: "%.2f", artwork.printWidthInches))\" x \(String(format: "%.2f", artwork.printHeightInches))\"")
            }

            Section(header: Text("Mat Details")) {
                LabeledContent("Color") {
                    artwork.matColor
                        .frame(width: 24, height: 24)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray, lineWidth: 0.5)
                        )
                }
                LabeledContent("Top", value: "\(String(format: "%.2f", artwork.matTopInches))\"")
                LabeledContent("Bottom", value: "\(String(format: "%.2f", artwork.matBottomInches))\"")
                LabeledContent("Left", value: "\(String(format: "%.2f", artwork.matLeftInches))\"")
                LabeledContent("Right", value: "\(String(format: "%.2f", artwork.matRightInches))\"")
            }

            Section(header: Text("Frame Details")) {
                LabeledContent("Color") {
                    artwork.frameColor
                        .frame(width: 24, height: 24)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray, lineWidth: 0.5)
                        )
                }
                LabeledContent("Width", value: "\(String(format: "%.2f", artwork.frameWidthInches))\"")
            }

            Section(header: Text("Final Dimensions")) {
                LabeledContent("Total Size", value: "\(String(format: "%.2f", artwork.totalWidthInches))\" x \(String(format: "%.2f", artwork.totalHeightInches))\"")
            }
        }
        .navigationTitle("Production Instructions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ProductionInstructionsView(artwork: ArtworkConfiguration(
            artworkName: "Sample Artwork",
            imageData: Data(),
            totalWidthInches: 18,
            totalHeightInches: 22,
            matColor: .white,
            frameColor: .black,
            frameWidthInches: 1.5,
            imageScale: 1.0,
            imageOffset: .zero,
            printWidthInches: 12,
            printHeightInches: 16,
            matTopInches: 3.0,
            matBottomInches: 3.0,
            matLeftInches: 3.0,
            matRightInches: 3.0,
            cropRatio: .r4x5,
            framingMode: .custom,
            mattingStyle: .centered,
            selectedStandardFrameId: nil
        ))
    }
}
