//
//  ArtworkConfiguration+Default.swift
//  MatLayout01
//
//  Created by Rickey Carter on 7/18/25.
//

import SwiftUI

extension ArtworkConfiguration {
    /// Creates a default, pre-packaged artwork configuration.
    static var defaultArtwork: ArtworkConfiguration? {
        // Ensure the sample image exists in your Asset Catalog.
        guard let image = UIImage(named: "SampleArtwork"),
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Default artwork image not found.")
            return nil
        }

        // Define the properties for the default framed artwork.
        return ArtworkConfiguration(
            artworkName: "Welcome Artwork",
            imageData: imageData,
            totalWidthInches: 33,
            totalHeightInches: 39,
            matColor: .white,
            frameColor: .black,
            frameWidthInches: 1.5,
            imageScale: 1.0,
            imageOffset: .zero,
            printWidthInches: 22,
            printHeightInches: 28,
            matTopInches: 4.0,
            matBottomInches: 4.0,
            matLeftInches: 4.0,
            matRightInches: 4.0,
            cropRatio: .r22x28, // Ratio should match print dimensions
            framingMode: .custom, // Corrected: This enables the custom frame
            mattingStyle: .centered,
            selectedStandardFrameId: nil,
            isAREnabledForFree: true
        )
    }
}
