import SwiftUI
import StoreKit
import KaracamAppModel

/// İlk bölüm ücretsiz; kalan 23 gün tek seferlik satın almayla açılır. Fiyat Product.displayPrice'tan gelir.
/// Ekran oyuncunun kendi hikâyesiyle konuşur: ilk tahmini, topladığı kanıt, taksite kalan.
struct PaywallView: View {
    @Environment(EntitlementStore.self) private var store
    @Environment(GameStore.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        MapCrop(spot: .office, height: 240)
                            .overlay(LinearGradient(colors: [Color.black.opacity(0.35), Theme.paper],
                                                    startPoint: .top, endPoint: .bottom))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("İLK HAFTA BİTTİ").font(.caption.weight(.bold)).foregroundStyle(Theme.rust)
                            Text("Hikâyenin kalanı").font(Theme.heading(.largeTitle))
                        }
                        .padding(20)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Halanın mektubu bir soruyla bitti: mühür nerede, imzayı kim attı? 8–30. günlerde köyü ayakta tutarken bu sorunun peşine düşeceksin.")
                            .font(Theme.story)
                            .fixedSize(horizontal: false, vertical: true)
                        yourStory
                        VStack(alignment: .leading, spacing: 8) {
                            Label("23 gün daha: gündem, projeler, siparişler", systemImage: "calendar")
                            Label("Gizemin çözümü, köyün oylaması, altı farklı son", systemImage: "magnifyingglass")
                            Label("Tek seferlik satın alma; abonelik ve reklam yok", systemImage: "checkmark.seal")
                            Label("Kaydın korunur, kaldığın yerden devam edersin", systemImage: "arrow.forward.circle")
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
                                Label("Hikâyeye devam et · \(product.displayPrice)", systemImage: "book.fill")
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
            }
            .ignoresSafeArea(edges: .top)
            .background(Theme.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } }
            }
            .task {
                // Mağaza yalnız bu ekran açılınca sorulur; oyunun açılışı hesap penceresi doğurmaz.
                if store.product == nil { await store.loadProduct() }
            }
        }
    }

    @ViewBuilder private var yourStory: some View {
        if let n = game.presentation?.notebook {
            VStack(alignment: .leading, spacing: 8) {
                Text("Senin hikâyen").font(Theme.heading(.headline))
                Label("Defterinde \(n.evidence.count) kayıt var", systemImage: "book.pages")
                if let guess = n.firstGuessLine {
                    Label(guess.replacingOccurrences(of: " (yalnız not; dünyayı değiştirmez)", with: ""),
                          systemImage: "person.fill.questionmark")
                }
                Label(n.goalLine, systemImage: "banknote")
            }
            .font(.callout)
            .paperCard()
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
