
//  MatLayout01
//
//  Created by Rickey Carter on 7/4/25.
//


// Create a new file: CodableArtworkConfiguration.swift
import SwiftUI


enum FramingMode: String, CaseIterable, Identifiable, Codable {
    case custom = "Custom Mat"
    case standard = "Standard Frame"
    var id: Self { self }
}


enum MattingStyle: String, CaseIterable, Identifiable, Codable {
    case centered = "Centered"
    case bottomWeighted = "Bottom-Weighted"
    var id: Self { self }
}

// Define an enum for crop ratios
enum CropRatio: String, CaseIterable, Identifiable, Codable {
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
    case r28x22 = "28x22"
    case r22x28 = "22x28"
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
        case .r28x22: return 28.0 / 22.0
        case .r22x28: return 22.0 / 28.0
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


// Helper struct to make Color Codable by storing its RGBA components.
struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

// Add Codable conformance to ArtworkConfiguration.
extension ArtworkConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case id, artworkName, imageData, totalWidthInches, totalHeightInches
        case matColor, frameColor, frameWidthInches, imageScale
        case imageOffsetWidth, imageOffsetHeight // Separate keys for CGSize components
        case printWidthInches, printHeightInches, matTopInches, matBottomInches
        case matLeftInches, matRightInches, cropRatio, framingMode
        case mattingStyle, selectedStandardFrameId
        case isAREnabledForFree // Add the new key
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let artworkName = try container.decode(String.self, forKey: .artworkName)
        let imageData = try container.decode(Data.self, forKey: .imageData)
        let totalWidthInches = try container.decode(Double.self, forKey: .totalWidthInches)
        let totalHeightInches = try container.decode(Double.self, forKey: .totalHeightInches)
        let matColor = (try container.decode(CodableColor.self, forKey: .matColor)).color
        let frameColor = (try container.decode(CodableColor.self, forKey: .frameColor)).color
        let frameWidthInches = try container.decode(Double.self, forKey: .frameWidthInches)
        let imageScale = try container.decode(CGFloat.self, forKey: .imageScale)
        let imageOffsetWidth = try container.decode(CGFloat.self, forKey: .imageOffsetWidth)
        let imageOffsetHeight = try container.decode(CGFloat.self, forKey: .imageOffsetHeight)
        let imageOffset = CGSize(width: imageOffsetWidth, height: imageOffsetHeight)
        let printWidthInches = try container.decode(Double.self, forKey: .printWidthInches)
        let printHeightInches = try container.decode(Double.self, forKey: .printHeightInches)
        let matTopInches = try container.decode(Double.self, forKey: .matTopInches)
        let matBottomInches = try container.decode(Double.self, forKey: .matBottomInches)
        let matLeftInches = try container.decode(Double.self, forKey: .matLeftInches)
        let matRightInches = try container.decode(Double.self, forKey: .matRightInches)
        let cropRatio = try container.decode(CropRatio.self, forKey: .cropRatio)
        let framingMode = try container.decode(FramingMode.self, forKey: .framingMode)
        let mattingStyle = try container.decode(MattingStyle.self, forKey: .mattingStyle)
        let selectedStandardFrameId = try container.decodeIfPresent(UUID.self, forKey: .selectedStandardFrameId)
        // Decode the new property, providing a default value for backward compatibility.
        let isAREnabledForFree = try container.decodeIfPresent(Bool.self, forKey: .isAREnabledForFree) ?? false

        self.init(id: id, artworkName: artworkName, imageData: imageData, totalWidthInches: totalWidthInches, totalHeightInches: totalHeightInches, matColor: matColor, frameColor: frameColor, frameWidthInches: frameWidthInches, imageScale: imageScale, imageOffset: imageOffset, printWidthInches: printWidthInches, printHeightInches: printHeightInches, matTopInches: matTopInches, matBottomInches: matBottomInches, matLeftInches: matLeftInches, matRightInches: matRightInches, cropRatio: cropRatio, framingMode: framingMode, mattingStyle: mattingStyle, selectedStandardFrameId: selectedStandardFrameId, isAREnabledForFree: isAREnabledForFree)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(artworkName, forKey: .artworkName)
        try container.encode(imageData, forKey: .imageData)
        try container.encode(totalWidthInches, forKey: .totalWidthInches)
        try container.encode(totalHeightInches, forKey: .totalHeightInches)
        try container.encode(CodableColor(color: matColor), forKey: .matColor)
        try container.encode(CodableColor(color: frameColor), forKey: .frameColor)
        try container.encode(frameWidthInches, forKey: .frameWidthInches)
        try container.encode(imageScale, forKey: .imageScale)
        try container.encode(imageOffset.width, forKey: .imageOffsetWidth)
        try container.encode(imageOffset.height, forKey: .imageOffsetHeight)
        try container.encode(printWidthInches, forKey: .printWidthInches)
        try container.encode(printHeightInches, forKey: .printHeightInches)
        try container.encode(matTopInches, forKey: .matTopInches)
        try container.encode(matBottomInches, forKey: .matBottomInches)
        try container.encode(matLeftInches, forKey: .matLeftInches)
        try container.encode(matRightInches, forKey: .matRightInches)
        try container.encode(cropRatio, forKey: .cropRatio)
        try container.encode(framingMode, forKey: .framingMode)
        try container.encode(mattingStyle, forKey: .mattingStyle)
        try container.encodeIfPresent(selectedStandardFrameId, forKey: .selectedStandardFrameId)
        try container.encode(isAREnabledForFree, forKey: .isAREnabledForFree)
    }
}
