//
//  ContentView.swift
//  MatLayout01
//
//  Created by Rickey Carter on 5/13/25.
//

import SwiftUI

struct ContentView: View {
    // Enum to manage which sheet is active
    enum ActiveSheet: Identifiable {
        case newArtwork
        case editArtwork(ArtworkConfiguration)
        case designWorkflow

        var id: String {
            switch self {
            case .newArtwork:
                return "new"
            case .editArtwork(let artwork):
                return artwork.id.uuidString
            case .designWorkflow:
                return "designWorkflow"
            }
        }
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Use AppStorage to show the overlay only on the first launch.
    @AppStorage("hasSeenInstructions") private var hasSeenInstructions: Bool = false

    // Use the new ViewModel to manage data and iCloud sync.
    @EnvironmentObject var viewModel: GalleryViewModel
    // Add properties for StoreManager
    @StateObject private var storeManager = StoreManager()
    
    @State private var activeSheet: ActiveSheet?
    #if os(iOS)
    @State private var showARViewForArtwork: ArtworkConfiguration?
    #endif
    #if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.dismissWindow) var dismissWindow
    #endif
    // State to manually re-show the instructions screen.
    @State private var showInstructionsSheet = false

    // iPad selection
    @State private var selectedArtworkId: UUID?

    private var selectedArtwork: ArtworkConfiguration? {
        guard let id = selectedArtworkId else { return nil }
        return viewModel.artworks.first(where: { $0.id == id })
    }

    var body: some View {
        ZStack {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }

            if !hasSeenInstructions {
                InstructionsOverlayView(isPresented: $hasSeenInstructions.inverted)
            }
        }
        .environmentObject(storeManager)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .newArtwork:
                BuildArtPieceView(artworkToEdit: nil) { newArtwork in
                    viewModel.addArtwork(newArtwork)
                }
            case .editArtwork(let artwork):
                BuildArtPieceView(artworkToEdit: artwork) { updatedArtwork in
                    viewModel.updateArtwork(updatedArtwork)
                }
            case .designWorkflow:
                DesignWorkflowView { newArtwork in
                    viewModel.addArtwork(newArtwork)
                }
            }
        }
        .sheet(isPresented: $showInstructionsSheet) {
            InstructionsOverlayView(isPresented: $showInstructionsSheet)
        }

        #if os(iOS)
        .fullScreenCover(item: $showARViewForArtwork) { artwork in
            ARArtView(artwork: artwork)
        }
        #endif
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        NavigationSplitView {
            List(selection: $selectedArtworkId) {
                ForEach(viewModel.artworks) { artwork in
                    HStack(spacing: 12) {
                        artwork.preview
                            .frame(width: 60, height: 60)
                            .cornerRadius(6)

                        VStack(alignment: .leading) {
                            Text(artwork.artworkName)
                                .font(.headline)
                            Text(String(format: "%.1f\" x %.1f\"", artwork.totalWidthInches, artwork.totalHeightInches))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(artwork.id)
                }
                .onDelete(perform: viewModel.deleteArtwork)
            }
            .listStyle(.sidebar)
            .navigationTitle("My Gallery")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    EditButton()
                    Button(action: { showInstructionsSheet = true }) {
                        Image(systemName: "questionmark.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { activeSheet = .designWorkflow }) {
                        Image(systemName: "plus")
                    }
                }
            }
        } detail: {
            NavigationStack {
                if let artwork = selectedArtwork {
                    ScrollView {
                        VStack(spacing: 20) {
                            artwork.preview
                                .frame(maxHeight: 500)
                                .cornerRadius(12)
                                .padding(.horizontal)

                            Text(artwork.description)
                                .font(.title2)
                                .fontWeight(.semibold)

                            HStack(spacing: 16) {
                                Button(action: { activeSheet = .editArtwork(artwork) }) {
                                    Label("Edit", systemImage: "pencil")
                                }

                                NavigationLink {
                                    ProductionInstructionsView(artwork: artwork)
                                } label: {
                                    Label("Instructions", systemImage: "list.bullet.rectangle")
                                }

                                #if os(iOS)
                                Button(action: { showARViewForArtwork = artwork }) {
                                    Label("AR View", systemImage: "arkit")
                                }
                                #elseif os(visionOS)
                                Button {
                                    viewModel.initialArtworkForGallery = artwork
                                    Task {
                                        await openImmersiveSpace(id: "artGallery")
                                        dismissWindow()
                                    }
                                } label: {
                                    Label("Gallery View", systemImage: "visionpro")
                                }
                                #endif
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical)
                    }
                    .navigationTitle(artwork.artworkName)
                } else {
                    ContentUnavailableView("Select an Artwork", systemImage: "photo.artframe", description: Text("Choose a piece from the sidebar to view details."))
                }
            }
        }
    }

    // MARK: - iPhone Layout (unchanged)

    private var iPhoneLayout: some View {
        NavigationStack {
            Group {
                if viewModel.artworks.isEmpty {
                    Text("Your gallery is empty.")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(viewModel.artworks) { artwork in
                            VStack(alignment: .leading, spacing: 0) {
                                artwork.preview
                                    .frame(height: 250)
                                    .cornerRadius(8)
                                    .padding(.bottom, 8)
                                
                                Text(artwork.description)
                                    .font(.headline)
                                    .padding(.bottom, 8)
                                
                                HStack {
                                    Spacer()
                                    Button(action: { activeSheet = .editArtwork(artwork) }) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    
                                    NavigationLink {
                                        ProductionInstructionsView(artwork: artwork)
                                    } label: {
                                        Label("Instructions", systemImage: "list.bullet.rectangle")
                                    }
                                    
                                    #if os(iOS)
                                    Button(action: { showARViewForArtwork = artwork }) {
                                        Label("AR View", systemImage: "arkit")
                                    }
                                    #elseif os(visionOS)
                                    Button {
                                        viewModel.initialArtworkForGallery = artwork
                                        Task {
                                            await openImmersiveSpace(id: "artGallery")
                                            dismissWindow()
                                        }
                                    } label: {
                                        Label("Gallery View", systemImage: "visionpro")
                                    }
                                    #endif
                          
                                    Spacer()
                                }
                                .buttonStyle(.bordered)
                                .labelStyle(.iconOnly)
                                .padding(.bottom, 8)
                            }
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: viewModel.deleteArtwork)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My Gallery")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    EditButton()
                    Button(action: { showInstructionsSheet = true }) {
                        Image(systemName: "questionmark.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { activeSheet = .newArtwork }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

// Helper to create a binding from a boolean.
extension Binding where Value == Bool {
    var inverted: Binding<Bool> {
        Binding<Bool>(
            get: { !self.wrappedValue },
            set: { self.wrappedValue = !$0 }
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(GalleryViewModel())
}
