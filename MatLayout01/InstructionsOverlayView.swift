//
//  InstructionsOverlayView.swift
//  MatLayout01
//
//  Created by Rickey Carter on 7/18/25.
//
import SwiftUI

struct InstructionsOverlayView: View {
    // This binding allows the view to dismiss itself.
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // A semi-transparent background that covers the whole screen.
            Color.black.opacity(0.75)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 40) {
                Text("Welcome to Your Gallery")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Instructions with icons.
                // For a "handwriting" style, you could use .font(.custom("YourFontName", size: 22))
                // after adding a custom font to your project.
                VStack(alignment: .leading, spacing: 25) {
                    InstructionRow(
                        icon: "plus.circle.fill",
                        text: "Tap the '+' button to create a new artwork. You can resize, crop and build a custom mat and frame for your art."
                    )
                    InstructionRow(
                        icon: "pencil.circle.fill",
                        text: "Tap 'Edit' on an item to modify its design."
                    )
                    InstructionRow(
                        icon: "arkit",
                        text: "Use 'AR View' to see your framed art on your wall. Simply tap on the wall where you would like the art hung. "
                    )
                }
                .padding(.horizontal, 30)

                // Button to dismiss the overlay.
                Button(action: {
                    withAnimation {
                        isPresented = false
                    }
                }) {
                    Text("Get Started")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 50)
                        .padding(.vertical, 15)
                        .background(Color.white)
                        .cornerRadius(25)
                }
                .padding(.top, 20)
            }
        }
        .transition(.opacity) // Animate the appearance and disappearance.
    }
}

// A helper view to keep the main body clean.
struct InstructionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.white)
                .frame(width: 45)
            Text(text)
                .font(.title3)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true) // Allow text to wrap.
            Spacer()
        }
    }
}
