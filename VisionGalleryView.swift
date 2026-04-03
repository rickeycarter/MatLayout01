//
//  VisionGalleryView.swift
//  MatLayout01
//
//  Immersive mixed-reality gallery for visionOS.
//  Detects walls, lets users place framed artwork, and reposition via drag.
//

#if os(visionOS)

import SwiftUI
import RealityKit
import ARKit

// MARK: - View Model

@Observable
@MainActor
final class ImmersiveGalleryViewModel {
    private let arkitSession = ARKitSession()
    private let planeDetection = PlaneDetectionProvider(alignments: [.vertical])

    private(set) var detectedWalls: [UUID: PlaneAnchor] = [:]
    var placedArtworks: [UUID: Entity] = [:]
    private var artworkWallMapping: [UUID: UUID] = [:]  // artworkId -> wallAnchorId
    private var artworkDepthOffset: [UUID: Float] = [:]  // artworkId -> half frame depth
    var selectedArtworkForPlacement: ArtworkConfiguration?
    var selectedPlacedArtworkId: UUID?
    var showWallLocators: Bool = true {
        didSet { updateWallLocatorVisibility() }
    }

    let rootEntity = Entity()
    private var wallColliders: [UUID: Entity] = [:]

    private let wallMaterial: UnlitMaterial = {
        var mat = UnlitMaterial()
        mat.color = .init(tint: .cyan.withAlphaComponent(0.15))
        return mat
    }()

    // MARK: ARKit Session

    func startSession() async {
        guard PlaneDetectionProvider.isSupported else {
            print("[Gallery] PlaneDetectionProvider is not supported on this device")
            return
        }

        do {
            try await arkitSession.run([planeDetection])
            print("[Gallery] ARKit session started successfully")
        } catch {
            print("[Gallery] ARKit session failed to start: \(error)")
            return
        }

        for await update in planeDetection.anchorUpdates {
            let anchor = update.anchor

            switch update.event {
            case .added, .updated:
                guard anchor.alignment == .vertical else { continue }
                // Only create colliders for actual walls and doors
                guard anchor.surfaceClassification == .wall || anchor.surfaceClassification == .door else { continue }
                detectedWalls[anchor.id] = anchor
                updateWallCollider(for: anchor)
            case .removed:
                detectedWalls.removeValue(forKey: anchor.id)
                if let collider = wallColliders.removeValue(forKey: anchor.id) {
                    collider.removeFromParent()
                }
                print("[Gallery] Wall removed: \(anchor.id)")
            }
        }
    }

    // MARK: Wall Colliders

    /// Compute orientation and position for a wall collider from an anchor.
    private func wallTransformValues(for anchor: PlaneAnchor) -> (orientation: simd_quatf, position: SIMD3<Float>) {
        let anchorMatrix = anchor.originFromAnchorTransform
        let wallNormal = normalize(SIMD3<Float>(
            anchorMatrix.columns.1.x,
            anchorMatrix.columns.1.y,
            anchorMatrix.columns.1.z
        ))
        let worldUp = SIMD3<Float>(0, 1, 0)
        let wallRight = normalize(cross(worldUp, wallNormal))
        let adjustedUp = normalize(cross(wallNormal, wallRight))

        var orientMatrix = matrix_identity_float4x4
        orientMatrix.columns.0 = SIMD4(wallRight, 0)
        orientMatrix.columns.1 = SIMD4(adjustedUp, 0)
        orientMatrix.columns.2 = SIMD4(wallNormal, 0)

        let extentWorld = anchorMatrix * anchor.geometry.extent.anchorFromExtentTransform
        let position = SIMD3<Float>(
            extentWorld.columns.3.x,
            extentWorld.columns.3.y,
            extentWorld.columns.3.z
        )
        return (simd_quatf(orientMatrix), position)
    }

    /// Creates or updates a tappable wall entity matching a detected wall.
    /// On first call, creates the entity. On subsequent calls, only updates the transform.
    private func updateWallCollider(for anchor: PlaneAnchor) {
        let (orientation, position) = wallTransformValues(for: anchor)

        if let existing = wallColliders[anchor.id] {
            // Update transform in place — do NOT recreate the entity.
            // Recreating destroys gesture tracking state.
            existing.orientation = orientation
            existing.position = position
            return
        }

        // First time: create the entity
        let extent = anchor.geometry.extent
        let mesh = MeshResource.generatePlane(
            width: extent.width,
            height: extent.height
        )
        let entity = ModelEntity(mesh: mesh, materials: [wallMaterial])
        if !showWallLocators {
            entity.components.set(OpacityComponent(opacity: 0))
        }
        entity.name = "wall-\(anchor.id.uuidString)"
        entity.orientation = orientation
        entity.position = position

        // Collision box matching the vertical plane (X = width, Y = height, Z = thickness)
        let shape = ShapeResource.generateBox(
            width: extent.width,
            height: extent.height,
            depth: 0.1
        )
        var collision = CollisionComponent(shapes: [shape])
        collision.filter = CollisionFilter(group: [], mask: [])
        entity.components.set(collision)
        entity.components.set(InputTargetComponent(allowedInputTypes: .all))
        entity.components.set(HoverEffectComponent())

        rootEntity.addChild(entity)
        wallColliders[anchor.id] = entity

        print("[Gallery] Wall collider CREATED: \(anchor.id) classification=\(anchor.surfaceClassification)")
    }

