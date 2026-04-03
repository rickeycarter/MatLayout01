//
//  DesignRecommendationEngine.swift
//  MatLayout01
//
//  Pure logic engine that generates artwork sizing and placement recommendations
//  based on room context. No UI — consumed by iPad design studio, AR guides,
//  and installation mode.
//

import Foundation

/// The output of the design recommendation engine
struct DesignRecommendation {

    /// Recommended frame size range for each piece
    struct SizeRange {
        let minWidthInches: Double
        let maxWidthInches: Double
        let minHeightInches: Double
        let maxHeightInches: Double

        var description: String {
            let minW = String(format: "%.0f", minWidthInches)
            let maxW = String(format: "%.0f", maxWidthInches)
            let minH = String(format: "%.0f", minHeightInches)
            let maxH = String(format: "%.0f", maxHeightInches)
            return "\(minW)-\(maxW)\" wide x \(minH)-\(maxH)\" tall"
        }
    }

    /// Which arrangement this recommendation is for
    let arrangement: ArtworkArrangement

    /// Number of pieces in this arrangement
    let pieceCount: Int

    /// Recommended size range per piece (total framed dimensions)
    let sizeRange: SizeRange

    /// Ideal center height from floor in inches
    let idealCenterHeightInches: Double

    /// Horizontal spacing between pieces in inches (0 for single piece)
    let spacingBetweenPiecesInches: Double

    /// Suggested orientation
    let suggestedOrientation: Orientation

    /// How well this arrangement fits the space
    let suitability: Suitability

    /// Any warnings or guidance notes
    let notes: [String]

    enum Orientation: String {
        case portrait = "Portrait"
        case landscape = "Landscape"
        case either = "Either"
    }

    /// How practical/suitable this arrangement is for the given wall
    enum Suitability: String, Comparable {
        case ideal = "Recommended"
        case good = "Good Option"
        case possible = "Possible"
        case tight = "Tight Fit"

        private var sortOrder: Int {
            switch self {
            case .ideal: return 0
            case .good: return 1
            case .possible: return 2
            case .tight: return 3
            }
        }

        static func < (lhs: Suitability, rhs: Suitability) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }
}

/// A collection of recommendations for all arrangement types, ranked by suitability
struct ArrangementComparison {
    /// All recommendations sorted by suitability (best first)
    let options: [DesignRecommendation]

    /// The top recommendation
    var best: DesignRecommendation? { options.first }

    /// Summary for display
    var summary: String {
        options.map { rec in
            let count = rec.pieceCount == 1 ? "1 piece" : "\(rec.pieceCount) pieces"
            return "\(rec.arrangement.rawValue) (\(count)): \(rec.sizeRange.description) each — \(rec.suitability.rawValue)"
        }.joined(separator: "\n")
    }
}

/// Generates design recommendations from room context using standard interior design rules.
struct DesignRecommendationEngine {

    // MARK: - Design Rule Constants

    /// Art should fill 60-75% of available wall width
    static let minWallCoverageRatio = 0.60
    static let maxWallCoverageRatio = 0.75

    /// Standard gallery hanging height: center of artwork at 57" from floor
    static let standardCenterHeightInches = 57.0

    /// Spacing between grouped pieces in inches
    static let pairSpacingInches = 3.0
    static let gallerySpacingInches = 2.5

    /// Minimum recommended frame height based on ceiling height
    /// Prevents comically small art on tall walls
    static let minFrameHeightRatioByCeiling: [Double: Double] = [
        8.0: 10.0,   // 8ft ceiling → at least 10" tall
        9.0: 14.0,   // 9ft ceiling → at least 14" tall
        10.0: 18.0,  // 10ft ceiling → at least 18" tall
        12.0: 22.0,  // 12ft ceiling → at least 22" tall
    ]

    // MARK: - Public API

    /// Generate a design recommendation for a specific arrangement from room context
    static func recommend(for room: RoomContext) -> DesignRecommendation {
        return recommendForArrangement(room: room, arrangement: room.arrangement)
    }

    /// Generate recommendations for ALL arrangement types and rank by suitability.
    /// Use this to show the user their options: "For your 10ft wall, here's what works..."
    static func recommendAll(for room: RoomContext) -> ArrangementComparison {
        let options = ArtworkArrangement.allCases.map { arrangement in
            recommendForArrangement(room: room, arrangement: arrangement)
        }.sorted { $0.suitability < $1.suitability }

        return ArrangementComparison(options: options)
    }

    // MARK: - Core Recommendation Logic

