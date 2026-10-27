import Foundation
import Testing
@testable import KaracamAppModel
@testable import KaracamCore

let content: GameContent = {
    do { return try GameContent.bundled() } catch { fatalError("İçerik yüklenemedi: \(error)") }
}()

/// Bellekte kayıt; istenince yazmayı reddeder.
actor MemoryStore: SaveStore {
    var saved: SaveEnvelope?
    var failNext = false
    var saveCount = 0

    func beginRun(_ runID: UUID) {}
    func save(_ envelope: SaveEnvelope) throws {
        if failNext { failNext = false; throw CocoaError(.fileWriteOutOfSpace) }
        saved = envelope
        saveCount += 1
    }
    func load() -> SaveRepository.LoadResult { saved.map { .loaded($0) } ?? .none }
    func deleteAll() { saved = nil }
    func setFail() { failNext = true }
}

@MainActor
final class RecordingFeedback: FeedbackSink {
    var events: [PresentationEvent] = []
    func play(_ events: [PresentationEvent]) { self.events += events }
}

@MainActor
@Suite struct GameStoreTests {
    func started() async -> (GameStore, MemoryStore) {
        let mem = MemoryStore()
        let store = GameStore(content: content, store: mem)
        await store.load()
        await store.newGame(playerName: "  ", seed: 7)
        return (store, mem)
    }

    func firstChoice(_ store: GameStore) -> Command.Action? {
        guard let scene = store.presentation?.scene, let id = scene.instanceID,
              let choice = scene.choices.first(where: { $0.enabled && $0.confirm == nil })
                ?? scene.choices.first(where: \.enabled) else { return nil }
        return .choose(sceneID: scene.sceneID, instanceID: id, choiceID: choice.id)
    }

    @Test func newGameStartsAndBlankNameIsDropped() async {
        let (store, mem) = await started()
        #expect(store.screen == .playing)
        #expect(store.playerName == nil)
        #expect(await mem.saveCount == 1)
        #expect(store.presentation?.day == 1)
    }

    @Test func staleScreenTapIsIgnored() async throws {
        let (store, mem) = await started()
        let rev = try #require(store.presentation?.revision)
        let action = try #require(firstChoice(store))
        #expect(await store.send(action, revision: rev))
        // Aynı ekrandan ikinci dokunuş: sürüm değişti, komut düşer.
        #expect(!(await store.send(action, revision: rev)))
        #expect(await mem.saveCount == 2)
    }

    @Test func failedSaveKeepsOldState() async throws {
        let (store, mem) = await started()
        let before = try #require(store.envelope)
        await mem.setFail()
        let action = try #require(firstChoice(store))
        #expect(!(await store.send(action)))
        #expect(store.envelope == before)
        #expect(store.notice != nil)
        // Sonraki deneme aynı komutla başarılı olur.
        #expect(await store.send(action))
        #expect(store.envelope?.state.revision == before.state.revision + 1)
    }

    @Test func lockedGateRequestsPaywallWithoutAdvancing() async throws {
        let (store, _) = await started()
        var guardCount = 0
        while store.presentation?.day != 7 || store.presentation?.phase != .recap {
            guardCount += 1
            try #require(guardCount < 500)
            let p = try #require(store.presentation)
            switch p.phase {
            case .morning, .anchor, .night:
                let action = try #require(firstChoice(store))
                await store.send(action)
            case .evening: await store.send(.settleEvening)
            case .recap:
                if p.guessPrompt { await store.send(.recordGuess(nil)) } else { await store.send(.finishDay) }
            default: Issue.record("beklenmeyen evre \(p.phase)"); return
            }
        }
        if store.presentation?.guessPrompt == true { await store.send(.recordGuess(nil)) }
        #expect(!(await store.send(.finishDay)))
        #expect(store.paywallRequested)
        #expect(store.presentation?.day == 7)
        store.isUnlocked = true
        #expect(await store.send(.finishDay))
        #expect(store.presentation?.day == 8)
    }

    @Test func feedbackReceivesEventsOnlyAfterCommit() async throws {
        let (store, mem) = await started()
        let fb = RecordingFeedback()
        store.attachFeedback(fb)
        await mem.setFail()
        let action = try #require(firstChoice(store))
        await store.send(action)
        #expect(fb.events.isEmpty)
        await store.send(action)
        #expect(!fb.events.isEmpty)
    }

    @Test func reopeningShowsContinueLine() async {
        let mem = MemoryStore()
        let first = GameStore(content: content, store: mem)
        await first.load()
        await first.newGame(playerName: "Deniz", seed: 3)
        let second = GameStore(content: content, store: mem)
        await second.load()
        #expect(second.screen == .title)
        #expect(second.playerName == "Deniz")
        #expect(second.continueSummary?.hasPrefix("1. gün") == true)
    }
}
