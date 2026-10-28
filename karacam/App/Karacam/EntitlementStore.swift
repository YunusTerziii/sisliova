import Foundation
import Observation
import StoreKit

/// Tek non-consumable ürünle tam oyun hakkı (StoreKit 2).
/// Erişim yalnız doğrulanmış işlemle verilir; geçici ağ hatası önceden doğrulanmış erişimi silmez,
/// iade/geri alma ise erişimi kapatır (kayıt korunur).
@MainActor
@Observable
final class EntitlementStore {
    static let productID = "com.yunusterzi.karacam.tamoyun"

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case pending
        case cancelled
        case failed(String)
        case purchased
    }

    private(set) var product: Product?
    private(set) var isUnlocked: Bool
    private(set) var state: PurchaseState = .idle
    private(set) var productError: String?
    private(set) var isRestoring = false

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private let cacheKey = "entitlement.fullGame.verified"

    init() {
        // Son doğrulanmış durum: StoreKit cevap verene kadar çevrim dışı oyuncuyu kilitlemez.
        isUnlocked = UserDefaults.standard.bool(forKey: cacheKey)
        #if DEBUG
        // Simülatörde tam oyunu StoreKit olmadan denemek için: `simctl launch … -karacamUnlockAll`.
        if ProcessInfo.processInfo.arguments.contains("-karacamUnlockAll") { isUnlocked = true }
        #endif
    }

    func start() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await result in Transaction.updates {
                    await self?.handle(result)
                }
            }
        }
        await refreshEntitlement()
        // Ürün bilgisi satın alma ekranı açılınca istenir (PaywallView).
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
            productError = product == nil ? "Ürün şu an App Store'dan alınamadı." : nil
        } catch {
            productError = "Mağazaya ulaşılamadı. Bağlantını kontrol edip yeniden dene."
        }
    }

    func purchase() async {
        guard let product, state != .purchasing else { return }
        state = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                switch verification {
                case let .verified(transaction):
                    guard transaction.productID == Self.productID else {
                        state = .failed("Beklenmeyen ürün.")
                        return
                    }
                    grant(true)
                    await transaction.finish()
                    state = .purchased
                case let .unverified(_, error):
                    state = .failed("Satın alma doğrulanamadı: \(error.localizedDescription)")
                }
            case .pending:
                state = .pending
            case .userCancelled:
                state = .cancelled
            @unknown default:
                state = .failed("Bilinmeyen satın alma sonucu.")
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
        } catch {
            state = .failed("Geri yükleme tamamlanamadı: \(error.localizedDescription)")
        }
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            if case let .verified(t) = result, t.productID == Self.productID, t.revocationDate == nil {
                found = true
            }
        }
        if found {
            grant(true)
            return
        }
        // Hak listesi boş geldiyse ancak işlem gerçekten geri alınmışsa kapat.
        if let latest = await Transaction.latest(for: Self.productID) {
            if case let .verified(t) = latest, t.revocationDate != nil {
                grant(false)
            } else if case .verified = latest {
                // Doğrulanmış ve geri alınmamış son işlem var: erişim sürer.
                grant(true)
            }
        }
        // İşlem hiç görünmüyorsa (ör. çevrim dışı ilk açılış) son doğrulanmış durum korunur.
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case let .verified(t) = result, t.productID == Self.productID else { return }
        grant(t.revocationDate == nil)
        await t.finish()
    }

    private func grant(_ value: Bool) {
        isUnlocked = value
        UserDefaults.standard.set(value, forKey: cacheKey)
    }
}