    /// Generate a recommendation for a specific arrangement type
    private static func recommendForArrangement(room: RoomContext, arrangement: ArtworkArrangement) -> DesignRecommendation {
        let wallWidthInches = room.wallWidthFeet * 12.0
        var notes: [String] = []

        // Calculate total art coverage width
        let minTotalCoverage = wallWidthInches * minWallCoverageRatio
        let maxTotalCoverage = wallWidthInches * maxWallCoverageRatio

        // Account for spacing in multi-piece arrangements
        let pieceCount = Double(arrangement.pieceCount)
        let totalSpacing: Double
        switch arrangement {
        case .single:
            totalSpacing = 0
        case .pair:
            totalSpacing = pairSpacingInches
        case .gallery:
            totalSpacing = gallerySpacingInches * (pieceCount - 1)
        }

        let minPerPieceWidth = max(4, (minTotalCoverage - totalSpacing) / pieceCount)
        let maxPerPieceWidth = (maxTotalCoverage - totalSpacing) / pieceCount

        // Height recommendations based on ceiling
        let minHeight = minimumFrameHeight(forCeilingFeet: room.ceilingHeightFeet)

        // Max height: art shouldn't dominate floor-to-ceiling.
        // Top of frame should stay at least 12" below ceiling,
        // bottom at least 30" above floor (roughly table/sofa back height)
        let ceilingInches = room.ceilingHeightFeet * 12.0
        let maxHeight = ceilingInches - 12.0 - 30.0

        // Orientation suggestion
        let orientation: DesignRecommendation.Orientation
        if arrangement == .gallery {
            orientation = .either
        } else if maxPerPieceWidth > maxHeight {
            orientation = .landscape
        } else {
            orientation = .portrait
        }

        // Center height — adjust for tall ceilings
        var centerHeight = room.idealCenterHeightInches
        if room.ceilingHeightFeet >= 10 {
            centerHeight = min(60.0, centerHeight + (room.ceilingHeightFeet - 9.0) * 1.5)
            notes.append("Center height raised to \(String(format: "%.0f", centerHeight))\" for \(String(format: "%.0f", room.ceilingHeightFeet))ft ceilings.")
        }

        // Spacing between pieces (per gap, for display)
        let spacingForResult: Double
        switch arrangement {
        case .single:
            spacingForResult = 0
        case .pair:
            spacingForResult = pairSpacingInches
        case .gallery:
            spacingForResult = gallerySpacingInches
        }

        // Viewing distance notes
        switch room.viewingDistance {
        case .hallway:
            notes.append("For narrow spaces, consider smaller pieces with finer detail that reward close viewing.")
        case .livingRoom:
            break
        case .largeSpace:
            notes.append("For large spaces, bolder imagery and larger frames carry more visual weight at distance.")
        }

        // Determine suitability
        let suitability = evaluateSuitability(
            minPerPieceWidth: minPerPieceWidth,
            maxPerPieceWidth: maxPerPieceWidth,
            minHeight: minHeight,
            maxHeight: maxHeight,
            arrangement: arrangement,
            wallWidthInches: wallWidthInches
        )

        if suitability == .tight {
            notes.append("This wall may be narrow for \(arrangement.rawValue.lowercased()). Consider fewer pieces.")
        }

        let sizeRange = DesignRecommendation.SizeRange(
            minWidthInches: minPerPieceWidth,
            maxWidthInches: maxPerPieceWidth,
            minHeightInches: minHeight,
            maxHeightInches: maxHeight
        )

        return DesignRecommendation(
            arrangement: arrangement,
            pieceCount: arrangement.pieceCount,
            sizeRange: sizeRange,
            idealCenterHeightInches: centerHeight,
            spacingBetweenPiecesInches: spacingForResult,
            suggestedOrientation: orientation,
            suitability: suitability,
            notes: notes
        )
    }

    /// Evaluate how well an arrangement fits a given wall
    private static func evaluateSuitability(
        minPerPieceWidth: Double,
        maxPerPieceWidth: Double,
        minHeight: Double,
        maxHeight: Double,
        arrangement: ArtworkArrangement,
        wallWidthInches: Double
    ) -> DesignRecommendation.Suitability {
        // If min > max, the pieces won't fit well
        if minPerPieceWidth > maxPerPieceWidth {
            return .tight
        }

        // Check if standard frames exist in this range
        let hasStandardFrames = StandardFrame.allFrames.contains { frame in
            frame.width >= minPerPieceWidth &&
            frame.width <= maxPerPieceWidth &&
            frame.height >= minHeight &&
            frame.height <= maxHeight
        }

        // Per-piece width in a comfortable, commonly-available range (12-36")
        let avgWidth = (minPerPieceWidth + maxPerPieceWidth) / 2.0
        let isComfortableSize = avgWidth >= 12 && avgWidth <= 36

        if isComfortableSize && hasStandardFrames {
            return .ideal
        } else if isComfortableSize {
            return .good
        } else if hasStandardFrames {
            return .good
        } else {
            return .possible
        }
    }

    // MARK: - Helpers

    /// Returns matching standard frame sizes that fall within the recommended range
    static func matchingStandardFrames(for recommendation: DesignRecommendation) -> [StandardFrame] {
        StandardFrame.allFrames.filter { frame in
            frame.width >= recommendation.sizeRange.minWidthInches &&
            frame.width <= recommendation.sizeRange.maxWidthInches &&
            frame.height >= recommendation.sizeRange.minHeightInches &&
            frame.height <= recommendation.sizeRange.maxHeightInches
        }
    }

    /// Returns matching print sizes (CropRatio) that would fit within the recommended range,
    /// assuming a typical 2" mat and 1.5" frame border on each side (7" total added to each dimension).
    static func matchingPrintSizes(for recommendation: DesignRecommendation, matInches: Double = 2.0, frameBorderInches: Double = 1.5) -> [CropRatio] {
        let overhead = (matInches + frameBorderInches) * 2.0
        return CropRatio.allCases.filter { ratio in
            let dims = ratio.dimensions
            let totalW = dims.width + overhead
            let totalH = dims.height + overhead
            return totalW >= recommendation.sizeRange.minWidthInches &&
                   totalW <= recommendation.sizeRange.maxWidthInches &&
                   totalH >= recommendation.sizeRange.minHeightInches &&
                   totalH <= recommendation.sizeRange.maxHeightInches
        }
    }

    /// Minimum frame height for a given ceiling height
    private static func minimumFrameHeight(forCeilingFeet ceiling: Double) -> Double {
        // Find the closest ceiling bracket at or below the given height
        let sorted = minFrameHeightRatioByCeiling.keys.sorted()
        var result = 10.0 // absolute minimum
        for key in sorted where key <= ceiling {
            result = minFrameHeightRatioByCeiling[key] ?? result
        }
        // Interpolate for in-between values
        if ceiling > 10.0 {
            result = 18.0 + (ceiling - 10.0) * 2.0
        }
        return result
    }
}
