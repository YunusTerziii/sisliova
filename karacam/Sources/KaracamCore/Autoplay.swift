import Foundation

/// Belirlenmiş stratejilerle otomatik oynatıcı. Denge raporu ve uçtan uca testler için;
/// insan davranışının tek modeli değildir.
public struct Strategy: Sendable {
    public var name: String
    /// İlk gün işletme: "spa" ya da "bees".
    public var business: String
    public var cashWeight: Double
    public var trustWeight: Double
    public var pressureWeight: Double
    /// Gündemde araştırma işlerine verilen ek puan.
    public var investigation: Double
    /// Rastgele sapma oranı (0–1). Tohumlu.
    public var noise: Double
    public var acceptsSale: Bool

    public init(name: String, business: String, cashWeight: Double, trustWeight: Double,
                pressureWeight: Double, investigation: Double, noise: Double = 0, acceptsSale: Bool = false) {
        self.name = name
        self.business = business
        self.cashWeight = cashWeight
        self.trustWeight = trustWeight
        self.pressureWeight = pressureWeight
        self.investigation = investigation
        self.noise = noise
        self.acceptsSale = acceptsSale
    }

    public static func presets(business: String) -> [Strategy] {
        [
            Strategy(name: "dengeli", business: business, cashWeight: 1, trustWeight: 900, pressureWeight: 500, investigation: 2500),
            Strategy(name: "tüccar", business: business, cashWeight: 1.6, trustWeight: 350, pressureWeight: 250, investigation: 0),
            Strategy(name: "yardımsever", business: business, cashWeight: 0.4, trustWeight: 1600, pressureWeight: 300, investigation: 800),
            Strategy(name: "araştırmacı", business: business, cashWeight: 0.8, trustWeight: 700, pressureWeight: 500, investigation: 6000),
            Strategy(name: "riskçi", business: business, cashWeight: 2, trustWeight: 500, pressureWeight: -50, investigation: 0),
            Strategy(name: "rastgele", business: business, cashWeight: 1, trustWeight: 600, pressureWeight: 400, investigation: 1000, noise: 1),
        ]
    }
}

public struct AutoplayResult: Sendable {
    public var ending: Ending
    public var endingDay: Int
    public var cashBeforePayment: Kurus
    public var finalCash: Kurus
    public var trust: Int
    public var pressure: Int
    public var caseResolved: Bool
    public var resolvedDay: Int?
    public var authoritySafe: Bool
    public var firstDayTrust60: Int?
    public var minCash: Kurus
    public var commands: Int
    public var business: Business
    public var caseID: SuspectID
    public var stuck: String?
}

public struct Autoplayer {
    public let engine: Engine
    public init(engine: Engine) { self.engine = engine }

    public func play(seed: UInt64, strategy: Strategy, caseOverride: SuspectID? = nil,
                     maxCommands: Int = 600) -> AutoplayResult {
        run(seed: seed, strategy: strategy, caseOverride: caseOverride, maxCommands: maxCommands).1
    }

    /// Oyunun son kayıt zarfı (sunum testleri için).
    public func playEnvelope(seed: UInt64, strategy: Strategy, caseOverride: SuspectID? = nil) -> SaveEnvelope {
        run(seed: seed, strategy: strategy, caseOverride: caseOverride, maxCommands: 600).0
    }

    /// Belirli bir günün sabahına kadar oynar (geliştirme sırasında geç sahneleri görmek için).
    public func playEnvelope(seed: UInt64, strategy: Strategy, untilDay day: Int) -> SaveEnvelope {
        run(seed: seed, strategy: strategy, caseOverride: nil, maxCommands: 600,
            stop: { $0.day >= day && ($0.phase == .agenda || $0.phase == .morning) }).0
    }

