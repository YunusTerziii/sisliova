import Foundation
import Testing
@testable import KaracamCore

@Suite("Akış, gündem ve taahhütler")
struct FlowTests {
    @Test func freeChapterGateLocksDayEight() throws {
        var d = Driver()
        try d.run(to: 7, phase: .recap)
        try d.send(.recordGuess(.halil))
        #expect(throws: CoreError.gateLocked) { try d.send(.finishDay, unlocked: false) }
        try d.send(.finishDay, unlocked: true)
        #expect(d.s.day == 8)
        #expect(d.env.metadata.firstGuess == .halil)
    }

    @Test func agendaOpensOnDayNineAndMorningIsUsedOnce() throws {
        var d = Driver()
        try d.run(to: 9, phase: .agenda)
        let items = d.engine.availableAgenda(d.s).map(\.id)
        #expect(items.contains("order9"))
        #expect(items.contains("rest"))
        #expect(!items.contains("stall"))
        try d.agenda("rest", "rest")
        #expect(d.s.phase != .agenda)
        #expect(throws: CoreError.invalidPhase) { try d.agenda("order9", "accept") }
    }

    @Test func orderNotTakenBringsFallbackOnSixteen() throws {
        var d = Driver()
        try d.run(to: 16, phase: .morning)
        #expect(d.s.current?.sceneID == "d16.morning.delivery")
        #expect(d.s.current?.variantIndex == nil)
        #expect(d.s.commitments["order9"] == nil)
    }

    @Test func insufficientPrepCashStillHasPartnerAndCancelPaths() throws {
        var d = Driver()
        try d.run(to: 16, phase: .morning, agenda: [9: ("order9", "accept")])
        #expect(d.s.commitments["order9"]?.status == .accepted)
        d.env.state.cash = 100_000
        let def = d.engine.content.scenes["d16.morning.delivery"]!
        let choices = d.engine.resolvedChoices(def, variant: d.s.current?.variantIndex)
        let available = Dictionary(uniqueKeysWithValues: choices.map { ($0.id, d.engine.availability($0, d.s).0) })
        #expect(available["deliver"] == false)
        #expect(available["partner"] == true)
        #expect(available["cancel"] == true)
        try d.choose("cancel")
        #expect(d.s.cash == 100_000 - 1_000_000)
        #expect(d.s.commitments["order9"]?.status == .cancelled)
    }

    @Test func deliveryNetsEightThousandOnce() throws {
        var d = Driver()
        try d.run(to: 16, phase: .morning, agenda: [9: ("order9", "accept")])
        let before = d.s.cash
        try d.choose("deliver")
        #expect(d.s.cash - before == 800_000)
        #expect(d.s.commitments["order9"]?.status == .fulfilled)
    }

    @Test func atMostTwoOpenCommitments() throws {
        var d = Driver()
        try d.run(to: 9, phase: .agenda)
        d.env.state.commitments["a"] = Commitment(id: "a", label: "a", acceptedDay: 9, dueDay: 20, expectedCash: 0, status: .accepted)
        d.env.state.commitments["b"] = Commitment(id: "b", label: "b", acceptedDay: 9, dueDay: 20, expectedCash: 0, status: .accepted)
        #expect(throws: CoreError.self) { try d.agenda("order9", "accept") }
    }

    @Test func sharedMandateDelaysOnlyNewProjects() throws {
        var d = Driver()
        try d.run(to: 8, phase: .anchor, picks: ["d01.noon.elif": "bees", "d08.morning.picture": "wait"])
        #expect(d.s.current?.sceneID == "dyn.mandate")
        let trust = d.s.trust
        try d.choose("shared")
        #expect(d.s.trust == trust + 3)
        try d.run(to: 9, phase: .agenda)
        d.env.state.cash = 5_000_000
        try d.agenda("invest1", "packaging")
        #expect(d.s.incomes["bees.packaging"]?.startsOn == 10)
        // Mevcut gelir bekletilmez.
        #expect(d.s.incomes["bees.base"]?.active(on: 9) == true)
    }

    @Test func centralMandateStartsSameDay() throws {
        var d = Driver()
        try d.run(to: 8, phase: .anchor, picks: ["d01.noon.elif": "bees", "d08.morning.picture": "wait", "dyn.mandate": "central"])
        try d.choose("central")
        try d.run(to: 9, phase: .agenda)
        d.env.state.cash = 5_000_000
        try d.agenda("invest1", "packaging")
        #expect(d.s.incomes["bees.packaging"]?.startsOn == 9)
    }

