import Foundation

/// Etki yorumlayıcısı. Her `EffectKind` için açık bir karşılık vardır.
extension Engine {
    static let lineKinds: Set<EffectKind> = [.setIncome, .setExpense, .startBusiness]

    func apply(_ e: Effect, to s: inout RunState, notes: inout [String], deferred: Bool) {
        guard Rulebook.all(e.when, s, content) else { return }
        var delay = deferred ? 0 : (e.startsAfterDays ?? 0)
        if e.project == true, s.mandate == .shared, !deferred { delay += 1 }
        if delay > 0 && !Engine.lineKinds.contains(e.kind) {
            var later = e
            later.startsAfterDays = nil
            later.project = nil
            later.when = nil
            s.scheduled.append(ScheduledEffect(day: s.day + delay, effect: later, note: e.label))
            return
        }
        let amount = e.amount ?? 0
        let target = e.target ?? ""

        switch e.kind {
        case .cash:
            s.cash += amount
        case .trust:
            s.trust = min(100, max(0, s.trust + Int(amount)))
        case .pressure:
            s.pressure = min(100, max(0, s.pressure + Int(amount)))
        case .setFlag:
            s.flags.insert(target)
        case .clearFlag:
            s.flags.remove(target)
        case .incrementCounter:
            s.counters[target, default: 0] += Int(amount == 0 ? 1 : amount)

        case .setIncome:
            // Aynı kimlikli kaynak üstüne eklenmez, yerine konur.
            s.incomes[target] = CashLine(id: target, label: e.label ?? target, amount: amount,
                                         startsOn: s.day + delay, endsAfter: e.expiresAfterDay,
                                         business: e.business)
        case .removeIncome:
            s.incomes.removeValue(forKey: target)
        case .setExpense:
            s.expenses[target] = CashLine(id: target, label: e.label ?? target, amount: max(0, amount),
                                          startsOn: s.day + delay, endsAfter: e.expiresAfterDay,
                                          business: e.business)
        case .reduceExpense:
            // Gider negatife düşmez.
            if var line = s.expenses[target] {
                line.amount = max(0, line.amount - amount)
                s.expenses[target] = line
            }
        case .removeExpenseAfterEvening:
            if s.settledDays.contains(s.day) {
                s.expenses.removeValue(forKey: target)
            } else if s.expenses[target] != nil {
                s.pendingExpenseRemoval.insert(target)
            }

        case .startBusiness:
            guard let def = content.businesses[target] else { return }
            for line in def.incomes {
                s.incomes[line.id] = CashLine(id: line.id, label: line.label, amount: line.amount,
                                              startsOn: max(s.day + delay, line.earliestDay ?? 0),
                                              endsAfter: nil, business: def.business)
            }
            for line in def.expenses {
                s.expenses[line.id] = CashLine(id: line.id, label: line.label, amount: line.amount,
                                               startsOn: max(s.day + delay, line.earliestDay ?? 0),
                                               endsAfter: nil, business: def.business)
            }
            s.business = def.business
            s.flags.insert("business.\(def.id)")
        case .closeBusiness:
            guard let b = Business(rawValue: target) else { return }
            // İşletmeye ait bütün gelir ve giderler birlikte kapanır; ortak kaynaklar kalır.
            s.incomes = s.incomes.filter { $0.value.business != b }
            let closing = s.expenses.filter { $0.value.business == b }.map(\.key)
            for id in closing {
                s.expenses.removeValue(forKey: id)
                s.pendingExpenseRemoval.remove(id)
            }
            if s.business == b { s.business = .closed }

        case .grantEvidence:
            Cases.grant(target, to: &s, content: content)

        case .acceptCommitment:
            let open = s.commitments.values.filter(\.isOpen).count
            guard open < rules.maxActiveCommitments, s.commitments[target] == nil else {
                notes.append("Aynı anda en fazla \(rules.maxActiveCommitments) açık taahhüt olabilir.")
                return
            }
            s.commitments[target] = Commitment(id: target, label: e.label ?? target, acceptedDay: s.day,
                                               dueDay: e.expiresAfterDay ?? s.day, expectedCash: amount,
                                               status: .accepted)
        case .fulfillCommitment:
            s.commitments[target]?.status = .fulfilled
        case .partnerCommitment:
            s.commitments[target]?.status = .partnered
        case .cancelCommitment:
            s.commitments[target]?.status = .cancelled

        case .setMandate:
            guard let m = Mandate(rawValue: e.value ?? "") else { return }
            // Güven etkisi yalnız yöntem değiştiğinde ve her yöntem için bir kez;
            // ortak → merkezî → ortak gidip gelmek puan üretmez.
            if s.mandate != m, s.flags.insert("mandateTrust.\(m.rawValue)").inserted {
                s.trust = min(100, max(0, s.trust + Int(amount)))
            }
            s.mandate = m
        case .setDayGrossPercent:
            for d in Rulebook.list(e.value).compactMap(Int.init) {
                s.grossPercentByDay[d] = Int(amount)
            }

        case .resolveCase:
            s.flags.insert("caseResolved")
            s.flags.insert("authorityRevoked")
            s.counters["caseResolvedDay"] = s.day
        case .revealTruth:
            s.flags.insert("truthRevealed")
        case .settleFinal:
            Final.settle(&s, content: content, notes: &notes)

        case .accuse:
            guard let who = SuspectID(rawValue: target) else { return }
            Cases.accuse(who, state: &s, content: content, notes: &notes)
        case .correctAccusation:
            Cases.correct(state: &s, content: content, notes: &notes)
        case .interview:
            guard let who = target == "culprit" ? s.caseID : SuspectID(rawValue: target) else { return }
            Cases.interview(who, state: &s, content: content, notes: &notes)
        case .recoverSeal:
            Cases.recoverSeal(witnessed: e.value == "witnessed", state: &s, content: content)

        case .resolveComplaint:
            Social.resolve(&s, content: content)
        case .voteConfidence:
            Social.vote(attend: e.value != "ignore", state: &s, content: content, notes: &notes)

        case .remember:
            if let text = e.value { s.memories.append(Memory(day: s.day, text: text)) }
        case .endGame:
            guard let ending = Ending(rawValue: e.value ?? "") else { return }
            if !target.isEmpty { s.flags.insert(target) }
            s.ending = ending
        }
    }
}
