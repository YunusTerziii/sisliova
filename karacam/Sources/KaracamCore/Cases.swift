import Foundation

/// Vaka dosyası işlemleri. Ham vaka bilgisi görünüm katmanına aktarılmaz;
/// yalnız oyuncunun edindiği kanıtlar `RunState.evidence` içinde durur.
enum Cases {
    static func fill(_ text: String, _ s: RunState, _ c: GameContent) -> String {
        let culprit = c.suspect(s.caseID)
        let decoy = c.suspect(s.decoySuspect)
        let pair = [culprit, decoy].sorted { $0.location < $1.location }
        // İki kişilik kayıtlarda adlar alfabetik; sıra suçluyu ele vermez.
        let third = SuspectID.allCases.first { $0 != s.caseID && $0 != s.decoySuspect } ?? s.decoySuspect
        let sig = [culprit, decoy].map(\.name).sorted()
        let tl = [culprit, c.suspect(third)].map(\.name).sorted()
        var out = text
        if out.contains("{missingParts}") {
            let missing = missingParts(s.caseID, s).map(\.label)
            out = out.replacingOccurrences(of: "{missingParts}",
                                           with: missing.isEmpty ? "eksik parça yok" : missing.joined(separator: ", "))
        }
        if out.contains("{finalChecklist}") {
            out = out.replacingOccurrences(of: "{finalChecklist}", with: finalChecklist(s, c))
        }
        if out.contains("{finalCashBefore}") {
            out = out.replacingOccurrences(of: "{finalCashBefore}", with: Money.format(s.finalCashBeforePayment ?? s.cash))
        }
        if let truth = c.cases.truths[s.caseID.rawValue] {
            out = out
                .replacingOccurrences(of: "{truthReveal}", with: truth.reveal)
                .replacingOccurrences(of: "{truthConfession}", with: truth.confession)
                .replacingOccurrences(of: "{truthAccounting}", with: truth.accounting)
                .replacingOccurrences(of: "{truthMotive}", with: truth.motive)
        }
        return out
            .replacingOccurrences(of: "{cash}", with: Money.format(s.cash))
            .replacingOccurrences(of: "{trust}", with: String(s.trust))
            .replacingOccurrences(of: "{complaint}", with: s.complaint?.grievance.lowercasedFirst ?? "bir aksama")
            .replacingOccurrences(of: "{pressure}", with: String(s.pressure))
            .replacingOccurrences(of: "{culprit}", with: culprit.name)
            .replacingOccurrences(of: "{culpritAcc}", with: culprit.accusative)
            .replacingOccurrences(of: "{culpritLocation}", with: culprit.location)
            .replacingOccurrences(of: "{culpritLocationText}", with: culprit.locationText)
            .replacingOccurrences(of: "{decoy}", with: decoy.name)
            .replacingOccurrences(of: "{decoyLocation}", with: decoy.location)
            .replacingOccurrences(of: "{sigA}", with: sig[0])
            .replacingOccurrences(of: "{sigB}", with: sig[1])
            .replacingOccurrences(of: "{tlA}", with: tl[0])
            .replacingOccurrences(of: "{tlB}", with: tl[1])
            .replacingOccurrences(of: "{placeA}", with: pair[0].location)
            .replacingOccurrences(of: "{placeB}", with: pair[1].location)
    }

    /// 29. ve 30. gün anlaşma kontrolü: görünür koşullar, gizli kalem yok.
    static func finalChecklist(_ s: RunState, _ c: GameContent) -> String {
        let r = c.rules
        var lines: [String] = []
        lines.append("Kasa şimdi \(Money.format(s.cash)).")
        if !s.settledDays.contains(r.finalDay) {
            var cash = s.cash
            let first = s.settledDays.contains(s.day) ? s.day + 1 : s.day
            if first <= r.finalDay {
                for d in first...r.finalDay { cash += Economy.forecast(s, rules: r, day: d).net }
            }
            lines.append("Bugünkü koşullarla 30. akşamdan sonra beklenen kasa: \(Money.format(cash)).")
        }
        let st = Final.status(s, c)
        lines.append("İlk taksit: 150.000 TL · Güven \(s.trust) (gereken \(r.requiredTrust)) · Baskı \(s.pressure) (\(r.pressureLoss) olursa alacaklı beklemez).")
        lines.append(st.authoritySafe ? "Satış yetkisi güvence altında." : "Satış yetkisi güvence altında değil: kayıp bildirimi ya da iptal gerekiyor.")
        return lines.joined(separator: "\n")
    }