    func run(seed: UInt64, strategy: Strategy, caseOverride: SuspectID?,
             maxCommands: Int, stop: ((RunState) -> Bool)? = nil) -> (SaveEnvelope, AutoplayResult) {
        var env = engine.newRun(seed: seed, runID: UUID(uuid: Autoplayer.uuid(seed)),
                                attemptID: UUID(uuid: Autoplayer.uuid(seed &+ 1)), caseOverride: caseOverride)
        var rng = SplitMix64(seed: seed ^ 0xA5A5_5A5A_1234_5678)
        var commands = 0
        var firstTrust60: Int?
        var minCash = env.state.cash
        var stuck: String?
        var counter: UInt64 = 0

        func send(_ action: Command.Action) -> Bool {
            counter += 1
            let cmd = Command(commandID: UUID(uuid: Autoplayer.uuid(seed &* 31 &+ counter)),
                              expectedRevision: env.state.revision, action: action)
            do {
                env = try engine.reduce(env, cmd, fullGameUnlocked: true).envelope
                commands += 1
                return true
            } catch {
                stuck = "\(env.state.day). gün \(env.state.phase): \(error)"
                return false
            }
        }

        while env.state.ending == nil && commands < maxCommands && stuck == nil {
            let s = env.state
            if let stop, stop(s) { break }
            if s.trust >= engine.content.rules.highTrust && firstTrust60 == nil { firstTrust60 = s.day }
            minCash = min(minCash, s.cash)
            switch s.phase {
            case .morning, .anchor, .night:
                guard let cur = s.current, let def = engine.content.scenes[cur.sceneID] else {
                    stuck = "\(s.day). gün \(s.phase): sahne yok"; break
                }
                let choices = engine.resolvedChoices(def, variant: cur.variantIndex)
                guard let pick = pickChoice(choices, def, s, strategy, &rng) else {
                    stuck = "\(s.day). gün \(def.id): kullanılabilir seçim yok"; break
                }
                _ = send(.choose(sceneID: def.id, instanceID: cur.instanceID, choiceID: pick))
            case .agenda:
                let items = engine.availableAgenda(s)
                var best: (String, String, Double)?
                for item in items {
                    guard let def = engine.content.scenes[item.sceneID] else { continue }
                    let v = engine.variantIndex(def, s)
                    let choices = engine.resolvedChoices(def, variant: v)
                    guard let pick = pickChoice(choices, def, s, strategy, &rng),
                          let ch = choices.first(where: { $0.id == pick }) else { continue }
                    var score = value(ch, s, strategy) + Double(item.priority) * 30
                    if item.category == .investigation { score += strategy.investigation }
                    if item.category == .rest { score -= 500 }
                    if strategy.noise > 0 { score += Double(rng.next(below: 10_000)) * strategy.noise }
                    if best == nil || score > best!.2 { best = (item.id, pick, score) }
                }
                guard let b = best else { stuck = "\(s.day). gün gündem boş"; break }
                _ = send(.chooseAgenda(itemID: b.0, choiceID: b.1))
            case .evening:
                _ = send(.settleEvening)
            case .recap:
                if s.flags.contains("letterRead") && !env.metadata.firstGuessRecorded {
                    _ = send(.recordGuess(.selim))
                } else {
                    _ = send(.finishDay)
                }
            case .ended:
                break
            }
        }
        let s = env.state
        return (env, AutoplayResult(
            ending: s.ending ?? .cash, endingDay: s.endingDay ?? s.day,
            cashBeforePayment: s.finalCashBeforePayment ?? s.cash, finalCash: s.cash,
            trust: s.trust, pressure: s.pressure, caseResolved: s.flags.contains("caseResolved"),
            resolvedDay: s.counters["caseResolvedDay"], authoritySafe: Final.authoritySafe(s),
            firstDayTrust60: firstTrust60, minCash: minCash, commands: commands,
            business: s.business, caseID: s.caseID,
            stuck: stuck ?? (s.ending == nil ? "komut sınırı" : nil)))
    }

