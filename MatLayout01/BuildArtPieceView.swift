//
//  BuildArtPieceView.swift
//  MatLayout01
//
//  Created by Rickey Carter on 6/21/25.
//


import SwiftUI
import PhotosUI

struct BuildArtPieceView: View {
    // The MattingStyle enum has been moved to its own file.

    // Environment property to dismiss the view
    @Environment(\.dismiss) private var dismiss

    // Artwork to edit (optional)
    var artworkToEdit: ArtworkConfiguration?
    // Completion handler to be called when "Done" is tapped
    var onComplete: (ArtworkConfiguration) -> Void

    // State for the selected image item and image data
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?

    // State for artwork name
    @State private var artworkName: String = ""

    // State for the selected crop ratio
    @State private var selectedCropRatio: CropRatio = .r4x5

    // State for zoom and pan
    @State private var initialScale: CGFloat = 1.0
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var finalOffset: CGSize = .zero

    // State for frame
    @State private var frameWidth: Double = 1.0
    @State private var frameColor: Color = .black

    // State for mat color
    @State private var matColor: Color = Color(red: 250/255, green: 249/255, blue: 246/255) // #FAF9F6

    // State for mat dimensions in inches
    @State private var matTop: Double = 2.0
    @State private var matBottom: Double = 2.0
    @State private var matLeft: Double = 2.0
    @State private var matRight: Double = 2.0

    // State for framing mode and standard frame selection
    @State private var framingMode: FramingMode = .custom
    @State private var selectedStandardFrameId: UUID?
    @State private var mattingStyle: MattingStyle = .centered

    // Computed properties for total dimensions
    var totalWidth: Double {
        if framingMode == .standard,
           let frameId = selectedStandardFrameId,
           let frame = currentAvailableFrames.first(where: { $0.id == frameId }) {
            return frame.width + (frameWidth * 2)
        }
        return selectedCropRatio.dimensions.width + matLeft + matRight + (frameWidth * 2)
    }
    var totalHeight: Double {
        if framingMode == .standard,
           let frameId = selectedStandardFrameId,
           let frame = currentAvailableFrames.first(where: { $0.id == frameId }) {
            return frame.height + (frameWidth * 2)
        }
        return selectedCropRatio.dimensions.height + matTop + matBottom + (frameWidth * 2)
    }

    // Computed property for the final combined image transform
    var finalImageTransform: (scale: CGFloat, offset: CGSize) {
        (scale: initialScale * finalScale, offset: finalOffset)
    }

    // A struct to use as an ID for the .task modifier
    struct PreviewConfig: Equatable {
        let totalWidth: Double
        let totalHeight: Double
        let imageIdentifier: String?
    }

    // Computed property for the list of currently available standard frames
    private var currentAvailableFrames: [StandardFrame] {
        availableStandardFrames(for: selectedCropRatio)
    }

