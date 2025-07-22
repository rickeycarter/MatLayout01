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

        var id: String {
            switch self {
            case .newArtwork:
                return "new"
            case .editArtwork(let artwork):
                return artwork.id.uuidString
            }
        }
    }

    // Use AppStorage to show the overlay only on the first launch.
    @AppStorage("hasSeenInstructions") private var hasSeenInstructions: Bool = false

    // Use the new ViewModel to manage data and iCloud sync.
    @StateObject private var viewModel = GalleryViewModel()
    // Add properties for StoreManager
    @StateObject private var storeManager = StoreManager()
    
    @State private var activeSheet: ActiveSheet?
    @State private var showARViewForArtwork: ArtworkConfiguration?
    // State to manually re-show the instructions screen.
    @State private var showInstructionsSheet = false
    // State for the upgrade sheet
    @State private var showUpgradeSheet = false

    var body: some View {
        ZStack {
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
                                        
                                        // Conditionally show AR button or Upgrade button
                                        if artwork.isAREnabledForFree || storeManager.isProUnlocked {
                                            Button(action: { showARViewForArtwork = artwork }) {
                                                Label("AR View", systemImage: "arkit")
                                            }
                                        } else {
                                            Button(action: { showUpgradeSheet = true }) {
                                                Label("Upgrade for AR", systemImage: "sparkles")
                                            }
                                        }
                          
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
                    }
                }
                .sheet(isPresented: $showInstructionsSheet) {
                    InstructionsOverlayView(isPresented: $showInstructionsSheet)
                }
                .sheet(isPresented: $showUpgradeSheet) {
                    UpgradeView(isPresented: $showUpgradeSheet)
                }
                .fullScreenCover(item: $showARViewForArtwork) { artwork in
                    ARArtView(artwork: artwork)
                }
            }
            
            if !hasSeenInstructions {
                InstructionsOverlayView(isPresented: $hasSeenInstructions.inverted)
            }
        }
        .environmentObject(storeManager)
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
}