    func pickChoice(_ choices: [ChoiceDefinition], _ def: SceneDefinition, _ s: RunState,
                    _ st: Strategy, _ rng: inout SplitMix64) -> String? {
        let enabled = choices.filter { engine.availability($0, s).0 }
        guard !enabled.isEmpty else { return nil }
        if def.id == "d01.noon.elif" { return enabled.first { $0.id == st.business }?.id ?? enabled[0].id }
        var best: (String, Double)?
        for ch in enabled {
            var v = value(ch, s, st)
            if st.noise > 0 { v += Double(rng.next(below: 10_000)) * st.noise }
            if best == nil || v > best!.1 { best = (ch.id, v) }
        }
        return best?.0
    }

    /// Bir seçimin kabaca değeri: anlık etkiler + bilinen akış kuralları.
    func value(_ ch: ChoiceDefinition, _ s: RunState, _ st: Strategy) -> Double {
        var v = 0.0
        let daysLeft = Double(max(1, engine.content.rules.finalDay - s.day + 1))
        for e in ch.effects where Rulebook.all(e.when, s, engine.content) {
            let a = Double(e.amount ?? 0)
            switch e.kind {
            case .cash: v += a / 100 * st.cashWeight
            case .trust: v += a * st.trustWeight * (s.trust < 60 ? 1.2 : 0.4)
            case .pressure: v -= a * st.pressureWeight * (s.pressure >= 40 ? 2 : 1)
            case .setIncome: v += a / 100 * daysLeft * 0.9 * st.cashWeight
            case .setExpense: v -= a / 100 * daysLeft * st.cashWeight
            case .reduceExpense: v += a / 100 * daysLeft * st.cashWeight
            case .removeExpenseAfterEvening: v += 1000 * daysLeft * st.cashWeight
            case .startBusiness: v += 50_000
            case .closeBusiness: v -= 60_000
            case .acceptCommitment: v += a / 100 * st.cashWeight + 2000
            case .grantEvidence, .interview, .recoverSeal: v += st.investigation * 0.6
            case .accuse:
                let who = SuspectID(rawValue: e.target ?? "")
                if let who, CaseSolver.canProve(who, with: Array(s.evidence.values)) { v += 50_000 }
                else { v -= 80_000 }
            case .setFlag where e.target == "authorityFrozen" || e.target == "authorityRevoked":
                v += s.day >= 20 ? 30_000 : 4000
            case .endGame:
                v += st.acceptsSale ? 1_000_000 : -1_000_000
            case .settleFinal: v += 10
            case .setDayGrossPercent: v -= 4000 * st.cashWeight
            case .correctAccusation: v += 20_000
            case .resolveComplaint: v += 3000
            case .voteConfidence: v += e.value == "attend" ? 5000 : -5000
            default: break
            }
        }
        if ch.confirm != nil && !ch.effects.contains(where: { $0.kind == .accuse }) { v -= 2000 }
        return v
    }

    static func uuid(_ x: UInt64) -> uuid_t {
        var r = SplitMix64(seed: x)
        let a = r.next(), b = r.next()
        return (UInt8(truncatingIfNeeded: a), UInt8(truncatingIfNeeded: a >> 8), UInt8(truncatingIfNeeded: a >> 16),
                UInt8(truncatingIfNeeded: a >> 24), UInt8(truncatingIfNeeded: a >> 32), UInt8(truncatingIfNeeded: a >> 40),
                UInt8(truncatingIfNeeded: a >> 48), UInt8(truncatingIfNeeded: a >> 56), UInt8(truncatingIfNeeded: b),
                UInt8(truncatingIfNeeded: b >> 8), UInt8(truncatingIfNeeded: b >> 16), UInt8(truncatingIfNeeded: b >> 24),
                UInt8(truncatingIfNeeded: b >> 32), UInt8(truncatingIfNeeded: b >> 40), UInt8(truncatingIfNeeded: b >> 48),
                UInt8(truncatingIfNeeded: b >> 56))
    }
}