    private func updateWallLocatorVisibility() {
        for (_, entity) in wallColliders {
            if showWallLocators {
                entity.components.remove(OpacityComponent.self)
            } else {
                entity.components.set(OpacityComponent(opacity: 0))
            }
        }
    }

    // MARK: Artwork Placement

    func handleTap(on entity: Entity, at scenePosition: SIMD3<Float>) async {
        print("[Gallery] Tap on entity: '\(entity.name)' at \(scenePosition)")
        guard entity.name.hasPrefix("wall-") else {
            print("[Gallery] Not a wall entity, ignoring")
            return
        }
        guard let config = selectedArtworkForPlacement else {
            print("[Gallery] No artwork selected for placement")
            return
        }

        // Find the corresponding wall anchor
        let idString = entity.name.replacingOccurrences(of: "wall-", with: "")
        guard let wallId = UUID(uuidString: idString),
              let wallAnchor = detectedWalls[wallId] else { return }

        // Build the interactive artwork entity
        print("[Gallery] Building artwork entity for '\(config.artworkName)'...")
        guard let artworkEntity = await ArtworkEntityBuilder.createInteractiveArtworkEntity(for: config) else {
            print("[Gallery] Failed to create artwork entity")
            return
        }

        // Compute a placement transform oriented flush against the wall.
        // The artwork entity has a built-in -90° X rotation that maps:
        //   local Y (height) → parent -Z,  local Z (depth) → parent +Y
        // So for the artwork to stand upright on a wall we need:
        //   parent X = right along wall (for width)
        //   parent Y = wall outward normal (for depth after rotation)
        //   parent Z = down (so -Z = up for height after rotation)
        let wallTransform = wallAnchor.originFromAnchorTransform
        let wallNormal = normalize(SIMD3<Float>(
            wallTransform.columns.1.x,
            wallTransform.columns.1.y,
            wallTransform.columns.1.z
        ))
        let worldUp = SIMD3<Float>(0, 1, 0)
        let wallRight = normalize(cross(worldUp, wallNormal))
        let adjustedUp = normalize(cross(wallNormal, wallRight))

        // Offset outward from the wall so the frame sits flush (not embedded)
        let inchToMeter: Float = 0.0254
        let halfFrameDepth = Float(config.frameWidthInches) * inchToMeter * 0.75 / 2.0
        let offsetPosition = scenePosition + wallNormal * halfFrameDepth

        var placementMatrix = matrix_identity_float4x4
        placementMatrix.columns.0 = SIMD4(wallRight, 0)
        placementMatrix.columns.1 = SIMD4(wallNormal, 0)
        placementMatrix.columns.2 = SIMD4(-adjustedUp, 0)
        placementMatrix.columns.3 = SIMD4(offsetPosition, 1)

        artworkEntity.transform = Transform(matrix: placementMatrix)

        let artworkId = UUID()
        artworkEntity.name = "artwork-\(artworkId.uuidString)"
        rootEntity.addChild(artworkEntity)
        placedArtworks[artworkId] = artworkEntity
        artworkWallMapping[artworkId] = wallId
        artworkDepthOffset[artworkId] = halfFrameDepth
        print("[Gallery] Placed artwork '\(config.artworkName)' at \(scenePosition)")

        // Exit placement mode after placing
        selectedArtworkForPlacement = nil
    }

    /// Projects a 3D point onto the wall plane that the given artwork is attached to.
    /// Returns the projected point, keeping the artwork flush against the wall.
    func projectOntoWall(artworkEntity: Entity, dragPosition: SIMD3<Float>) -> SIMD3<Float> {
        // Find which wall this artwork belongs to
        let idString = artworkEntity.name.replacingOccurrences(of: "artwork-", with: "")
        guard let artworkId = UUID(uuidString: idString),
              let wallId = artworkWallMapping[artworkId],
              let wallAnchor = detectedWalls[wallId] else {
            return dragPosition
        }

        let wallTransform = wallAnchor.originFromAnchorTransform
        let wallNormal = normalize(SIMD3<Float>(
            wallTransform.columns.1.x,
            wallTransform.columns.1.y,
            wallTransform.columns.1.z
        ))

        // A point on the wall plane (the anchor's center)
        let extentWorld = wallTransform * wallAnchor.geometry.extent.anchorFromExtentTransform
        let wallPoint = SIMD3<Float>(extentWorld.columns.3.x, extentWorld.columns.3.y, extentWorld.columns.3.z)

        // Project dragPosition onto the wall plane, then offset outward by frame depth
        let depthOffset = artworkDepthOffset[artworkId] ?? 0
        let projectedOffset = dot(dragPosition - wallPoint, wallNormal)
        return dragPosition - projectedOffset * wallNormal + wallNormal * depthOffset
    }

