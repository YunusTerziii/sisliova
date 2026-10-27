import SwiftUI
import KaracamCore
import KaracamAppModel

/// Masa: kompakt kasa/güven/baskı, portre, başlık, metin ve iki büyük somut eylem.
struct MasaView: View {
    @Environment(GameStore.self) private var game
    @Environment(Preferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var showSettings = false
    @State private var rewind: RewindKind?

    enum RewindKind {
        case day, chapter
    }

    var body: some View {
        if let p = game.presentation {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HUDView(p: p)
                    if let ending = p.ending {
                        EndingView(ending: ending, canRewindChapter: p.canRewindChapter) { rewind = .chapter }
                    } else {
                        if let last = p.lastOutcome, p.phase != .recap {
                            OutcomeCard(outcome: last)
                        }
                        phaseContent(p)
                    }
                }
                .padding(16)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: p.revision)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Theme.paper)
            .navigationTitle("\(p.day). gün · \(p.dayTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Günün başına dön", systemImage: "arrow.uturn.backward") { rewind = .day }
                            .disabled(!p.canRewindDay)
                        Button("Bölüm başına dön", systemImage: "backward.end") { rewind = .chapter }
                            .disabled(!p.canRewindChapter)
                        Divider()
                        Button("Ana ekran", systemImage: "house") { game.returnToTitle() }
                        Button("Ayarlar", systemImage: "gearshape") { showSettings = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Menü")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .alert(rewind == .chapter ? "Bölüm başına dönülsün mü?" : "Günün başına dönülsün mü?",
                   isPresented: Binding(get: { rewind != nil }, set: { if !$0 { rewind = nil } }),
                   presenting: rewind) { kind in
                Button("Geri dön", role: .destructive) {
                    Task { await game.send(kind == .day ? .restoreDayCheckpoint : .restoreChapterCheckpoint) }
                }
                Button("Vazgeç", role: .cancel) {}
            } message: { _ in
                Text("Sonraki kararların geri alınır. Vaka ve tohum değişmez; ilk tahminin ve tam oyun hakkın korunur.")
            }
        } else {
            ProgressView()
        }
    }

    private var reduceMotion: Bool { preferences.reduceMotion || systemReduceMotion }

    @ViewBuilder
    private func phaseContent(_ p: PlayPresentation) -> some View {
        switch p.phase {
        case .morning, .anchor, .night:
            if let scene = p.scene {
                SceneCard(scene: scene) { choice in
                    guard let id = scene.instanceID else { return }
                    Task {
                        await game.send(.choose(sceneID: scene.sceneID, instanceID: id, choiceID: choice.id),
                                        revision: p.revision)
                    }
                }
            }
        case .agenda:
            if let agenda = p.agenda { AgendaView(agenda: agenda, revision: p.revision) }
        case .evening:
            if let evening = p.evening {
                EveningCard(evening: evening)
                Button("Akşam hesabını kapat") {
                    Task { await game.send(.settleEvening, revision: p.revision) }
                }
                .buttonStyle(ActionButtonStyle())
                .disabled(game.isBusy)
            }
        case .recap:
            if let recap = p.recap { RecapView(p: p, recap: recap) }
        case .ended:
            EmptyView()
        }
    }
}

// MARK: Üst bilgi

