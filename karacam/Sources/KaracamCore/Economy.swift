import Foundation

public struct EveningLine: Sendable, Equatable {
    public var id: String
    public var label: String
    public var amount: Kurus
}

public struct Evening: Sendable, Equatable {
    public var day: Int
    public var gross: Kurus
    public var basisPoints: Int64
    public var dayPercent: Int
    public var adjustedGross: Kurus
    public var expenses: Kurus
    public var pressureFee: Kurus
    public var incomeLines: [EveningLine]
    public var expenseLines: [EveningLine]
    public var net: Kurus { adjustedGross - expenses - pressureFee }

    public var record: EveningRecord {
        EveningRecord(day: day, gross: gross, adjustedGross: adjustedGross,
                      expenses: expenses, pressureFee: pressureFee)
    }
}

public enum Economy {
    public static func basisPoints(trust: Int, rules: Rules) -> Int64 {
        if trust < rules.lowTrust { return rules.lowBasisPoints }
        if trust >= rules.highTrust { return rules.highBasisPoints }
        return rules.normalBasisPoints
    }

    public static func pressureFee(pressure: Int, rules: Rules) -> Kurus {
        guard pressure >= rules.pressureStart else { return 0 }
        return min(rules.pressureCap,
                   Int64(max(0, pressure - rules.pressureOffset)) * rules.pressurePerPoint)
    }

    /// Belirtilen günün akşam hesabı. Güven ve baskı verilmezse bugünkü değerler kullanılır.
    public static func forecast(_ state: RunState, rules: Rules, day: Int? = nil,
                                trust: Int? = nil, pressure: Int? = nil) -> Evening {
        let d = day ?? state.day
        let incomes = state.incomes.values.filter { $0.active(on: d) }.sorted { $0.id < $1.id }
        let expenses = state.expenses.values.filter { $0.active(on: d) }.sorted { $0.id < $1.id }
        let gross = incomes.reduce(Kurus(0)) { $0 + $1.amount }
        let basis = basisPoints(trust: trust ?? state.trust, rules: rules)
        let percent = state.grossPercentByDay[d] ?? 100
        // Brüt × basisPoint / 10000 × yüzde / 100; tamsayı, kuruş.
        let adjusted = gross * basis * Int64(percent) / 1_000_000
        let expenseTotal = expenses.reduce(Kurus(0)) { $0 + $1.amount }
        let fee = pressureFee(pressure: pressure ?? state.pressure, rules: rules)
        return Evening(
            day: d, gross: gross, basisPoints: basis, dayPercent: percent,
            adjustedGross: adjusted, expenses: expenseTotal, pressureFee: fee,
            incomeLines: incomes.map { EveningLine(id: $0.id, label: $0.label, amount: $0.amount) },
            expenseLines: expenses.map { EveningLine(id: $0.id, label: $0.label, amount: $0.amount) })
    }

    /// Akşamı bir kez hesaplar. Aynı gün ikinci kez çağrılırsa hata verir.
    public static func settle(_ state: RunState, rules: Rules) throws -> (RunState, Evening) {
        guard state.phase == .evening else { throw CoreError.invalidPhase }
        guard !state.settledDays.contains(state.day) else { throw CoreError.duplicateEvening }
        let report = forecast(state, rules: rules)
        var next = state
        next.cash += report.net
        next.settledDays.insert(state.day)
        next.evenings.append(report.record)
        for id in state.pendingExpenseRemoval {
            next.expenses.removeValue(forKey: id)
        }
        next.pendingExpenseRemoval.removeAll()
        return (next, report)
    }

    /// "Bugünkü koşullar değişmezse" 30. gün ödeme öncesi kasa tahmini.
    /// Bilinen başlangıç/bitiş tarihleri ve açık taahhüt tahsilatları dahildir.
    public static func projection(_ state: RunState, rules: Rules,
                                  commitmentCash: Kurus) -> Kurus {
        var cash = state.cash
        let firstDay = state.settledDays.contains(state.day) ? state.day + 1 : state.day
        guard firstDay <= rules.finalDay else { return cash + commitmentCash }
        for d in firstDay...rules.finalDay {
            cash += forecast(state, rules: rules, day: d).net
        }
        return cash + commitmentCash
    }
}

/// Basit, taşınabilir, tohumlu üreteç. Dünya gerçeği yalnız buradan üretilir.
public struct SplitMix64: Codable, Sendable {
    public var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    public mutating func next(below n: Int) -> Int {
        Int(next() % UInt64(n))
    }
}

public enum CaseSolver {
    /// İddia düzeyindeki bilgiler aday elemez.
    public static func candidates(_ evidence: [Evidence]) -> Set<SuspectID> {
        evidence.filter { $0.reliability != .claimed }
            .reduce(Set(SuspectID.allCases)) { $0.intersection($1.possibleSuspects) }
    }

    /// İmza, bağımsız zaman ve tanıklı mühür zinciri üç ayrı kaynaktan doğrulanmış olmalı.
    public static func canProve(_ person: SuspectID, with evidence: [Evidence]) -> Bool {
        let verified = evidence.filter {
            $0.reliability == .verified && $0.possibleSuspects.contains(person)
        }
        let signatures = verified.filter { $0.kind == .signature }
        let timelines = verified.filter { $0.kind == .timeline }
        let custody = verified.filter { $0.kind == .custody }
        return signatures.contains { a in
            timelines.contains { b in
                custody.contains { c in
                    Set([a.sourceID, b.sourceID, c.sourceID]).count == 3
                }
            }
        }
    }

    public enum ProofPart: String, CaseIterable, Sendable {
        case signature, timeline, custody
        public var label: String {
            switch self {
            case .signature: "imza kaydı"
            case .timeline: "tarih kaydı"
            case .custody: "mührün tanıklı teslimi"
            }
        }
    }

    /// Bu kişi için doğrulanmış olarak eldeki dosya parçaları.
    public static func proofParts(for person: SuspectID, with evidence: [Evidence]) -> Set<ProofPart> {
        var parts: Set<ProofPart> = []
        for e in evidence where e.reliability == .verified && e.possibleSuspects.contains(person) {
            switch e.kind {
            case .signature: parts.insert(.signature)
            case .timeline: parts.insert(.timeline)
            case .custody: parts.insert(.custody)
            default: break
            }
        }
        return parts
    }
}
