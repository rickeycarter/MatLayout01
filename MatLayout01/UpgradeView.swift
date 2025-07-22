//
//  UpgradeView.swift
//  MatLayout01
//
//  Created by Rickey Carter on 7/21/25.
//


// UpgradeView.swift

import SwiftUI

struct UpgradeView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Unlock Pro Features")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("The free version allows you to use AR for the sample artwork.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Text("Purchase the Pro version to unlock AR for all your creations.")
                .multilineTextAlignment(.center)

            Button(action: {
                Task {
                    await storeManager.purchasePro()
                }
            }) {
                Text("Upgrade to Pro")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            Button("Restore Purchases") {
                Task {
                    await storeManager.restorePurchases()
                }
            }
            
            Button("Not Now") {
                isPresented = false
            }
            .padding(.top)

        }
        .padding()
        .onChange(of: storeManager.isProUnlocked) { _, isPro in
            if isPro {
                isPresented = false
            }
        }
    }
}