struct HUDView: View {
    let p: PlayPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(p.chapterTitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Text("\(p.finalDay - p.day) gün kaldı")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { stats }
                VStack(alignment: .leading, spacing: 6) { stats }
            }
            Text(p.businessLabel)
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
        }
        .paperCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var stats: some View {
        stat("Kasa", p.cash, note: nil, color: p.cashValue < 0 ? Theme.rust : Theme.charcoal)
        stat("Güven", "\(p.trust)", note: p.trustNote, color: p.trust < 25 ? Theme.rust : (p.trust >= 60 ? Theme.moss : Theme.charcoal))
        stat("Baskı", "\(p.pressure)", note: p.pressureNote, color: p.pressure >= 50 ? Theme.rust : Theme.charcoal)
    }

    private func stat(_ label: String, _ value: String, note: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(Theme.secondary)
            Text(value).font(.title3.monospacedDigit().weight(.semibold)).foregroundStyle(color)
            if let note, !note.isEmpty {
                Text(note).font(.caption2).foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OutcomeCard: View {
    let outcome: Outcome

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(outcome.sceneTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondary)
            Text(outcome.text).font(.callout)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.moss.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

// MARK: Sahne

struct SceneCard: View {
    @Environment(GameStore.self) private var game
    let scene: ScenePresentation
    let onChoose: (ChoicePresentation) -> Void
    @State private var pendingConfirm: ChoicePresentation?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                if let portrait = scene.speaker.portrait {
                    Image(portrait)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Theme.charcoal.opacity(0.15)))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(scene.slotLabel.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.secondary)
                    Text(scene.speaker.name).font(.headline)
                    if !scene.speaker.role.isEmpty {
                        Text(scene.speaker.role).font(.footnote).foregroundStyle(Theme.secondary)
                    }
                }
            }
            Text(scene.title).font(Theme.heading())
            if scene.speaker.portrait == nil || scene.illustration != nil {
                IllustrationRow(assets: Theme.illustrationAssets(scene.illustration ?? fallbackIllustration))
            }
            Text(scene.body)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                ForEach(Array(scene.choices.enumerated()), id: \.element.id) { index, choice in
                    ChoiceButton(choice: choice, prominent: index == 0) {
                        if choice.confirm != nil { pendingConfirm = choice } else { onChoose(choice) }
                    }
                    .disabled(!choice.enabled || game.isBusy)
                }
            }
        }
        .paperCard()
        .alert("Emin misin?", isPresented: Binding(get: { pendingConfirm != nil }, set: { if !$0 { pendingConfirm = nil } }),
               presenting: pendingConfirm) { choice in
            Button("Evet") { onChoose(choice) }
            Button("Vazgeç", role: .cancel) {}
        } message: { choice in
            Text(choice.confirm ?? "")
        }
    }

    /// Portresi olmayan konuşmacı için harfli daire yerine yer çizimi (ör. Derya → kaplıca).
    private var fallbackIllustration: String? {
        switch scene.speaker.id {
        case "derya": return "kaplica"
        case "kamyon": return "kamyon"
        case "araba": return "araba"
        default: return nil
        }
    }
}

struct IllustrationRow: View {
    let assets: [String]

    var body: some View {
        if !assets.isEmpty {
            HStack(spacing: 8) {
                ForEach(assets, id: \.self) { name in
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 150)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
        }
    }
}

struct ChoiceButton: View {
    let choice: ChoicePresentation
    var prominent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(choice.label)
                if !choice.badges.isEmpty {
                    Text(choice.badges.joined(separator: " · "))
                        .font(.footnote.weight(.regular))
                        .opacity(0.85)
                }
                ForEach(choice.preview, id: \.self) { line in
                    Text(line).font(.footnote.weight(.regular)).opacity(0.85)
                }
                if let reason = choice.disabledReason, !choice.enabled {
                    Text(reason).font(.footnote.weight(.regular))
                }
            }
        }
        .buttonStyle(ActionButtonStyle(prominent: prominent && choice.enabled))
        .accessibilityHint(choice.confirm != nil ? "Onay ister" : "")
    }
}

// MARK: Gündem

struct AgendaView: View {
    @Environment(GameStore.self) private var game
    let agenda: AgendaPresentation
    let revision: Int
    @State private var open: AgendaEntry?
    @State private var showAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bu sabah ne yapacaksın?").font(Theme.heading())
            Text("Bir işi açmak sabahı harcamaz; seçim yapınca sabah kullanılır.")
                .font(.footnote).foregroundStyle(Theme.secondary)
            if let due = agenda.dueNote {
                Label(due, systemImage: "calendar.badge.exclamationmark")
                    .font(.callout)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.rust.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
            ForEach(agenda.suggested) { entry in row(entry) }
            DisclosureGroup("Bütün gündem (\(agenda.all.count))", isExpanded: $showAll) {
                VStack(spacing: 8) {
                    ForEach(agenda.all) { entry in row(entry) }
                }
                .padding(.top, 8)
            }
            .frame(minHeight: 44)
        }
        .sheet(item: $open) { entry in
            NavigationStack {
                ScrollView {
                    SceneCard(scene: entry.scene) { choice in
                        Task {
                            if await game.send(.chooseAgenda(itemID: entry.id, choiceID: choice.id), revision: revision) {
                                open = nil
                            }
                        }
                    }
                    .padding(16)
                }
                .background(Theme.paper)
                .navigationTitle(entry.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Kapat") { open = nil } }
                }
            }
        }
    }

    private func row(_ entry: AgendaEntry) -> some View {
        Button { open = entry } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.title).font(.headline)
                    if entry.isNew { tag("Yeni", Theme.moss) }
                    if entry.closesToday { tag("Bugün son", Theme.rust) }
                }
                Text(entry.summary).font(.callout).foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.windowNote).font(.caption).foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .foregroundStyle(color)
            .overlay(Capsule().strokeBorder(color.opacity(0.6)))
    }
}

