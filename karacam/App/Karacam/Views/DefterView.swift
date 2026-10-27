import SwiftUI
import KaracamCore
import KaracamAppModel

/// Defter: üstte üç satır (hedef, sıradaki taahhüt, açık soru); altında hesap, insanlar, kanıt, geçmiş.
struct DefterView: View {
    @Environment(GameStore.self) private var game
    @State private var page: Page = .accounts

    enum Page: String, CaseIterable, Identifiable {
        case accounts = "Hesap"
        case people = "İnsanlar"
        case evidence = "Kanıt"
        case history = "Geçmiş"
        var id: Self { self }
    }

    var body: some View {
        ScrollView {
            if let p = game.presentation {
                let n = p.notebook
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        topLine("target", n.goalLine)
                        topLine("calendar", n.commitmentLine)
                        topLine("questionmark.circle", n.questionLine)
                    }
                    .paperCard()
                    Picker("Bölüm", selection: $page) {
                        ForEach(Page.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    switch page {
                    case .accounts: accounts(n)
                    case .people: people(n, revision: p.revision, open: p.ending == nil)
                    case .evidence: evidence(n)
                    case .history: history(n)
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.paper)
        .navigationTitle("Defter")
        .navigationBarTitleDisplayMode(.inline)
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
            heading("Bugünkü koşullar değişmezse")
            Text(n.projection).font(.title3.monospacedDigit().weight(.semibold))
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
                heading("Taahhütler")
                ForEach(n.commitments) { LineRow(line: $0) }
            }
            .paperCard()
        }
    }

    @ViewBuilder
    private func people(_ n: NotebookPresentation, revision: Int, open: Bool) -> some View {
        ForEach(n.people) { person in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    if let portrait = person.portrait {
                        Image(portrait)
                            .resizable().scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading) {
                        Text(person.name).font(.headline)
                        Text(person.role).font(.footnote).foregroundStyle(Theme.secondary)
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
        }
    }

    @ViewBuilder
    private func evidence(_ n: NotebookPresentation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(n.fileLine).font(.callout.weight(.semibold))
            Text(n.candidatesLine).font(.callout)
            Text(n.authorityLine).font(.callout)
            if let guess = n.firstGuessLine { Text(guess).font(.footnote).foregroundStyle(Theme.secondary) }
        }
        .paperCard()
        if n.evidence.isEmpty {
            Text("Henüz kayda geçmiş kanıt yok.").font(.callout).foregroundStyle(Theme.secondary)
        }
        ForEach(n.evidence) { e in
            VStack(alignment: .leading, spacing: 4) {
                Text(e.title).font(.headline)
                Text("\(e.kindLabel) · \(e.reliabilityLabel) · \(e.day). gün")
                    .font(.caption).foregroundStyle(Theme.secondary)
                Text(e.text).font(.callout).fixedSize(horizontal: false, vertical: true)
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
        ForEach(Array(n.history.reversed())) { line in
            HStack(alignment: .firstTextBaseline) {
                Text(line.amount).font(.caption.monospacedDigit()).foregroundStyle(Theme.secondary)
                    .frame(width: 52, alignment: .leading)
                Text(line.label).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
