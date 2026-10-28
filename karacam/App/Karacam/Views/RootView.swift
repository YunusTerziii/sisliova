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
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    Image("map-karacam")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 460)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay(LinearGradient(colors: [Theme.paper.opacity(0), Theme.paper.opacity(0.2), Theme.paper],
                                                startPoint: UnitPoint(x: 0.5, y: 0.45), endPoint: .bottom))
                        .accessibilityLabel("Karaçam köyünün çizim haritası")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Karaçam")
                            .font(.system(size: 56, weight: .bold, design: .serif))
                        Text("Köyü Kurtar")
                            .font(Theme.heading(.title2))
                            .foregroundStyle(Theme.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
                }
                VStack(alignment: .leading, spacing: 20) {
                    Text("Halandan kalan kooperatifin üç milyon liralık borcu var. Otuz gün sonra ilk taksit: 150.000 TL. Ve köyden biri, senden önce bir şey imzalamış.")
                        .font(Theme.story)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if let summary = game.continueSummary {
                        VStack(alignment: .leading, spacing: 12) {
                            if let n = game.playerName {
                                Text("Tekrar hoş geldin, \(n).").font(Theme.heading(.title3))
                            }
                            Text(summary)
                                .font(.callout)
                                .foregroundStyle(Theme.secondary)
                                .lineLimit(3)
                            Button {
                                game.continueGame()
                            } label: {
                                Label("Devam et", systemImage: "play.fill")
                            }
                            .buttonStyle(ActionButtonStyle())
                        }
                        .paperCard()
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(game.envelope == nil ? "Yeni hikâye" : "Baştan başla")
                            .font(Theme.heading(.title3))
                        TextField("Adın (isteğe bağlı)", text: $name)
                            .textInputAutocapitalization(.words)
                            .padding(14)
                            .frame(minHeight: 48)
                            .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.charcoal.opacity(0.15)))
                        Button {
                            if game.envelope == nil { start() } else { confirmNew = true }
                        } label: {
                            Label(game.envelope == nil ? "Karaçam'a git" : "Yeni oyun başlat", systemImage: "figure.walk")
                        }
                        .buttonStyle(ActionButtonStyle(prominent: game.envelope == nil))
                        .disabled(game.isBusy)
                    }
                    .paperCard()
                    Button {
                        showSettings = true
                    } label: {
                        Label("Ayarlar", systemImage: "gearshape")
                    }
                    .buttonStyle(ActionButtonStyle(prominent: false))
                }
                .padding(20)
            }
        }
        .ignoresSafeArea(edges: .top)
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
    @Environment(GameStore.self) private var game
    @State private var router = TabRouter()
    /// Defter en son açıldığında kaç kanıt vardı; fazlası sekmede rozet olur.
    @State private var seenEvidence: Int?

    private var evidenceCount: Int { game.presentation?.notebook.evidence.count ?? 0 }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            NavigationStack { MasaView() }
                .tabItem { Label("Masa", systemImage: "rectangle.and.pencil.and.ellipsis") }
                .tag(TabRouter.Tab.masa)
            NavigationStack { KasabaView() }
                .tabItem { Label("Köy", systemImage: "map") }
                .tag(TabRouter.Tab.koy)
            NavigationStack { DefterView() }
                .tabItem { Label("Defter", systemImage: "book.closed") }
                .badge(max(0, evidenceCount - (seenEvidence ?? evidenceCount)))
                .tag(TabRouter.Tab.defter)
        }
        .environment(router)
        .onAppear { if seenEvidence == nil { seenEvidence = evidenceCount } }
        .onChange(of: router.tab) { _, tab in
            if tab == .defter { seenEvidence = evidenceCount }
        }
        .onChange(of: evidenceCount) { old, new in
            // Geri sarma kanıtı azaltırsa rozet eksiye düşmesin.
            if new < (seenEvidence ?? new) || router.tab == .defter { seenEvidence = new }
        }
    }
}