    // Computed property to determine if the matting style picker should be shown
    private var showMattingStylePicker: Bool {
        guard framingMode == .standard,
              let frameId = selectedStandardFrameId,
              let standardFrame = currentAvailableFrames.first(where: { $0.id == frameId })
        else { return false }

        let printSize = selectedCropRatio.dimensions
        guard standardFrame.width >= printSize.width, standardFrame.height >= printSize.height else { return false }

        let horizontalMat = (standardFrame.width - printSize.width) / 2.0
        let verticalMat = (standardFrame.height - printSize.height) / 2.0

        return verticalMat > horizontalMat
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack {
                        Color(uiColor: .systemGray5) // The "wall" color

                        if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                            GeometryReader { geometry in
                                let artworkAspectRatio = totalHeight > 0 ? totalWidth / totalHeight : 1.0
                                let containerSize = geometry.size
                                let containerAspectRatio = containerSize.width / containerSize.height

                                let previewFrameSize = (containerAspectRatio > artworkAspectRatio) ?
                                    CGSize(width: containerSize.height * artworkAspectRatio, height: containerSize.height) :
                                    CGSize(width: containerSize.width, height: containerSize.width / artworkAspectRatio)

                                let pointsPerInch = totalWidth > 0 ? previewFrameSize.width / totalWidth : 0
                                let previewMatWidth = (selectedCropRatio.dimensions.width + matLeft + matRight) * pointsPerInch
                                let previewMatHeight = (selectedCropRatio.dimensions.height + matTop + matBottom) * pointsPerInch
                                let previewImageWidth = selectedCropRatio.dimensions.width * pointsPerInch
                                let previewImageHeight = selectedCropRatio.dimensions.height * pointsPerInch

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
                    .frame(height: 300)
                }
                .listRowInsets(EdgeInsets())

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

                Section(header: Text("Artwork Name")) {
                    TextField("e.g., \"My Masterpiece\"", text: $artworkName)
                }

                Section(header: Text("Print Size")) {
                    Picker("Select Ratio", selection: $selectedCropRatio) {
                        ForEach(CropRatio.allCases) { ratio in
                            Text(ratio.rawValue).tag(ratio)
                        }
                    }
                }

                DisclosureGroup("Frame & Mat Settings") {
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
                    } else {
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
                    }
                }

                Section(header: Text("Output Dimensions (for AR)")) {
                    Text("Total Width: \(totalWidth, specifier: "%.2f") in")
                    Text("Total Height: \(totalHeight, specifier: "%.2f") in")
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
                            printWidthInches: selectedCropRatio.dimensions.width,
                            printHeightInches: selectedCropRatio.dimensions.height,
                            matTopInches: matTop,
                            matBottomInches: matBottom,
                            matLeftInches: matLeft,
                            matRightInches: matRight,
                            cropRatio: selectedCropRatio,
                            framingMode: framingMode,
                            mattingStyle: mattingStyle,
                            selectedStandardFrameId: selectedStandardFrameId
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
                updateMatFromStandardFrame()
            }
            .onChange(of: selectedCropRatio) { _, newRatio in
                if framingMode == .standard {
                    selectedStandardFrameId = availableStandardFrames(for: newRatio).first?.id
                }
                updateMatFromStandardFrame()
            }
            .onChange(of: selectedStandardFrameId) { _, _ in
                updateMatFromStandardFrame()
            }
            .onChange(of: mattingStyle) { _, _ in
                updateMatFromStandardFrame()
            }
        }
    }

    private func initializeView() {
        if let artwork = artworkToEdit {
            // Populate state from existing artwork
            artworkName = artwork.artworkName
            selectedImageData = artwork.imageData
            selectedCropRatio = artwork.cropRatio
            framingMode = artwork.framingMode
            selectedStandardFrameId = artwork.selectedStandardFrameId
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
        guard framingMode == .standard else { return }

        let printSize = selectedCropRatio.dimensions

        guard let frameId = selectedStandardFrameId,
              let standardFrame = currentAvailableFrames.first(where: { $0.id == frameId })
        else {
            matTop = 0; matBottom = 0; matLeft = 0; matRight = 0
            return
        }

        let totalHorizontalMat = standardFrame.width - printSize.width
        let totalVerticalMat = standardFrame.height - printSize.height

        if mattingStyle == .bottomWeighted && showMattingStylePicker {
            // Bottom-weighted: top, left, and right mats are equal
            let sideMat = totalHorizontalMat / 2.0
            matLeft = max(0, sideMat)
            matRight = max(0, sideMat)
            matTop = max(0, sideMat)
            matBottom = max(0, standardFrame.height - printSize.height - matTop)
        } else {
            // Centered: the default behavior
            matLeft = max(0, totalHorizontalMat / 2.0)
            matRight = max(0, totalHorizontalMat / 2.0)
            matTop = max(0, totalVerticalMat / 2.0)
            matBottom = max(0, totalVerticalMat / 2.0)
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
