import Foundation

// Görünüm katmanına giden güvenli sunum. Ham vaka dosyası (suçlu, iz açıklığı,
// yanıltıcı yer) buraya girmez; yalnız oyuncunun edindiği bilgiler ve izinli metinler.

public struct SpeakerPresentation: Sendable, Equatable {
    public var id: String
    public var name: String
    public var role: String
    public var portrait: String?
}

public struct ChoicePresentation: Sendable, Equatable, Identifiable {
    public var id: String
    public var label: String
    public var badges: [String]
    public var preview: [String]
    public var enabled: Bool
    public var disabledReason: String?
    public var confirm: String?
}

public struct ScenePresentation: Sendable, Equatable {
    public var sceneID: String
    public var instanceID: String?
    public var speaker: SpeakerPresentation
    public var title: String
    public var body: String
    public var illustration: String?
    public var choices: [ChoicePresentation]
    public var slotLabel: String
}

public struct AgendaEntry: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String
    public var category: AgendaItemDefinition.Category
    public var windowNote: String
    public var isNew: Bool
    public var closesToday: Bool
    public var scene: ScenePresentation
}

public struct AgendaPresentation: Sendable, Equatable {
    public var suggested: [AgendaEntry]
    public var all: [AgendaEntry]
    public var dueNote: String?
}

public struct LinePresentation: Sendable, Equatable, Identifiable {
    public var id: String
    public var label: String
    public var amount: String
    public var note: String?
}

public struct EveningPresentation: Sendable, Equatable {
    public var day: Int
    public var incomeLines: [LinePresentation]
    public var gross: String
    public var multiplierNote: String
    public var adjustedGross: String
    public var expenseLines: [LinePresentation]
    public var expenses: String
    public var pressureFee: String?
    public var net: String
    public var netValue: Kurus
    public var settled: Bool
}

public struct ChapterSummary: Sendable, Equatable {
    public var title: String
    public var lines: [String]
    public var changes: [String]
}

public struct RecapPresentation: Sendable, Equatable {
    public var day: Int
    public var memories: [String]
    public var evening: EveningPresentation?
    public var chapter: ChapterSummary?
    public var nextDayNote: String?
}

public struct EvidencePresentation: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var text: String
    public var kindLabel: String
    public var reliabilityLabel: String
    public var day: Int
}

public struct PersonPresentation: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var role: String
    public var portrait: String?
    public var notes: [String]
    public var eliminated: Bool?
}

public struct NotebookPresentation: Sendable, Equatable {
    public var goalLine: String
    public var commitmentLine: String
    public var questionLine: String
    public var incomes: [LinePresentation]
    public var expenses: [LinePresentation]
    public var today: EveningPresentation
    public var projection: String
    public var projectionNote: String
    public var commitments: [LinePresentation]
    public var people: [PersonPresentation]
    public var evidence: [EvidencePresentation]
    public var candidatesLine: String
    public var fileLine: String
    public var authorityLine: String
    public var firstGuessLine: String?
    public var history: [LinePresentation]
}

public struct VillageMarker: Sendable, Equatable, Identifiable {
    public var id: String
    public var label: String
    public var status: String
    public var symbol: String
    public var x: Double
    public var y: Double
    public var active: Bool
}

public struct EpiloguePresentation: Sendable, Equatable, Identifiable {
    public var id: String
    public var heading: String
    public var text: String
}

public struct EndingPresentation: Sendable, Equatable {
    public var ending: Ending
    public var title: String
    public var summary: String
    public var why: [String]
    public var decisive: [String]
    public var numbers: [LinePresentation]
    public var epilogue: [EpiloguePresentation]
    public var guessLine: String?
    public var shareText: String
}

public struct PlayPresentation: Sendable, Equatable {
    public var revision: Int
    public var day: Int
    public var finalDay: Int
    public var dayTitle: String
    public var chapterTitle: String
    public var phase: Phase
    public var cash: String
    public var cashValue: Kurus
    public var trust: Int
    public var pressure: Int
    public var trustNote: String
    public var pressureNote: String
    public var businessLabel: String
    public var lastOutcome: Outcome?
    public var scene: ScenePresentation?
    public var agenda: AgendaPresentation?
    public var evening: EveningPresentation?
    public var recap: RecapPresentation?
    public var guessPrompt: Bool
    public var gateAhead: Bool
    public var ending: EndingPresentation?
    public var notebook: NotebookPresentation
    public var village: [VillageMarker]
    public var canRewindDay: Bool
    public var canRewindChapter: Bool
    public var rewindCount: Int
}

