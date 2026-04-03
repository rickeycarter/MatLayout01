//
//  RoomContextView.swift
//  MatLayout01
//
//  Room questionnaire that feeds the DesignRecommendationEngine
//  and shows live arrangement comparisons.
//

import SwiftUI

struct RoomContextView: View {

    /// Called when the user proceeds — passes the best recommendation and the user's frame dimensions
    var onContinue: (_ recommendation: DesignRecommendation?, _ frameWidth: Double, _ frameHeight: Double) -> Void

    @State private var roomContext = RoomContext()

    // Frame dimensions the user already has
    @State private var frameInnerWidth: Double = 16.0
    @State private var frameInnerHeight: Double = 20.0

    private var comparison: ArrangementComparison {
        DesignRecommendationEngine.recommendAll(for: roomContext)
    }

    /// Approximate total framed size (inner dims + ~1" frame rail per side)
    private var estimatedTotalWidth: Double { frameInnerWidth + 2.0 }
    private var estimatedTotalHeight: Double { frameInnerHeight + 2.0 }

    var body: some View {
        Form {
            Section("Your Frame") {
                Text("Enter the inner dimensions of your frame (the opening where the mat and print will sit).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stepper("Inner Width: \(frameInnerWidth, specifier: "%.1f") in",
                        value: $frameInnerWidth, in: 4...60, step: 0.5)
                Stepper("Inner Height: \(frameInnerHeight, specifier: "%.1f") in",
                        value: $frameInnerHeight, in: 4...60, step: 0.5)
            }

            Section("About the Space") {
                Picker("Ceiling Height", selection: $roomContext.ceilingHeightFeet) {
                    Text("8 ft").tag(8.0)
                    Text("9 ft").tag(9.0)
                    Text("10+ ft").tag(10.0)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Stepper("Wall Width: \(Int(roomContext.wallWidthFeet)) feet",
                        value: $roomContext.wallWidthFeet, in: 3...30, step: 1)

                Picker("Viewing Distance", selection: $roomContext.viewingDistance) {
                    ForEach(ViewingDistance.allCases) { distance in
                        Text(shortLabel(for: distance)).tag(distance)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section("How Your Frame Fits") {
                ForEach(comparison.options, id: \.arrangement) { rec in
                    recommendationRow(rec)
                }
            }

            Section {
                Button {
                    onContinue(comparison.best, frameInnerWidth, frameInnerHeight)
                } label: {
                    HStack {
                        Spacer()
                        Text("Continue with Recommendations")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }

                Button {
                    onContinue(nil, frameInnerWidth, frameInnerHeight)
                } label: {
                    HStack {
                        Spacer()
                        Text("Skip — Use My Frame Only")
                            .font(.subheadline)
                        Spacer()
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Room Context")
    }

    // MARK: - Subviews

    @ViewBuilder
    private func recommendationRow(_ rec: DesignRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(rec.arrangement.rawValue)
                    .font(.headline)
                Spacer()
                Text(rec.suitability.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(suitabilityColor(rec.suitability).opacity(0.15))
                    .foregroundStyle(suitabilityColor(rec.suitability))
                    .clipShape(Capsule())
            }

            let count = rec.pieceCount == 1 ? "1 piece" : "\(rec.pieceCount) pieces"
            Text("\(count): \(rec.sizeRange.description) each")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Frame-fit assessment
            let assessment = frameAssessment(for: rec)
            Label(assessment.label, systemImage: assessment.icon)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(assessment.color)

            ForEach(rec.notes, id: \.self) { note in
                Label(note, systemImage: "lightbulb.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private struct FrameAssessment {
        let label: String
        let icon: String
        let color: Color
    }

    /// Evaluate how the user's frame fits within the recommendation's size range
    private func frameAssessment(for rec: DesignRecommendation) -> FrameAssessment {
        let totalW = estimatedTotalWidth
        let totalH = estimatedTotalHeight

        let fitsWidth = totalW >= rec.sizeRange.minWidthInches && totalW <= rec.sizeRange.maxWidthInches
        let fitsHeight = totalH >= rec.sizeRange.minHeightInches && totalH <= rec.sizeRange.maxHeightInches

        let frameDesc = String(format: "%.0fx%.0f", frameInnerWidth, frameInnerHeight)

        if fitsWidth && fitsHeight {
            return FrameAssessment(
                label: "Your \(frameDesc) frame is a great fit!",
                icon: "checkmark.circle.fill",
                color: .green
            )
        } else if totalW < rec.sizeRange.minWidthInches || totalH < rec.sizeRange.minHeightInches {
            return FrameAssessment(
                label: "Your \(frameDesc) frame is smaller than recommended",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )
        } else {
            return FrameAssessment(
                label: "Your \(frameDesc) frame is larger than recommended",
                icon: "arrow.up.circle.fill",
                color: .blue
            )
        }
    }

    private func suitabilityColor(_ suitability: DesignRecommendation.Suitability) -> Color {
        switch suitability {
        case .ideal: return .green
        case .good: return .blue
        case .possible: return .orange
        case .tight: return .red
        }
    }

    private func shortLabel(for distance: ViewingDistance) -> String {
        switch distance {
        case .hallway: return "Hallway"
        case .livingRoom: return "Living Room"
        case .largeSpace: return "Large Space"
        }
    }
}

#Preview {
    NavigationStack {
        RoomContextView { recommendation, frameW, frameH in
            print("Recommendation: \(String(describing: recommendation)), Frame: \(frameW)x\(frameH)")
        }
    }
}
