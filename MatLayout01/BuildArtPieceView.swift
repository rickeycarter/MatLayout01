//
//  BuildArtPieceView.swift
//  MatLayout01
//
//  Created by Rickey Carter on 6/21/25.
//


import SwiftUI
import PhotosUI

/// Determines whether the builder starts from a photo or from frame dimensions
enum BuilderMode {
    case photoFirst
    case frameFirst
}

struct BuildArtPieceView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Parameters

    var artworkToEdit: ArtworkConfiguration?
    var onComplete: (ArtworkConfiguration) -> Void
    var builderMode: BuilderMode = .photoFirst
    var designRecommendation: DesignRecommendation? = nil
    var initialFrameWidth: Double? = nil
    var initialFrameHeight: Double? = nil

    // MARK: - State

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var artworkName: String = ""
    @State private var selectedCropRatio: CropRatio = .r4x5

    // Zoom and pan
    @State private var initialScale: CGFloat = 1.0
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var finalOffset: CGSize = .zero

    // Frame
    @State private var frameWidth: Double = 1.0
    @State private var frameColor: Color = .black

    // Mat
    @State private var matColor: Color = Color(red: 250/255, green: 249/255, blue: 246/255) // #FAF9F6
    @State private var matTop: Double = 2.0
    @State private var matBottom: Double = 2.0
    @State private var matLeft: Double = 2.0
    @State private var matRight: Double = 2.0

    // Framing mode
    @State private var framingMode: FramingMode = .custom
    @State private var selectedStandardFrameId: UUID?
    @State private var mattingStyle: MattingStyle = .centered
    @State private var frameSettingsExpanded: Bool = false

    // Custom frame dimensions
    @State private var customFrameWidth: Double = 16.0
    @State private var customFrameHeight: Double = 20.0

    // Pre-cut mat (frame-first mode only)
    @State private var hasPreCutMat: Bool = false
    @State private var matOpeningWidth: Double = 8.0
    @State private var matOpeningHeight: Double = 10.0

    // MARK: - Computed Properties

    /// Effective print dimensions: from pre-cut mat opening or selected CropRatio
    private var effectivePrintWidth: Double {
        if builderMode == .frameFirst && hasPreCutMat {
            return matOpeningWidth
        }
        return selectedCropRatio.dimensions.width
    }

    private var effectivePrintHeight: Double {
        if builderMode == .frameFirst && hasPreCutMat {
            return matOpeningHeight
        }
        return selectedCropRatio.dimensions.height
    }

    var totalWidth: Double {
        if framingMode == .standard,
           let frameId = selectedStandardFrameId,
           let frame = currentAvailableFrames.first(where: { $0.id == frameId }) {
            return frame.width + (frameWidth * 2)
        }
        if framingMode == .customFrame {
            return customFrameWidth + (frameWidth * 2)
        }
        return effectivePrintWidth + matLeft + matRight + (frameWidth * 2)
    }

    var totalHeight: Double {
        if framingMode == .standard,
           let frameId = selectedStandardFrameId,
           let frame = currentAvailableFrames.first(where: { $0.id == frameId }) {
            return frame.height + (frameWidth * 2)
        }
        if framingMode == .customFrame {
            return customFrameHeight + (frameWidth * 2)
        }
        return effectivePrintHeight + matTop + matBottom + (frameWidth * 2)
    }

    var finalImageTransform: (scale: CGFloat, offset: CGSize) {
        (scale: initialScale * finalScale, offset: finalOffset)
    }

    struct PreviewConfig: Equatable {
        let totalWidth: Double
        let totalHeight: Double
        let imageIdentifier: String?
    }

    private var currentAvailableFrames: [StandardFrame] {
        availableStandardFrames(for: selectedCropRatio)
    }

    private var showMattingStylePicker: Bool {
        let printSize = (width: effectivePrintWidth, height: effectivePrintHeight)
        var frameInnerWidth: Double
        var frameInnerHeight: Double

        if framingMode == .standard,
           let frameId = selectedStandardFrameId,
           let standardFrame = currentAvailableFrames.first(where: { $0.id == frameId }) {
            frameInnerWidth = standardFrame.width
            frameInnerHeight = standardFrame.height
        } else if framingMode == .customFrame {
            frameInnerWidth = customFrameWidth
            frameInnerHeight = customFrameHeight
        } else {
            return false
        }

        guard frameInnerWidth >= printSize.width, frameInnerHeight >= printSize.height else { return false }

        let horizontalMat = (frameInnerWidth - printSize.width) / 2.0
        let verticalMat = (frameInnerHeight - printSize.height) / 2.0

        return verticalMat > horizontalMat
    }

    /// Print sizes filtered to those that fit the current frame (frame-first mode only)
    private var compatiblePrintSizes: [CropRatio] {
        guard builderMode == .frameFirst else { return CropRatio.allCases }

        let innerW: Double
        let innerH: Double
        if framingMode == .customFrame {
            innerW = customFrameWidth
            innerH = customFrameHeight
        } else if framingMode == .standard,
                  let frameId = selectedStandardFrameId,
                  let frame = currentAvailableFrames.first(where: { $0.id == frameId }) {
            innerW = frame.width
            innerH = frame.height
        } else {
            return CropRatio.allCases
        }

        return CropRatio.allCases.filter { ratio in
            let dims = ratio.dimensions
            return dims.width <= innerW && dims.height <= innerH
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .regular {
                    iPadLayout
                } else {
                    iPhoneLayout
                }
            }
            .navigationTitle(artworkToEdit == nil ? "New Artwork" : "Edit Artwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        guard let imageData = selectedImageData else { return }
                        let config = ArtworkConfiguration(
                            id: artworkToEdit?.id ?? UUID(),
                            artworkName: artworkName,
                            imageData: imageData,
                            totalWidthInches: totalWidth,
                            totalHeightInches: totalHeight,
                            matColor: matColor,
                            frameColor: frameColor,
                            frameWidthInches: frameWidth,
                            imageScale: finalImageTransform.scale,
                            imageOffset: finalOffset,
                            printWidthInches: effectivePrintWidth,
                            printHeightInches: effectivePrintHeight,
                            matTopInches: matTop,
                            matBottomInches: matBottom,
                            matLeftInches: matLeft,
                            matRightInches: matRight,
                            cropRatio: selectedCropRatio,
                            framingMode: framingMode,
                            mattingStyle: mattingStyle,
                            selectedStandardFrameId: selectedStandardFrameId,
                            customFrameWidthInches: framingMode == .customFrame ? customFrameWidth : nil,
                            customFrameHeightInches: framingMode == .customFrame ? customFrameHeight : nil,
                            hasPreCutMat: hasPreCutMat
                        )
                        onComplete(config)
                        dismiss()
                    }
                    .disabled(selectedImageData == nil || artworkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: initializeView)
            .onChange(of: framingMode) { _, newMode in
                if newMode == .standard {
                    selectedStandardFrameId = availableStandardFrames(for: selectedCropRatio).first?.id
                }
                // In frame-first mode the frame is fixed — never enlarge it to fit the print
                if newMode == .customFrame && builderMode != .frameFirst {
                    let printSize = selectedCropRatio.dimensions
                    customFrameWidth = max(customFrameWidth, printSize.width)
                    customFrameHeight = max(customFrameHeight, printSize.height)
                }
                // Reset pre-cut mat when leaving customFrame mode
                if newMode != .customFrame {
                    hasPreCutMat = false
                }
                updateMatFromStandardFrame()
            }
            .onChange(of: selectedCropRatio) { _, newRatio in
                if framingMode == .standard {
                    selectedStandardFrameId = availableStandardFrames(for: newRatio).first?.id
                }
                // In frame-first mode the frame is fixed — never enlarge it to fit the print
                if framingMode == .customFrame && builderMode != .frameFirst {
                    let printSize = newRatio.dimensions
                    customFrameWidth = max(customFrameWidth, printSize.width)
                    customFrameHeight = max(customFrameHeight, printSize.height)
                }
                updateMatFromStandardFrame()
            }
            .onChange(of: selectedStandardFrameId) { _, _ in
                updateMatFromStandardFrame()
            }
            .onChange(of: mattingStyle) { _, _ in
                updateMatFromStandardFrame()
            }
            .onChange(of: customFrameWidth) { _, _ in
                if hasPreCutMat {
                    matOpeningWidth = min(matOpeningWidth, customFrameWidth)
                }
                updateMatFromStandardFrame()
                ensureCropRatioCompatible()
            }
            .onChange(of: customFrameHeight) { _, _ in
                if hasPreCutMat {
                    matOpeningHeight = min(matOpeningHeight, customFrameHeight)
                }
                updateMatFromStandardFrame()
                ensureCropRatioCompatible()
            }
            .onChange(of: hasPreCutMat) { _, newValue in
                if newValue {
                    // Default mat opening to 2" smaller than frame inner on each side
                    matOpeningWidth = max(1, customFrameWidth - 4.0)
                    matOpeningHeight = max(1, customFrameHeight - 4.0)
                }
                updateMatFromStandardFrame()
            }
            .onChange(of: matOpeningWidth) { _, _ in
                matOpeningWidth = min(matOpeningWidth, customFrameWidth)
                updateMatFromStandardFrame()
            }
            .onChange(of: matOpeningHeight) { _, _ in
                matOpeningHeight = min(matOpeningHeight, customFrameHeight)
                updateMatFromStandardFrame()
            }
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            // Left: Large preview
            previewArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Right: Scrollable controls
            Form {
                photoPickerSection
                artworkNameSection
                if builderMode == .frameFirst {
                    frameAndMatSection
                    preCutMatSection
                    if !hasPreCutMat {
                        printSizeSection
                    }
                } else {
                    printSizeSection
                    frameAndMatSection
                }
                outputDimensionsSection
            }
            .frame(width: 380)
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        Form {
            Section {
                previewArea
                    .frame(height: 300)
            }
            .listRowInsets(EdgeInsets())

            photoPickerSection
            artworkNameSection
            if builderMode == .frameFirst {
                frameAndMatSection
                preCutMatSection
                if !hasPreCutMat {
                    printSizeSection
                }
            } else {
                printSizeSection
                frameAndMatSection
            }
            outputDimensionsSection
        }
    }

    // MARK: - Shared Sections

    @ViewBuilder
    private var previewArea: some View {
        ZStack {
            Color(uiColor: .systemGray5)

            if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                GeometryReader { geometry in
                    let artworkAspectRatio = totalHeight > 0 ? totalWidth / totalHeight : 1.0
                    let containerSize = geometry.size
                    let containerAspectRatio = containerSize.width / containerSize.height

                    let previewFrameSize = (containerAspectRatio > artworkAspectRatio) ?
                        CGSize(width: containerSize.height * artworkAspectRatio, height: containerSize.height) :
                        CGSize(width: containerSize.width, height: containerSize.width / artworkAspectRatio)

                    let pointsPerInch = totalWidth > 0 ? previewFrameSize.width / totalWidth : 0
                    let previewMatWidth = (effectivePrintWidth + matLeft + matRight) * pointsPerInch
                    let previewMatHeight = (effectivePrintHeight + matTop + matBottom) * pointsPerInch
                    let previewImageWidth = effectivePrintWidth * pointsPerInch
                    let previewImageHeight = effectivePrintHeight * pointsPerInch

                    let xOffset = (matLeft - matRight) / 2.0 * pointsPerInch
                    let yOffset = (matTop - matBottom) / 2.0 * pointsPerInch

                    ZStack {
                        frameColor
                        matColor.frame(width: previewMatWidth, height: previewMatHeight)
                        ZoomableImageView(
                            uiImage: uiImage,
                            initialScale: initialScale,
                            geometrySize: geometry.size,
                            currentScale: $currentScale,
                            finalScale: $finalScale,
                            currentOffset: $currentOffset,
                            finalOffset: $finalOffset
                        )
                        .frame(width: previewImageWidth, height: previewImageHeight)
                        .clipped()
                        .offset(x: xOffset, y: yOffset)
                    }
                    .frame(width: previewFrameSize.width, height: previewFrameSize.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .task(id: PreviewConfig(totalWidth: totalWidth, totalHeight: totalHeight, imageIdentifier: selectedPhoto?.itemIdentifier)) {
                        let imageCropBoxSize = CGSize(width: previewImageWidth, height: previewImageHeight)
                        updateInitialScale(imageSize: uiImage.size, imageGestureAreaSize: geometry.size, imageCropBoxSize: imageCropBoxSize)
                    }
                }
            } else {
                Text("Select an Image to Begin").foregroundColor(.gray)
            }
        }
    }

    private var photoPickerSection: some View {
        Section {
            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                Label(selectedImageData == nil ? "Select Image" : "Change Image", systemImage: "photo.on.rectangle.angled")
            }
            .onChange(of: selectedPhoto) { oldValue, newValue in
               Task {
                   if let data = try? await newValue?.loadTransferable(type: Data.self) {
                       selectedImageData = data
                   }
               }
           }
        }
    }

    private var artworkNameSection: some View {
        Section(header: Text("Artwork Name")) {
            TextField("e.g., \"My Masterpiece\"", text: $artworkName)
        }
    }

    private var printSizeSection: some View {
        Section(header: Text("Print Size")) {
            let sizes = compatiblePrintSizes
            if sizes.isEmpty {
                Text("No standard print sizes fit this frame. Adjust frame dimensions or use Custom Mat mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Select Ratio", selection: $selectedCropRatio) {
                    ForEach(sizes) { ratio in
                        Text(ratio.rawValue).tag(ratio)
                    }
                }
            }

            if builderMode == .frameFirst {
                Label {
                    Text("Print sizes refer to paper dimensions. The image area is typically \u{00BD}\" smaller per side to allow for mounting.")
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var preCutMatSection: some View {
        if builderMode == .frameFirst && framingMode == .customFrame {
            Section(header: Text("Pre-Cut Mat")) {
                Toggle("Frame has a pre-cut mat", isOn: $hasPreCutMat)

                if hasPreCutMat {
                    Text("Enter the mat opening dimensions — the visible area where your image shows through.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Stepper("Opening Width: \(matOpeningWidth, specifier: "%.1f") in",
                            value: $matOpeningWidth, in: 1...max(1, customFrameWidth), step: 0.5)
                    Stepper("Opening Height: \(matOpeningHeight, specifier: "%.1f") in",
                            value: $matOpeningHeight, in: 1...max(1, customFrameHeight), step: 0.5)

                    let hMat = (customFrameWidth - matOpeningWidth) / 2.0
                    let vMat = (customFrameHeight - matOpeningHeight) / 2.0
                    if hMat >= 0 && vMat >= 0 {
                        Text("Mat borders: \(String(format: "%.1f", hMat))\" sides, \(String(format: "%.1f", vMat))\" top/bottom")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var frameAndMatSection: some View {
        DisclosureGroup("Frame & Mat Settings", isExpanded: $frameSettingsExpanded) {
            Picker("Framing Style", selection: $framingMode) {
                ForEach(FramingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 5)

            Section(header: Text("Frame (Inches)")) {
                ColorPicker("Frame Color", selection: $frameColor)
                Stepper("Width: \(frameWidth, specifier: "%.2f") in", value: $frameWidth, in: 0.5...5, step: 0.25)
            }

            if framingMode == .custom {
                Section(header: Text("Mat Dimensions (Inches)")) {
                    ColorPicker("Mat Color", selection: $matColor)
                    Stepper("Top: \(matTop, specifier: "%.2f") in", value: $matTop, in: 0...20, step: 0.25)
                    Stepper("Bottom: \(matBottom, specifier: "%.2f") in", value: $matBottom, in: 0...20, step: 0.25)
                    Stepper("Left: \(matLeft, specifier: "%.2f") in", value: $matLeft, in: 0...20, step: 0.25)
                    Stepper("Right: \(matRight, specifier: "%.2f") in", value: $matRight, in: 0...20, step: 0.25)
                }
            } else if framingMode == .standard {
                Section(header: Text("Standard Frame")) {
                    ColorPicker("Mat Color", selection: $matColor)
                    Picker("Size", selection: $selectedStandardFrameId) {
                        ForEach(currentAvailableFrames) { frame in
                            Text(frame.description).tag(frame.id as UUID?)
                        }
                    }
                    if showMattingStylePicker {
                        Picker("Matting Style", selection: $mattingStyle) {
                            ForEach(MattingStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            } else if framingMode == .customFrame {
                Section(header: Text("Custom Frame Size")) {
                    ColorPicker("Mat Color", selection: $matColor)
                    Stepper("Inner Width: \(customFrameWidth, specifier: "%.1f") in", value: $customFrameWidth, in: 1...60, step: 0.5)
                    Stepper("Inner Height: \(customFrameHeight, specifier: "%.1f") in", value: $customFrameHeight, in: 1...60, step: 0.5)
                    if showMattingStylePicker {
                        Picker("Matting Style", selection: $mattingStyle) {
                            ForEach(MattingStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    private var outputDimensionsSection: some View {
        Section(header: Text("Output Dimensions (for AR)")) {
            Text("Total Width: \(totalWidth, specifier: "%.2f") in")
            Text("Total Height: \(totalHeight, specifier: "%.2f") in")
        }
    }

    // MARK: - Functions

    private func initializeView() {
        if let artwork = artworkToEdit {
            // Populate state from existing artwork
            artworkName = artwork.artworkName
            selectedImageData = artwork.imageData
            selectedCropRatio = artwork.cropRatio
            framingMode = artwork.framingMode
            selectedStandardFrameId = artwork.selectedStandardFrameId
            customFrameWidth = artwork.customFrameWidthInches ?? 16.0
            customFrameHeight = artwork.customFrameHeightInches ?? 20.0
            mattingStyle = artwork.mattingStyle
            frameWidth = artwork.frameWidthInches
            frameColor = artwork.frameColor
            matColor = artwork.matColor
            matTop = artwork.matTopInches
            matBottom = artwork.matBottomInches
            matLeft = artwork.matLeftInches
            matRight = artwork.matRightInches
            finalScale = artwork.imageScale
            finalOffset = artwork.imageOffset
            hasPreCutMat = artwork.hasPreCutMat
            if artwork.hasPreCutMat {
                matOpeningWidth = artwork.printWidthInches
                matOpeningHeight = artwork.printHeightInches
            }
        } else if builderMode == .frameFirst {
            // Frame-first mode: use the user's actual frame dimensions
            framingMode = .customFrame
            frameSettingsExpanded = true
            if let w = initialFrameWidth, let h = initialFrameHeight {
                customFrameWidth = w
                customFrameHeight = h
            } else if let rec = designRecommendation {
                let avgW = ((rec.sizeRange.minWidthInches + rec.sizeRange.maxWidthInches) / 2.0).rounded()
                let avgH = ((rec.sizeRange.minHeightInches + rec.sizeRange.maxHeightInches) / 2.0).rounded()
                customFrameWidth = avgW
                customFrameHeight = avgH
            }
            // Select best print and compute mat immediately
            selectBestPrintForFrame()
            // Also run deferred to catch cases where @State defaults matched entered values
            Task { @MainActor in
                selectBestPrintForFrame()
                updateMatFromStandardFrame()
            }
        } else if let rec = designRecommendation {
            // Photo-first with recommendation — apply size guidance
            framingMode = .customFrame
            let avgW = ((rec.sizeRange.minWidthInches + rec.sizeRange.maxWidthInches) / 2.0).rounded()
            let avgH = ((rec.sizeRange.minHeightInches + rec.sizeRange.maxHeightInches) / 2.0).rounded()
            customFrameWidth = avgW
            customFrameHeight = avgH
        }
        updateMatFromStandardFrame()
    }

    private func resetImageTransformations() {
        currentScale = 1.0
        finalScale = 1.0
        currentOffset = .zero
        finalOffset = .zero
    }

    private func updateInitialScale(imageSize: CGSize, imageGestureAreaSize: CGSize, imageCropBoxSize: CGSize) {
        guard imageSize.width > 0, imageSize.height > 0,
              imageGestureAreaSize.width > 0, imageGestureAreaSize.height > 0,
              imageCropBoxSize.width > 0, imageCropBoxSize.height > 0 else {
            initialScale = 1.0
            return
        }
        // Only reset transforms if it's a new image
        if artworkToEdit == nil {
            resetImageTransformations()
        }
        let fitScale = min(imageGestureAreaSize.width / imageSize.width, imageGestureAreaSize.height / imageSize.height)
        let fittedImageWidth = imageSize.width * fitScale
        let fittedImageHeight = imageSize.height * fitScale
        guard fittedImageWidth > 0, fittedImageHeight > 0 else {
            initialScale = 1.0
            return
        }
        let scaleToFillWidth = imageCropBoxSize.width / fittedImageWidth
        let scaleToFillHeight = imageCropBoxSize.height / fittedImageHeight
        initialScale = max(scaleToFillWidth, scaleToFillHeight)
    }

    private func availableStandardFrames(for ratio: CropRatio) -> [StandardFrame] {
        let printSize = ratio.dimensions
        let exactFrame = StandardFrame(name: "Print Size", width: printSize.width, height: printSize.height)

        let largerFrames = StandardFrame.allFrames.filter {
            $0.width >= printSize.width && $0.height >= printSize.height
        }

        return ([exactFrame] + largerFrames).sorted { ($0.width * $0.height) < ($1.width * $1.height) }
    }

    private func updateMatFromStandardFrame() {
        guard framingMode == .standard || framingMode == .customFrame else { return }

        let printSize = (width: effectivePrintWidth, height: effectivePrintHeight)
        var frameInnerWidth: Double
        var frameInnerHeight: Double

        if framingMode == .standard {
            guard let frameId = selectedStandardFrameId,
                  let standardFrame = currentAvailableFrames.first(where: { $0.id == frameId })
            else {
                matTop = 0; matBottom = 0; matLeft = 0; matRight = 0
                return
            }
            frameInnerWidth = standardFrame.width
            frameInnerHeight = standardFrame.height
        } else {
            frameInnerWidth = customFrameWidth
            frameInnerHeight = customFrameHeight
        }

        let totalHorizontalMat = frameInnerWidth - printSize.width
        let totalVerticalMat = frameInnerHeight - printSize.height

        if mattingStyle == .bottomWeighted && showMattingStylePicker {
            // Bottom-weighted: top, left, and right mats are equal
            let sideMat = totalHorizontalMat / 2.0
            matLeft = max(0, sideMat)
            matRight = max(0, sideMat)
            matTop = max(0, sideMat)
            matBottom = max(0, frameInnerHeight - printSize.height - matTop)
        } else {
            // Centered: the default behavior
            matLeft = max(0, totalHorizontalMat / 2.0)
            matRight = max(0, totalHorizontalMat / 2.0)
            matTop = max(0, totalVerticalMat / 2.0)
            matBottom = max(0, totalVerticalMat / 2.0)
        }
    }

    /// In frame-first mode, ensure the selected crop ratio still fits when frame size changes
    private func ensureCropRatioCompatible() {
        guard builderMode == .frameFirst else { return }
        let sizes = compatiblePrintSizes
        if !sizes.contains(selectedCropRatio), let first = sizes.first {
            selectedCropRatio = first
        }
    }

    /// Select the largest print size that fits inside the current custom frame
    private func selectBestPrintForFrame() {
        let best = CropRatio.allCases.filter { ratio in
            let d = ratio.dimensions
            return d.width <= customFrameWidth && d.height <= customFrameHeight
        }.max { a, b in
            a.dimensions.width * a.dimensions.height < b.dimensions.width * b.dimensions.height
        }
        if let best {
            selectedCropRatio = best
        }
    }
}

// A private helper view to contain the image and its gestures
fileprivate struct ZoomableImageView: View {
    let uiImage: UIImage
    let initialScale: CGFloat
    let geometrySize: CGSize
    @Binding var currentScale: CGFloat
    @Binding var finalScale: CGFloat
    @Binding var currentOffset: CGSize
    @Binding var finalOffset: CGSize

    var body: some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
            .scaleEffect(initialScale * currentScale * finalScale)
            .offset(x: currentOffset.width + finalOffset.width, y: currentOffset.height + finalOffset.height)
            .frame(width: geometrySize.width, height: geometrySize.height)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in currentScale = value }
                    .onEnded { value in finalScale *= value; currentScale = 1.0 }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in currentOffset = value.translation }
                    .onEnded { value in finalOffset.width += value.translation.width; finalOffset.height += value.translation.height; currentOffset = .zero }
            )
    }
}


#Preview {
    BuildArtPieceView(artworkToEdit: nil) { artworkConfig in
        print("Artwork configuration created: \(artworkConfig)")
    }
}