extension Engine {
    public func present(_ env: SaveEnvelope) -> PlayPresentation {
        let s = env.state
        let c = content
        let day = c.dayDefinition(s.day)
        let chapter = c.chapter(for: s.day)
        var scene: ScenePresentation?
        if let cur = s.current, let def = c.scenes[cur.sceneID] {
            scene = presentScene(def, variant: cur.variantIndex, instanceID: cur.instanceID, s)
        }
        let agenda = s.phase == .agenda ? presentAgenda(s) : nil
        let eveningVisible = s.phase == .evening
        let ending = s.ending != nil ? presentEnding(env) : nil
        return PlayPresentation(
            revision: s.revision, day: s.day, finalDay: rules.finalDay,
            dayTitle: day?.title ?? "", chapterTitle: chapter?.title ?? "",
            phase: s.phase, cash: Money.format(s.cash), cashValue: s.cash,
            trust: s.trust, pressure: s.pressure,
            trustNote: trustNote(s), pressureNote: pressureNote(s),
            businessLabel: businessLabel(s),
            lastOutcome: s.lastOutcome,
            scene: scene, agenda: agenda,
            evening: eveningVisible ? presentEvening(s, day: s.day) : nil,
            recap: s.phase == .recap ? presentRecap(s) : nil,
            guessPrompt: s.phase == .recap && s.flags.contains("letterRead") && !env.metadata.firstGuessRecorded,
            gateAhead: s.phase == .recap && s.day >= rules.freeLastDay && s.day < rules.finalDay,
            ending: ending,
            notebook: presentNotebook(env),
            village: presentVillage(s),
            canRewindDay: env.dayCheckpoint != nil && s.ending == nil,
            canRewindChapter: env.chapterCheckpoint != nil,
            rewindCount: env.metadata.rewindCount)
    }

    // MARK: Sahne

    func speakerPresentation(_ id: String) -> SpeakerPresentation {
        let sp = content.speakers[id]
        return SpeakerPresentation(id: id, name: sp?.name ?? id, role: sp?.role ?? "", portrait: sp?.portrait)
    }

    public func presentScene(_ def: SceneDefinition, variant: Int?, instanceID: String?,
                             _ s: RunState) -> ScenePresentation {
        let v = variant.flatMap { i in def.variants.flatMap { i < $0.count ? $0[i] : nil } }
        let speakerID = v?.speakerID ?? def.speakerID
        let choices = resolvedChoices(def, variant: variant).compactMap { choice -> ChoicePresentation? in
            let (ok, reason) = availability(choice, s)
            if !ok && choice.hideWhenUnavailable == true { return nil }
            return ChoicePresentation(
                id: choice.id, label: Cases.fill(choice.label, s, content),
                badges: badges(for: choice, s),
                preview: (choice.preview ?? []).map { Cases.fill($0, s, content) } + dynamicPreview(choice, s),
                enabled: ok, disabledReason: reason,
                confirm: confirmText(choice, s))
        }
        let slotLabel: String
        switch def.slot {
        case .morning: slotLabel = "Sabah"
        case .anchor: slotLabel = "Gün içi"
        case .night: slotLabel = "Gece"
        case .agenda: slotLabel = "Gündem"
        }
        return ScenePresentation(
            sceneID: def.id, instanceID: instanceID, speaker: speakerPresentation(speakerID),
            title: Cases.fill(v?.title ?? def.title, s, content),
            body: Cases.fill(v?.body ?? def.body, s, content),
            illustration: v?.illustration ?? def.illustration,
            choices: choices, slotLabel: slotLabel)
    }

    func confirmText(_ choice: ChoiceDefinition, _ s: RunState) -> String? {
        if let accuse = choice.effects.first(where: { $0.kind == .accuse }),
           let who = SuspectID(rawValue: accuse.target ?? "") {
            // Onay metni kişiye göre değişmez; hangi kaydın kimi gösterdiğini oyuncu kendisi okur.
            let person = content.suspect(who)
            return "\(person.accusative) köyün önünde suçlamak üzeresin. Dosyanda: \(fileSummary(s)). Kurul kayıtları yan yana koyacak; dosya bu kişiyi taşımazsa güven −\(rules.wrongAccusationTrust). Emin misin?"
        }
        return choice.confirm.map { Cases.fill($0, s, content) }
    }

