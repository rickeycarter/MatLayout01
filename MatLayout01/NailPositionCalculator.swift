//
//  NailPositionCalculator.swift
//  MatLayout01
//
//  Calculates precise nail/hanger positions for artwork installation.
//  Used by visionOS installation mode and iOS AR installation guides.
//

import Foundation

/// A single nail placement instruction
struct NailPosition {
    /// Height from floor to nail in inches
    let heightFromFloorInches: Double

    /// Horizontal offset from the center of the arrangement in inches.
    /// 0 for a single centered piece. Negative = left, positive = right.
    let horizontalOffsetInches: Double

    /// The artwork this nail is for
    let artworkName: String

    /// Where the top and bottom of the frame will land (for ghost outline rendering)
    let frameTopFromFloorInches: Double
    let frameBottomFromFloorInches: Double

    var heightDescription: String {
        let feet = Int(heightFromFloorInches) / 12
        let inches = heightFromFloorInches.truncatingRemainder(dividingBy: 12)
        return "\(feet)' \(String(format: "%.1f", inches))\""
    }

    var heightInchesDescription: String {
        String(format: "%.1f", heightFromFloorInches) + "\""
    }
}

/// Result of calculating positions for an entire arrangement
struct InstallationLayout {
    /// Individual nail positions for each piece
    let nailPositions: [NailPosition]

    /// Total width of the arrangement including spacing, in inches
    let totalArrangementWidthInches: Double

    /// Notes and warnings
    let notes: [String]
}

/// Calculates nail positions for single and multi-piece installations.
struct NailPositionCalculator {

    /// Calculate nail position for a single artwork.
    ///
    /// - Parameters:
    ///   - artwork: The artwork configuration (needs totalHeightInches and hangerDropInches)
    ///   - idealCenterHeight: Desired center of artwork from floor (default 57")
    /// - Returns: A NailPosition with the computed height
    static func calculateSingle(
        artwork: ArtworkConfiguration,
        idealCenterHeight: Double = 57.0
    ) -> NailPosition {
        let frameHeight = artwork.totalHeightInches
        let hangerDrop = artwork.hangerDropInches ?? 0

        // Nail height = center + half the frame height - hanger drop
        let nailHeight = idealCenterHeight + (frameHeight / 2.0) - hangerDrop

        let frameTop = idealCenterHeight + (frameHeight / 2.0)
        let frameBottom = idealCenterHeight - (frameHeight / 2.0)

        return NailPosition(
            heightFromFloorInches: nailHeight,
            horizontalOffsetInches: 0,
            artworkName: artwork.artworkName,
            frameTopFromFloorInches: frameTop,
            frameBottomFromFloorInches: frameBottom
        )
    }

    /// Calculate nail positions for multiple artworks arranged horizontally.
    ///
    /// Pieces are centered on the wall with equal spacing between them.
    /// All pieces share the same center height (aligned by center, not by top edge).
    ///
    /// - Parameters:
    ///   - artworks: The artwork configurations to arrange
    ///   - idealCenterHeight: Desired center of artwork from floor (default 57")
    ///   - spacingInches: Gap between pieces in inches
    /// - Returns: An InstallationLayout with all nail positions
    static func calculateArrangement(
        artworks: [ArtworkConfiguration],
        idealCenterHeight: Double = 57.0,
        spacingInches: Double = 3.0
    ) -> InstallationLayout {
        guard !artworks.isEmpty else {
            return InstallationLayout(nailPositions: [], totalArrangementWidthInches: 0, notes: [])
        }

        if artworks.count == 1 {
            let nail = calculateSingle(artwork: artworks[0], idealCenterHeight: idealCenterHeight)
            return InstallationLayout(
                nailPositions: [nail],
                totalArrangementWidthInches: artworks[0].totalWidthInches,
                notes: []
            )
        }

        var notes: [String] = []

        // Calculate total width of the arrangement
        let totalPieceWidth = artworks.reduce(0.0) { $0 + $1.totalWidthInches }
        let totalSpacing = spacingInches * Double(artworks.count - 1)
        let totalArrangementWidth = totalPieceWidth + totalSpacing

        // Calculate each nail position
        var nailPositions: [NailPosition] = []
        var currentX = -totalArrangementWidth / 2.0 // Start from left edge

        for artwork in artworks {
            let frameWidth = artwork.totalWidthInches
            let frameHeight = artwork.totalHeightInches
            let hangerDrop = artwork.hangerDropInches ?? 0

            // Center of this piece
            let pieceCenterX = currentX + (frameWidth / 2.0)

            // Nail height for this piece (all share same center height)
            let nailHeight = idealCenterHeight + (frameHeight / 2.0) - hangerDrop

            let frameTop = idealCenterHeight + (frameHeight / 2.0)
            let frameBottom = idealCenterHeight - (frameHeight / 2.0)

            nailPositions.append(NailPosition(
                heightFromFloorInches: nailHeight,
                horizontalOffsetInches: pieceCenterX,
                artworkName: artwork.artworkName,
                frameTopFromFloorInches: frameTop,
                frameBottomFromFloorInches: frameBottom
            ))

            currentX += frameWidth + spacingInches
        }

        // Check if pieces have different heights (common in gallery walls)
        let heights = Set(artworks.map { $0.totalHeightInches })
        if heights.count > 1 {
            notes.append("Pieces have different heights. They will be aligned by center, not by top edge.")
        }

        // Check for missing hanger drop measurements
        let missingDropCount = artworks.filter({ $0.hangerDropInches == nil }).count
        if missingDropCount > 0 {
            notes.append("\(missingDropCount) piece(s) missing hanger drop measurement. Nail height assumes wire at top of frame.")
        }

        return InstallationLayout(
            nailPositions: nailPositions,
            totalArrangementWidthInches: totalArrangementWidth,
            notes: notes
        )
    }
}