    func removeAllPlaced() {
        for (_, entity) in placedArtworks {
            entity.removeFromParent()
        }
        placedArtworks.removeAll()
        artworkWallMapping.removeAll()
        artworkDepthOffset.removeAll()
        selectedPlacedArtworkId = nil
    }

    func removePlacedArtwork(_ id: UUID) {
        if let entity = placedArtworks.removeValue(forKey: id) {
            entity.removeFromParent()
        }
        artworkWallMapping.removeValue(forKey: id)
        artworkDepthOffset.removeValue(forKey: id)
        if selectedPlacedArtworkId == id {
            selectedPlacedArtworkId = nil
        }
    }

    func selectPlacedArtwork(entity: Entity) {
        let idString = entity.name.replacingOccurrences(of: "artwork-", with: "")
        guard let artworkId = UUID(uuidString: idString),
              placedArtworks[artworkId] != nil else { return }
        selectedPlacedArtworkId = artworkId
    }
}

// MARK: - View

struct VisionGalleryView: View {
    @EnvironmentObject var galleryViewModel: GalleryViewModel
    @State private var viewModel = ImmersiveGalleryViewModel()
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openWindow) var openWindow

    var body: some View {
        RealityView { content, attachments in
            content.add(viewModel.rootEntity)

            if let toolbar = attachments.entity(for: "toolbar") {
                toolbar.position = [0, 1.0, -1.5]
                content.add(toolbar)
            }
        } attachments: {
            Attachment(id: "toolbar") {
                toolbarContent
            }
        }
        .gesture(tapGesture)
        .simultaneousGesture(dragGesture)
        .task {
            // Pre-select the artwork the user was viewing when they opened the gallery
            if let initial = galleryViewModel.initialArtworkForGallery {
                viewModel.selectedArtworkForPlacement = initial
                galleryViewModel.initialArtworkForGallery = nil
            }
            await viewModel.startSession()
        }
    }

    // MARK: Gestures

    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                print("[Gallery] SpatialTapGesture fired on '\(value.entity.name)'")
                // Tapping a placed artwork selects it for removal
                if value.entity.name.hasPrefix("artwork-") {
                    viewModel.selectPlacedArtwork(entity: value.entity)
                    return
                }
                let scenePos = value.convert(value.location3D, from: .local, to: .scene)
                Task {
                    await viewModel.handleTap(on: value.entity, at: scenePos)
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                guard value.entity.name.hasPrefix("artwork-") else { return }
                let scenePos = value.convert(value.location3D, from: .local, to: .scene)
                value.entity.position = viewModel.projectOntoWall(
                    artworkEntity: value.entity,
                    dragPosition: scenePos
                )
            }
    }

    // MARK: Toolbar

    private var toolbarContent: some View {
        VStack(spacing: 12) {
            if let selected = viewModel.selectedArtworkForPlacement {
                Label("Look at a wall and pinch to place \"\(selected.artworkName)\"", systemImage: "hand.pinch")
                    .font(.headline)
            } else if viewModel.selectedPlacedArtworkId != nil {
                Label("Artwork selected — drag to move, or tap Remove", systemImage: "hand.point.up.left")
                    .font(.headline)
            } else if viewModel.placedArtworks.isEmpty {
                Text("Select an artwork to place on a wall")
                    .font(.headline)
            } else {
                Text("\(viewModel.placedArtworks.count) piece\(viewModel.placedArtworks.count == 1 ? "" : "s") placed — pinch to select")
                    .font(.headline)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(galleryViewModel.artworks) { artwork in
                        Button {
                            viewModel.selectedArtworkForPlacement = artwork
                            print("[Gallery] Selected artwork: '\(artwork.artworkName)' for placement")
                        } label: {
                            VStack(spacing: 4) {
                                artwork.preview
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                                Text(artwork.artworkName)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(6)
                            .background(
                                viewModel.selectedArtworkForPlacement?.id == artwork.id
                                    ? Color.accentColor.opacity(0.3)
                                    : Color.clear
                            )
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            HStack(spacing: 20) {
                Button {
                    viewModel.showWallLocators.toggle()
                } label: {
                    Label(
                        viewModel.showWallLocators ? "Hide Walls" : "Show Walls",
                        systemImage: viewModel.showWallLocators ? "rectangle.dashed" : "rectangle"
                    )
                }
                .buttonStyle(.bordered)

                if viewModel.selectedArtworkForPlacement != nil {
                    Button("Cancel") {
                        viewModel.selectedArtworkForPlacement = nil
                    }
                    .buttonStyle(.bordered)
                }

                if let selectedId = viewModel.selectedPlacedArtworkId {
                    Button {
                        viewModel.removePlacedArtwork(selectedId)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button("Deselect") {
                        viewModel.selectedPlacedArtworkId = nil
                    }
                    .buttonStyle(.bordered)
                }

                if !viewModel.placedArtworks.isEmpty {
                    Button("Clear All") {
                        viewModel.removeAllPlaced()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Button("Done") {
                    Task {
                        await dismissImmersiveSpace()
                        openWindow(id: "main")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .glassBackgroundEffect()
        .frame(width: 500)
    }
}

#endif
