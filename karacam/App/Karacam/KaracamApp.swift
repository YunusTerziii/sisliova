import SwiftUI
import KaracamCore
import KaracamAppModel

@main
struct KaracamApp: App {
    @State private var game: GameStore
    @State private var entitlements = EntitlementStore()
    @State private var preferences: Preferences
    /// GameStore geri bildirimi zayıf tutar; sahibi burası.
    @State private var feedback: FeedbackPlayer

    init() {
        let content: GameContent
        do {
            content = try GameContent.bundled()
        } catch {
            fatalError("Oyun içeriği yüklenemedi: \(error)")
        }
        let prefs = Preferences()
        let player = FeedbackPlayer(preferences: prefs)
        _preferences = State(initialValue: prefs)
        _feedback = State(initialValue: player)
        _game = State(initialValue: GameStore(content: content,
                                              store: SaveRepository(url: SaveRepository.defaultURL()),
                                              feedback: player))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(game)
                .environment(entitlements)
                .environment(preferences)
                .task {
                    await entitlements.start()
                    await game.load()
                }
                .onChange(of: entitlements.isUnlocked, initial: true) { _, unlocked in
                    game.isUnlocked = unlocked
                    if unlocked { game.paywallRequested = false }
                }
        }
    }
}