// MARK: Akşam

struct EveningCard: View {
    let evening: EveningPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(evening.day). akşam hesabı").font(Theme.heading())
            ForEach(evening.incomeLines) { LineRow(line: $0) }
            Divider()
            LineRow(label: "Brüt", amount: evening.gross, note: evening.multiplierNote)
            LineRow(label: "Kasaya giren brüt", amount: evening.adjustedGross)
            ForEach(evening.expenseLines) { LineRow(line: $0) }
            if let fee = evening.pressureFee {
                LineRow(label: "Alacaklı baskı kesintisi", amount: fee)
            }
            Divider()
            HStack {
                Text(evening.settled ? "Net" : "Tahmini net").font(.headline)
                Spacer()
                Text(evening.net)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(evening.netValue < 0 ? Theme.rust : Theme.moss)
            }
            .accessibilityElement(children: .combine)
        }
        .paperCard()
    }
}

struct LineRow: View {
    let label: String
    let amount: String
    var note: String?

    init(label: String, amount: String, note: String? = nil) {
        self.label = label
        self.amount = amount
        self.note = note
    }

    init(line: LinePresentation) {
        self.init(label: line.label, amount: line.amount, note: line.note)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.callout)
                if let note { Text(note).font(.caption).foregroundStyle(Theme.secondary) }
            }
            Spacer(minLength: 12)
            Text(amount).font(.callout.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Gün sonu

struct RecapView: View {
    @Environment(GameStore.self) private var game
    @Environment(EntitlementStore.self) private var entitlements
    let p: PlayPresentation
    let recap: RecapPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(recap.day). günün sonu").font(Theme.heading())
            if !recap.memories.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(recap.memories, id: \.self) { Text("• " + $0).font(.callout) }
                }
                .paperCard()
            }
            if let evening = recap.evening { EveningCard(evening: evening) }
            if let chapter = recap.chapter {
                VStack(alignment: .leading, spacing: 8) {
                    Text(chapter.title).font(Theme.heading(.title3))
                    ForEach(chapter.lines, id: \.self) { Text($0).font(.callout) }
                    if !chapter.changes.isEmpty {
                        Text("Bu bölümde değişenler").font(.subheadline.weight(.semibold)).padding(.top, 4)
                        ForEach(chapter.changes, id: \.self) { Text("• " + $0).font(.callout) }
                    }
                }
                .paperCard()
            }
            if p.guessPrompt {
                GuessView(revision: p.revision)
            } else {
                if let next = recap.nextDayNote {
                    Text(next).font(.callout).foregroundStyle(Theme.secondary)
                }
                if p.gateAhead && !entitlements.isUnlocked {
                    Text("İlk bölüm burada bitiyor. Hikâyenin kalanı tek seferlik satın almayla açılır; kaydın korunur.")
                        .font(.callout)
                        .paperCard()
                    Button("Tam oyunu aç") { game.paywallRequested = true }
                        .buttonStyle(ActionButtonStyle())
                } else {
                    Button("Günü bitir") {
                        Task { await game.send(.finishDay, revision: p.revision) }
                    }
                    .buttonStyle(ActionButtonStyle())
                    .disabled(game.isBusy)
                }
            }
        }
    }
}

/// 7. akşam ilk tahmin. Yanlış tahmin dosyayı kilitlemez; "bilmiyorum" da bir cevaptır.
struct GuessView: View {
    @Environment(GameStore.self) private var game
    let revision: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("İlk tahminin").font(Theme.heading(.title3))
            Text("Satış yetkisini kim imzaladı sence? Tahminin yalnız kayda geçer; kimseyi suçlamaz, sonradan fikrini değiştirebilirsin.")
                .font(.callout)
            ForEach(game.presentation?.notebook.people.filter { $0.eliminated != nil } ?? []) { person in
                Button(person.name) { guess(SuspectID(rawValue: person.id)) }
                    .buttonStyle(ActionButtonStyle(prominent: false))
            }
            Button("Henüz bilmiyorum") { guess(nil) }
                .buttonStyle(ActionButtonStyle(prominent: false))
        }
        .paperCard()
    }

    private func guess(_ who: SuspectID?) {
        Task { await game.send(.recordGuess(who), revision: revision) }
    }
}
