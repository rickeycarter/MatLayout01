//
//  StandardFrame.swift
//  MatLayout01
//
//  Created by Rickey Carter on 6/21/25.
//

import Foundation

struct StandardFrame: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let width: Double
    let height: Double

    var description: String {
        if name == "Print Size" {
            return "\(String(format: "%.1f", width))\" x \(String(format: "%.1f", height))\" (Exact Match)"
        }
        // Handle potential non-integer values for display
        let widthStr = String(format: width.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", width)
        let heightStr = String(format: height.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", height)
        return "\(name) - \(widthStr)\" x \(heightStr)\""
    }

    static let allFrames: [StandardFrame] = [
        // Portrait
        StandardFrame(name: "4x6 (portrait)", width: 4, height: 6),
        StandardFrame(name: "5x7 (portrait)", width: 5, height: 7),
        StandardFrame(name: "8x10 (portrait)", width: 8, height: 10),
        StandardFrame(name: "8.5x11 (portrait)", width: 8.5, height: 11),
        StandardFrame(name: "11x14 (portrait)", width: 11, height: 14),
        StandardFrame(name: "12x16 (portrait)", width: 12, height: 16),
        StandardFrame(name: "16x20 (portrait)", width: 16, height: 20),
        StandardFrame(name: "18x24 (portrait)", width: 18, height: 24),
        StandardFrame(name: "20x30 (portrait)", width: 20, height: 30),
        StandardFrame(name: "24x36 (portrait)", width: 24, height: 36),
        // Landscape
        StandardFrame(name: "6x4 (landscape)", width: 6, height: 4),
        StandardFrame(name: "7x5 (landscape)", width: 7, height: 5),
        StandardFrame(name: "10x8 (landscape)", width: 10, height: 8),
        StandardFrame(name: "11x8.5 (landscape)", width: 11, height: 8.5),
        StandardFrame(name: "14x11 (landscape)", width: 14, height: 11),
        StandardFrame(name: "16x12 (landscape)", width: 16, height: 12),
        StandardFrame(name: "20x16 (landscape)", width: 20, height: 16),
        StandardFrame(name: "24x18 (landscape)", width: 24, height: 18),
        StandardFrame(name: "30x20 (landscape)", width: 30, height: 20),
        StandardFrame(name: "36x24 (landscape)", width: 36, height: 24)
    ]
}