    func dynamicPreview(_ choice: ChoiceDefinition, _ s: RunState) -> [String] {
        var lines: [String] = []
        for e in choice.effects where Rulebook.all(e.when, s, content) {
            if e.kind == .accuse, !lines.contains(where: { $0.hasPrefix("Dosyanda") }) {
                lines.append("Dosyanda: \(fileSummary(s)).")
            }
            if e.kind == .interview, let who = SuspectID(rawValue: e.target ?? ""),
               !Rulebook.holds(Predicate(kind: .interviewAvailable, target: nil, amount: nil, value: who.rawValue), s, content) {
                lines.append("Son görüşmeden beri yeni kayıt yok.")
            }
        }
        return lines
    }

    /// Kişiden bağımsız dosya özeti: hangi tür doğrulanmış kayıt elde.
    func fileSummary(_ s: RunState) -> String {
        CaseSolver.ProofPart.allCases.map { part in
            let have = s.evidence.values.contains { $0.reliability == .verified && $0.kind == kind(of: part) }
            return "\(part.label) \(have ? "var" : "yok")"
        }.joined(separator: ", ")
    }

    /// Güven ve baskı rozetleri sayı değil yön gösterir: oyuncu hesap tablosu değil karar okur.
    func direction(_ name: String, _ a: Int64) -> String {
        let strong = abs(a) >= 6
        if a > 0 { return name + (strong ? " ▲▲" : " ▲") }
        return name + (strong ? " ▼▼" : " ▼")
    }

    func badges(for choice: ChoiceDefinition, _ s: RunState) -> [String] {
        var out: [String] = []
        let delayNote = s.mandate == .shared ? " (ortak kurul: yarın başlar)" : ""
        for e in choice.effects where Rulebook.all(e.when, s, content) {
            let a = e.amount ?? 0
            let later = (e.startsAfterDays ?? 0) > 0 ? " · \(s.day + (e.startsAfterDays ?? 0)). gün" : ""
            switch e.kind {
            case .cash where a != 0:
                out.append("Kasa \(Money.format(a, signed: true))\(later)")
            case .trust where a != 0:
                out.append(direction("Güven", a) + later)
            case .pressure where a != 0:
                out.append(direction("Baskı", a) + later)
            case .setIncome:
                var t = "Her akşam \(Money.format(a, signed: true)) brüt"
                if let end = e.expiresAfterDay { t += " (\(end). akşama kadar)" }
                if (e.startsAfterDays ?? 0) > 0 { t += " (\(s.day + (e.startsAfterDays ?? 0)). günden)" }
                if e.project == true { t += delayNote }
                out.append(t)
            case .setExpense:
                var t = "Günlük gider +\(Money.format(a))"
                if (e.startsAfterDays ?? 0) > 0 { t += " (\(s.day + (e.startsAfterDays ?? 0)). günden)" }
                if let end = e.expiresAfterDay { t += " (\(end). güne kadar)" }
                out.append(t)
            case .reduceExpense:
                out.append("Günlük gider −\(Money.format(a))" + (e.project == true ? delayNote : ""))
            case .removeExpenseAfterEvening:
                out.append("Bu akşamdan sonra gider kalkar")
            case .startBusiness:
                if let def = content.businesses[e.target ?? ""] {
                    let g = def.incomes.reduce(Kurus(0)) { $0 + $1.amount }
                    let x = def.expenses.reduce(Kurus(0)) { $0 + $1.amount }
                    var t = "Her akşam \(Money.format(g, signed: true)) brüt"
                    if x > 0 {
                        let start = def.expenses.compactMap(\.earliestDay).max() ?? s.day
                        t += ", günlük gider \(Money.format(x))" + (start > s.day ? " (\(start). günden)" : "")
                    }
                    if e.project == true { t += delayNote }
                    out.append(t)
                }
            case .closeBusiness:
                out.append("İşletmenin bütün geliri ve gideri kapanır")
            case .acceptCommitment:
                out.append("Taahhüt: \(e.expiresAfterDay ?? s.day). gün")
            case .setDayGrossPercent:
                out.append("\(Rulebook.list(e.value).map { "\($0)." }.joined(separator: ", ")) akşam brüt %\(a)")
            case .endGame:
                out.append("Hikâye burada biter")
            case .setMandate:
                if s.mandate?.rawValue != e.value, a != 0, !s.flags.contains("mandateTrust.\(e.value ?? "")") {
                    out.append(direction("Güven", a))
                }
            default:
                break
            }
        }
        return out
    }

