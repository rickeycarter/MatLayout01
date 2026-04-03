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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ARViewContainer(artwork: artwork)
                .edgesIgnoringSafeArea(.all)

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
    }
}

fileprivate struct ARViewContainer: UIViewRepresentable {
    let artwork: ArtworkConfiguration

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
                    }
                }
            }
        }

    }
}

#endif
