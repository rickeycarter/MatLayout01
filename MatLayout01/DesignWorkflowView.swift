//
//  DesignWorkflowView.swift
//  MatLayout01
//
//  Decision screen for creating new artwork on iPad.
//  Offers two workflows: "I Have a Frame" and "I Have a Photo".
//

import SwiftUI

struct DesignWorkflowView: View {
    var onComplete: (ArtworkConfiguration) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var showBuilder = false
    @State private var builderMode: BuilderMode = .photoFirst
    @State private var recommendation: DesignRecommendation?
    @State private var enteredFrameWidth: Double?
    @State private var enteredFrameHeight: Double?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Text("How would you like to start?")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Choose the path that matches your situation.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)

                    // Workflow cards
                    HStack(spacing: 16) {
                        // "I Have a Frame" — goes through RoomContextView first
                        NavigationLink {
                            RoomContextView { rec, frameW, frameH in
                                builderMode = .frameFirst
                                recommendation = rec
                                enteredFrameWidth = frameW
                                enteredFrameHeight = frameH
                                showBuilder = true
                            }
                        } label: {
                            WorkflowCard(
                                title: "I Have a Frame",
                                subtitle: "Enter your frame dimensions and we'll recommend the best print size",
                                systemImage: "rectangle.inset.filled",
                                isRecommended: true
                            )
                        }
                        .buttonStyle(.plain)

                        // "I Have a Photo" — goes directly to builder
                        Button {
                            builderMode = .photoFirst
                            recommendation = nil
                            showBuilder = true
                        } label: {
                            WorkflowCard(
                                title: "I Have a Photo",
                                subtitle: "Start with your photo and explore different framing options",
                                systemImage: "photo.artframe",
                                isRecommended: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)

                    // Guidance text
                    GroupBox {
                        Label {
                            Text("We recommend starting with a frame you love. Standard frames are affordable and easy to find. Once you know the frame size, we can calculate the ideal print dimensions \u{2014} including mounting buffer.")
                        } icon: {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                        }
                        .font(.callout)
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("New Artwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showBuilder) {
            BuildArtPieceView(
                artworkToEdit: nil,
                onComplete: { config in
                    onComplete(config)
                    dismiss()
                },
                builderMode: builderMode,
                designRecommendation: recommendation,
                initialFrameWidth: enteredFrameWidth,
                initialFrameHeight: enteredFrameHeight
            )
        }
    }
}

// MARK: - Workflow Card

private struct WorkflowCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isRecommended: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(isRecommended ? .blue : .secondary)
                .frame(height: 50)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if isRecommended {
                Text("Recommended")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isRecommended ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        }
    }
}

#Preview {
    DesignWorkflowView { config in
        print("Created: \(config.artworkName)")
    }
}
