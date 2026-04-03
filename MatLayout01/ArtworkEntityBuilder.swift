//
//  ArtworkEntityBuilder.swift
//  MatLayout01
//
//  Shared RealityKit entity builder for framed artwork.
//  Used by iOS ARArtView and visionOS VisionGalleryView.
//

import RealityKit
import UIKit

struct ArtworkEntityBuilder {
    static let inchToMeter: Float = 0.0254

    /// Builds a complete framed artwork entity from an ArtworkConfiguration.
    /// The returned entity is oriented upright (-90 deg X rotation) with its
    /// back face at z=0 (flush against the anchor/wall plane).
    @MainActor
    static func createArtworkEntity(for config: ArtworkConfiguration) async -> Entity? {
        let artworkHolder = Entity()

        let totalWidthMeters = Float(config.totalWidthInches) * inchToMeter
        let totalHeightMeters = Float(config.totalHeightInches) * inchToMeter
        let frameThicknessMeters = Float(config.frameWidthInches) * inchToMeter
        let frameDepthMeters = frameThicknessMeters * 0.75

        // Shift forward so back face sits on the anchor plane
        artworkHolder.position.z = frameDepthMeters / 2.0

        // Rotate -90 degrees around X to stand upright on a vertical surface
        artworkHolder.transform.rotation = simd_quatf(
            angle: -Float.pi / 2,
            axis: [1, 0, 0]
        )

        // MARK: Frame rails

        let frameMaterial = UnlitMaterial(color: UIColor(config.frameColor))
        let frameHolder = Entity()
        artworkHolder.addChild(frameHolder)

        // Top rail
        let topRailMesh = MeshResource.generateBox(
            width: totalWidthMeters,
            height: frameThicknessMeters,
            depth: frameDepthMeters
        )
        let topRail = ModelEntity(mesh: topRailMesh, materials: [frameMaterial])
        topRail.position.y = (totalHeightMeters - frameThicknessMeters) / 2.0
        frameHolder.addChild(topRail)

        // Bottom rail
        let bottomRail = topRail.clone(recursive: true)
        bottomRail.position.y = -topRail.position.y
        frameHolder.addChild(bottomRail)

        // Left rail
        let sideRailHeight = totalHeightMeters - (2 * frameThicknessMeters)
        let leftRailMesh = MeshResource.generateBox(
            width: frameThicknessMeters,
            height: sideRailHeight,
            depth: frameDepthMeters
        )
        let leftRail = ModelEntity(mesh: leftRailMesh, materials: [frameMaterial])
        leftRail.position.x = -(totalWidthMeters - frameThicknessMeters) / 2.0
        frameHolder.addChild(leftRail)

        // Right rail
        let rightRail = leftRail.clone(recursive: true)
        rightRail.position.x = -leftRail.position.x
        frameHolder.addChild(rightRail)

        // MARK: Mat

        let matWidthMeters = Float(config.printWidthInches + config.matLeftInches + config.matRightInches) * inchToMeter
        let matHeightMeters = Float(config.printHeightInches + config.matTopInches + config.matBottomInches) * inchToMeter
        let matMaterial = UnlitMaterial(color: UIColor(config.matColor))
        let matMesh = MeshResource.generateBox(width: matWidthMeters, height: matHeightMeters, depth: 0.002)
        let matEntity = ModelEntity(mesh: matMesh, materials: [matMaterial])
        matEntity.position.z = -frameDepthMeters / 2.0 + 0.001
        artworkHolder.addChild(matEntity)

        // MARK: Print with texture

        let printWidthMeters = Float(config.printWidthInches) * inchToMeter
        let printHeightMeters = Float(config.printHeightInches) * inchToMeter
        let printMesh = MeshResource.generateBox(width: printWidthMeters, height: printHeightMeters, depth: 0.001)

        var printMaterial: RealityKit.Material

        if let uiImage = UIImage(data: config.imageData) {
            let normalizedImage = normalizeImageOrientation(uiImage)
            if let cgImage = normalizedImage.cgImage {
                do {
                    let textureResource = try await TextureResource(
                        image: cgImage,
                        options: .init(semantic: .color)
                    )
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
        printEntity.position.z = matEntity.position.z + 0.001
        artworkHolder.addChild(printEntity)

        return artworkHolder
    }

    /// Creates an artwork entity with collision and input target components
    /// so it can receive tap and drag gestures in visionOS.
    @MainActor
    static func createInteractiveArtworkEntity(for config: ArtworkConfiguration) async -> Entity? {
        guard let entity = await createArtworkEntity(for: config) else { return nil }

        let totalWidthMeters = Float(config.totalWidthInches) * inchToMeter
        let totalHeightMeters = Float(config.totalHeightInches) * inchToMeter
        let frameDepthMeters = Float(config.frameWidthInches) * inchToMeter * 0.75

        let collisionShape = ShapeResource.generateBox(
            width: totalWidthMeters,
            height: totalHeightMeters,
            depth: frameDepthMeters
        )

        let wrapper = Entity()
        wrapper.addChild(entity)
        wrapper.components.set(CollisionComponent(shapes: [collisionShape]))
        wrapper.components.set(InputTargetComponent(allowedInputTypes: .indirect))
        wrapper.components.set(HoverEffectComponent())

        return wrapper
    }

    // MARK: - Private

    private static func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? image
    }
}