    static func add(_ ev: Evidence, to s: inout RunState) {
        if let old = s.evidence[ev.id] {
            // Aynı kanıt yeniden verilmez; yalnız güvenilirliği yükselebilir.
            if ev.reliability > old.reliability { s.evidence[ev.id] = ev }
            return
        }
        s.evidence[ev.id] = ev
    }

    static func grant(_ id: String, to s: inout RunState, content c: GameContent) {
        if let trace = c.cases.traces.first(where: { $0.id == id }) {
            let clear = s.clarity[trace.clarityKey] == true
            let withTrait = Set(c.cases.suspects.filter { $0.traits.contains(trace.trait) }.map(\.id))
            let culpritHas = withTrait.contains(s.caseID)
            let suspects: Set<SuspectID>
            let text: String
            if !clear {
                suspects = Set(SuspectID.allCases)
                text = trace.unclear
            } else if culpritHas {
                suspects = withTrait
                text = trace.clearWithTrait
            } else {
                suspects = Set(SuspectID.allCases).subtracting(withTrait)
                text = trace.clearWithoutTrait
            }
            add(Evidence(id: trace.id, title: trace.title, text: fill(text, s, c), kind: .trace,
                         reliability: .observed, sourceID: trace.sourceID,
                         possibleSuspects: suspects, acquiredDay: s.day), to: &s)
            return
        }
        guard let t = c.cases.evidence.first(where: { $0.id == id }) else { return }
        let all = Set(SuspectID.allCases)
        let suspects: Set<SuspectID>
        switch t.suspects {
        case .all: suspects = all
        case .culprit: suspects = [s.caseID]
        case .others: suspects = all.subtracting([t.subject ?? s.caseID])
        case .pair: suspects = [s.caseID, s.decoySuspect]
        case .notCulprit: suspects = all.subtracting([s.caseID])
        case .notDecoy: suspects = all.subtracting([s.decoySuspect])
        }
        let raw = t.textByCase?[s.caseID.rawValue] ?? t.text
        add(Evidence(id: t.id, title: t.title, text: fill(raw, s, c), kind: t.kind,
                     reliability: t.reliability, sourceID: t.sourceID,
                     possibleSuspects: suspects, acquiredDay: s.day), to: &s)
    }

    static func has(_ s: RunState, _ ids: [String]) -> Bool {
        ids.contains { s.evidence[$0] != nil }
    }

    static func interview(_ who: SuspectID, state s: inout RunState, content c: GameContent,
                          notes: inout [String]) {
        guard let texts = c.cases.interviews[who.rawValue] else { return }
        let all = Set(SuspectID.allCases)
        let person = c.suspect(who)
        s.counters["interviews", default: 0] += 1
        if who == s.caseID {
            add(Evidence(id: "claim.\(who.rawValue)", title: "\(person.name): kendi anlatımı",
                         text: fill(texts.asCulprit.claim, s, c), kind: .testimony, reliability: .claimed,
                         sourceID: "interview.\(who.rawValue)", possibleSuspects: all.subtracting([who]),
                         acquiredDay: s.day), to: &s)
            let targeted = has(s, ["signature", "timeline", "timeline.witness", "location.narrow"])
                || CaseSolver.candidates(Array(s.evidence.values)) == [who]
            if targeted && s.evidence["location"] == nil {
                notes.append(fill(texts.asCulprit.followUp, s, c))
                grant("location", to: &s, content: c)
            } else if targeted {
                notes.append("\(person.name) aynı cevabı tekrarladı; yeni bir şey söylemedi.")
            } else {
                notes.append("Elinde \(person.accusative) bağlayan bir kayıt olmadan konuşma kısa kesildi.")
            }
        } else {
            add(Evidence(id: "claim.\(who.rawValue)", title: "\(person.name): kendi anlatımı",
                         text: fill(texts.asInnocent.claim, s, c), kind: .testimony, reliability: .claimed,
                         sourceID: "interview.\(who.rawValue)", possibleSuspects: all.subtracting([who]),
                         acquiredDay: s.day), to: &s)
            if has(s, ["timeline", "timeline.witness"]) {
                notes.append(fill(texts.asInnocent.followUp, s, c))
                add(Evidence(id: "alibi.\(who.rawValue)", title: "\(person.name): tarihle örtüşen hesap",
                             text: fill(texts.asInnocent.followUp, s, c), kind: .testimony,
                             reliability: .corroborated, sourceID: "alibi.\(who.rawValue)",
                             possibleSuspects: all.subtracting([who]), acquiredDay: s.day), to: &s)
            } else {
                notes.append("Söyledikleri bir tarih kaydıyla karşılaştırılmadan doğrulanamaz.")
            }
        }
        s.interviewMarks[who.rawValue] = s.evidence.count
    }