    // MARK: Gündem

    func presentAgenda(_ s: RunState) -> AgendaPresentation {
        let items = availableAgenda(s)
        let entries: [AgendaEntry] = items.compactMap { item in
            guard let def = content.scenes[item.sceneID] else { return nil }
            var p = presentScene(def, variant: variantIndex(def, s), instanceID: nil, s)
            p.slotLabel = "Gündem"
            let window: String
            if item.toDay >= rules.finalDay - 1 || item.cooldownDays != nil {
                window = item.cooldownDays.map { "Tekrar için \($0) gün ara" } ?? "Açık"
            } else if item.toDay == s.day {
                window = "Bugün son gün"
            } else {
                window = "\(item.toDay). güne kadar"
            }
            return AgendaEntry(id: item.id, title: Cases.fill(item.title, s, content),
                               summary: Cases.fill(item.summary, s, content),
                               category: item.category, windowNote: window,
                               isNew: item.fromDay == s.day, closesToday: item.toDay == s.day,
                               scene: p)
        }
        // Öneri sırası: bugün açılan, bugün kapanan, öncelik.
        let ranked = entries.enumerated().sorted { l, r in
            func score(_ e: AgendaEntry, _ i: Int) -> Int {
                let pr = items.first { $0.id == e.id }?.priority ?? 0
                return pr + (e.isNew ? 40 : 0) + (e.closesToday ? 30 : 0) - (e.category == .rest ? 1000 : 0)
            }
            let a = score(l.element, l.offset), b = score(r.element, r.offset)
            return a != b ? a > b : l.offset < r.offset
        }.map(\.element)
        return AgendaPresentation(suggested: Array(ranked.prefix(3)), all: entries,
                                  dueNote: content.dayDefinition(s.day)?.dueNote)
    }

    // MARK: Akşam

    public func presentEvening(_ s: RunState, day: Int) -> EveningPresentation {
        let ev = Economy.forecast(s, rules: rules, day: day)
        let settledRecord = s.evenings.last { $0.day == day }
        let pct: String
        switch ev.basisPoints {
        case rules.lowBasisPoints: pct = "Güven \(rules.lowTrust) altında: köy çekingen, brütün %\(ev.basisPoints / 100)'i"
        case rules.highBasisPoints: pct = "Güven \(rules.highTrust) ve üstü: köy sana koşuyor, brütün %\(ev.basisPoints / 100)'i"
        default: pct = "Güven \(rules.lowTrust)–\(rules.highTrust - 1): brütün tamamı"
        }
        let dayNote = ev.dayPercent != 100 ? " · bugün yalnız %\(ev.dayPercent)" : ""
        return EveningPresentation(
            day: day,
            incomeLines: ev.incomeLines.map { LinePresentation(id: $0.id, label: $0.label, amount: Money.format($0.amount, signed: true), note: nil) },
            gross: Money.format(ev.gross),
            multiplierNote: pct + dayNote,
            adjustedGross: Money.format(ev.adjustedGross),
            expenseLines: ev.expenseLines.map { LinePresentation(id: $0.id, label: $0.label, amount: Money.format(-$0.amount), note: nil) },
            expenses: Money.format(-ev.expenses),
            pressureFee: ev.pressureFee > 0 ? Money.format(-ev.pressureFee) : nil,
            net: Money.format(settledRecord?.net ?? ev.net, signed: true),
            netValue: settledRecord?.net ?? ev.net,
            settled: s.settledDays.contains(day))
    }

    // MARK: Gün sonu

    func presentRecap(_ s: RunState) -> RecapPresentation {
        let mem = s.memories.filter { $0.day == s.day }.map { Cases.fill($0.text, s, content) }
        var summary: ChapterSummary?
        if let ch = content.chapter(for: s.day), ch.lastDay == s.day {
            summary = chapterSummary(s, ch)
        }
        // Takvim notları o günün sonunda okunacak biçimde yazılır ("Yarın: …").
        return RecapPresentation(day: s.day, memories: mem,
                                 evening: s.settledDays.contains(s.day) ? presentEvening(s, day: s.day) : nil,
                                 chapter: summary, nextDayNote: content.dayDefinition(s.day)?.promise)
    }

