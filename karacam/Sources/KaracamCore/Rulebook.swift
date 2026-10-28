import Foundation

/// Koşul değerlendirici. Bütün türlerin karşılığı burada; bilinmeyen tür derlenmez.
public enum Rulebook {
    public static func all(_ predicates: [Predicate]?, _ s: RunState, _ c: GameContent) -> Bool {
        (predicates ?? []).allSatisfy { holds($0, s, c) }
    }

    static func list(_ value: String?) -> [String] {
        (value ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    static func suspect(_ value: String?, _ s: RunState) -> SuspectID? {
        guard let v = value else { return nil }
        if v == "culprit" { return s.caseID }
        return SuspectID(rawValue: v)
    }

    public static func holds(_ p: Predicate, _ s: RunState, _ c: GameContent) -> Bool {
        let amount = p.amount ?? 0
        switch p.kind {
        case .flag: return s.flags.contains(p.target ?? "")
        case .notFlag: return !s.flags.contains(p.target ?? "")
        case .anyFlag: return list(p.value).contains { s.flags.contains($0) }
        case .noFlag: return !list(p.value).contains { s.flags.contains($0) }
        case .business: return list(p.value).contains(s.business.rawValue)
        case .notBusiness: return !list(p.value).contains(s.business.rawValue)
        case .caseIs: return s.caseID.rawValue == p.value
        case .caseIsNot: return s.caseID.rawValue != p.value
        case .hasEvidence: return s.evidence[p.target ?? ""] != nil
        case .notEvidence: return s.evidence[p.target ?? ""] == nil
        case .hasAnyEvidence: return list(p.value).contains { s.evidence[$0] != nil }
        case .noEvidence: return !list(p.value).contains { s.evidence[$0] != nil }
        case .lacksAnyEvidence: return list(p.value).contains { s.evidence[$0] == nil }
        case .trustAtLeast: return Int64(s.trust) >= amount
        case .trustBelow: return Int64(s.trust) < amount
        case .pressureAtLeast: return Int64(s.pressure) >= amount
        case .pressureBelow: return Int64(s.pressure) < amount
        case .cashAtLeast: return s.cash >= amount
        case .cashBelow: return s.cash < amount
        case .dayAtLeast: return Int64(s.day) >= amount
        case .dayAtMost: return Int64(s.day) <= amount
        case .dayIn: return list(p.value).contains(String(s.day))
        case .commitmentIs:
            guard let cm = s.commitments[p.target ?? ""] else { return false }
            return list(p.value).contains(cm.status.rawValue)
        case .commitmentAbsent: return s.commitments[p.target ?? ""] == nil
        case .activeCommitmentsBelow:
            return Int64(s.commitments.values.filter(\.isOpen).count) < amount
        case .incomeActive: return s.incomes[p.target ?? ""] != nil
        case .incomeAbsent: return s.incomes[p.target ?? ""] == nil
        case .expenseActive: return s.expenses[p.target ?? ""] != nil
        case .mandateIs: return (s.mandate?.rawValue ?? "none") == p.value
        case .clarity: return s.clarity[p.target ?? ""] == true
        case .notClarity: return s.clarity[p.target ?? ""] != true
        case .canProve:
            guard let who = suspect(p.value, s) else { return false }
            return CaseSolver.canProve(who, with: Array(s.evidence.values))
        case .cannotProve:
            guard let who = suspect(p.value, s) else { return true }
            return !CaseSolver.canProve(who, with: Array(s.evidence.values))
        case .singleCandidate: return CaseSolver.candidates(Array(s.evidence.values)).count == 1
        case .multipleCandidates: return CaseSolver.candidates(Array(s.evidence.values)).count > 1
        case .counterAtLeast: return Int64(s.counters[p.target ?? ""] ?? 0) >= amount
        case .counterBelow: return Int64(s.counters[p.target ?? ""] ?? 0) < amount
        case .complaintStageToday:
            guard let cp = s.complaint, cp.stage != .closed else { return false }
            switch p.value {
            case "signs": return cp.signsDay == s.day
            case "petition": return cp.petitionDay == s.day && cp.stage != .closed
            case "vote": return cp.voteDay == s.day
            default: return false
            }
        case .complaintActive: return s.complaint.map { $0.stage != .closed } ?? false
        case .complaintInactive: return !(s.complaint.map { $0.stage != .closed } ?? false)
        case .authoritySafe: return Final.authoritySafe(s)
        case .authorityUnsafe: return !Final.authoritySafe(s)
        case .finalReady: return Final.status(s, c).ready
        case .finalNotReady: return !Final.status(s, c).ready
        case .interviewAvailable:
            guard let who = suspect(p.value, s) else { return false }
            guard let mark = s.interviewMarks[who.rawValue] else { return true }
            return s.evidence.count > mark
        case .wrongAccusationOpen:
            return s.accusations.contains { !$0.proven && !$0.corrected }
        case .grievanceAny:
            return c.social.grievances.contains { s.flags.contains($0.flag) }
        case .sealLocated: return s.evidence["location"] != nil || s.evidence["location.narrow"] != nil
        case .sealNotLocated: return s.evidence["location"] == nil && s.evidence["location.narrow"] == nil
        case .endingIs: return s.ending?.rawValue == p.value
        }
    }
}

public enum Money {
    /// Kuruşu "12.500 TL" biçiminde yazar (Türkçe binlik ayırıcı).
    public static func format(_ k: Kurus, signed: Bool = false) -> String {
        let lira = k / 100
        let negative = lira < 0
        var digits = String(abs(lira))
        var groups: [String] = []
        while digits.count > 3 {
            groups.insert(String(digits.suffix(3)), at: 0)
            digits.removeLast(3)
        }
        groups.insert(digits, at: 0)
        let body = groups.joined(separator: ".") + " TL"
        if negative { return "−" + body }
        return signed && lira > 0 ? "+" + body : body
    }
}
