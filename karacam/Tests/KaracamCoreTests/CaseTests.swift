import Foundation
import Testing
@testable import KaracamCore

@Suite("Vaka, kanıt ve itham")
struct CaseTests {
    func ev(_ id: String, _ kind: EvidenceKind, _ r: Reliability, _ src: String, _ who: Set<SuspectID>) -> Evidence {
        Evidence(id: id, title: id, text: id, kind: kind, reliability: r, sourceID: src, possibleSuspects: who, acquiredDay: 1)
    }

    @Test func claimsAloneDoNotEliminate() {
        let claim = ev("c", .testimony, .claimed, "halil", [.selim, .sevim])
        #expect(CaseSolver.candidates([claim]) == Set(SuspectID.allCases))
        let observed = ev("o", .trace, .observed, "x", [.selim, .halil])
        #expect(CaseSolver.candidates([claim, observed]) == [.selim, .halil])
    }

    @Test func threeIndependentRecordsProveAndCopiesDoNot() {
        let sig = ev("s", .signature, .verified, "registry", [.halil])
        let time = ev("t", .timeline, .verified, "deliveryLog", [.halil])
        let cust = ev("c", .custody, .verified, "handover", [.halil])
        #expect(CaseSolver.canProve(.halil, with: [sig, time, cust]))
        #expect(!CaseSolver.canProve(.selim, with: [sig, time, cust]))
        let sameSource = ev("t2", .timeline, .verified, "registry", [.halil])
        let cust2 = ev("c2", .custody, .verified, "registry", [.halil])
        #expect(!CaseSolver.canProve(.halil, with: [sig, sameSource, cust2]))
    }

    @Test func clarityIsIndependentOfCaseIdentity() {
        // Aynı vaka, farklı açıklık: belirsiz iz kimseyi elemiyor ve bir kimlik kodu değil.
        for culprit in SuspectID.allCases {
            var unclear = Driver(culprit: culprit, clarity: ["voice": false])
            Cases.grant("trace.voice", to: &unclear.env.state, content: sharedContent)
            #expect(unclear.s.evidence["trace.voice"]?.possibleSuspects == Set(SuspectID.allCases))
            var clear = Driver(culprit: culprit, clarity: ["voice": true])
            Cases.grant("trace.voice", to: &clear.env.state, content: sharedContent)
            #expect(clear.s.evidence["trace.voice"]?.possibleSuspects.contains(culprit) == true)
        }
    }

    @Test func seedFixesCaseAndClarity() {
        let e = Engine(content: sharedContent)
        let a = e.newRun(seed: 777).state
        let b = e.newRun(seed: 777).state
        #expect(a.caseID == b.caseID && a.clarity == b.clarity && a.decoySuspect == b.decoySuspect)
        var cases = Set<SuspectID>()
        for seed in 0..<60 { cases.insert(e.newRun(seed: UInt64(seed)).state.caseID) }
        #expect(cases.count == 3)
    }

    @Test func earlyPathResolvesByDayThirteen() throws {
        // 9. sabah imza, 9. gece kayıt talebi → 10. gün tarih, 11. sabah hedefli görüşme, 12. sabah tanıklı mühür, 13. sabah dosya.
        var d = Driver(culprit: .halil)
        try d.run(to: 9, phase: .agenda, picks: ["d01.noon.elif": "bees"])
        d.env.state.cash += 10_000_000
        try d.agenda("records", "signature")
        try d.run(to: 9, phase: .night)
        try d.choose("request")
        try d.run(to: 11, phase: .agenda, picks: ["d10.night.target": "wait"])
        #expect(d.s.evidence["timeline"] != nil)
        try d.agenda("interview", "halil")
        #expect(d.s.evidence["location"] != nil)
        try d.run(to: 12, phase: .agenda)
        try d.agenda("retrieveSeal", "witnessed")
        #expect(d.s.flags.contains("custodyVerified"))
        try d.run(to: 13, phase: .agenda)
        #expect(CaseSolver.canProve(.halil, with: Array(d.s.evidence.values)))
        try d.agenda("submitCase", "halil")
        #expect(d.s.flags.contains("caseResolved"))
        #expect(d.s.counters["caseResolvedDay"] == 13)
        // Erken çözüm sonraki sahneleri değiştirir: 18. gün dosya toplantısı gelmez, 21. gece yaklaşım seçimi gelir.
        try d.run(to: 18, phase: .anchor)
        #expect(d.s.current?.sceneID != "d18.noon.hearing")
        try d.run(to: 21, phase: .night)
        #expect(d.s.current?.sceneID == "d21.night.approach")
        #expect(d.s.current?.variantIndex == 0)
        #expect(!d.engine.availableAgenda(d.s).contains { $0.id == "submitCase" } )
    }

    @Test func targetedNightQuestionGivesLocationOnce() throws {
        var d = Driver(culprit: .sevim)
        try d.run(to: 9, phase: .agenda)
        d.env.state.cash += 10_000_000
        try d.agenda("records", "signature")
        try d.run(to: 10, phase: .night)
        #expect(d.s.current?.sceneID == "d10.night.target")
        #expect(d.s.current?.variantIndex == 0)
        try d.choose("ask")
        #expect(d.s.evidence["location"] != nil)
        try d.run(to: 11, phase: .agenda)
        // Yeni kayıt olmadan aynı kişiye ikinci görüşme reddedilir.
        #expect(throws: CoreError.self) { try d.agenda("interview", "sevim") }
    }

    @Test func wrongAccusationCostsOnceAndCanBeCorrected() throws {
        var d = Driver(culprit: .sevim)
        try d.run(to: 9, phase: .agenda)
        d.env.state.trust = 40
        try d.agenda("submitCase", "selim")
        #expect(d.s.trust == 32)
        #expect(d.s.flags.contains("wrongAccusation"))
        #expect(!d.s.flags.contains("caseResolved"))
        try d.run(to: 10, phase: .agenda)
        #expect(d.engine.availableAgenda(d.s).contains { $0.id == "correct" })
        let before = d.s.trust
        try d.agenda("correct", "correct")
        #expect(d.s.trust == before + 4)
        try d.run(to: 11, phase: .agenda)
        #expect(!d.engine.availableAgenda(d.s).contains { $0.id == "correct" })
    }

    @Test func wrongFirstGuessDoesNotLockTheFile() throws {
        var d = Driver(culprit: .selim)
        try d.run(to: 7, phase: .recap)
        try d.send(.recordGuess(.halil))
        try d.finish()
        try d.run(to: 9, phase: .agenda)
        #expect(d.engine.availableAgenda(d.s).contains { $0.id == "submitCase" })
        #expect(d.engine.availableAgenda(d.s).contains { $0.id == "interview" })
    }

    @Test func presentationNeverLeaksCulpritBeforeEvidence() throws {
        for culprit in SuspectID.allCases {
            var d = Driver(culprit: culprit)
            try d.run(to: 9, phase: .agenda)
            let p = d.engine.present(d.env)
            let dump = "\(p.notebook)" + "\(p.agenda as Any)"
            // Kimseyi gösteren doğrulanmış kayıt yokken dosya satırı boş olmalı.
            #expect(p.notebook.fileLine.contains("· imza nüshası"))
            #expect(!dump.contains("caseID"))
        }
    }
}
