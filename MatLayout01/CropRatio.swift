//
//  for.swift
//  MatLayout01
//
//  Created by Rickey Carter on 6/21/25.
//


// CropRatio.swift

import Foundation
import CoreGraphics

// Define an enum for crop ratios
enum CropRatio: String, CaseIterable, Identifiable {
    case r2x3 = "2x3"
    case r3x2 = "3x2"
    case r4x5 = "4x5"
    case r5x4 = "5x4"
    case r4x6 = "4x6"
    case r6x4 = "6x4"
    case r5x7 = "5x7"
    case r7x5 = "7x5"
    case r11x14 = "11x14"
    case r14x11 = "14x11"
    case r16x20 = "16x20"
    case r20x16 = "20x16"
    case r20x24 = "20x24"
    case r24x20 = "24x20"
    case r24x36 = "24x36"
    case r36x24 = "36x24"

    var id: String { self.rawValue }

    var ratio: CGFloat {
        switch self {
        case .r2x3: return 2.0 / 3.0
        case .r3x2: return 3.0 / 2.0
        case .r4x5: return 4.0 / 5.0
        case .r5x4: return 5.0 / 4.0
        case .r4x6: return 4.0 / 6.0
        case .r6x4: return 6.0 / 4.0
        case .r5x7: return 5.0 / 7.0
        case .r7x5: return 7.0 / 5.0
        case .r11x14: return 11.0 / 14.0
        case .r14x11: return 14.0 / 11.0
        case .r16x20: return 16.0 / 20.0
        case .r20x16: return 20.0 / 16.0
        case .r20x24: return 20.0 / 24.0
        case .r24x20: return 24.0 / 20.0
        case .r24x36: return 24.0 / 36.0
        case .r36x24: return 36.0 / 24.0
        }
    }

    var dimensions: (width: Double, height: Double) {
        let components = self.rawValue.components(separatedBy: "x")
        guard components.count == 2,
              let width = Double(components[0]),
              let height = Double(components[1]) else {
            return (0, 0)
        }
        return (width: width, height: height)
    }
}