    @Test func complaintNeedsLowTrustAndAKnownGrievance() throws {
        var d = Driver()
        try d.run(to: 10, phase: .evening)
        d.env.state.trust = 30
        try d.settle()
        #expect(d.s.complaint == nil, "aksama yokken şikâyet doğmamalı")
        try d.run(to: 11, phase: .evening)
        d.env.state.trust = 30
        d.env.state.flags.insert("grievance.overtime")
        try d.settle()
        let c = try #require(d.s.complaint)
        #expect(c.signsDay == 12 && c.petitionDay == 13 && c.voteDay == 15)
        try d.run(to: 15, phase: .anchor, picks: ["dyn.social.petition": "insist"])
        // 15. gün yönetim sahnesi de var; oylamaya kadar ilerle.
        while d.s.current?.sceneID != "dyn.social.vote" { try d.choose(d.firstFreeChoice()!) }
        d.env.state.trust = 30
        try d.choose("attend")
        #expect(d.s.flags.contains("boardOversight"))
        #expect(d.s.complaint?.stage == .closed)
        #expect(d.s.ending == nil, "kurul denetimi oyunu bitirmez")
    }

    @Test func complaintAvoidsProtectedAndLastDays() throws {
        var d = Driver()
        try d.run(to: 25, phase: .evening)
        d.env.state.trust = 20
        d.env.state.complaint = nil
        d.env.state.complaintsStarted = 0
        d.env.state.flags.insert("grievance.workload")
        try d.settle()
        // 25. akşam başlasa oylama 29'a düşerdi: son sessiz günlere girdiği için hiç başlamaz.
        #expect(d.s.complaint == nil)
        #expect(d.s.complaintsStarted == 0)
    }

    @Test func complaintStagesSkipProtectedDays() throws {
        var d = Driver()
        try d.run(to: 14, phase: .evening)
        d.env.state.trust = 20
        d.env.state.complaint = nil
        d.env.state.complaintsStarted = 0
        d.env.state.flags.insert("grievance.workload")
        try d.settle()
        let c = try #require(d.s.complaint)
        #expect(c.startDay == 14)
        #expect(c.signsDay == 15)
        #expect(c.petitionDay == 17)
        #expect(c.voteDay == 18)
    }

    @Test func dayCheckpointRestoreMovesRevisionForward() throws {
        var d = Driver()
        try d.run(to: 3, phase: .anchor)
        let rev = d.s.revision
        let cash = d.s.cash
        try d.choose("raise")
        try d.send(.restoreDayCheckpoint)
        #expect(d.s.day == 3)
        #expect(d.s.revision == rev + 2)
        #expect(d.s.incomes["dues"] == nil)
        #expect(d.env.metadata.rewindCount == 1)
        #expect(d.s.cash >= cash - 1_000_000)
        #expect(d.s.seed == 42)
    }

    @Test func firstGuessSurvivesRewind() throws {
        var d = Driver()
        try d.run(to: 7, phase: .recap)
        try d.send(.recordGuess(.sevim))
        try d.send(.finishDay)
        try d.send(.restoreChapterCheckpoint)
        #expect(d.env.metadata.firstGuess == .sevim)
        #expect(d.env.metadata.firstGuessRecorded)
    }

    @Test func recapShowsThatDaysOwnPromise() throws {
        var d = Driver()
        try d.run(to: 1, phase: .recap)
        let note = d.engine.present(d.env).recap?.nextDayNote
        #expect(note == sharedContent.dayDefinition(1)?.promise)
    }

    @Test func switchingMandateBackAndForthGivesTrustOnce() {
        var s = Driver().s
        s.trust = 40
        var notes: [String] = []
        let e = Engine(content: sharedContent)
        func set(_ m: String, _ amount: Int64) {
            e.apply(Effect(kind: .setMandate, target: nil, amount: amount, value: m), to: &s, notes: &notes, deferred: false)
        }
        set("shared", 3)
        set("central", -2)
        set("shared", 3)
        #expect(s.trust == 41)
    }

    @Test func trustCannotEndTheGameInTheFreeWeek() throws {
        var d = Driver()
        try d.run(to: 4, phase: .evening)
        d.env.state.trust = 0
        try d.settle()
        #expect(d.s.ending == nil)
        #expect(d.s.trust == 1)
    }
}
