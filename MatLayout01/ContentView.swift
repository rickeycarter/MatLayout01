//
//  ContentView.swift
//  MatLayout01
//
//  Created by Rickey Carter on 5/13/25.
//

import SwiftUI
import PhotosUI // Import PhotosUI for PhotosPicker

// Define an enum for crop ratios
enum CropRatio: String, CaseIterable, Identifiable {
    case r2x3 = "2x3"
    case r3x2 = "3x2"
    case r4x5 = "4x5"
    case r5x4 = "5x4"
    case r4x6 = "4x6"
    case r6x4 = "6x4"
    case r5x7 = "5x7"
    case r7x5 = "7x5"
    case r11x14 = "11x14"
    case r14x11 = "14x11"
    case r16x20 = "16x20"
    case r20x16 = "20x16"

    var id: String { self.rawValue }

    var ratio: CGFloat {
        switch self {
        case .r2x3: return 2.0 / 3.0
        case .r3x2: return 3.0 / 2.0
        case .r4x5: return 4.0 / 5.0
        case .r5x4: return 5.0 / 4.0
        case .r4x6: return 4.0 / 6.0
        case .r6x4: return 6.0 / 4.0
        case .r5x7: return 5.0 / 7.0
        case .r7x5: return 7.0 / 5.0
        case .r11x14: return 11.0 / 14.0
        case .r14x11: return 14.0 / 11.0
        case .r16x20: return 16.0 / 20.0
        case .r20x16: return 20.0 / 16.0
        }
    }
}

struct ContentView: View {
    // State for the selected image item and image data
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?

    // State for the selected crop ratio
    @State private var selectedCropRatio: CropRatio = .r4x5

    // State for image dimensions
    @State private var imageWidth: Double = 300.0 // Default width
    @State private var imageHeight: Double = 200.0 // Default height

    // State for zoom and pan
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var finalOffset: CGSize = .zero

    // State for mat dimensions
    @State private var matTop: Double = 20.0 // Default mat top
    @State private var matBottom: Double = 20.0 // Default mat bottom
    @State private var matLeft: Double = 20.0 // Default mat left
    @State private var matRight: Double = 20.0 // Default mat right

    var body: some View {
        NavigationView {
            VStack {
                // Image display area
                if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                    GeometryReader { geometry in
                        let cropRectWidth = min(geometry.size.width, geometry.size.height * selectedCropRatio.ratio)
                        let cropRectHeight = min(geometry.size.height, geometry.size.width / selectedCropRatio.ratio)
                        
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(currentScale * finalScale)
                            .offset(x: currentOffset.width + finalOffset.width, y: currentOffset.height + finalOffset.height)
                            .frame(width: geometry.size.width, height: geometry.size.height) // Ensure image takes up GeometryReader space for gesture hit testing
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        currentScale = value
                                    }
                                    .onEnded { value in
                                        finalScale *= value
                                        currentScale = 1.0
                                    }
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        currentOffset = value.translation
                                    }
                                    .onEnded { value in
                                        finalOffset.width += value.translation.width
                                        finalOffset.height += value.translation.height
                                        currentOffset = .zero
                                    }
                            )
                            .overlay(
                                Rectangle()
                                    .stroke(Color.yellow, lineWidth: 2)
                                    .frame(width: cropRectWidth, height: cropRectHeight)
                                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            )
                            .clipped() // Clip the image to the bounds of the GeometryReader
                            .contentShape(Rectangle()) // Ensures gestures are recognized within the entire frame
                    }
                    .frame(maxHeight: 300)
                    .border(Color.gray)

                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(maxHeight: 300)
                        .overlay(Text("Select an Image").foregroundColor(.gray))
                }

                // PhotosPicker for selecting an image
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images, // We are only interested in images
                    photoLibrary: .shared() // Use the shared photo library
                ) {
                    Label("Select Image", systemImage: "photo.on.rectangle.angled")
                }
                .padding()
                .onChange(of: selectedPhoto) { _, newValue in
                                   Task {
                                       // Retrieve the data from the selected photo item
                                       if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                           selectedImageData = data
                                           // Reset zoom/pan when a new image is selected
                                           resetImageTransformations()
                                       }
                                   }
                               }

                Form {
                    // Picker for crop ratio
                    Section(header: Text("Print Size")) {
                        Picker("Select Ratio", selection: $selectedCropRatio) {
                            ForEach(CropRatio.allCases) { ratio in
                                Text(ratio.rawValue).tag(ratio)
                            }
                        }
                      //  .pickerStyle(SegmentedPickerStyle())
                    }

                    // Dials for image dimensions
                    Section(header: Text("Output Dimensions (for AR)")) {
                        Stepper("Width: \(imageWidth, specifier: "%.0f") px", value: $imageWidth, in: 50...1000, step: 10)
                        Stepper("Height: \(imageHeight, specifier: "%.0f") px", value: $imageHeight, in: 50...1000, step: 10)
                    }
                    
                    // Steppers for mat dimensions
                    Section(header: Text("Mat Dimensions (Points)")) {
                        Stepper("Top: \(matTop, specifier: "%.0f") pt", value: $matTop, in: 0...200, step: 5)
                        Stepper("Bottom: \(matBottom, specifier: "%.0f") pt", value: $matBottom, in: 0...200, step: 5)
                        Stepper("Left: \(matLeft, specifier: "%.0f") pt", value: $matLeft, in: 0...200, step: 5)
                        Stepper("Right: \(matRight, specifier: "%.0f") pt", value: $matRight, in: 0...200, step: 5)
                    }
                }

                Spacer()
            }
            .navigationTitle("Image Processor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset View") {
                        resetImageTransformations()
                    }
                }
            }
        }
    }

    private func resetImageTransformations() {
        currentScale = 1.0
        finalScale = 1.0
        currentOffset = .zero
        finalOffset = .zero
        // Optionally reset mat dimensions as well, or keep them
        // matTop = 20.0
        // matBottom = 20.0
        // matLeft = 20.0
        // matRight = 20.0
    }
}

#Preview {
    ContentView()
}
