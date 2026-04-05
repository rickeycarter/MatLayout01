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
    var selectedArtworkForPlacement: ArtworkConfiguration? {
        didSet { updateTargetRectangles() }
    }
    var selectedPlacedArtworkId: UUID?
    var showWallLocators: Bool = true {
        didSet { updateWallLocatorVisibility() }
    }

    // MARK: Placement Guides
    var showPlacementGuides: Bool = false {
        didSet { updateGuideVisibility() }
    }
    var guideCenterHeightInches: Double = 57.0 {
        didSet { updateAllGuidePositions() }
    }
    var currentHeightOffsetInches: Double? = nil
    private var guideEntities: [UUID: Entity] = [:]  // wallAnchorId -> guide root
    private let snapThresholdMeters: Float = 0.04    // ~1.6 inches

    // MARK: Nail Guides
    var showNailGuides: Bool = false {
        didSet { updateNailGuides() }
    }
    private var nailGuideEntities: [UUID: Entity] = [:]       // artworkId -> nail guide root
    private var placedArtworkConfigs: [UUID: ArtworkConfiguration] = [:]
    private let defaultHangerDropInches: Double = 1.5

    private let nailMaterial: UnlitMaterial = {
        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor(red: 0.2, green: 1.0, blue: 0.2, alpha: 1.0))
        return mat
    }()

    let rootEntity = Entity()
    private var wallColliders: [UUID: Entity] = [:]

    private let wallMaterial: UnlitMaterial = {
        var mat = UnlitMaterial()
        mat.color = .init(tint: .cyan.withAlphaComponent(0.15))
        return mat
    }()

    private let guideMaterial: UnlitMaterial = {
        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 0.7))
        return mat
    }()
    private let guideStrokeWidth: Float = 0.004  // 4mm visible stroke
    private let guideDepth: Float = 0.002         // 2mm depth

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
                guideEntities.removeValue(forKey: anchor.id)
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
            // Update guide line width and position if wall extent changed
            if let guideRoot = guideEntities[anchor.id] {
                positionGuide(guideRoot, onWall: existing)
                if let line = guideRoot.findEntity(named: "guideLine") as? ModelEntity {
                    line.model?.mesh = MeshResource.generateBox(
                        width: anchor.geometry.extent.width,
                        height: guideStrokeWidth,
                        depth: guideDepth
                    )
                }
            }
            return
        }

        // First time: create the entity
        let extent = anchor.geometry.extent
        let mesh = MeshResource.generatePlane(
            width: extent.width,
            height: extent.height
        )
        let entity = ModelEntity(mesh: mesh, materials: [wallMaterial])
        if showWallLocators {
            entity.components.set(OpacityComponent(opacity: 0.15))
        } else {
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
        createGuideEntities(for: anchor.id, wallEntity: entity, extentWidth: extent.width)

        print("[Gallery] Wall collider CREATED: \(anchor.id) classification=\(anchor.surfaceClassification)")
    }

    private func updateWallLocatorVisibility() {
        for (_, entity) in wallColliders {
            if showWallLocators {
                entity.components.set(OpacityComponent(opacity: 0.15))
            } else {
                entity.components.set(OpacityComponent(opacity: 0))
            }
        }
    }

    // MARK: Placement Guides

    private func createGuideEntities(for anchorId: UUID, wallEntity: Entity, extentWidth: Float) {
        let guideRoot = Entity()
        guideRoot.name = "guide-\(anchorId.uuidString)"

        // Center height line spanning the wall width
        let lineMesh = MeshResource.generateBox(width: extentWidth, height: guideStrokeWidth, depth: guideDepth)
        let lineEntity = ModelEntity(mesh: lineMesh, materials: [guideMaterial])
        lineEntity.name = "guideLine"
        guideRoot.addChild(lineEntity)

        // Target rectangle (4 edges) — hidden until artwork is selected for placement
        let targetRoot = Entity()
        targetRoot.name = "guideTarget"
        targetRoot.components.set(OpacityComponent(opacity: 0))

        for edgeName in ["targetTop", "targetBottom", "targetLeft", "targetRight"] {
            let edge = ModelEntity(
                mesh: MeshResource.generateBox(width: 0.01, height: 0.01, depth: guideDepth),
                materials: [guideMaterial]
            )
            edge.name = edgeName
            targetRoot.addChild(edge)
        }
        guideRoot.addChild(targetRoot)

        positionGuide(guideRoot, onWall: wallEntity)

        if !showPlacementGuides {
            guideRoot.components.set(OpacityComponent(opacity: 0))
        }

        wallEntity.addChild(guideRoot)
        guideEntities[anchorId] = guideRoot
    }

    private func positionGuide(_ guideRoot: Entity, onWall wallEntity: Entity) {
        let inchToMeter: Float = 0.0254
        let idealHeightMeters = Float(guideCenterHeightInches) * inchToMeter
        let wallWorldY = wallEntity.position(relativeTo: nil).y
        let localY = idealHeightMeters - wallWorldY
        guideRoot.position = SIMD3<Float>(0, localY, guideDepth / 2.0)
    }

    private func updateAllGuidePositions() {
        for (anchorId, guideRoot) in guideEntities {
            guard let wallEntity = wallColliders[anchorId] else { continue }
            positionGuide(guideRoot, onWall: wallEntity)
        }
    }

    private func updateGuideVisibility() {
        for (_, guideRoot) in guideEntities {
            if showPlacementGuides {
                guideRoot.components.remove(OpacityComponent.self)
                updateTargetRectangles()
            } else {
                guideRoot.components.set(OpacityComponent(opacity: 0))
            }
        }
    }

    private func updateTargetRectangles() {
        guard showPlacementGuides else { return }

        guard let config = selectedArtworkForPlacement else {
            // Hide all target rectangles
            for (_, guideRoot) in guideEntities {
                if let target = guideRoot.findEntity(named: "guideTarget") {
                    target.components.set(OpacityComponent(opacity: 0))
                }
            }
            return
        }

        let inchToMeter: Float = 0.0254
        let artW = Float(config.totalWidthInches) * inchToMeter
        let artH = Float(config.totalHeightInches) * inchToMeter
        let stroke = guideStrokeWidth

        for (_, guideRoot) in guideEntities {
            guard let target = guideRoot.findEntity(named: "guideTarget") else { continue }

            if let top = target.findEntity(named: "targetTop") as? ModelEntity {
                top.model?.mesh = MeshResource.generateBox(width: artW, height: stroke, depth: guideDepth)
                top.position = SIMD3(0, artH / 2.0, 0)
            }
            if let bottom = target.findEntity(named: "targetBottom") as? ModelEntity {
                bottom.model?.mesh = MeshResource.generateBox(width: artW, height: stroke, depth: guideDepth)
                bottom.position = SIMD3(0, -artH / 2.0, 0)
            }
            if let left = target.findEntity(named: "targetLeft") as? ModelEntity {
                left.model?.mesh = MeshResource.generateBox(width: stroke, height: artH, depth: guideDepth)
                left.position = SIMD3(-artW / 2.0, 0, 0)
            }
            if let right = target.findEntity(named: "targetRight") as? ModelEntity {
                right.model?.mesh = MeshResource.generateBox(width: stroke, height: artH, depth: guideDepth)
                right.position = SIMD3(artW / 2.0, 0, 0)
            }

            target.components.remove(OpacityComponent.self)
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
        var offsetPosition = scenePosition + wallNormal * halfFrameDepth

        // Snap to guide center height if guides are on and within threshold
        if showPlacementGuides {
            let idealY = Float(guideCenterHeightInches) * inchToMeter
            if abs(offsetPosition.y - idealY) < snapThresholdMeters {
                offsetPosition.y = idealY
            }
        }

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
        placedArtworkConfigs[artworkId] = config
        print("[Gallery] Placed artwork '\(config.artworkName)' at \(scenePosition)")

        // Create nail guide if nails are currently shown
        if showNailGuides {
            createNailGuide(for: artworkId)
        }

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

    /// Projects onto the wall, then optionally snaps to the guide center height.
    func projectOntoWallWithSnap(artworkEntity: Entity, dragPosition: SIMD3<Float>) -> SIMD3<Float> {
        var projected = projectOntoWall(artworkEntity: artworkEntity, dragPosition: dragPosition)

        if showPlacementGuides {
            let inchToMeter: Float = 0.0254
            let idealY = Float(guideCenterHeightInches) * inchToMeter
            let offsetY = projected.y - idealY
            currentHeightOffsetInches = Double(offsetY) / Double(inchToMeter)

            if abs(offsetY) < snapThresholdMeters {
                projected.y = idealY
                currentHeightOffsetInches = 0
            }
        } else {
            currentHeightOffsetInches = nil
        }

        return projected
    }

    // MARK: Nail Guides

    private func nailPosition(for artworkId: UUID) -> SIMD3<Float>? {
        guard let entity = placedArtworks[artworkId],
              let config = placedArtworkConfigs[artworkId] else { return nil }

        let inchToMeter: Float = 0.0254
        let frameHalfHeight = Float(config.totalHeightInches) * inchToMeter / 2.0
        let hangerDrop = Float(config.hangerDropInches ?? defaultHangerDropInches) * inchToMeter

        let artPos = entity.position(relativeTo: nil)
        let nailY = artPos.y + frameHalfHeight - hangerDrop

        let nailZ = artPos.z // keep same Z plane as artwork center

        return SIMD3<Float>(artPos.x, nailY, nailZ)
    }

    private func formatHeight(meters: Float) -> String {
        let totalInches = Double(meters) / 0.0254
        let feet = Int(totalInches / 12.0)
        let inches = totalInches - Double(feet * 12)
        if feet > 0 {
            return String(format: "%d' %.1f\"", feet, inches)
        } else {
            return String(format: "%.1f\"", inches)
        }
    }

    private func createNailGuide(for artworkId: UUID) {
        // Remove existing guide if any
        if let existing = nailGuideEntities.removeValue(forKey: artworkId) {
            existing.removeFromParent()
        }

        guard let pos = nailPosition(for: artworkId) else { return }

        let guideRoot = Entity()
        guideRoot.name = "nail-\(artworkId.uuidString)"
        guideRoot.position = pos

        // Crosshair: center sphere
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.008),
            materials: [nailMaterial]
        )
        guideRoot.addChild(sphere)

        // Crosshair: horizontal line
        let hLine = ModelEntity(
            mesh: MeshResource.generateBox(width: 0.04, height: 0.003, depth: 0.002),
            materials: [nailMaterial]
        )
        guideRoot.addChild(hLine)

        // Crosshair: vertical line
        let vLine = ModelEntity(
            mesh: MeshResource.generateBox(width: 0.003, height: 0.04, depth: 0.002),
            materials: [nailMaterial]
        )
        guideRoot.addChild(vLine)

        // Height label
        let heightText = formatHeight(meters: pos.y)
        let textMesh = MeshResource.generateText(
            heightText,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.02),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byClipping
        )
        let textEntity = ModelEntity(mesh: textMesh, materials: [nailMaterial])
        textEntity.name = "nailLabel"
        // Position label to the right of the crosshair
        textEntity.position = SIMD3<Float>(0.03, -0.01, 0)
        guideRoot.addChild(textEntity)

        rootEntity.addChild(guideRoot)
        nailGuideEntities[artworkId] = guideRoot
    }

    func updateNailGuidePosition(for artworkId: UUID) {
        guard let guideRoot = nailGuideEntities[artworkId],
              let pos = nailPosition(for: artworkId) else { return }
        guideRoot.position = pos

        // Update height label text
        let heightText = formatHeight(meters: pos.y)
        if let textEntity = guideRoot.children.reversed().first(where: { $0 is ModelEntity }) as? ModelEntity, textEntity.name == "nailLabel" {
            textEntity.model?.mesh = MeshResource.generateText(
                heightText,
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: 0.02),
                containerFrame: .zero,
                alignment: .left,
                lineBreakMode: .byClipping
            )
        }
    }

    private func updateNailGuides() {
        if showNailGuides {
            // Create guides for all placed artworks
            for artworkId in placedArtworks.keys {
                createNailGuide(for: artworkId)
            }
        } else {
            // Remove all nail guides
            for (_, guide) in nailGuideEntities {
                guide.removeFromParent()
            }
            nailGuideEntities.removeAll()
        }
    }

    func removeAllPlaced() {
        for (_, entity) in placedArtworks {
            entity.removeFromParent()
        }
        for (_, guide) in nailGuideEntities {
            guide.removeFromParent()
        }
        placedArtworks.removeAll()
        artworkWallMapping.removeAll()
        artworkDepthOffset.removeAll()
        placedArtworkConfigs.removeAll()
        nailGuideEntities.removeAll()
        selectedPlacedArtworkId = nil
    }

    func removePlacedArtwork(_ id: UUID) {
        if let entity = placedArtworks.removeValue(forKey: id) {
            entity.removeFromParent()
        }
        if let guide = nailGuideEntities.removeValue(forKey: id) {
            guide.removeFromParent()
        }
        artworkWallMapping.removeValue(forKey: id)
        artworkDepthOffset.removeValue(forKey: id)
        placedArtworkConfigs.removeValue(forKey: id)
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
                let headAnchor = AnchorEntity(.head)
                headAnchor.name = "toolbarAnchor"
                // Position relative to head: slightly below eye level, 1.5m forward
                toolbar.position = [0, -0.4, -1.5]
                headAnchor.addChild(toolbar)
                content.add(headAnchor)
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
                value.entity.position = viewModel.projectOntoWallWithSnap(
                    artworkEntity: value.entity,
                    dragPosition: scenePos
                )
                // Update nail guide position if visible
                if viewModel.showNailGuides {
                    let idStr = value.entity.name.replacingOccurrences(of: "artwork-", with: "")
                    if let artworkId = UUID(uuidString: idStr) {
                        viewModel.updateNailGuidePosition(for: artworkId)
                    }
                }
            }
            .onEnded { _ in
                viewModel.currentHeightOffsetInches = nil
            }
    }

    // MARK: Toolbar

    private var toolbarContent: some View {
        VStack(spacing: 12) {
            if let offset = viewModel.currentHeightOffsetInches, viewModel.showPlacementGuides {
                if abs(offset) < 0.5 {
                    Label("Snapped to ideal center (\(Int(viewModel.guideCenterHeightInches))\")", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else {
                    let direction = offset > 0 ? "above" : "below"
                    Label(String(format: "%.1f\" %@ ideal center (%d\")", abs(offset), direction, Int(viewModel.guideCenterHeightInches)), systemImage: "arrow.up.and.down")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
            } else if let selected = viewModel.selectedArtworkForPlacement {
                Label("Look at a wall and pinch to place \"\(selected.artworkName)\"", systemImage: "hand.pinch")
                    .font(.headline)
            } else if viewModel.selectedPlacedArtworkId != nil {
                Label("Artwork selected — drag to move, or tap Remove", systemImage: "hand.point.up.left")
                    .font(.headline)
            } else if viewModel.showNailGuides && !viewModel.placedArtworks.isEmpty {
                Label("Nail positions for \(viewModel.placedArtworks.count) piece\(viewModel.placedArtworks.count == 1 ? "" : "s")", systemImage: "scope")
                    .font(.headline)
                    .foregroundStyle(.green)
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

                Button {
                    viewModel.showPlacementGuides.toggle()
                } label: {
                    Label(
                        viewModel.showPlacementGuides ? "Hide Guides" : "Show Guides",
                        systemImage: viewModel.showPlacementGuides ? "ruler.fill" : "ruler"
                    )
                }
                .buttonStyle(.bordered)
                .tint(viewModel.showPlacementGuides ? .orange : nil)

                if !viewModel.placedArtworks.isEmpty {
                    Button {
                        viewModel.showNailGuides.toggle()
                    } label: {
                        Label(
                            viewModel.showNailGuides ? "Hide Nails" : "Show Nails",
                            systemImage: viewModel.showNailGuides ? "scope" : "scope"
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.showNailGuides ? .green : nil)
                }

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

            if viewModel.showPlacementGuides {
                Divider()
                HStack {
                    Text("Center Height")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(viewModel.guideCenterHeightInches))\"")
                        .font(.subheadline)
                        .monospacedDigit()
                    Stepper("", value: Bindable(viewModel).guideCenterHeightInches, in: 48...72, step: 1)
                        .labelsHidden()
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(20)
        .glassBackgroundEffect()
        .frame(width: 1000)
    }
}

#endif
