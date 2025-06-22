//
//  ARArtView.swift
//  MatLayout01
//
//  Created by Rickey Carter on 6/21/25.
//



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

    class Coordinator: NSObject {
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
                let artworkEntity = createArtworkEntity(for: artwork)
                newAnchor.addChild(artworkEntity)
                arView.scene.addAnchor(newAnchor)
                
                self.placedArtworkAnchor = newAnchor
            }
        }

        func createArtworkEntity(for config: ArtworkConfiguration) -> Entity {
            let inchToMeter: Float = 0.0254
            let artworkHolder = Entity()

            // Convert all dimensions from inches to meters
            let totalWidthMeters = Float(config.totalWidthInches) * inchToMeter
            let totalHeightMeters = Float(config.totalHeightInches) * inchToMeter
            let frameThicknessMeters = Float(config.frameWidthInches) * inchToMeter
            let frameDepthMeters = frameThicknessMeters * 0.75 // Sensible depth for the frame

            // 1. Create the frame entity
            let frameMaterial = SimpleMaterial(color: UIColor(config.frameColor), isMetallic: false)
            let frameMesh = MeshResource.generateBox(width: totalWidthMeters, height: totalHeightMeters, depth: frameDepthMeters)
            let frameEntity = ModelEntity(mesh: frameMesh, materials: [frameMaterial])
            artworkHolder.addChild(frameEntity)

            // 2. Create the mat entity
            let matWidthMeters = Float(config.printWidthInches + config.matLeftInches + config.matRightInches) * inchToMeter
            let matHeightMeters = Float(config.printHeightInches + config.matTopInches + config.matBottomInches) * inchToMeter
            let matMaterial = SimpleMaterial(color: UIColor(config.matColor), isMetallic: false)
            let matMesh = MeshResource.generateBox(width: matWidthMeters, height: matHeightMeters, depth: 0.002) // Very thin
            let matEntity = ModelEntity(mesh: matMesh, materials: [matMaterial])
            matEntity.position.z = frameDepthMeters / 2 + 0.001 // Position slightly in front of the frame
            artworkHolder.addChild(matEntity)

            // 3. Create the print entity with the artwork image
            let printWidthMeters = Float(config.printWidthInches) * inchToMeter
            let printHeightMeters = Float(config.printHeightInches) * inchToMeter
            let printMesh = MeshResource.generateBox(width: printWidthMeters, height: printHeightMeters, depth: 0.001) // Even thinner
            
            var printMaterial: RealityKit.Material = SimpleMaterial(color: .darkGray, isMetallic: false)
            
            if let uiImage = UIImage(data: config.imageData), let cgImage = uiImage.cgImage {
                do {
                    let texture = try TextureResource(image: cgImage, options: .init(semantic: .color))
                    var unlitMaterial = UnlitMaterial()
                    unlitMaterial.color = .init(texture: .init(texture))
                    printMaterial = unlitMaterial
                } catch {
                    print("Failed to generate texture from image data: \(error)")
                }
            }

            let printEntity = ModelEntity(mesh: printMesh, materials: [printMaterial])
            printEntity.position.z = matEntity.position.z + 0.001 // Position slightly in front of the mat
            artworkHolder.addChild(printEntity)

            return artworkHolder
        }
    }
}
