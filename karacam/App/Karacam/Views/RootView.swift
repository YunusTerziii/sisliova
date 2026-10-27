import SwiftUI
import KaracamCore
import KaracamAppModel

struct RootView: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        @Bindable var game = game
        Group {
            switch game.screen {
            case .loading:
                ProgressView("Karaçam açılıyor")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .title:
                TitleView()
            case .playing:
                MainTabs()
            case let .failed(message):
                ContentUnavailableView("Kayıt açılamadı", systemImage: "exclamationmark.triangle",
                                       description: Text(message))
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .foregroundStyle(Theme.charcoal)
        .tint(Theme.moss)
        .preferredColorScheme(.light)
        .alert("Bilgi", isPresented: Binding(get: { game.notice != nil }, set: { if !$0 { game.notice = nil } })) {
            Button("Tamam", role: .cancel) { game.notice = nil }
        } message: {
            Text(game.notice ?? "")
        }
        .sheet(isPresented: $game.paywallRequested) {
            PaywallView()
        }
    }
}

// MARK: Ana ekran

struct TitleView: View {
    @Environment(GameStore.self) private var game
    @State private var name = ""
    @State private var confirmNew = false
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image("map-karacam")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Karaçam köyünün çizim haritası")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Karaçam")
                        .font(Theme.heading(.largeTitle))
                    Text("Kasabayı Kurtar")
                        .font(Theme.heading(.title3))
                        .foregroundStyle(Theme.secondary)
                    Text("Halandan kalan kooperatifin 3 milyon liralık borcu var. 30 gün sonra ilk taksit: 150.000 TL.")
                        .font(.body)
                        .padding(.top, 4)
                }
                if let summary = game.continueSummary {
                    VStack(alignment: .leading, spacing: 12) {
                        if let n = game.playerName {
                            Text("Tekrar hoş geldin, \(n).").font(.headline)
                        }
                        Text(summary)
                            .font(.body)
                            .foregroundStyle(Theme.secondary)
                        Button("Devam et") { game.continueGame() }
                            .buttonStyle(ActionButtonStyle())
                    }
                    .paperCard()
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(game.envelope == nil ? "Yeni hikâye" : "Baştan başla")
                        .font(Theme.heading(.title3))
                    TextField("Adın (isteğe bağlı)", text: $name)
                        .textInputAutocapitalization(.words)
                        .padding(12)
                        .frame(minHeight: 44)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    Button(game.envelope == nil ? "Karaçam'a git" : "Yeni oyun başlat") {
                        if game.envelope == nil { start() } else { confirmNew = true }
                    }
                    .buttonStyle(ActionButtonStyle(prominent: game.envelope == nil))
                    .disabled(game.isBusy)
                }
                .paperCard()
                Button("Ayarlar") { showSettings = true }
                    .frame(minHeight: 44)
            }
            .padding(20)
        }
        .alert("Yeni oyun başlasın mı?", isPresented: $confirmNew) {
            Button("Başlat", role: .destructive) { start() }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Mevcut kayıt silinir; tam oyun hakkın korunur.")
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private func start() {
        Task { await game.newGame(playerName: name) }
    }
}

// MARK: Sekmeler

struct MainTabs: View {
    var body: some View {
        TabView {
            NavigationStack { MasaView() }
                .tabItem { Label("Masa", systemImage: "rectangle.and.pencil.and.ellipsis") }
            NavigationStack { KasabaView() }
                .tabItem { Label("Kasaba", systemImage: "map") }
            NavigationStack { DefterView() }
                .tabItem { Label("Defter", systemImage: "book.closed") }
        }
    }
}
