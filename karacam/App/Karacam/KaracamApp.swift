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

    #if DEBUG
    /// `-karacamDemoDay 22` (ve isteğe bağlı `-karacamDemoStrategy dengeli`): dengeli otomatik oyuncuyla o güne kadar oynar.
    static func debugFastForward(_ game: GameStore) async {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-karacamDemoDay"), i + 1 < args.count, let day = Int(args[i + 1]) else { return }
        var name = "dengeli"
        if let j = args.firstIndex(of: "-karacamDemoStrategy"), j + 1 < args.count { name = args[j + 1] }
        let business = args.contains("-karacamDemoBees") ? "bees" : "spa"
        guard let strategy = Strategy.presets(business: business).first(where: { $0.name == name }) else { return }
        let env = Autoplayer(engine: game.engine).playEnvelope(seed: 2026, strategy: strategy, untilDay: day)
        await game.loadPrepared(env)
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(game)
                .environment(entitlements)
                .environment(preferences)
                .task {
                    await entitlements.start()
                    await game.load()
                    #if DEBUG
                    await Self.debugFastForward(game)
                    #endif
                }
                .onChange(of: entitlements.isUnlocked, initial: true) { _, unlocked in
                    game.isUnlocked = unlocked
                    if unlocked { game.paywallRequested = false }
                }
        }
    }
}
