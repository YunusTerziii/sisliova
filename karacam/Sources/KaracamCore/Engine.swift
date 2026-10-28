import Foundation

public struct Command: Codable, Sendable, Equatable {
    public enum Action: Codable, Sendable, Equatable {
        /// Sabah, öğle veya gece sahnesinde bir seçim.
        case choose(sceneID: String, instanceID: String, choiceID: String)
        /// Gündem menüsünden açılan işte bir seçim. Menüyü açmak durum değiştirmez.
        case chooseAgenda(itemID: String, choiceID: String)
        case settleEvening
        case finishDay
        case recordGuess(SuspectID?)
        case toggleElimination(SuspectID)
        case restoreDayCheckpoint
        case restoreChapterCheckpoint
    }

    public var commandID: UUID
    public var expectedRevision: Int
    public var action: Action

    public init(commandID: UUID = UUID(), expectedRevision: Int, action: Action) {
        self.commandID = commandID
        self.expectedRevision = expectedRevision
        self.action = action
    }
}

/// Yalnız sunum amaçlı olaylar: ses, haptic, kısa bildirim.
public enum PresentationEvent: Sendable, Equatable {
    case choiceApplied(text: String)
    case evidenceGained([String])
    case eveningSettled(net: Kurus)
    case dayStarted(Int)
    case chapterCompleted(Int)
    case gameEnded(Ending)
    case rewound(toDay: Int)
    case noteChanged
}

public struct Transition: Sendable {
    public var envelope: SaveEnvelope
    public var events: [PresentationEvent]
}

/// Saf oyun çekirdeği: eski snapshot + komut + içerik → yeni snapshot.
/// Dosya, ağ, gerçek saat veya arayüz kullanmaz.
public struct Engine: Sendable {
    public let content: GameContent
    var rules: Rules { content.rules }

    public init(content: GameContent) {
        self.content = content
    }

    // MARK: Yeni oyun

    public func newRun(seed: UInt64, runID: UUID = UUID(), attemptID: UUID = UUID(),
                       caseOverride: SuspectID? = nil, clarityOverride: [String: Bool]? = nil,
                       playerName: String? = nil) -> SaveEnvelope {
        var rng = SplitMix64(seed: seed)
        let suspects = SuspectID.allCases
        let rolledCase = suspects[rng.next(below: suspects.count)]
        let caseID = caseOverride ?? rolledCase
        // İz açıklığı vaka kimliğinden ayrı zarlarla seçilir ve kayda alınır.
        var clarity: [String: Bool] = [:]
        for key in Set(content.cases.traces.map(\.clarityKey)).sorted() {
            clarity[key] = rng.next(below: 100) < content.cases.clarityChance
        }
        if let o = clarityOverride { clarity.merge(o) { $1 } }
        let others = suspects.filter { $0 != caseID }
        let decoy = others[rng.next(below: others.count)]

        var state = RunState(
            runID: runID, revision: 0, seed: seed, caseID: caseID, clarity: clarity,
            decoySuspect: decoy, day: 1, phase: .morning, current: nil, slotQueue: [],
            business: .none, cash: rules.initialCash, trust: rules.initialTrust,
            pressure: rules.initialPressure, incomes: [:], expenses: [:], evidence: [:],
            flags: [], counters: [:], commitments: [:], scheduled: [], activityLastDay: [:],
            usedAgendaItems: [], completedInstances: [], appliedCommands: [], settledDays: [],
            pendingExpenseRemoval: [], mandate: nil, grossPercentByDay: [:], paymentMade: false,
            ending: nil, endingDay: nil, lastOutcome: nil, memories: [], evenings: [],
            interviewMarks: [:], accusations: [], complaint: nil, complaintsStarted: 0,
            deryaMetDay: nil, finalCashBeforePayment: nil)
        var events: [PresentationEvent] = []
        enterDay(&state, events: &events)
        let metadata = RunMetadata(firstGuess: nil, firstGuessRecorded: false, firstGuessDay: nil,
                                   rewindCount: 0, attemptID: attemptID, eliminated: [],
                                   playerName: playerName)
        return SaveEnvelope(schemaVersion: SaveEnvelope.currentSchema,
                            contentVersion: content.contentVersion, state: state,
                            metadata: metadata, dayCheckpoint: state, chapterCheckpoint: state)
    }

    // MARK: Reducer

