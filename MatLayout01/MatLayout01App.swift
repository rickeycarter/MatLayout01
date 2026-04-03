//
//  MatLayout01App.swift
//  MatLayout01
//
//  Created by Rickey Carter on 5/13/25.
//

import SwiftUI
import SwiftData

@main
struct MatLayout01App: App {
    @StateObject private var galleryViewModel = GalleryViewModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(galleryViewModel)
        }

        #if os(visionOS)
        ImmersiveSpace(id: "artGallery") {
            VisionGalleryView()
                .environmentObject(galleryViewModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        #endif
    }
}
