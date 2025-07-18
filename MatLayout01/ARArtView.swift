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
                    if let artworkEntity = await createArtworkEntity(for: artwork) {
                        newAnchor.addChild(artworkEntity)
                        self.arView?.scene.addAnchor(newAnchor)
                        self.placedArtworkAnchor = newAnchor
                    }
                }
            }
        }

        func createArtworkEntity(for config: ArtworkConfiguration) async -> Entity? {
            let inchToMeter: Float = 0.0254
            let artworkHolder = Entity()

            // Convert all dimensions from inches to meters
            let totalWidthMeters = Float(config.totalWidthInches) * inchToMeter
            let totalHeightMeters = Float(config.totalHeightInches) * inchToMeter
            let frameThicknessMeters = Float(config.frameWidthInches) * inchToMeter
            let frameDepthMeters = frameThicknessMeters * 0.75

            // Shift the entire artwork holder forward so its back is on the anchor plane
            artworkHolder.position.z = frameDepthMeters / 2.0
            
            // Rotate the artwork -90 degrees around the X-axis to make it stand upright
            let minusNinetyDegreesInRadians = -Float.pi / 2
            artworkHolder.transform.rotation = simd_quatf(angle: minusNinetyDegreesInRadians, axis: [1, 0, 0])

            // 1. Create the frame from four separate entities
            //let frameMaterial = SimpleMaterial(color: UIColor(config.frameColor), isMetallic: false)
            let frameMaterial = UnlitMaterial(color: UIColor(config.frameColor))
            let frameHolder = Entity()
            artworkHolder.addChild(frameHolder)

            // Top rail
            let topRailMesh = MeshResource.generateBox(width: totalWidthMeters, height: frameThicknessMeters, depth: frameDepthMeters)
            let topRail = ModelEntity(mesh: topRailMesh, materials: [frameMaterial])
            topRail.position.y = (totalHeightMeters - frameThicknessMeters) / 2.0
            frameHolder.addChild(topRail)

            // Bottom rail
            let bottomRail = topRail.clone(recursive: true)
            bottomRail.position.y = -topRail.position.y
            frameHolder.addChild(bottomRail)

            // Left rail
            let sideRailHeight = totalHeightMeters - (2 * frameThicknessMeters)
            let leftRailMesh = MeshResource.generateBox(width: frameThicknessMeters, height: sideRailHeight, depth: frameDepthMeters)
            let leftRail = ModelEntity(mesh: leftRailMesh, materials: [frameMaterial])
            leftRail.position.x = -(totalWidthMeters - frameThicknessMeters) / 2.0
            frameHolder.addChild(leftRail)

            // Right rail
            let rightRail = leftRail.clone(recursive: true)
            rightRail.position.x = -leftRail.position.x
            frameHolder.addChild(rightRail)

            // 2. Create the mat entity
            let matWidthMeters = Float(config.printWidthInches + config.matLeftInches + config.matRightInches) * inchToMeter
            let matHeightMeters = Float(config.printHeightInches + config.matTopInches + config.matBottomInches) * inchToMeter
            // Use UnlitMaterial to avoid reflections and show the pure color
            let matMaterial = UnlitMaterial(color: UIColor(config.matColor))
            let matMesh = MeshResource.generateBox(width: matWidthMeters, height: matHeightMeters, depth: 0.002)
            let matEntity = ModelEntity(mesh: matMesh, materials: [matMaterial])
            // Position the mat slightly behind the frame's front face
            matEntity.position.z = -frameDepthMeters / 2.0 + 0.001
            artworkHolder.addChild(matEntity)

            // 3. Create the print entity with the artwork image
            let printWidthMeters = Float(config.printWidthInches) * inchToMeter
            let printHeightMeters = Float(config.printHeightInches) * inchToMeter
            let printMesh = MeshResource.generateBox(width: printWidthMeters, height: printHeightMeters, depth: 0.001)
            
            var printMaterial: RealityKit.Material
            
            if let uiImage = UIImage(data: config.imageData) {
                // Normalize the image orientation before creating the texture
                let normalizedImage = self.normalizeImageOrientation(uiImage)
                
                if let cgImage = normalizedImage.cgImage {
                    do {
                        let textureResource = try await TextureResource(image: cgImage, options: .init(semantic: .color))
                        let materialTexture = MaterialParameters.Texture(textureResource)
                        var unlitMaterial = UnlitMaterial()
                        unlitMaterial.color = .init(texture: materialTexture)
                        printMaterial = unlitMaterial
                    } catch {
                        print("Failed to generate texture from image data: \(error)")
                        printMaterial = SimpleMaterial(color: .darkGray, isMetallic: false)
                    }
                } else {
                    printMaterial = SimpleMaterial(color: .darkGray, isMetallic: false)
                }
            } else {
                printMaterial = SimpleMaterial(color: .darkGray, isMetallic: false)
            }
            
            let printEntity = ModelEntity(mesh: printMesh, materials: [printMaterial])
            // Position the print slightly in front of the mat
            printEntity.position.z = matEntity.position.z + 0.001
            artworkHolder.addChild(printEntity)
            
            return artworkHolder
        }
        
        private func normalizeImageOrientation(_ image: UIImage) -> UIImage {
            if image.imageOrientation == .up {
                return image
            }
            
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return normalizedImage ?? image
        }
    }
}
