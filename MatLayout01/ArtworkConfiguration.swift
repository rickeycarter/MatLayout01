//
//  to.swift
//  MatLayout01
//
//  Created by Rickey Carter on 6/21/25.
//

import SwiftUI

struct ArtworkConfiguration: Identifiable, CustomStringConvertible {
    let id: UUID
    let artworkName: String
    let imageData: Data
    let totalWidthInches: Double
    let totalHeightInches: Double
    let matColor: Color
    let frameColor: Color
    let frameWidthInches: Double
    let imageScale: CGFloat
    let imageOffset: CGSize
    let printWidthInches: Double
    let printHeightInches: Double
    let matTopInches: Double
    let matBottomInches: Double
    let matLeftInches: Double
    let matRightInches: Double

    let cropRatio: CropRatio
    let framingMode: FramingMode
    let mattingStyle: MattingStyle
    let selectedStandardFrameId: UUID?
    let creationDate: Date

    // Custom initializer
    init(
        id: UUID = UUID(),
        artworkName: String,
        imageData: Data,
        totalWidthInches: Double,
        totalHeightInches: Double,
        matColor: Color,
        frameColor: Color,
        frameWidthInches: Double,
        imageScale: CGFloat,
        imageOffset: CGSize,
        printWidthInches: Double,
        printHeightInches: Double,
        matTopInches: Double,
        matBottomInches: Double,
        matLeftInches: Double,
        matRightInches: Double,
        cropRatio: CropRatio,
        framingMode: FramingMode,
        mattingStyle: MattingStyle,
        selectedStandardFrameId: UUID?,
        creationDate: Date = Date()
    ) {
        self.id = id
        self.artworkName = artworkName
        self.imageData = imageData
        self.totalWidthInches = totalWidthInches
        self.totalHeightInches = totalHeightInches
        self.matColor = matColor
        self.frameColor = frameColor
        self.frameWidthInches = frameWidthInches
        self.imageScale = imageScale
        self.imageOffset = imageOffset
        self.printWidthInches = printWidthInches
        self.printHeightInches = printHeightInches
        self.matTopInches = matTopInches
        self.matBottomInches = matBottomInches
        self.matLeftInches = matLeftInches
        self.matRightInches = matRightInches
        self.cropRatio = cropRatio
        self.framingMode = framingMode
        self.mattingStyle = mattingStyle
        self.selectedStandardFrameId = selectedStandardFrameId
        self.creationDate = creationDate
    }

    // MARK: - CustomStringConvertible
    var description: String {
        let dimensionString = "\(String(format: "%.1f", totalWidthInches))\" x \(String(format: "%.1f", totalHeightInches))\""
        if artworkName.isEmpty {
            return dimensionString
        } else {
            return "\(artworkName) (\(dimensionString))"
        }
    }

    // MARK: - Preview View
    @ViewBuilder
    var preview: some View {
        if totalHeightInches > 0, let uiImage = UIImage(data: imageData) {
            let artworkAspectRatio = totalWidthInches / totalHeightInches

            GeometryReader { geometry in
                let scale = geometry.size.width / totalWidthInches

                let matWidth = (matLeftInches + printWidthInches + matRightInches) * scale
                let matHeight = (matTopInches + printHeightInches + matBottomInches) * scale

                let imageWidth = printWidthInches * scale
                let imageHeight = printHeightInches * scale

                let imageXOffset = (matLeftInches - matRightInches) / 2 * scale
                let imageYOffset = (matTopInches - matBottomInches) / 2 * scale

                ZStack {
                    frameColor

                    matColor
                        .frame(width: matWidth, height: matHeight)

                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageWidth, height: imageHeight)
                        .clipped()
                        .offset(x: imageXOffset, y: imageYOffset)
                }
            }
            .aspectRatio(artworkAspectRatio, contentMode: .fit)
            .clipped()
        }
    }
}
