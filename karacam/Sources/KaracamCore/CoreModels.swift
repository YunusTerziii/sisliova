import Foundation

/// Bütün para kuruş cinsinden tutulur: 30.000 TL = 3.000.000 kuruş.
public typealias Kurus = Int64

public enum SuspectID: String, Codable, CaseIterable, Hashable, Sendable, Comparable {
    case selim, halil, sevim
    public static func < (a: SuspectID, b: SuspectID) -> Bool { a.rawValue < b.rawValue }
}

public enum Business: String, Codable, Sendable {
    case none, spa, bees, closed
}

public enum Phase: String, Codable, Sendable {
    case agenda, morning, anchor, evening, night, recap, ended
}

/// İçerikteki sahne yuvası. `agenda` yuvası gündem menüsünden açılan sahnelerdir.
public enum Slot: String, Codable, Sendable {
    case morning, anchor, night, agenda
}

public enum Ending: String, Codable, CaseIterable, Sendable {
    case cooperative, together, sale, cash, trust, pressure
}

public enum Mandate: String, Codable, Sendable { case shared, central }

public enum EvidenceKind: String, Codable, CaseIterable, Sendable {
    case trace, document, signature, timeline, custody, testimony, location
}

public enum Reliability: String, Codable, CaseIterable, Sendable, Comparable {
    case claimed, observed, corroborated, verified
    var rank: Int {
        switch self {
        case .claimed: 0
        case .observed: 1
        case .corroborated: 2
        case .verified: 3
        }
    }
    public static func < (a: Reliability, b: Reliability) -> Bool { a.rank < b.rank }
}

public struct CashLine: Codable, Sendable, Equatable {
    public var id: String
    public var label: String
    public var amount: Kurus
    public var startsOn: Int
    public var endsAfter: Int?
    public var business: Business?

    public func active(on day: Int) -> Bool {
        day >= startsOn && (endsAfter.map { day <= $0 } ?? true)
    }
}

public struct Evidence: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var text: String
    public var kind: EvidenceKind
    public var reliability: Reliability
    public var sourceID: String
    public var possibleSuspects: Set<SuspectID>
    public var acquiredDay: Int
}

public struct Commitment: Codable, Sendable, Equatable {
    public enum Status: String, Codable, Sendable {
        case accepted, fulfilled, partnered, cancelled
    }
    public var id: String
    public var label: String
    public var acceptedDay: Int
    public var dueDay: Int
    /// Vade günü beklenen tahsilat (projeksiyonda kullanılır).
    public var expectedCash: Kurus
    public var status: Status
    public var isOpen: Bool { status == .accepted }
}

public struct ScheduledEffect: Codable, Sendable, Equatable {
    public var day: Int
    public var effect: Effect
    public var note: String?
}

public struct SceneInstance: Codable, Sendable, Equatable {
    public var sceneID: String
    public var instanceID: String
    public var variantIndex: Int?
    public var slot: Slot
    /// Gündemden açılan sahnelerde gündem işinin kimliği.
    public var agendaItemID: String?
}

public struct Memory: Codable, Sendable, Equatable {
    public var day: Int
    public var text: String
}

public struct Outcome: Codable, Sendable, Equatable {
    public var day: Int
    public var sceneTitle: String
    public var text: String
    /// Sonucu doğuran sahne; eski kayıtlarda yok.
    public var sceneID: String?
    /// Bu seçimle deftere eklenen kanıtların başlıkları; eski kayıtlarda yok.
    public var newEvidence: [String]?

    public init(day: Int, sceneTitle: String, text: String, sceneID: String? = nil, newEvidence: [String]? = nil) {
        self.day = day
        self.sceneTitle = sceneTitle
        self.text = text
        self.sceneID = sceneID
        self.newEvidence = newEvidence
    }
}

public struct EveningRecord: Codable, Sendable, Equatable {
    public var day: Int
    public var gross: Kurus
    public var adjustedGross: Kurus
    public var expenses: Kurus
    public var pressureFee: Kurus
    public var net: Kurus { adjustedGross - expenses - pressureFee }
}

public struct Accusation: Codable, Sendable, Equatable {
    public var subject: SuspectID
    public var day: Int
    public var proven: Bool
    public var correct: Bool
    public var corrected: Bool
}