    public func reduce(_ envelope: SaveEnvelope, _ command: Command,
                       fullGameUnlocked: Bool) throws -> Transition {
        let old = envelope.state
        guard command.expectedRevision == old.revision else { throw CoreError.staleCommand }
        guard !old.appliedCommands.contains(command.commandID) else { throw CoreError.duplicateCommand }

        var env = envelope
        var s = old
        var events: [PresentationEvent] = []

        switch command.action {
        case let .choose(sceneID, instanceID, choiceID):
            guard s.ending == nil else { throw CoreError.gameEnded }
            guard [.morning, .anchor, .night].contains(s.phase), let cur = s.current else {
                throw CoreError.invalidPhase
            }
            guard cur.sceneID == sceneID, cur.instanceID == instanceID else { throw CoreError.sceneMismatch }
            guard !s.completedInstances.contains(instanceID) else { throw CoreError.duplicateCommand }
            try applyChoice(&s, instance: cur, choiceID: choiceID, events: &events)
            if s.ending == nil { advance(&s, events: &events) }

        case let .chooseAgenda(itemID, choiceID):
            guard s.ending == nil else { throw CoreError.gameEnded }
            guard s.phase == .agenda else { throw CoreError.invalidPhase }
            guard let item = availableAgenda(s).first(where: { $0.id == itemID }) else {
                throw CoreError.choiceUnavailable("Gündem işi şu an açık değil: \(itemID)")
            }
            guard let scene = content.scenes[item.sceneID] else { throw CoreError.unknownScene(item.sceneID) }
            let instance = SceneInstance(sceneID: scene.id, instanceID: "d\(s.day).agenda.\(item.id)",
                                         variantIndex: variantIndex(scene, s), slot: .agenda,
                                         agendaItemID: item.id)
            guard !s.completedInstances.contains(instance.instanceID) else { throw CoreError.duplicateCommand }
            s.current = instance
            let speaker = instance.variantIndex.flatMap { scene.variants?[$0].speakerID } ?? scene.speakerID
            s.flags.insert("met.\(speaker)")
            try applyChoice(&s, instance: instance, choiceID: choiceID, events: &events)
            if s.ending == nil {
                s.current = nil
                beginSlot(&s, .anchor, events: &events)
            }

        case .settleEvening:
            guard s.ending == nil else { throw CoreError.gameEnded }
            guard s.phase == .evening else { throw CoreError.invalidPhase }
            let (next, report) = try Economy.settle(s, rules: rules)
            s = next
            events.append(.eveningSettled(net: report.net))
            afterEvening(&s, events: &events)
            if s.ending == nil { beginSlot(&s, .night, events: &events) }

        case .finishDay:
            guard s.ending == nil else { throw CoreError.gameEnded }
            guard s.phase == .recap else { throw CoreError.invalidPhase }
            if s.day >= rules.freeLastDay && !fullGameUnlocked && s.day < rules.finalDay {
                throw CoreError.gateLocked
            }
            if s.day == rules.freeLastDay && !env.metadata.firstGuessRecorded {
                // İlk tahmin ekranı atlanırsa "bilmiyorum" olarak kaydedilir.
                env.metadata.firstGuessRecorded = true
                env.metadata.firstGuessDay = s.day
            }
            let finishedChapter = content.chapter(for: s.day)
            s.day += 1
            enterDay(&s, events: &events)
            if let ch = finishedChapter, ch.lastDay == s.day - 1 {
                events.append(.chapterCompleted(ch.id))
            }

        case let .recordGuess(guess):
            guard s.flags.contains("letterRead"), !env.metadata.firstGuessRecorded else {
                throw CoreError.choiceUnavailable("İlk tahmin şu an alınamaz")
            }
            env.metadata.firstGuess = guess
            env.metadata.firstGuessRecorded = true
            env.metadata.firstGuessDay = s.day
            events.append(.noteChanged)

        case let .toggleElimination(person):
            if env.metadata.eliminated.contains(person) {
                env.metadata.eliminated.remove(person)
            } else {
                env.metadata.eliminated.insert(person)
            }
            events.append(.noteChanged)

        case .restoreDayCheckpoint, .restoreChapterCheckpoint:
            let isDay = command.action == .restoreDayCheckpoint
            guard let cp = isDay ? env.dayCheckpoint : env.chapterCheckpoint else {
                throw CoreError.invalidPhase
            }
            var restored = cp
            restored.appliedCommands = old.appliedCommands
            s = restored
            env.metadata.rewindCount += 1
            if !isDay { env.dayCheckpoint = restored }
            events.append(.rewound(toDay: restored.day))
        }

        s.appliedCommands.insert(command.commandID)
        // Geri sarmada da revision ileri gider: current + 1.
        s.revision = old.revision + 1
        env.state = s

        // Gün başı ve bölüm başı kayıtları.
        if case .finishDay = command.action {
            var cp = s
            cp.appliedCommands = []
            env.dayCheckpoint = cp
            if let ch = content.chapter(for: s.day), ch.firstDay == s.day {
                env.chapterCheckpoint = cp
            }
        }
        return Transition(envelope: env, events: events)
    }

