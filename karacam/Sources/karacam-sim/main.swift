import Foundation
import KaracamCore

// Gerçek motorla denge denemesi: stratejiler × işletmeler × vakalar × tohumlar.
// Kullanım: swift run karacam-sim [tohum sayısı]

let seeds = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 40 : 40
let content = try GameContent.bundled()
let engine = Engine(content: content)
let player = Autoplayer(engine: engine)

func tl(_ k: Kurus) -> String { Money.format(k) }

print("Karaçam denge denemesi — içerik \(content.contentVersion), \(seeds) tohum/hücre\n")
print("strateji      işletme vaka   | köy  birl satış kasa güven baskı | ort.kasa(ödeme önc.) min.kasa  çözüm  güven60 | takılma")
var stuckLines: [String] = []
var totals: [Ending: Int] = [:]
for business in ["spa", "bees"] {
    for strategy in Strategy.presets(business: business) {
        for suspect in SuspectID.allCases {
            var counts: [Ending: Int] = [:]
            var cashSum: Int64 = 0
            var minCash: Int64 = .max
            var resolved = 0
            var trust60Days: [Int] = []
            var stuck = 0
            for i in 0..<seeds {
                let seed = UInt64(1000 + i) &* 7919
                let r = player.play(seed: seed, strategy: strategy, caseOverride: suspect)
                counts[r.ending, default: 0] += 1
                totals[r.ending, default: 0] += 1
                cashSum += r.cashBeforePayment
                minCash = min(minCash, r.minCash)
                if r.caseResolved { resolved += 1 }
                if let d = r.firstDayTrust60 { trust60Days.append(d) }
                if let s = r.stuck {
                    stuck += 1
                    if stuckLines.count < 20 { stuckLines.append("\(strategy.name)/\(business)/\(suspect): \(s)") }
                }
            }
            func c(_ e: Ending) -> String { String(format: "%4d", counts[e] ?? 0) }
            let avgTrust60 = trust60Days.isEmpty ? "  —" : String(format: "%4.1f", Double(trust60Days.reduce(0, +)) / Double(trust60Days.count))
            let name = strategy.name.padding(toLength: 13, withPad: " ", startingAt: 0)
            print("\(name) \(business.padding(toLength: 7, withPad: " ", startingAt: 0)) \(suspect.rawValue.padding(toLength: 6, withPad: " ", startingAt: 0)) |\(c(.cooperative))\(c(.together))\(c(.sale))\(c(.cash))\(c(.trust))\(c(.pressure)) | \(tl(cashSum / Int64(seeds)).padding(toLength: 20, withPad: " ", startingAt: 0)) \(tl(minCash).padding(toLength: 10, withPad: " ", startingAt: 0)) \(String(format: "%3d", resolved))/\(seeds)  \(avgTrust60)    | \(stuck)")
        }
    }
}
print("\nToplam sonlar: " + Ending.allCases.map { "\($0.rawValue) \(totals[$0] ?? 0)" }.joined(separator: ", "))
if !stuckLines.isEmpty {
    print("\nTakılmalar:")
    stuckLines.forEach { print("  " + $0) }
}
