import SwiftUI
import StoreKit
import KaracamAppModel

/// İlk bölüm ücretsiz; kalan 23 gün tek seferlik satın almayla açılır. Fiyat Product.displayPrice'tan gelir.
struct PaywallView: View {
    @Environment(EntitlementStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Hikâyenin kalanı").font(Theme.heading(.title))
                    Text("İlk hafta bitti. Tam oyun 8–30. günleri açar: gündem, işletme projeleri, satış yetkisinin kimde olduğu, mühür, köyün oylaması, altı son ve kişisel epilog.")
                        .font(.body)
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Tek seferlik satın alma; abonelik yok", systemImage: "checkmark.circle")
                        Label("Kaydın korunur, kaldığın yerden devam edersin", systemImage: "checkmark.circle")
                        Label("Reklam yok, çevrim dışı oynanır", systemImage: "checkmark.circle")
                    }
                    .font(.callout)
                    .paperCard()

                    if store.isUnlocked {
                        Label("Tam oyun açık", systemImage: "lock.open")
                            .font(.headline).foregroundStyle(Theme.moss)
                        Button("Devam et") { dismiss() }
                            .buttonStyle(ActionButtonStyle())
                    } else if let product = store.product {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            Text("Tam oyunu aç · \(product.displayPrice)")
                        }
                        .buttonStyle(ActionButtonStyle())
                        .disabled(store.state == .purchasing)
                    } else {
                        Text(store.productError ?? "Mağaza bilgisi yükleniyor…")
                            .font(.callout).foregroundStyle(Theme.secondary)
                        Button("Yeniden dene") { Task { await store.loadProduct() } }
                            .buttonStyle(ActionButtonStyle(prominent: false))
                    }

                    statusLine

                    Button("Satın alımları geri yükle") { Task { await store.restore() } }
                        .frame(minHeight: 44)
                        .disabled(store.isRestoring)
                }
                .padding(20)
            }
            .background(Theme.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } }
            }
        }
    }

    @ViewBuilder private var statusLine: some View {
        switch store.state {
        case .idle, .purchased:
            EmptyView()
        case .purchasing:
            ProgressView("Satın alma sürüyor")
        case .pending:
            Text("Satın alma onay bekliyor (ör. aile onayı). Onaylandığında tam oyun kendiliğinden açılır.")
                .font(.callout)
        case .cancelled:
            Text("Satın alma iptal edildi. Hiçbir ücret alınmadı.").font(.callout)
        case let .failed(message):
            Text(message).font(.callout).foregroundStyle(Theme.rust)
        }
    }
}