    func commitmentCash(_ s: RunState) -> Kurus {
        // Açık taahhütlerin bilinen tahsilatı (Defter'de ayrıca yazılır).
        s.commitments.values.filter(\.isOpen).reduce(Kurus(0)) { $0 + $1.expectedCash }
    }

    func chapterSummary(_ s: RunState, _ ch: ChapterDefinition) -> ChapterSummary {
        let today = Economy.forecast(s, rules: rules, day: s.day + 1)
        var lines: [String] = []
        lines.append("Kasa: \(Money.format(s.cash)) · Güven \(s.trust) · Baskı \(s.pressure)")
        lines.append("Yarınki koşullarla akşam: brüt \(Money.format(today.gross)), gider \(Money.format(today.expenses)), net \(Money.format(today.net, signed: true))")
        let gap = rules.firstInstallment - s.cash
        lines.append(gap > 0 ? "İlk taksite \(Money.format(gap)) eksik, \(rules.finalDay - s.day) akşam var."
                             : "Kasa ilk taksiti bugünden karşılıyor; güven ve yetki koşulları ayrıca gerekli.")
        let proj = Economy.projection(s, rules: rules, commitmentCash: commitmentCash(s))
        lines.append("Bugünkü koşullar değişmezse 30. gün ödeme öncesi kasa: \(Money.format(proj))")
        for cm in s.commitments.values.sorted(by: { $0.dueDay < $1.dueDay }) where cm.isOpen {
            lines.append("Bekleyen: \(cm.label), \(cm.dueDay). gün")
        }
        if s.day == 14, let dues = s.incomes["dues"], dues.endsAfter == 14 {
            lines.append("Aidat katkısı bu akşam son kez yattı (\(Money.format(dues.amount)) brüt).")
        }
        if s.day >= 21 {
            if s.flags.contains("caseResolved") {
                lines.append("Satış yetkisi dosyası kapandı; yetki iptal edildi.")
            } else {
                let parts = CaseSolver.ProofPart.allCases.map { part -> String in
                    let have = s.evidence.values.contains {
                        $0.reliability == .verified && kind(of: part) == $0.kind
                    }
                    return "\(part.label) \(have ? "var" : "yok")"
                }
                lines.append("Dosya: " + parts.joined(separator: " · ") + ". 24. gün son kamuya açık görüşme.")
            }
            lines.append(Final.authoritySafe(s) ? "Yetki güvencesi: sağlandı."
                         : "Yetki güvencesi: yok. Mühür kaybını bildirmek ya da yetkiyi iptal ettirmek gerekiyor.")
        }
        if s.day == 27 {
            let st = Final.status(s, content)
            lines.append("30. gün koşulları: kasa \(st.cashEnough ? "yetiyor" : "yetmiyor") · güven \(st.trustEnough ? "yeterli" : "\(rules.requiredTrust) altında") · baskı \(st.pressureOK ? "sınırda değil" : "sınırda") · yetki \(st.authoritySafe ? "güvende" : "güvende değil")")
            lines.append("Son üç günde yeni zorunlu felaket yok. 29. gün son çalışma kararı, 30. gün son gelir ve ödeme.")
        }
        let chapterMemories = s.memories.filter { $0.day >= ch.firstDay && $0.day <= ch.lastDay }
            .map { Cases.fill($0.text, s, content) }
        return ChapterSummary(title: "\(ch.title) bitti", lines: lines, changes: Array(chapterMemories.suffix(5)))
    }

    func kind(of part: CaseSolver.ProofPart) -> EvidenceKind {
        switch part {
        case .signature: .signature
        case .timeline: .timeline
        case .custody: .custody
        }
    }

    // MARK: Defter

