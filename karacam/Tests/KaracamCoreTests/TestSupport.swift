import Foundation
import Testing
@testable import KaracamCore

let sharedContent: GameContent = {
    do { return try GameContent.bundled() } catch { fatalError("İçerik yüklenemedi: \(error)") }
}()

/// Test sürücüsü: komutları gerçek reducer üzerinden gönderir.
struct Driver {
    let engine: Engine
    var env: SaveEnvelope
    var counter: UInt64 = 0

    init(seed: UInt64 = 42, culprit: SuspectID = .selim, clarity: [String: Bool]? = nil) {
        engine = Engine(content: sharedContent)
        env = engine.newRun(seed: seed, runID: UUID(), attemptID: UUID(), caseOverride: culprit,
                            clarityOverride: clarity)
    }

    var s: RunState { env.state }

    @discardableResult
    mutating func send(_ action: Command.Action, unlocked: Bool = true, id: UUID = UUID()) throws -> Transition {
        let t = try engine.reduce(env, Command(commandID: id, expectedRevision: env.state.revision, action: action),
                                  fullGameUnlocked: unlocked)
        env = t.envelope
        return t
    }

    mutating func choose(_ choiceID: String) throws {
        guard let cur = s.current else { throw CoreError.invalidPhase }
        try send(.choose(sceneID: cur.sceneID, instanceID: cur.instanceID, choiceID: choiceID))
    }

    mutating func agenda(_ item: String, _ choice: String) throws {
        try send(.chooseAgenda(itemID: item, choiceID: choice))
    }

    mutating func settle() throws { try send(.settleEvening) }

    mutating func finish() throws {
        if s.flags.contains("letterRead") && !env.metadata.firstGuessRecorded {
            try send(.recordGuess(nil))
        }
        try send(.finishDay)
    }

    func firstFreeChoice() -> String? {
        guard let cur = s.current, let def = engine.content.scenes[cur.sceneID] else { return nil }
        let choices = engine.resolvedChoices(def, variant: cur.variantIndex)
        return choices.first { engine.availability($0, s).0 && engine.upfrontCost($0, s) == 0 && !$0.effects.contains { $0.kind == .endGame } }?.id
            ?? choices.first { engine.availability($0, s).0 }?.id
    }

    /// Sahne kimliği → seçim haritası ve gün → gündem işi ile, hedef gün/evreye kadar oynar.
    mutating func run(to day: Int, phase: Phase, picks: [String: String] = [:],
                      agenda: [Int: (String, String)] = [:]) throws {
        var guardCount = 0
        while !(s.day == day && s.phase == phase) {
            guardCount += 1
            if guardCount > 2000 || s.ending != nil { throw CoreError.invalidPhase }
            switch s.phase {
            case .morning, .anchor, .night:
                let id = s.current!.sceneID
                if let pick = picks[id] { try choose(pick) } else { try choose(firstFreeChoice()!) }
            case .agenda:
                if let (item, choice) = agenda[s.day] { try self.agenda(item, choice) } else { try self.agenda("rest", "rest") }
            case .evening: try settle()
            case .recap: try finish()
            case .ended: return
            }
        }
    }
}