    static func missingParts(_ who: SuspectID, _ s: RunState) -> [CaseSolver.ProofPart] {
        let have = CaseSolver.proofParts(for: who, with: Array(s.evidence.values))
        return CaseSolver.ProofPart.allCases.filter { !have.contains($0) }
    }

    static func accuse(_ who: SuspectID, state s: inout RunState, content c: GameContent,
                       notes: inout [String]) {
        let person = c.suspect(who)
        if CaseSolver.canProve(who, with: Array(s.evidence.values)) {
            s.accusations.append(Accusation(subject: who, day: s.day, proven: true, correct: true, corrected: false))
            s.flags.insert("caseResolved")
            s.flags.insert("authorityRevoked")
            s.flags.insert("culpritExposed")
            s.counters["caseResolvedDay"] = s.day
            s.pressure = max(0, s.pressure - 5)
            notes.append("Kurul üç ayrı kaydı yan yana koydu. \(person.name) satış yetkisinden çekildi; yetki iptal edildi.")
        } else {
            // Kanıtsız itham, kişi doğru da olsa yanlış da olsa aynı görünür ve aynı bedeli öder;
            // tepki üzerinden deneme-yanılma ile suçlu bulunamaz.
            let correct = who == s.caseID
            s.accusations.append(Accusation(subject: who, day: s.day, proven: false, correct: correct, corrected: false))
            s.flags.insert(correct ? "accusedEarly" : "wrongAccusation")
            s.flags.insert("unprovenAccusation")
            s.trust = max(0, s.trust - c.rules.wrongAccusationTrust)
            s.pressure = min(100, s.pressure + 3)
            notes.append("Köyün önünde \(person.accusative) suçladın. \(person.name) inkâr etti; kurul dosyayı yetersiz buldu.")
        }
    }

    static func correct(state s: inout RunState, content c: GameContent, notes: inout [String]) {
        guard let i = s.accusations.firstIndex(where: { !$0.proven && !$0.corrected }) else { return }
        s.accusations[i].corrected = true
        let person = c.suspect(s.accusations[i].subject)
        // Açık özür bir kez puan verir; yaşananı olmamış yapmaz.
        if s.flags.insert("correctionRewarded.\(person.id.rawValue)").inserted {
            s.trust = min(100, s.trust + c.rules.correctionTrust)
        }
        notes.append("\(person.accusative) kanıtsız suçladığını açıkça geri aldın.")
    }

    static func recoverSeal(witnessed: Bool, state s: inout RunState, content c: GameContent) {
        s.flags.insert("sealRecovered")
        if s.evidence["location"] == nil {
            grant("location", to: &s, content: c)
        }
        if witnessed {
            s.flags.insert("custodyVerified")
            s.flags.remove("sealSilent")
            grant("custody", to: &s, content: c)
        } else if !s.flags.contains("custodyVerified") {
            s.flags.insert("sealSilent")
        }
    }
}

extension String {
    var lowercasedFirst: String {
        guard let first else { return self }
        return String(first).lowercased(with: Locale(identifier: "tr_TR")) + dropFirst()
    }
}
