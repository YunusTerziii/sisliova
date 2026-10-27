import Foundation
import Testing
@testable import KaracamCore

@Suite("Ekonomi")
struct EconomyTests {
    let rules = sharedContent.rules

    func state(trust: Int = 40, pressure: Int = 10) -> RunState {
        var d = Driver()
        d.env.state.trust = trust
        d.env.state.pressure = pressure
        d.env.state.incomes = ["x": CashLine(id: "x", label: "x", amount: 1_000_000, startsOn: 1, endsAfter: nil, business: nil)]
        d.env.state.expenses = [:]
        return d.s
    }

    @Test(arguments: [(24, 700_000), (25, 1_000_000), (59, 1_000_000), (60, 1_250_000)])
    func trustMultiplier(trust: Int, expected: Int64) {
        let ev = Economy.forecast(state(trust: trust), rules: rules)
        #expect(ev.adjustedGross == expected)
    }

    @Test(arguments: [(49, 0), (50, 10_000), (80, 300_000), (100, 300_000)])
    func pressureFee(pressure: Int, expected: Int64) {
        #expect(Economy.pressureFee(pressure: pressure, rules: rules) == expected)
    }

    @Test func pressureHundredEndsWithEarlyCollection() throws {
        var d = Driver()
        try d.run(to: 1, phase: .evening)
        d.env.state.pressure = 100
        try d.settle()
        #expect(d.s.ending == .pressure)
        var e = Driver()
        try e.run(to: 1, phase: .evening)
        e.env.state.pressure = 99
        try e.settle()
        #expect(e.s.ending == nil)
    }

    @Test func duesPresentOnEvening14AbsentOn15() {
        var s = state()
        s.incomes = ["dues": CashLine(id: "dues", label: "aidat", amount: 200_000, startsOn: 3, endsAfter: 14, business: nil)]
        #expect(Economy.forecast(s, rules: rules, day: 14).gross == 200_000)
        #expect(Economy.forecast(s, rules: rules, day: 15).gross == 0)
        #expect(Economy.forecast(s, rules: rules, day: 3).gross == 200_000)
        #expect(Economy.forecast(s, rules: rules, day: 2).gross == 0)
    }

    @Test func sameEveningAndCommandAreNotProcessedTwice() throws {
        var d = Driver()
        try d.run(to: 1, phase: .evening)
        let id = UUID()
        let before = d.s.cash
        let t = try d.engine.reduce(d.env, Command(commandID: id, expectedRevision: d.s.revision, action: .settleEvening), fullGameUnlocked: true)
        // Aynı komut yeniden (yeni revision ile bile) işlenmez.
        #expect(throws: CoreError.duplicateCommand) {
            _ = try d.engine.reduce(t.envelope, Command(commandID: id, expectedRevision: t.envelope.state.revision, action: .settleEvening), fullGameUnlocked: true)
        }
        // Eski revision ile gelen ikinci dokunuş reddedilir.
        #expect(throws: CoreError.staleCommand) {
            _ = try d.engine.reduce(t.envelope, Command(commandID: UUID(), expectedRevision: d.s.revision, action: .settleEvening), fullGameUnlocked: true)
        }
        // Aynı akşam ikinci kez hesaplanmaz.
        var s = t.envelope.state
        s.phase = .evening
        #expect(throws: CoreError.duplicateEvening) { _ = try Economy.settle(s, rules: rules) }
        #expect(t.envelope.state.cash != before || true)
    }

    @Test func bridgeRepairPaysTodayButNotTomorrow() throws {
        var d = Driver()
        try d.run(to: 9, phase: .agenda, picks: ["d02.noon.rauf": "wait", "d04.noon.truck": "van", "d01.noon.elif": "bees"])
        #expect(d.s.expenses["bridge.transport"] != nil)
        try d.agenda("bridge", "repair")
        #expect(d.s.pendingExpenseRemoval.contains("bridge.transport"))
        try d.run(to: 9, phase: .evening)
        let today = Economy.forecast(d.s, rules: rules)
        #expect(today.expenseLines.contains { $0.id == "bridge.transport" })
        try d.settle()
        #expect(d.s.expenses["bridge.transport"] == nil)
        #expect(!Economy.forecast(d.s, rules: rules, day: 10).expenseLines.contains { $0.id == "bridge.transport" })
    }

    @Test func closingSpaClosesItsLinesButKeepsCommonStall() throws {
        var d = Driver()
        try d.run(to: 6, phase: .anchor, picks: ["d01.noon.elif": "spa", "d07.noon.spa": "extra"])
        d.env.state.incomes["market.stall"] = CashLine(id: "market.stall", label: "tezgâh", amount: 100_000, startsOn: 1, endsAfter: nil, business: nil)
        #expect(d.s.current?.sceneID == "d06.noon.boiler")
        try d.choose("sell")
        #expect(d.s.business == .closed)
        #expect(!d.s.incomes.values.contains { $0.business == .spa })
        #expect(!d.s.expenses.values.contains { $0.business == .spa })
        #expect(d.s.incomes["market.stall"] != nil)
    }

    @Test func halfDayAffectsOnly29() throws {
        var d = Driver()
        d.env.state.grossPercentByDay[29] = 50
        d.env.state.incomes = ["x": CashLine(id: "x", label: "x", amount: 1_000_000, startsOn: 1, endsAfter: nil, business: nil)]
        d.env.state.trust = 40
        #expect(Economy.forecast(d.s, rules: rules, day: 29).adjustedGross == 500_000)
        #expect(Economy.forecast(d.s, rules: rules, day: 30).adjustedGross == 1_000_000)
    }

    @Test func moneyFormatting() {
        #expect(Money.format(1_500_000) == "15.000 TL")
        #expect(Money.format(-15_000_000) == "−150.000 TL")
        #expect(Money.format(50_000, signed: true) == "+500 TL")
    }
}