    func presentNotebook(_ env: SaveEnvelope) -> NotebookPresentation {
        let s = env.state
        let evenings = rules.finalDay - s.day + (s.settledDays.contains(s.day) ? 0 : 1)
        let gap = rules.firstInstallment - s.cash
        let goal: String
        if s.paymentMade {
            goal = "İlk taksit ödendi."
        } else if gap > 0 {
            goal = "İlk taksite \(Money.format(gap)) eksik · \(max(0, evenings)) akşam kaldı"
        } else {
            goal = "Kasa ilk taksiti karşılıyor · kurul desteği (güven \(rules.requiredTrust)+) ve yetki güvencesi de gerekli"
        }
        let open = s.commitments.values.filter(\.isOpen).sorted { $0.dueDay < $1.dueDay }
        let commitmentLine: String
        if let first = open.first {
            commitmentLine = "\(first.dueDay). gün: \(first.label)"
        } else if let next = content.calendar.days.first(where: { $0.day > s.day && $0.dueNote != nil }) {
            commitmentLine = "\(next.day). gün: \(next.dueNote ?? "")"
        } else {
            commitmentLine = "\(rules.finalDay). gün: 150.000 TL ilk taksit"
        }
        let evidenceList = Array(s.evidence.values)
        let question: String
        if s.flags.contains("caseResolved") {
            question = "Satış yetkisi dosyası kapandı."
        } else if !s.flags.contains("met.letter") && s.day < rules.freeLastDay {
            question = "Defterden koparılan sayfada ne yazıyordu?"
        } else {
            question = content.cases.question
        }
        // Eleme oyuncunun işi: defter kesişimi hesaplamaz, yalnız oyuncunun kendi notlarını sayar.
        let cleared = env.metadata.eliminated.count
        let candidatesLine = cleared == 0
            ? "Kayıtları yan yana koy; kimi şüpheden çıkardığını İnsanlar sayfasında işaretle."
            : "Kendi notun: \(cleared) kişiyi şüpheden çıkardın."

        let parts = CaseSolver.ProofPart.allCases.map { part -> String in
            let have = evidenceList.contains { $0.reliability == .verified && $0.kind == kind(of: part) }
            return (have ? "✓ " : "· ") + part.label
        }
        let fileLine = "Kurula götürülecek dosya: " + parts.joined(separator: "  ")
        let authority: String
        if Final.authoritySafe(s) {
            authority = s.flags.contains("authorityRevoked") ? "Satış yetkisi iptal edildi." : "Mühür kaybı bildirildi; eski mühürle imza geçmez."
        } else if s.flags.contains("letterRead") {
            authority = "İmzalı bir satış yetkisi dolaşıyor olabilir ve mühür kayıp. Kaybı bildirmek gündemde."
        } else {
            authority = "Koparılan sayfanın sırrı henüz çözülmedi."
        }

        let today = presentEvening(s, day: s.day)
        let proj = Economy.projection(s, rules: rules, commitmentCash: commitmentCash(s))
        let projectionNote = "Güven \(s.trust) ve baskı \(s.pressure) aynı kalırsa; bilinen bitişler, başlayacak giderler ve bekleyen tahsilatlar dahil. Yeni kararların bunu değiştirir."

        let incomes = s.incomes.values.sorted { $0.id < $1.id }.map { line in
            LinePresentation(id: line.id, label: line.label, amount: Money.format(line.amount, signed: true),
                             note: lineNote(line, s))
        }
        let expenses = s.expenses.values.sorted { $0.id < $1.id }.map { line in
            LinePresentation(id: line.id, label: line.label, amount: Money.format(-line.amount),
                             note: lineNote(line, s) ?? (s.pendingExpenseRemoval.contains(line.id) ? "bu akşamdan sonra kalkar" : nil))
        }
        let commitments = s.commitments.values.sorted { $0.dueDay < $1.dueDay }.map { cm in
            LinePresentation(id: cm.id, label: cm.label, amount: "\(cm.dueDay). gün", note: statusLabel(cm.status))
        }

        var people: [PersonPresentation] = []
        for sp in content.speakers.values.sorted(by: { $0.name < $1.name })
        where sp.person != false && s.flags.contains("met.\(sp.id)") {
            let notes = (sp.notes ?? []).filter { Rulebook.all($0.when, s, content) }
                .map { Cases.fill($0.text, s, content) }
            let suspect = SuspectID(rawValue: sp.id)
            people.append(PersonPresentation(id: sp.id, name: sp.name, role: sp.role, portrait: sp.portrait,
                                             notes: notes, eliminated: suspect.map { env.metadata.eliminated.contains($0) }))
        }

        let evidence = s.evidence.values.sorted { ($0.acquiredDay, $0.id) < ($1.acquiredDay, $1.id) }.map { e in
            EvidencePresentation(id: e.id, title: e.title, text: e.text, kindLabel: kindLabel(e.kind),
                                 reliabilityLabel: reliabilityLabel(e.reliability), day: e.acquiredDay)
        }
        var history: [LinePresentation] = []
        for (i, m) in s.memories.enumerated().reversed() {
            history.append(LinePresentation(id: "m\(i)", label: Cases.fill(m.text, s, content), amount: "\(m.day). gün", note: nil))
        }
        var guessLine: String?
        if env.metadata.firstGuessRecorded {
            guessLine = "İlk tahminin: " + (env.metadata.firstGuess.map { content.suspect($0).name } ?? "bilmiyorum")
                + " (yalnız not; dünyayı değiştirmez)"
        }
        return NotebookPresentation(
            goalLine: goal, commitmentLine: commitmentLine, questionLine: question,
            incomes: incomes, expenses: expenses, today: today,
            projection: Money.format(proj), projectionNote: projectionNote,
            commitments: commitments, people: people, evidence: evidence,
            candidatesLine: candidatesLine, fileLine: fileLine, authorityLine: authority,
            firstGuessLine: guessLine, history: history)
    }

