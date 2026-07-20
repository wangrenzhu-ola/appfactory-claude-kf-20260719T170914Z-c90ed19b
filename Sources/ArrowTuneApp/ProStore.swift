import Foundation
import StoreKit

/// StoreKit 2 manager for the one-time Pro unlock. Non-consumable only: no
/// subscription, no trial countdown, no renewal. Purchase restores through
/// Transaction.currentEntitlements and AppStore.sync().
@MainActor
final class ProStore: ObservableObject {
    static let productID = "com.arrowtune.pro.lifetime"

    @Published private(set) var isPro = false
    @Published private(set) var product: Product?
    @Published var purchaseError: String?
    @Published var purchaseInFlight = false
    @Published var storeUnavailable = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if let transaction = try? update.payloadValue {
                    await self.apply(transaction: transaction)
                }
            }
        }
        Task { await reload() }
    }

    deinit { updatesTask?.cancel() }

    func reload() async {
        await refreshEntitlement()
        do {
            let products = try await Product.products(for: [ProStore.productID])
            product = products.first
            storeUnavailable = products.isEmpty
        } catch {
            product = nil
            storeUnavailable = true
        }
    }

    var displayPrice: String? { product?.displayPrice }

    func purchase() async {
        purchaseError = nil
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        guard let product else {
            purchaseError = "Pro unlock is unavailable right now. Check your connection and try again."
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verification.payloadValue
                await apply(transaction: transaction)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval. Pro activates once it completes."
            @unknown default:
                purchaseError = "Purchase could not be completed. Try again later."
            }
        } catch {
            purchaseError = "Purchase failed. You were not charged — try again."
        }
    }

    func restore() async {
        purchaseError = nil
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isPro {
                purchaseError = "No previous Pro purchase was found for this Apple Account."
            }
        } catch {
            purchaseError = "Restore failed. Check your connection and try again."
        }
    }

    private func refreshEntitlement() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue,
               transaction.productID == ProStore.productID,
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPro = entitled
    }

    private func apply(transaction: Transaction) async {
        if transaction.productID == ProStore.productID {
            isPro = transaction.revocationDate == nil
        }
    }
}
