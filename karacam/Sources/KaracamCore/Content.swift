import Foundation

// MARK: - Koşullar ve etkiler

/// Bütün bilinen koşul türleri. Bilinmeyen tür JSON çözümlemesinde hata verir; sessizce atlanmaz.
public enum PredicateKind: String, Codable, CaseIterable, Sendable {
    case flag, notFlag
    case anyFlag, noFlag
    case business, notBusiness
    case caseIs, caseIsNot
    case hasEvidence, notEvidence, hasAnyEvidence, noEvidence, lacksAnyEvidence
    case trustAtLeast, trustBelow
    case pressureAtLeast, pressureBelow
    case cashAtLeast, cashBelow
    case dayAtLeast, dayAtMost, dayIn
    case commitmentIs, commitmentAbsent, activeCommitmentsBelow
    case incomeActive, incomeAbsent, expenseActive
    case mandateIs
    case clarity, notClarity
    case canProve, cannotProve
    case singleCandidate, multipleCandidates
    case counterAtLeast, counterBelow
    case complaintStageToday
    case complaintActive, complaintInactive
    case authoritySafe, authorityUnsafe
    case finalReady, finalNotReady
    case interviewAvailable
    case wrongAccusationOpen
    case grievanceAny
    case sealLocated, sealNotLocated
    case endingIs
}

public struct Predicate: Codable, Sendable, Equatable {
    public var kind: PredicateKind
    public var target: String?
    public var amount: Int64?
    public var value: String?
}

public enum EffectKind: String, Codable, CaseIterable, Sendable {
    case cash, trust, pressure
    case setFlag, clearFlag, incrementCounter
    case setIncome, removeIncome
    case setExpense, reduceExpense, removeExpenseAfterEvening
    case startBusiness, closeBusiness
    case grantEvidence
    case acceptCommitment, fulfillCommitment, partnerCommitment, cancelCommitment
    case setMandate
    case setDayGrossPercent
    case resolveCase, revealTruth, settleFinal
    case accuse, correctAccusation, interview, recoverSeal
    case resolveComplaint, voteConfidence
    case remember, endGame
}

public struct Effect: Codable, Sendable, Equatable {
    public var kind: EffectKind
    public var target: String?
    public var amount: Int64?
    public var value: String?
    public var label: String?
    public var business: Business?
    public var startsAfterDays: Int?
    public var expiresAfterDay: Int?
    /// Yeni proje: ortak kurul yönetiminde bir gün sonra başlar.
    public var project: Bool?
    /// Yalnız bu koşullar sağlanırsa uygulanır (AND).
    public var when: [Predicate]?
}

// MARK: - Sahneler

public struct TextVariant: Codable, Sendable, Equatable {
    public var when: [Predicate]
    public var text: String
}

public struct ChoiceDefinition: Codable, Sendable, Equatable {
    public var id: String
    public var label: String
    public var resultText: String
    public var effects: [Effect]
    public var requirements: [Predicate]?
    public var requirementText: String?
    public var preview: [String]?
    public var resultVariants: [TextVariant]?
    /// Kalıcı/ölümcül sonuç doğuran seçimlerde ikinci onay metni.
    public var confirm: String?
    public var memory: String?
    public var hideWhenUnavailable: Bool?
    /// Para yetmese de seçilebilir (onaylı ekonomik kayıp).
    public var allowDebt: Bool?
    /// false ise gündem işi tamamlanmış sayılmaz (tekrarlanabilir görüşmeler).
    public var completesItem: Bool?
}

public struct SceneVariant: Codable, Sendable, Equatable {
    public var when: [Predicate]
    public var title: String?
    public var body: String?
    public var speakerID: String?
    public var illustration: String?
    public var choices: [ChoiceDefinition]?
}

public struct SceneDefinition: Codable, Sendable, Equatable {
    public var id: String
    public var day: Int?
    public var slot: Slot
    /// Aynı gün/yuvada aynı gruptaki sahnelerden ilk uyan gelir. Varsayılan: yuva adı.
    public var group: String?
    public var speakerID: String
    public var title: String
    public var body: String
    public var requirements: [Predicate]?
    public var choices: [ChoiceDefinition]
    public var variants: [SceneVariant]?
    public var emotionalBeat: String?
    public var callbacks: [String]?
    public var illustration: String?
    /// Gün bağımsız, durum koşuluyla gelen öğle sahnesi (şikâyet, yönetim, Derya).
    public var dynamic: Bool?
}

