import SwiftUI
import KaracamCore
import KaracamAppModel

/// Defter: üstte üç satır (hedef, sıradaki taahhüt, açık soru); altında hesap, insanlar, kanıt, geçmiş.
struct DefterView: View {
    @Environment(GameStore.self) private var game
    @Environment(TabRouter.self) private var router

    enum Page: String, CaseIterable, Identifiable {
        case accounts = "Hesap"
        case people = "İnsanlar"
        case evidence = "Kanıt"
        case history = "Geçmiş"
        var id: Self { self }
    }

    var body: some View {
        @Bindable var router = router
        ScrollView {
            if let p = game.presentation {
                let n = p.notebook
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        topLine("target", n.goalLine)
                        topLine("calendar", n.commitmentLine)
                        topLine("questionmark.circle", n.questionLine)
                    }
                    .paperCard()
                    Picker("Bölüm", selection: $router.defterPage) {
                        ForEach(Page.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    switch router.defterPage {
                    case .accounts: accounts(n)
                    case .people: people(n, revision: p.revision, open: p.ending == nil)
                    case .evidence: evidence(n, today: p.day)
                    case .history: history(n)
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.paper)
        .navigationTitle("Defter")
        .navigationBarTitleDisplayMode(.inline)
        .paperNavigationBar()
    }

    private func topLine(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.moss)
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(Theme.heading(.headline)).padding(.top, 4)
    }

    @ViewBuilder
    private func accounts(_ n: NotebookPresentation) -> some View {
        EveningCard(evening: n.today)
        VStack(alignment: .leading, spacing: 8) {
            heading("30. gün ödeme öncesi kasa (tahmin)")
            Text(n.projection).font(.title2.monospacedDigit().weight(.bold))
            Text(n.projectionNote).font(.footnote).foregroundStyle(Theme.secondary)
        }
        .paperCard()
        VStack(alignment: .leading, spacing: 8) {
            heading("Süren gelirler (brüt)")
            if n.incomes.isEmpty { Text("Henüz düzenli gelir yok.").font(.callout).foregroundStyle(Theme.secondary) }
            ForEach(n.incomes) { LineRow(line: $0) }
            heading("Süren giderler")
            if n.expenses.isEmpty { Text("Düzenli gider yok.").font(.callout).foregroundStyle(Theme.secondary) }
            ForEach(n.expenses) { LineRow(line: $0) }
        }
        .paperCard()
        if !n.commitments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                heading("Verilen sözler")
                ForEach(n.commitments) { LineRow(line: $0) }
            }
            .paperCard()
        }
    }

    @ViewBuilder
    private func people(_ n: NotebookPresentation, revision: Int, open: Bool) -> some View {
        if n.people.isEmpty {
            Text("Henüz kimseyle tanışmadın.").font(.callout).foregroundStyle(Theme.secondary)
        }
        ForEach(n.people) { person in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    if let portrait = person.portrait {
                        Image(portrait)
                            .resizable().scaledToFill()
                            .frame(width: 76, height: 76)
                            .background(Theme.paper)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Theme.charcoal.opacity(0.12)))
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name).font(Theme.heading(.title3))
                        Text(person.role).font(.footnote).foregroundStyle(Theme.secondary)
                        if person.eliminated == true {
                            Label("Şüpheden çıkardın", systemImage: "checkmark.seal.fill")
                                .font(.caption.weight(.semibold)).foregroundStyle(Theme.moss)
                        }
                    }
                    Spacer()
                }
                ForEach(person.notes, id: \.self) { Text("• " + $0).font(.callout) }
                if let eliminated = person.eliminated, open, let id = SuspectID(rawValue: person.id) {
                    Toggle(isOn: Binding(get: { eliminated }, set: { _ in
                        Task { await game.send(.toggleElimination(id), revision: revision) }
                    })) {
                        Text("Kendi notum: şüpheden çıkardım").font(.callout)
                    }
                    .frame(minHeight: 44)
                }
            }
            .paperCard()
            .opacity(person.eliminated == true ? 0.75 : 1)
        }
    }

    private func evidenceSymbol(_ kindLabel: String) -> String {
        switch kindLabel {
        case "İz": "pawprint.fill"
        case "Belge": "doc.text.fill"
        case "İmza": "signature"
        case "Tarih": "clock.fill"
        case "Tanıklı teslim": "seal.fill"
        case "İfade": "quote.bubble.fill"
        case "Yer": "mappin.and.ellipse"
        default: "doc.fill"
        }
    }

    @ViewBuilder
    private func evidence(_ n: NotebookPresentation, today: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(n.fileLine).font(.callout.weight(.semibold))
            Text(n.candidatesLine).font(.callout)
            Text(n.authorityLine).font(.callout)
            if let guess = n.firstGuessLine { Text(guess).font(.footnote).foregroundStyle(Theme.secondary) }
        }
        .paperCard()
        if n.evidence.isEmpty {
            Text("Henüz kayda geçmiş kanıt yok.").font(.callout).foregroundStyle(Theme.secondary)
        }
        ForEach(n.evidence.reversed()) { e in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: evidenceSymbol(e.kindLabel))
                    .font(.title3)
                    .foregroundStyle(Theme.paper)
                    .frame(width: 44, height: 44)
                    .background(e.reliabilityLabel == "Doğrulanmış" ? Theme.moss : Theme.charcoal.opacity(0.75),
                                in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(e.title).font(.headline)
                        if e.day == today {
                            Text("Yeni").font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .foregroundStyle(Theme.moss)
                                .background(Theme.moss.opacity(0.12), in: Capsule())
                        }
                    }
                    Text("\(e.kindLabel) · \(e.reliabilityLabel) · \(e.day). gün")
                        .font(.caption).foregroundStyle(Theme.secondary)
                    Text(e.text).font(.system(.callout, design: .serif)).fixedSize(horizontal: false, vertical: true)
                }
            }
            .paperCard()
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func history(_ n: NotebookPresentation) -> some View {
        if n.history.isEmpty {
            Text("Henüz kayıtlı karar yok.").font(.callout).foregroundStyle(Theme.secondary)
        }
        ForEach(n.history) { line in
            HStack(alignment: .firstTextBaseline) {
                Text(line.amount).font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(Theme.secondary)
                    .frame(width: 56, alignment: .leading)
                Text(line.label).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