/// Şikâyet ve güven oylaması (bölüm 6). Aşama günleri başlarken bir kez hesaplanır.
public struct ComplaintState: Codable, Sendable, Equatable {
    public enum Stage: String, Codable, Sendable { case signs, petition, vote, closed }
    public var number: Int
    public var startDay: Int
    public var signsDay: Int
    public var petitionDay: Int
    public var voteDay: Int
    public var stage: Stage
    public var grievance: String
}

public struct RunState: Codable, Sendable, Equatable {
    public var runID: UUID
    public var revision: Int
    public var seed: UInt64
    public var caseID: SuspectID
    /// İz açıklığı vaka kimliğinden ayrı seçilir: true = iz net okunuyor.
    public var clarity: [String: Bool]
    /// Mührün olası iki yerinden yanıltıcı olanın sahibi (vaka kimliğinden farklı).
    public var decoySuspect: SuspectID
    public var day: Int
    public var phase: Phase
    public var current: SceneInstance?
    /// Bu yuvada sırası gelecek sahne grupları.
    public var slotQueue: [String]
    public var business: Business
    public var cash: Kurus
    public var trust: Int
    public var pressure: Int
    public var incomes: [String: CashLine]
    public var expenses: [String: CashLine]
    public var evidence: [String: Evidence]
    public var flags: Set<String>
    public var counters: [String: Int]
    public var commitments: [String: Commitment]
    public var scheduled: [ScheduledEffect]
    public var activityLastDay: [String: Int]
    public var usedAgendaItems: Set<String>
    public var completedInstances: Set<String>
    public var appliedCommands: Set<UUID>
    public var settledDays: Set<Int>
    public var pendingExpenseRemoval: Set<String>
    public var mandate: Mandate?
    public var grossPercentByDay: [Int: Int]
    public var paymentMade: Bool
    public var ending: Ending?
    public var endingDay: Int?
    public var lastOutcome: Outcome?
    public var memories: [Memory]
    public var evenings: [EveningRecord]
    public var interviewMarks: [String: Int]
    public var accusations: [Accusation]
    public var complaint: ComplaintState?
    public var complaintsStarted: Int
    public var deryaMetDay: Int?
    public var finalCashBeforePayment: Kurus?
}

public struct RunMetadata: Codable, Sendable, Equatable {
    public var firstGuess: SuspectID?
    public var firstGuessRecorded: Bool
    public var firstGuessDay: Int?
    public var rewindCount: Int
    public var attemptID: UUID
    /// Oyuncunun kendi eleme notları. Dünyayı değiştirmez, geri sarılmaz.
    public var eliminated: Set<SuspectID>
    public var playerName: String?
}

public struct SaveEnvelope: Codable, Sendable, Equatable {
    public static let currentSchema = 1
    public var schemaVersion: Int
    public var contentVersion: String
    public var state: RunState
    public var metadata: RunMetadata
    public var dayCheckpoint: RunState?
    public var chapterCheckpoint: RunState?
}

public struct Rules: Codable, Sendable {
    public var initialCash: Kurus
    public var initialTrust: Int
    public var initialPressure: Int
    public var firstInstallment: Kurus
    public var totalDebt: Kurus
    public var lowTrust: Int
    /// Gelir çarpanının yükseldiği güven eşiği.
    public var highTrust: Int
    /// 30. gün ödeme planı için gereken kurul desteği. Eski içerikte yoksa `highTrust`.
    public var paymentTrust: Int?
    public var requiredTrust: Int { paymentTrust ?? highTrust }
    public var lowBasisPoints: Int64
    public var normalBasisPoints: Int64
    public var highBasisPoints: Int64
    public var pressureStart: Int
    public var pressureOffset: Int
    public var pressurePerPoint: Kurus
    public var pressureCap: Kurus
    public var pressureLoss: Int
    public var finalDay: Int
    public var freeLastDay: Int
    public var maxActiveCommitments: Int
    public var maxComplaints: Int
    public var voteThreshold: Int
    public var complaintTrustBelow: Int
    public var complaintEarliestDay: Int
    public var protectedDays: [Int]
    public var lastQuietDays: Int
    public var wrongAccusationTrust: Int
    public var correctionTrust: Int
}

public enum CoreError: Error, Equatable, Sendable {
    case invalidPhase
    case duplicateEvening
    case insufficientCash
    case missingFinalConditions
    case staleCommand
    case duplicateCommand
    case invalidContent(String)
    case unknownScene(String)
    case sceneMismatch
    case choiceUnavailable(String)
    case gateLocked
    case gameEnded
}