    func lineNote(_ line: CashLine, _ s: RunState) -> String? {
        var parts: [String] = []
        if line.startsOn > s.day { parts.append("\(line.startsOn). günden") }
        if let end = line.endsAfter { parts.append("\(end). akşama kadar") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    func statusLabel(_ st: Commitment.Status) -> String {
        switch st {
        case .accepted: "açık"
        case .fulfilled: "teslim edildi"
        case .partnered: "üreticiyle tamamlandı"
        case .cancelled: "iptal edildi"
        }
    }

    public func kindLabel(_ k: EvidenceKind) -> String {
        switch k {
        case .trace: "İz"
        case .document: "Belge"
        case .signature: "İmza"
        case .timeline: "Tarih"
        case .custody: "Teslim zinciri"
        case .testimony: "İfade"
        case .location: "Yer"
        }
    }

    public func reliabilityLabel(_ r: Reliability) -> String {
        switch r {
        case .claimed: "İddia"
        case .observed: "Gözlem"
        case .corroborated: "Destekli"
        case .verified: "Doğrulanmış"
        }
    }

    func trustNote(_ s: RunState) -> String {
        if s.trust < rules.lowTrust { return "Brüt gelirin %\(rules.lowBasisPoints / 100)'i" }
        if s.trust >= rules.highTrust { return "Brüt gelirin %\(rules.highBasisPoints / 100)'i" }
        return "Brüt gelirin tamamı"
    }

    func pressureNote(_ s: RunState) -> String {
        let fee = Economy.pressureFee(pressure: s.pressure, rules: rules)
        if fee > 0 { return "Alacaklı her akşam \(Money.format(fee)) kesiyor · \(rules.pressureLoss)'de borcu bir anda ister" }
        return "Alacaklının sabrı · \(rules.pressureStart)'te kesinti başlar"
    }

    func businessLabel(_ s: RunState) -> String {
        switch s.business {
        case .none: return "İşletme seçilmedi"
        case .spa: return "Kaplıca açık"
        case .bees: return s.flags.contains("business.beesNetwork") ? "Arı üretici ağı" : "Arı evi"
        case .closed: return "Kaplıca kapalı"
        }
    }

    // MARK: Kasaba

    func presentVillage(_ s: RunState) -> [VillageMarker] {
        var m: [VillageMarker] = []
        let bridge: String
        if s.flags.contains("bridgeRepaired") || s.flags.contains("bridgeFixed") {
            bridge = "Onarıldı; kamyon geçiyor"
        } else if s.expenses["bridge.transport"] != nil {
            bridge = "Çürük; mallar kamyonetle taşınıyor (günlük fark)"
        } else {
            bridge = "Demirleri çürük; kamyon geçemiyor"
        }
        m.append(VillageMarker(id: "bridge", label: "Köprü", status: bridge, symbol: "point.topleft.down.to.point.bottomright.curvepath",
                               x: 0.505, y: 0.79, active: s.flags.contains("bridgeFixed") || s.flags.contains("bridgeRepaired")))
        let spa: String
        switch s.business {
        case .spa:
            var extras: [String] = []
            if s.flags.contains("spaInsulated") { extras.append("yalıtımlı") }
            if s.incomes["spa.extra"] != nil { extras.append("ek seans") }
            if s.incomes["spa.group"] != nil { extras.append("grup paketi") }
            spa = "Açık" + (extras.isEmpty ? "" : " · " + extras.joined(separator: ", "))
        case .closed: spa = "Kazan satıldı; kapalı"
        default: spa = s.flags.contains("met.halil") ? "Kapalı; anahtar Halil'de" : "Kapalı"
        }
        m.append(VillageMarker(id: "spa", label: "Kaplıca", status: spa, symbol: "drop",
                               x: 0.80, y: 0.36, active: s.business == .spa))
        let bees: String
        if s.business == .bees {
            var extras: [String] = []
            if s.incomes["bees.buyer"] != nil { extras.append("Nermin düzenli alıyor") }
            if s.incomes["bees.packaging"] != nil { extras.append("paketleme") }
            if s.incomes["bees.brand"] != nil { extras.append("etiketli ürün") }
            bees = (s.flags.contains("business.beesNetwork") ? "Üretici ağı" : "Kovanlar dolu")
                + (extras.isEmpty ? "" : " · " + extras.joined(separator: ", "))
        } else {
            bees = "Boş kovanlar"
        }
        m.append(VillageMarker(id: "bees", label: "Arı evi", status: bees, symbol: "hexagon",
                               x: 0.17, y: 0.30, active: s.business == .bees))
        let stall: String
        if s.incomes["market.stall"] != nil { stall = "Ortak tezgâh kuruldu" }
        else if s.flags.contains("stallSupport") { stall = "Küçük ortak destek" }
        else { stall = "Meydan, çınar ve iki bank" }
        m.append(VillageMarker(id: "square", label: "Meydan", status: stall, symbol: "tree",
                               x: 0.50, y: 0.53, active: s.incomes["market.stall"] != nil))
        let office = Final.authoritySafe(s) ? "Yetki güvende" : "Defterden bir sayfa eksik"
        m.append(VillageMarker(id: "office", label: "Kooperatif", status: office, symbol: "building.columns",
                               x: 0.48, y: 0.42, active: Final.authoritySafe(s)))
        let nine = s.flags.contains("nineHelped") ? "Bacası tütüyor" : (s.flags.contains("met.nine") ? "Kışa kendi hazırlanıyor" : "Köyün en yaşlısı")
        m.append(VillageMarker(id: "nine", label: "Hatice Nine'nin evi", status: nine, symbol: "house",
                               x: 0.15, y: 0.55, active: s.flags.contains("nineHelped")))
        return m
    }

    // MARK: Son

    func presentEnding(_ env: SaveEnvelope) -> EndingPresentation? {
        let s = env.state
        guard let ending = s.ending, let def = content.endings[ending] else { return nil }
        let why = def.why.filter { Rulebook.all($0.when, s, content) }.map { Cases.fill($0.text, s, content) }
        let decisive = def.decisive.filter { Rulebook.all($0.when, s, content) }.map { Cases.fill($0.text, s, content) }
        var numbers: [LinePresentation] = []
        if let before = s.finalCashBeforePayment {
            numbers.append(LinePresentation(id: "before", label: "Ödeme öncesi kasa", amount: Money.format(before), note: nil))
        }
        if s.paymentMade {
            numbers.append(LinePresentation(id: "paid", label: "İlk taksit", amount: Money.format(-rules.firstInstallment), note: nil))
        }
        numbers.append(LinePresentation(id: "cash", label: "Kalan kasa", amount: Money.format(s.cash), note: nil))
        numbers.append(LinePresentation(id: "trust", label: "Güven", amount: "\(s.trust)", note: nil))
        numbers.append(LinePresentation(id: "pressure", label: "Baskı", amount: "\(s.pressure)", note: nil))
        numbers.append(LinePresentation(id: "day", label: "Biten gün", amount: "\(s.endingDay ?? s.day)", note: nil))
        let epilogue = content.epilogue.compactMap { sec -> EpiloguePresentation? in
            guard let entry = sec.entries.first(where: { Rulebook.all($0.when, s, content) }) else { return nil }
            return EpiloguePresentation(id: sec.id, heading: sec.heading, text: Cases.fill(entry.text, s, content))
        }
        var guess: String?
        if env.metadata.firstGuessRecorded, s.flags.contains("truthRevealed") || s.flags.contains("caseResolved") {
            let g = env.metadata.firstGuess.map { content.suspect($0).name } ?? "bilmiyorum"
            guess = "7. gece ilk tahminin: \(g). İmzayı atan: \(content.suspect(s.caseID).name)."
        }
        let share = "Karaçam: \(def.title). \(s.endingDay ?? s.day). gün, güven \(s.trust)."
        return EndingPresentation(ending: ending, title: def.title, summary: Cases.fill(def.summary, s, content),
                                  why: why, decisive: decisive, numbers: numbers, epilogue: epilogue,
                                  guessLine: guess, shareText: share)
    }
}
