//
//  StoreManager.swift
//  MatLayout01
//
//  Created by Rickey Carter on 7/21/25.
//


// StoreManager.swift

import Foundation
import StoreKit

// Use a specific product identifier for your IAP.
// You must create this in App Store Connect.
fileprivate let proUnlockProductId = "com.rickeyecarter.MatLayout01.prounlock"

@MainActor
class StoreManager: ObservableObject {
    @Published private(set) var isProUnlocked: Bool = false
    
    private var transactionListener: Task<Void, Error>? = nil

    init() {
        // Start a task to listen for transaction updates.
        transactionListener = Task.detached {
            for await result in Transaction.updates {
                await self.handle(transactionVerification: result)
            }
        }
        
        // Also check current entitlements on launch.
        Task {
            await checkInitialPurchaseStatus()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }

    func purchasePro() async {
        do {
            let products = try await Product.products(for: [proUnlockProductId])
            guard let proProduct = products.first else {
                print("Error: Pro product not found.")
                return
            }
            
            let result = try await proProduct.purchase()
            
            // Handle the different purchase outcomes
            switch result {
            case .success(let verificationResult):
                // The purchase was successful, now handle the transaction
                await self.handle(transactionVerification: verificationResult)
            case .userCancelled:
                // The user cancelled the purchase.
                print("User cancelled purchase.")
            case .pending:
                // The purchase is pending and requires further action.
                print("Purchase is pending.")
            @unknown default:
                break
            }
            
        } catch {
            print("Purchase failed: \(error)")
        }
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkInitialPurchaseStatus()
        } catch {
            print("Could not sync purchases: \(error)")
        }
    }
    
    private func checkInitialPurchaseStatus() async {
        // Check all transactions to see if the user has ever purchased the pro unlock.
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == proUnlockProductId {
                self.isProUnlocked = true
                await transaction.finish() // Finish transaction after granting entitlement
                return // Found a valid purchase
            }
        }
        self.isProUnlocked = false
    }

    private func handle(transactionVerification result: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = result, transaction.productID == proUnlockProductId {
            // The transaction is valid and for our pro product.
            self.isProUnlocked = true
            // Always finish a transaction.
            await transaction.finish()
        }
    }
}
