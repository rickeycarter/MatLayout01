//
//  RoomContext.swift
//  MatLayout01
//
//  Room context model for the design recommendation engine.
//  Captures information about the space where artwork will be displayed.
//

import Foundation

/// How far a typical viewer stands from the wall
enum ViewingDistance: String, CaseIterable, Identifiable, Codable {
    case hallway = "Hallway / Narrow Space"
    case livingRoom = "Living Room / Office"
    case largeSpace = "Large Open Space"

    var id: Self { self }

    /// Approximate viewing distance in feet
    var typicalDistanceFeet: Double {
        switch self {
        case .hallway: return 4
        case .livingRoom: return 8
        case .largeSpace: return 15
        }
    }
}

/// How many pieces will be displayed on the wall
enum ArtworkArrangement: String, CaseIterable, Identifiable, Codable {
    case single = "Single Statement Piece"
    case pair = "Pair"
    case gallery = "Gallery Wall (3+)"

    var id: Self { self }

    var pieceCount: Int {
        switch self {
        case .single: return 1
        case .pair: return 2
        case .gallery: return 3
        }
    }
}

/// Captures the physical characteristics of the room/wall where art will be displayed.
/// Used by DesignRecommendationEngine to suggest appropriate sizes and placement.
struct RoomContext: Codable {
    /// Ceiling height in feet (common values: 8, 9, 10, 12)
    var ceilingHeightFeet: Double = 9.0

    /// Available wall width in feet
    var wallWidthFeet: Double = 10.0

    /// Number and style of pieces to display
    var arrangement: ArtworkArrangement = .single

    /// Typical viewing distance
    var viewingDistance: ViewingDistance = .livingRoom

    /// Ideal center height of artwork from floor in inches.
    /// Gallery standard is 57". Users can override.
    var idealCenterHeightInches: Double = 57.0
}
