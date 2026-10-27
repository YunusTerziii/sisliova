import Foundation
import Testing
@testable import KaracamCore

@Suite("İçerik paketi")
struct ContentTests {
    let c = sharedContent

    @Test func catalogDecodesAndCoversThirtyDays() {
        #expect(c.calendar.days.map(\.day) == Array(1...30))
        for day in 1...30 {
            #expect(c.chapter(for: day) != nil, "\(day). günün bölümü yok")
        }
        for day in [1, 2, 3, 4, 5, 6, 7, 8, 16, 20, 25, 26, 29, 30] {
            #expect(!c.scenes(day: day, slot: .morning).isEmpty, "\(day). gün sabah sahnesi yok")
        }
        for day in 1...30 where day != 27 {
            #expect(!c.scenes(day: day, slot: .night).isEmpty || day == 0, "\(day). gün gece sahnesi yok")
        }
    }

    @Test func everyReferenceResolves() {
        let evidenceIDs = Set(c.cases.evidence.map(\.id)).union(c.cases.traces.map(\.id))
        let assetIDs = Set(c.assets.illustrations.map(\.id) + c.assets.map.map(\.id))
        for scene in c.scenes.values {
            #expect(c.speakers[scene.speakerID] != nil, "\(scene.id): konuşmacı yok")
            for ill in ([scene.illustration] + (scene.variants ?? []).map(\.illustration)).compactMap({ $0 }) {
                for part in ill.split(separator: ",") {
                    #expect(assetIDs.contains(String(part)), "\(scene.id): görsel yok \(part)")
                }
            }
            let allChoices = scene.choices + (scene.variants ?? []).flatMap { $0.choices ?? [] }
            for ch in allChoices {
                for e in ch.effects {
                    switch e.kind {
                    case .grantEvidence:
                        #expect(evidenceIDs.contains(e.target ?? ""), "\(scene.id)/\(ch.id): kanıt yok \(e.target ?? "")")
                    case .startBusiness:
                        #expect(c.businesses[e.target ?? ""] != nil, "\(scene.id): işletme yok")
                    case .setMandate:
                        #expect(Mandate(rawValue: e.value ?? "") != nil)
                    case .endGame:
                        #expect(Ending(rawValue: e.value ?? "") != nil)
                    case .accuse, .interview:
                        #expect(e.target == "culprit" || SuspectID(rawValue: e.target ?? "") != nil)
                    default: break
                    }
                }
            }
            if scene.day != nil { #expect(scene.slot != .agenda, "\(scene.id): günlü sahne gündem yuvasında") }
        }
        for item in c.agenda {
            #expect(c.scenes[item.sceneID]?.slot == .agenda, "\(item.id): gündem sahnesi yok")
        }
        for sp in c.speakers.values where sp.portrait != nil {
            #expect(c.assets.portraits.contains { $0.asset == sp.portrait }, "\(sp.id): portre manifestte yok")
        }
        #expect(c.endings.count == Ending.allCases.count)
        #expect(c.epilogue.count >= 5)
    }

    /// İki kilitli düğmeyle ilerlemeyi kilitleme: her zorunlu sahnede ücretsiz, şartsız bir yol olmalı.
    @Test func everySlotSceneHasAFreePath() {
        // d30 final: iki seçim birbirini tamamlar. d01 öğle: başlangıç kasası (30.000) iki işletmeye de her zaman yeter.
        let complementary: Set<String> = ["d30.night.final", "d01.noon.elif"]
        for scene in c.scenes.values where scene.slot != .agenda && !complementary.contains(scene.id) {
            var sets: [[ChoiceDefinition]] = []
            if !scene.choices.isEmpty || scene.variants == nil { sets.append(scene.choices) }
            sets += (scene.variants ?? []).compactMap(\.choices)
            for set in sets {
                let free = set.contains { ch in
                    (ch.requirements ?? []).isEmpty
                        && !ch.effects.contains { $0.kind == .cash && ($0.amount ?? 0) < 0 && $0.when == nil }
                        && !ch.effects.contains { $0.kind == .endGame }
                }
                #expect(free, "\(scene.id): ücretsiz/şartsız seçim yok")
            }
        }
    }

    @Test func noUnknownKindsAndMoneyIsKurus() throws {
        // JSON çözümlemesi bilinmeyen türde hata verir; burada tutarların kuruş olduğunu kaba kontrol ederiz.
        for scene in c.scenes.values {
            for ch in scene.choices + (scene.variants ?? []).flatMap({ $0.choices ?? [] }) {
                for e in ch.effects where e.kind == .cash || e.kind == .setIncome || e.kind == .setExpense {
                    let a = abs(e.amount ?? 0)
                    #expect(a == 0 || a % 100 == 0, "\(scene.id)/\(ch.id): tutar kuruş değil gibi")
                    #expect(a == 0 || a >= 10_000, "\(scene.id)/\(ch.id): tutar TL yazılmış olabilir")
                }
            }
        }
    }

    /// Romantizmi istememek ana oyunu bozmaz: Derya seçimleri para, güven, baskı veya kanıt üretmez.
    @Test func deryaChoicesOnlySetFlags() {
        for def in sharedContent.scenes.values {
            let groups: [(String, [ChoiceDefinition])] = [(def.speakerID, def.choices)]
                + (def.variants ?? []).map { ($0.speakerID ?? def.speakerID, $0.choices ?? def.choices) }
            for (speaker, choices) in groups where speaker == "derya" {
                for choice in choices {
                    let kinds = choice.effects.map(\.kind).filter { $0 != .setFlag && $0 != .clearFlag }
                    #expect(kinds.isEmpty, "\(def.id)/\(choice.id): \(kinds)")
                }
            }
        }
    }
}
