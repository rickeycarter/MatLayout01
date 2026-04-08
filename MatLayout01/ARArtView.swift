//
//  ARArtView.swift
//  MatLayout01
//
//  Created by Rickey Carter on 6/21/25.
//

#if os(iOS)

import SwiftUI
import RealityKit
import ARKit

struct ARArtView: View {
    let artwork: ArtworkConfiguration
    @Environment(\.dismiss) private var dismiss
    @State private var showPlacementHint = true

    var body: some View {
        ZStack {
            ARViewContainer(artwork: artwork, onArtworkPlaced: {
                withAnimation { showPlacementHint = false }
            })
            .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.4).clipShape(Circle()))
                    }
                    .padding()
                }

                Spacer()

                if showPlacementHint {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .font(.title2)
                        Text("Point your camera at a wall, then tap where you want to hang your artwork")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

fileprivate struct ARViewContainer: UIViewRepresentable {
    let artwork: ArtworkConfiguration
    var onArtworkPlaced: (() -> Void)?

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .vertical
        arView.session.run(config, options: [])

        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .verticalPlane
        coachingOverlay.activatesAutomatically = true // Activate the coaching overlay
        coachingOverlay.delegate = context.coordinator // Set the delegate
        arView.addSubview(coachingOverlay)
        
        context.coordinator.arView = arView
        context.coordinator.artwork = artwork
        context.coordinator.onArtworkPlaced = onArtworkPlaced

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        arView.addGestureRecognizer(tapGesture)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    class Coordinator: NSObject, ARCoachingOverlayViewDelegate {
        weak var arView: ARView?
        var artwork: ArtworkConfiguration?
        var placedArtworkAnchor: AnchorEntity?
        var onArtworkPlaced: (() -> Void)?

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = arView, let artwork = artwork else { return }

            let tapLocation = recognizer.location(in: arView)
            
            let results = arView.raycast(from: tapLocation, allowing: .existingPlaneGeometry, alignment: .vertical)
            
            if let firstResult = results.first {
                if let existingAnchor = placedArtworkAnchor {
                    arView.scene.removeAnchor(existingAnchor)
                }
                
                let newAnchor = AnchorEntity(world: firstResult.worldTransform)
                
                Task {
                    if let artworkEntity = await ArtworkEntityBuilder.createArtworkEntity(for: artwork) {
                        newAnchor.addChild(artworkEntity)
                        self.arView?.scene.addAnchor(newAnchor)
                        self.placedArtworkAnchor = newAnchor
                        self.onArtworkPlaced?()
                    }
                }
            }
        }

    }
}

#endif