public struct Speaker: Codable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var role: String
    public var portrait: String?
    /// Defter'in "İnsanlar" bölümünde gösterilir; koşulu tutan bütün notlar.
    public var notes: [TextVariant]?
    /// false ise Defter'de kişi olarak listelenmez (mektup, haber gibi).
    public var person: Bool?
}

public struct StoryFile: Codable, Sendable {
    public var speakers: [Speaker]
    public var scenes: [SceneDefinition]
}

// MARK: - Takvim ve gündem

public struct DayDefinition: Codable, Sendable, Equatable {
    public var day: Int
    public var chapter: Int
    public var title: String
    /// true: sabah gündem yerine o günün zorunlu sahnesi gelir.
    public var dueMorning: Bool
    public var promise: String?
    public var dueNote: String?
}

public struct ChapterDefinition: Codable, Sendable, Equatable {
    public var id: Int
    public var title: String
    public var firstDay: Int
    public var lastDay: Int
    public var theme: String
}

public struct CalendarFile: Codable, Sendable {
    public var chapters: [ChapterDefinition]
    public var days: [DayDefinition]
}

public struct AgendaItemDefinition: Codable, Sendable, Equatable {
    public enum Category: String, Codable, Sendable { case business, investigation, people, finance, rest }
    public var id: String
    public var title: String
    public var summary: String
    public var sceneID: String
    public var category: Category
    public var fromDay: Int
    public var toDay: Int
    public var cooldownDays: Int?
    public var once: Bool
    public var requirements: [Predicate]?
    public var priority: Int
}

public struct ActivitiesFile: Codable, Sendable {
    public var items: [AgendaItemDefinition]
}

// MARK: - Vakalar

public struct SuspectDefinition: Codable, Sendable, Equatable {
    public var id: SuspectID
    public var name: String
    public var accusative: String
    public var role: String
    public var traits: [String]
    public var location: String
    public var locationText: String
}

public enum SuspectRule: String, Codable, Sendable {
    /// `pair`: suçlu + yanıltıcı şüpheli. `notDecoy`: suçlu + üçüncü kişi.
    /// İki kayıt ayrı ayrı iki kişiyi gösterir; suçlu ancak ikisi birleştirilince kalır.
    case all, culprit, others, pair, notCulprit, notDecoy
}

public struct EvidenceTemplate: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var kind: EvidenceKind
    public var reliability: Reliability
    public var sourceID: String
    public var suspects: SuspectRule
    /// `others` için aklanmak istenen kişi.
    public var subject: SuspectID?
    public var text: String
    public var textByCase: [String: String]?
}

public struct TraceDefinition: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var clarityKey: String
    public var trait: String
    public var sourceID: String
    public var clearWithTrait: String
    public var clearWithoutTrait: String
    public var unclear: String
}

public struct InterviewText: Codable, Sendable, Equatable {
    public var claim: String
    public var followUp: String
}

public struct SuspectInterviews: Codable, Sendable, Equatable {
    public var asCulprit: InterviewText
    public var asInnocent: InterviewText
}

public struct CaseTruth: Codable, Sendable, Equatable {
    public var motive: String
    public var signedWhat: String
    public var reveal: String
    public var confession: String
    public var accounting: String
}

public struct CasesFile: Codable, Sendable {
    public var question: String
    public var suspects: [SuspectDefinition]
    public var evidence: [EvidenceTemplate]
    public var traces: [TraceDefinition]
    public var interviews: [String: SuspectInterviews]
    public var truths: [String: CaseTruth]
    public var clarityChance: Int
}

// MARK: - Sonlar ve epilog

public struct EndingDefinition: Codable, Sendable, Equatable {
    public var id: Ending
    public var title: String
    public var summary: String
    public var why: [TextVariant]
    public var decisive: [TextVariant]
}

public struct EpilogueSection: Codable, Sendable, Equatable {
    public var id: String
    public var heading: String
    public var entries: [TextVariant]
}

public struct EndingsFile: Codable, Sendable {
    public var endings: [EndingDefinition]
}

public struct EpiloguesFile: Codable, Sendable {
    public var sections: [EpilogueSection]
}

public struct GrievanceDefinition: Codable, Sendable, Equatable {
    public var flag: String
    public var label: String
}

public struct SocialRulesFile: Codable, Sendable {
    public var grievances: [GrievanceDefinition]
}

public struct SaleTermsFile: Codable, Sendable {
    public var title: String
    public var cashToCommonAccount: Kurus
    public var terms: [String]
    public var gains: [String]
    public var losses: [String]
}

public struct BusinessDefinition: Codable, Sendable, Equatable {
    public var id: String
    public var business: Business
    public var label: String
    public var incomes: [BusinessLine]
    public var expenses: [BusinessLine]
}

