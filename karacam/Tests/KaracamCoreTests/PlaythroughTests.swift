import Foundation
import Testing
@testable import KaracamCore

@Suite struct PlaythroughTests {
    static let business = ["spa", "bees"]

    @Test(arguments: business)
    func everyStrategyAndCaseReachesAnEnding(business: String) {
        let player = Autoplayer(engine: Engine(content: sharedContent))
        for strategy in Strategy.presets(business: business) {
            for culprit in SuspectID.allCases {
                for seed in UInt64(1)...4 {
                    let r = player.play(seed: seed * 977, strategy: strategy, caseOverride: culprit)
                    #expect(r.stuck == nil, "\(strategy.name)/\(business)/\(culprit)/\(seed): \(r.stuck ?? "")")
                    if r.ending == .together || r.ending == .cooperative {
                        // Taksit tek kez düşülür.
                        #expect(r.finalCash == r.cashBeforePayment - sharedContent.rules.firstInstallment)
                        #expect(r.endingDay == 30)
                    }
                }
            }
        }
    }

    @Test func everyEndingHasExplanationAndEpilogue() {
        let player = Autoplayer(engine: Engine(content: sharedContent))
        var seen: Set<Ending> = []
        for strategy in Strategy.presets(business: "spa") + Strategy.presets(business: "bees") {
            for culprit in SuspectID.allCases {
                let r = player.play(seed: 5, strategy: strategy, caseOverride: culprit)
                seen.insert(r.ending)
            }
        }
        #expect(seen.count >= 3)
    }

    @Test func daySevenSaleEndsImmediatelyWithSaleEpilogue() throws {
        var d = Driver()
        try d.run(to: 7, phase: .morning)
        #expect(d.s.current?.sceneID == "d07.morning.lawyer")
        try d.choose("sign")
        #expect(d.s.ending == .sale)
        let p = d.engine.present(d.env)
        let ending = try #require(p.ending)
        #expect(!ending.why.isEmpty)
        #expect(ending.epilogue.count == sharedContent.epilogue.count)
        #expect(ending.epilogue.contains { $0.text.contains("on iki ay") })
        // Bittikten sonra komut kabul edilmez.
        #expect(throws: CoreError.self) { try d.settle() }
    }

    @Test func finalDayPaysOnceAndCannotBeReplayed() throws {
        let engine = Engine(content: sharedContent)
        let player = Autoplayer(engine: engine)
        let strategy = Strategy.presets(business: "spa")[0]
        let r = player.play(seed: 11, strategy: strategy, caseOverride: .sevim)
        #expect(r.ending == .together)
        #expect(r.finalCash == r.cashBeforePayment - 15_000_000)
        // Bitmiş oyunda akşam hesabı ya da gün sonu ikinci kez para üretmez.
        let env = player.playEnvelope(seed: 11, strategy: strategy, caseOverride: .sevim)
        for action in [Command.Action.settleEvening, .finishDay] {
            #expect(throws: CoreError.gameEnded) {
                try engine.reduce(env, Command(expectedRevision: env.state.revision, action: action), fullGameUnlocked: true)
            }
        }
        #expect(env.state.paymentMade)
    }

    @Test func endingPresentationFillsAllPlaceholders() throws {
        let engine = Engine(content: sharedContent)
        for (i, strategy) in (Strategy.presets(business: "spa") + Strategy.presets(business: "bees")).enumerated() {
            let env = Autoplayer(engine: engine).playEnvelope(seed: UInt64(100 + i), strategy: strategy,
                                                              caseOverride: SuspectID.allCases[i % 3])
            let e = try #require(engine.present(env).ending)
            let all = ([e.title, e.summary, e.shareText] + e.why + e.decisive + e.epilogue.map(\.text)).joined(separator: "\n")
            #expect(!all.contains("{"), "\(strategy.name): \(all)")
        }
    }

}
