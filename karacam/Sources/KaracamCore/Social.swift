import Foundation

/// Şikâyet ve güven oylaması. Rastgele doğmaz: düşük güven + köyde bilinen bir aksama gerekir.
enum Social {
    static func maybeStartComplaint(_ s: inout RunState, content c: GameContent) {
        let r = c.rules
        guard s.day >= r.complaintEarliestDay,
              s.trust < r.complaintTrustBelow,
              s.complaintsStarted < r.maxComplaints,
              s.complaint.map({ $0.stage == .closed }) ?? true,
              let grievance = c.social.grievances.first(where: { s.flags.contains($0.flag) })
        else { return }
        let lastAllowed = r.finalDay - r.lastQuietDays
        func free(_ d: Int) -> Int {
            var day = d
            while r.protectedDays.contains(day) { day += 1 }
            return day
        }
        let signs = free(s.day + 1)
        let petition = free(max(signs + 1, s.day + 2))
        let vote = free(max(petition + 1, s.day + 4))
        // Vade günlerini ve son üç günü beklenmedik kesintiyle bozma.
        guard vote <= lastAllowed else { return }
        s.complaintsStarted += 1
        s.complaint = ComplaintState(number: s.complaintsStarted, startDay: s.day, signsDay: signs,
                                     petitionDay: petition, voteDay: vote, stage: .signs,
                                     grievance: grievance.label)
    }

    static func resolve(_ s: inout RunState, content c: GameContent) {
        if s.complaint != nil { s.complaint?.stage = .closed }
        // Şikâyetin kaynağı ele alındı: bilinen aksamalar kapanır.
        for g in c.social.grievances { s.flags.remove(g.flag) }
        s.flags.insert("grievanceAddressed")
    }

    static func vote(attend: Bool, state s: inout RunState, content c: GameContent, notes: inout [String]) {
        let r = c.rules
        if attend {
            if s.trust >= r.voteThreshold {
                notes.append("Oylamada destek \(s.trust). Görev sürüyor.")
                s.flags.insert("voteWon")
            } else {
                notes.append("Oylamada destek \(s.trust). Kurul denetimi başladı: kapalı pazarlık yetkin sınırlandı.")
                s.flags.insert("boardOversight")
            }
        } else {
            s.trust = max(0, s.trust - 8)
            s.pressure = min(100, s.pressure + 3)
            s.flags.insert("boardOversight")
            notes.append("Oylamaya çıkmadın. Kurul denetimi kendiliğinden başladı.")
        }
        s.complaint?.stage = .closed
    }
}

public struct FinalStatus: Sendable, Equatable {
    public var cashBefore: Kurus
    public var cashEnough: Bool
    public var trustEnough: Bool
    public var pressureOK: Bool
    public var authoritySafe: Bool
    public var ready: Bool { cashEnough && trustEnough && pressureOK && authoritySafe }
}

public enum Final {
    public static func authoritySafe(_ s: RunState) -> Bool {
        s.flags.contains("authorityFrozen") || s.flags.contains("authorityRevoked")
            || s.flags.contains("caseResolved")
    }

    public static func status(_ s: RunState, _ c: GameContent) -> FinalStatus {
        FinalStatus(cashBefore: s.cash,
                    cashEnough: s.cash >= c.rules.firstInstallment,
                    trustEnough: s.trust >= c.rules.highTrust,
                    pressureOK: s.pressure < c.rules.pressureLoss,
                    authoritySafe: authoritySafe(s))
    }

    /// Özel başarı: kanıtlı doğru hesaplaşma, güvenli mühür zinciri, düzeltilmemiş haksız itham yok.
    public static func special(_ s: RunState) -> Bool {
        s.flags.contains("culpritExposed")
            && CaseSolver.canProve(s.caseID, with: Array(s.evidence.values))
            && s.flags.contains("custodyVerified")
            && !s.accusations.contains { !$0.correct && !$0.corrected }
    }

    /// 30. gün akşam hesabından sonra bir kez çalışır. Para yetmezse ekonomik kayıp,
    /// güven yetmezse destek kaybı; ödeme sonrası düşük kasa ikinci bir kayıp değildir.
    static func settle(_ s: inout RunState, content c: GameContent, notes: inout [String]) {
        guard s.ending == nil, s.day == c.rules.finalDay, s.settledDays.contains(s.day) else { return }
        let st = status(s, c)
        s.finalCashBeforePayment = s.cash
        if !st.cashEnough {
            s.ending = .cash
        } else if !st.trustEnough {
            s.ending = .trust
        } else if !st.pressureOK {
            s.ending = .pressure
        } else if !st.authoritySafe {
            s.flags.insert("otherOrder")
            s.ending = .sale
        } else if !s.paymentMade {
            s.cash -= c.rules.firstInstallment
            s.paymentMade = true
            s.ending = special(s) ? .together : .cooperative
            notes.append("150.000 TL ilk taksit gönderildi. Kasada \(Money.format(s.cash)) kaldı.")
        }
    }
}