    // MARK: Gün akışı

    func enterDay(_ s: inout RunState, events: inout [PresentationEvent]) {
        s.flags = s.flags.filter { !$0.hasPrefix("today.") }
        s.current = nil
        s.slotQueue = []
        // Zamanı gelen ertelenmiş etkiler.
        let due = s.scheduled.filter { $0.day <= s.day }
        s.scheduled.removeAll { $0.day <= s.day }
        var sink: [String] = []
        for item in due {
            apply(item.effect, to: &s, notes: &sink, deferred: true)
            if let note = item.note { s.memories.append(Memory(day: s.day, text: note)) }
        }
        events.append(.dayStarted(s.day))
        let def = content.dayDefinition(s.day)
        if s.day <= rules.freeLastDay || s.day >= rules.finalDay || def?.dueMorning == true {
            beginSlot(&s, .morning, events: &events)
        } else {
            s.phase = .agenda
        }
    }

    func groupKey(_ scene: SceneDefinition) -> String {
        (scene.dynamic == true ? "dyn:" : "") + (scene.group ?? scene.slot.rawValue)
    }

    func beginSlot(_ s: inout RunState, _ slot: Slot, events: inout [PresentationEvent]) {
        var groups: [String] = []
        for scene in content.scenes(day: s.day, slot: slot) {
            let key = groupKey(scene)
            if !groups.contains(key) { groups.append(key) }
        }
        if slot == .anchor {
            for scene in content.dynamicAnchors() {
                let key = groupKey(scene)
                if !groups.contains(key) { groups.append(key) }
            }
        }
        s.phase = phase(for: slot)
        s.slotQueue = groups
        s.current = nil
        advance(&s, events: &events)
    }

    func phase(for slot: Slot) -> Phase {
        switch slot {
        case .morning, .agenda: .morning
        case .anchor: .anchor
        case .night: .night
        }
    }

    /// Sıradaki sahneyi açar; yuva bittiyse bir sonraki evreye geçer.
    func advance(_ s: inout RunState, events: inout [PresentationEvent]) {
        s.current = nil
        let slot: Slot
        switch s.phase {
        case .morning: slot = .morning
        case .anchor: slot = .anchor
        case .night: slot = .night
        default: return
        }
        while !s.slotQueue.isEmpty {
            let group = s.slotQueue.removeFirst()
            let pool = group.hasPrefix("dyn:")
                ? content.dynamicAnchors()
                : content.scenes(day: s.day, slot: slot)
            for scene in pool where groupKey(scene) == group {
                let instanceID = "d\(s.day).\(slot.rawValue).\(scene.id)"
                if s.completedInstances.contains(instanceID) { continue }
                if Rulebook.all(scene.requirements, s, content) {
                    let v = variantIndex(scene, s)
                    s.current = SceneInstance(sceneID: scene.id, instanceID: instanceID,
                                              variantIndex: v, slot: slot)
                    let speaker = v.flatMap { scene.variants?[$0].speakerID } ?? scene.speakerID
                    s.flags.insert("met.\(speaker)")
                    return
                }
            }
        }
        switch slot {
        case .morning, .agenda: beginSlot(&s, .anchor, events: &events)
        case .anchor: s.phase = .evening
        case .night: s.phase = .recap
        }
    }

    func variantIndex(_ scene: SceneDefinition, _ s: RunState) -> Int? {
        scene.variants?.firstIndex { Rulebook.all($0.when, s, content) }
    }

    // MARK: Seçimler

    public func resolvedChoices(_ scene: SceneDefinition, variant: Int?) -> [ChoiceDefinition] {
        if let v = variant, let variants = scene.variants, v < variants.count, let c = variants[v].choices {
            return c
        }
        return scene.choices
    }

