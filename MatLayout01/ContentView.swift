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

    // Use @State to manage artworks locally since GalleryViewModel was removed.
    @State private var artworks: [ArtworkConfiguration] = []
    @State private var activeSheet: ActiveSheet?
    @State private var showARViewForArtwork: ArtworkConfiguration?

    var body: some View {
        NavigationStack {
            Group {
                if artworks.isEmpty {
                    Text("Your gallery is empty.")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(artworks) { artwork in
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
                                    
                                    // This may need to be adjusted if ProductionInstructionsView
                                    // also had dependencies on the old view model.
                                    NavigationLink {
                                        ProductionInstructionsView(artwork: artwork)
                                    } label: {
                                        Label("Instructions", systemImage: "list.bullet.rectangle")
                                    }
                                    
                                    Button(action: { showARViewForArtwork = artwork }) {
                                        Label("AR View", systemImage: "arkit")
                                    }
                                    Spacer()
                                }
                                .buttonStyle(.bordered)
                                .labelStyle(.iconOnly)
                                .padding(.bottom, 8)
                            }
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteArtwork)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My Gallery")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        activeSheet = .newArtwork
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .newArtwork:
                    BuildArtPieceView(artworkToEdit: nil) { newArtwork in
                        // Add the new artwork to the local state array.
                        artworks.append(newArtwork)
                    }
                case .editArtwork(let artwork):
                    BuildArtPieceView(artworkToEdit: artwork) { updatedArtwork in
                        // Find and update the artwork in the local state array.
                        if let index = artworks.firstIndex(where: { $0.id == updatedArtwork.id }) {
                            artworks[index] = updatedArtwork
                        }
                    }
                }
            }
            .fullScreenCover(item: $showARViewForArtwork) { artwork in
                ARArtView(artwork: artwork)
            }
        }
    }
    
    // Function to handle deleting artworks from the local state.
    private func deleteArtwork(at offsets: IndexSet) {
        artworks.remove(atOffsets: offsets)
    }
}

#Preview {
    ContentView()
}