public struct BusinessLine: Codable, Sendable, Equatable {
    public var id: String
    public var label: String
    public var amount: Kurus
    /// Bu günden önce başlamaz (ör. rutin gider 8. gün).
    public var earliestDay: Int?
}

public struct BalanceFile: Codable, Sendable {
    public var rules: Rules
    public var businesses: [BusinessDefinition]
}

public struct AssetEntry: Codable, Sendable, Equatable {
    public var id: String
    public var asset: String?
    public var status: String
    public var note: String?
}

public struct AssetManifest: Codable, Sendable {
    public var portraits: [AssetEntry]
    public var illustrations: [AssetEntry]
    public var map: [AssetEntry]
}

// MARK: - Paket

public struct GameContent: Sendable {
    public static let version = "1.0.0-alpha.1"

    public var rules: Rules
    public var businesses: [String: BusinessDefinition]
    public var speakers: [String: Speaker]
    public var scenes: [String: SceneDefinition]
    public var sceneOrder: [String]
    public var calendar: CalendarFile
    public var agenda: [AgendaItemDefinition]
    public var cases: CasesFile
    public var endings: [Ending: EndingDefinition]
    public var epilogue: [EpilogueSection]
    public var social: SocialRulesFile
    public var saleTerms: SaleTermsFile
    public var assets: AssetManifest
    public var contentVersion: String

    public static func load(from directory: URL) throws -> GameContent {
        func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
            let url = directory.appendingPathComponent(name)
            let data: Data
            do { data = try Data(contentsOf: url) } catch {
                throw CoreError.invalidContent("\(name) okunamadı")
            }
            do { return try JSONDecoder().decode(T.self, from: data) } catch {
                throw CoreError.invalidContent("\(name): \(error)")
            }
        }
        let balance = try decode(BalanceFile.self, "balance.json")
        let story = try decode(StoryFile.self, "story.json")
        let calendar = try decode(CalendarFile.self, "calendar.json")
        let activities = try decode(ActivitiesFile.self, "activities.json")
        let cases = try decode(CasesFile.self, "cases.json")
        let endings = try decode(EndingsFile.self, "endings.json")
        let epilogues = try decode(EpiloguesFile.self, "epilogues.json")
        let social = try decode(SocialRulesFile.self, "social_rules.json")
        let sale = try decode(SaleTermsFile.self, "sale_terms.json")
        let assets = try decode(AssetManifest.self, "asset_manifest.json")

        var scenes: [String: SceneDefinition] = [:]
        for scene in story.scenes {
            guard scenes[scene.id] == nil else {
                throw CoreError.invalidContent("Yinelenen sahne: \(scene.id)")
            }
            scenes[scene.id] = scene
        }
        var endingMap: [Ending: EndingDefinition] = [:]
        for e in endings.endings { endingMap[e.id] = e }
        return GameContent(
            rules: balance.rules,
            businesses: Dictionary(uniqueKeysWithValues: balance.businesses.map { ($0.id, $0) }),
            speakers: Dictionary(uniqueKeysWithValues: story.speakers.map { ($0.id, $0) }),
            scenes: scenes,
            sceneOrder: story.scenes.map(\.id),
            calendar: calendar,
            agenda: activities.items,
            cases: cases,
            endings: endingMap,
            epilogue: epilogues.sections,
            social: social,
            saleTerms: sale,
            assets: assets,
            contentVersion: GameContent.version
        )
    }

    /// Paketle gelen kanonik içerik.
    public static func bundled() throws -> GameContent {
        guard let url = Bundle.module.url(forResource: "Content", withExtension: nil) else {
            throw CoreError.invalidContent("Content klasörü pakette yok")
        }
        return try load(from: url)
    }

    public func dayDefinition(_ day: Int) -> DayDefinition? {
        calendar.days.first { $0.day == day }
    }

    public func chapter(for day: Int) -> ChapterDefinition? {
        calendar.chapters.first { day >= $0.firstDay && day <= $0.lastDay }
    }

    public func suspect(_ id: SuspectID) -> SuspectDefinition {
        cases.suspects.first { $0.id == id }!
    }

    /// Belirli gün ve yuvadaki sahneler, içerikteki sırayla.
    func scenes(day: Int, slot: Slot) -> [SceneDefinition] {
        sceneOrder.compactMap { scenes[$0] }.filter { $0.day == day && $0.slot == slot }
    }

    func dynamicAnchors() -> [SceneDefinition] {
        sceneOrder.compactMap { scenes[$0] }.filter { $0.dynamic == true && $0.slot == .anchor }
    }
}