    /// Seçimin kullanılabilirliği; kullanılamıyorsa nedeni.
    public func availability(_ choice: ChoiceDefinition, _ s: RunState) -> (Bool, String?) {
        if !Rulebook.all(choice.requirements, s, content) {
            return (false, choice.requirementText ?? "Şartlar henüz sağlanmadı")
        }
        if choice.allowDebt != true {
            let cost = upfrontCost(choice, s)
            if cost > 0 && s.cash < cost {
                return (false, "Kasa yetmiyor: \(Money.format(cost)) gerekiyor")
            }
        }
        return (true, nil)
    }

    func upfrontCost(_ choice: ChoiceDefinition, _ s: RunState) -> Kurus {
        choice.effects.reduce(Kurus(0)) { sum, e in
            guard e.kind == .cash, let a = e.amount, a < 0, (e.startsAfterDays ?? 0) == 0,
                  Rulebook.all(e.when, s, content) else { return sum }
            return sum - a
        }
    }

    func applyChoice(_ s: inout RunState, instance: SceneInstance, choiceID: String,
                     events: inout [PresentationEvent]) throws {
        guard let scene = content.scenes[instance.sceneID] else { throw CoreError.unknownScene(instance.sceneID) }
        let choices = resolvedChoices(scene, variant: instance.variantIndex)
        guard let choice = choices.first(where: { $0.id == choiceID }) else {
            throw CoreError.choiceUnavailable(choiceID)
        }
        let (ok, reason) = availability(choice, s)
        guard ok else { throw CoreError.choiceUnavailable(reason ?? choiceID) }

        // Sonuç metni etkilerden önceki duruma göre seçilir.
        let resultText = choice.resultVariants?.first { Rulebook.all($0.when, s, content) }?.text
            ?? choice.resultText
        let evidenceBefore = Set(s.evidence.keys)
        var notes: [String] = []
        for effect in choice.effects {
            apply(effect, to: &s, notes: &notes, deferred: false)
        }
        s.completedInstances.insert(instance.instanceID)
        if let itemID = instance.agendaItemID {
            s.activityLastDay[itemID] = s.day
            if let item = content.agenda.first(where: { $0.id == itemID }), item.once,
               choice.completesItem != false {
                s.usedAgendaItems.insert(itemID)
            }
        }
        let title = variantTitle(scene, instance.variantIndex)
        let text = ([resultText] + notes).filter { !$0.isEmpty }.joined(separator: " ")
        s.lastOutcome = Outcome(day: s.day, sceneTitle: title, text: text)
        if let memory = choice.memory {
            s.memories.append(Memory(day: s.day, text: memory))
        }
        events.append(.choiceApplied(text: text))
        let gained = Set(s.evidence.keys).subtracting(evidenceBefore)
        if !gained.isEmpty {
            events.append(.evidenceGained(gained.sorted().compactMap { s.evidence[$0]?.title }))
        }
        if let ending = s.ending {
            s.phase = .ended
            s.current = nil
            s.endingDay = s.day
            events.append(.gameEnded(ending))
        }
    }

    func variantTitle(_ scene: SceneDefinition, _ v: Int?) -> String {
        if let v, let t = scene.variants?[v].title { return t }
        return scene.title
    }

    // MARK: Akşam sonrası

    func afterEvening(_ s: inout RunState, events: inout [PresentationEvent]) {
        if s.pressure >= rules.pressureLoss {
            end(&s, .pressure, events: &events)
            return
        }
        if s.trust <= 0 {
            end(&s, .trust, events: &events)
            return
        }
        Social.maybeStartComplaint(&s, content: content)
    }

    func end(_ s: inout RunState, _ ending: Ending, events: inout [PresentationEvent]) {
        s.ending = ending
        s.endingDay = s.day
        s.phase = .ended
        s.current = nil
        s.slotQueue = []
        events.append(.gameEnded(ending))
    }

    // MARK: Gündem

    /// Bugün açılabilecek gündem işleri (sabah evresinde).
    public func availableAgenda(_ s: RunState) -> [AgendaItemDefinition] {
        guard s.phase == .agenda else { return [] }
        return content.agenda.filter { item in
            guard s.day >= item.fromDay, s.day <= item.toDay else { return false }
            if item.once && s.usedAgendaItems.contains(item.id) { return false }
            if let cd = item.cooldownDays, let last = s.activityLastDay[item.id], s.day - last < cd {
                return false
            }
            return Rulebook.all(item.requirements, s, content)
        }
    }
}
