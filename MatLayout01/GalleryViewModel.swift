//
//  GalleryViewModel.swift
//  MatLayout01
//
//  Created by Rickey Carter on 7/4/25.
//

// Create a new file: GalleryViewModel.swift
import SwiftUI

@MainActor
class GalleryViewModel: ObservableObject {
    @Published var artworks: [ArtworkConfiguration] = []
    private let filename = "artworks.json"

    private var iCloudDocumentsURL: URL? {
        guard let url = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
            return nil
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }

    private var fileURL: URL? {
        iCloudDocumentsURL?.appendingPathComponent(filename)
    }

    init() {
        loadArtworks()
        
        // If the gallery is empty after loading, add the default artwork.
        // This ensures it only gets added on the very first launch.
        if artworks.isEmpty {
            if let defaultArtwork = ArtworkConfiguration.defaultArtwork {
                artworks.append(defaultArtwork)
            }
        }
    }

    func addArtwork(_ artwork: ArtworkConfiguration) {
        artworks.append(artwork)
        // Re-sort after adding a new item
        artworks.sort(by: { $0.creationDate > $1.creationDate })
        saveArtworks()
    }

    func updateArtwork(_ artwork: ArtworkConfiguration) {
        if let index = artworks.firstIndex(where: { $0.id == artwork.id }) {
            artworks[index] = artwork
            // Re-sort after updating an item in case the date was changed
            artworks.sort(by: { $0.creationDate > $1.creationDate })
            saveArtworks()
        }
    }

    func deleteArtwork(at offsets: IndexSet) {
        artworks.remove(atOffsets: offsets)
        saveArtworks()
    }

    func saveArtworks() {
        guard let url = fileURL else { return }
        do {
            let data = try JSONEncoder().encode(artworks)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Error saving artworks: \(error.localizedDescription)")
        }
    }

    func loadArtworks() {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decodedArtworks = try JSONDecoder().decode([ArtworkConfiguration].self, from: data)
            // Sort the artworks by creationDate in descending order (newest first)
            self.artworks = decodedArtworks.sorted(by: { $0.creationDate > $1.creationDate })
        } catch {
            print("Error loading artworks: \(error.localizedDescription)")
        }
    }
}
