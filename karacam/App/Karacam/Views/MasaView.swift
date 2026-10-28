import SwiftUI
import KaracamCore
import KaracamAppModel

/// Masa: üstte köyün durumu, altında o anki sahne. Sahne büyük bir dekor ve portreyle açılır;
/// gece sahneleri karanlık karttadır. Akşam hesabı kendiliğinden kapanır, gün sonunda okunur.
struct MasaView: View {
    @Environment(GameStore.self) private var game
    @Environment(Preferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var showSettings = false
    @State private var rewind: RewindKind?
    @State private var letter: Outcome?
    @State private var shownLetterRevision: Int?

    enum RewindKind {
        case day, chapter
    }

    static let letterSceneID = "d07.night.letter"

    var body: some View {
        if let p = game.presentation {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HUDView(p: p).id("top")
                        if let ending = p.ending {
                            EndingView(ending: ending, canRewindChapter: p.canRewindChapter) { rewind = .chapter }
                        } else {
                            if let last = p.lastOutcome, p.phase != .recap, p.phase != .evening {
                                OutcomeCard(outcome: last)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            phaseContent(p)
                        }
                    }
                    .padding(16)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: p.revision)
                }
                .onChange(of: p.revision) { _, _ in
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { proxy.scrollTo("top", anchor: .top) }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .paperNavigationBar()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("\(p.day). GÜN").font(.caption2.weight(.bold)).foregroundStyle(Theme.secondary)
                        Text(p.dayTitle).font(.system(.headline, design: .serif)).lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                }
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
            .fullScreenCover(item: $letter) { outcome in
                LetterScreen(outcome: outcome) { letter = nil }
            }
            .task(id: p.revision) { await advance(p) }
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

    /// Akşam hesabında karar yok: kısa bir an gösterilir ve kendiliğinden kapanır.
    /// Halanın mektubu okunduğunda bir kez tam ekran açılır.
    private func advance(_ p: PlayPresentation) async {
        if p.phase == .evening {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 900))
            guard !Task.isCancelled else { return }
            await game.send(.settleEvening, revision: p.revision)
        } else if p.phase == .recap, let last = p.lastOutcome, last.sceneID == Self.letterSceneID,
                  shownLetterRevision != p.revision {
            shownLetterRevision = p.revision
            letter = last
        }
    }

    @ViewBuilder
    private func phaseContent(_ p: PlayPresentation) -> some View {
        switch p.phase {
        case .morning, .anchor, .night:
            if let scene = p.scene {
                SceneCard(scene: scene, night: p.phase == .night) { choice in
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
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Akşam oluyor, Sevim kasayı sayıyor…")
                            .font(.system(.body, design: .serif).italic())
                    }
                    EveningCard(evening: evening)
                    Button("Akşam hesabını kapat") {
                        Task { await game.send(.settleEvening, revision: p.revision) }
                    }
                    .buttonStyle(ActionButtonStyle(prominent: false))
                    .disabled(game.isBusy)
                }
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
    @State private var showNotes = false

    private let installment: Double = 15_000_000

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(p.chapterTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Text(p.finalDay - p.day == 0 ? "Ödeme günü" : "Ödemeye \(p.finalDay - p.day) gün")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(p.finalDay - p.day <= 3 ? Theme.rust : Theme.secondary)
            }
            DayStrip(day: p.day, finalDay: p.finalDay)
            HStack(alignment: .top, spacing: 14) { stats }
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showNotes.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Label(p.businessLabel, systemImage: "storefront")
                    Spacer()
                    Image(systemName: showNotes ? "chevron.up" : "info.circle")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showNotes {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Güven: \(p.trustNote.lowercasedFirstLetter)", systemImage: "person.3")
                    Label(p.pressureNote, systemImage: "exclamationmark.triangle")
                }
                .transition(.opacity)
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.secondary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.charcoal.opacity(0.12)))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var stats: some View {
        stat("Kasa", p.cash, note: "taksitin %\(Int(max(0, min(1, Double(p.cashValue) / installment)) * 100))'i",
             fill: Double(p.cashValue) / installment, color: p.cashValue < 0 ? Theme.rust : Theme.charcoal)
        stat("Güven", "\(p.trust)", note: nil, fill: Double(p.trust) / 100,
             color: p.trust < 25 ? Theme.rust : (p.trust >= 70 ? Theme.moss : Theme.charcoal))
        stat("Baskı", "\(p.pressure)", note: nil,
             fill: Double(p.pressure) / 100, color: p.pressure >= 35 ? Theme.rust : Theme.charcoal)
    }

    private func stat(_ label: String, _ value: String, note: String?, fill: Double,
                      color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondary)
            Text(value)
                .font(.headline.monospacedDigit().weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Capsule().fill(Theme.charcoal.opacity(0.1))
                .frame(height: 5)
                .overlay(alignment: .leading) {
                    GeometryReader { g in
                        Capsule().fill(color.opacity(0.8))
                            .frame(width: g.size.width * max(0, min(1, fill)))
                    }
                }
            if let note, !note.isEmpty {
                Text(note).font(.caption2).foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// 30 günlük şerit: geçen günler dolu, bugün vurgulu, ödeme günü işaretli.
extension String {
    var lowercasedFirstLetter: String {
        guard let f = first else { return self }
        return String(f).lowercased(with: Locale(identifier: "tr_TR")) + dropFirst()
    }
}

struct DayStrip: View {
    let day: Int
    let finalDay: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...finalDay, id: \.self) { d in
                RoundedRectangle(cornerRadius: 2)
                    .fill(d < day ? Theme.charcoal.opacity(0.55) : (d == day ? Theme.moss : Theme.charcoal.opacity(0.1)))
                    .frame(height: d == day ? 10 : 6)
                    .overlay {
                        if d == finalDay { RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.rust, lineWidth: 1.5) }
                    }
            }
        }
        .frame(height: 10)
        .accessibilityLabel("\(finalDay) günün \(day). günü")
    }
}

// MARK: Sahne

struct SceneCard: View {
    @Environment(GameStore.self) private var game
    let scene: ScenePresentation
    var night = false
    let onChoose: (ChoicePresentation) -> Void
    @State private var pendingConfirm: ChoicePresentation?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SceneStage(scene: scene, night: night)
            VStack(alignment: .leading, spacing: 16) {
                Text(scene.title).font(Theme.heading(.title))
                Text(scene.body)
                    .font(Theme.story)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 12) {
                    ForEach(scene.choices) { choice in
                        ChoiceButton(choice: choice, night: night) {
                            if choice.confirm != nil { pendingConfirm = choice } else { onChoose(choice) }
                        }
                        .disabled(!choice.enabled || game.isBusy)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .foregroundStyle(night ? Theme.nightText : Theme.charcoal)
        .background(night ? Theme.nightCard : Color.white.opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Theme.charcoal.opacity(night ? 0.4 : 0.12)))
        .shadow(color: .black.opacity(night ? 0.25 : 0.06), radius: 12, y: 6)
        .alert("Emin misin?", isPresented: Binding(get: { pendingConfirm != nil }, set: { if !$0 { pendingConfirm = nil } }),
               presenting: pendingConfirm) { choice in
            Button("Evet", role: .destructive) { onChoose(choice) }
            Button("Vazgeç", role: .cancel) {}
        } message: { choice in
            Text(choice.confirm ?? "")
        }
    }
}

/// Bütün seçenekler eşit görünür; geri dönüşü olmayanlar kırmızı çerçeve ve kilitle işaretlenir.
struct ChoiceButton: View {
    let choice: ChoicePresentation
    var night = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    private var irreversible: Bool { choice.confirm != nil }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(choice.label)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !choice.badges.isEmpty {
                        BadgeChips(badges: choice.badges, night: night)
                    }
                    ForEach(choice.preview, id: \.self) { line in
                        Text(line).font(.footnote).opacity(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if irreversible {
                        Label("Geri dönüşü yok", systemImage: "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(night ? Color(red: 0.92, green: 0.55, blue: 0.48) : Theme.rust)
                    }
                    if let reason = choice.disabledReason, !choice.enabled {
                        Label(reason, systemImage: "xmark.circle").font(.footnote.weight(.medium))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .opacity(0.35)
                    .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(night ? Color.white.opacity(0.06) : Theme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(irreversible ? (night ? Color(red: 0.92, green: 0.55, blue: 0.48) : Theme.rust)
                                  : (night ? Theme.nightText.opacity(0.3) : Theme.charcoal.opacity(0.22)),
                                  lineWidth: irreversible ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityHint(irreversible ? "Geri dönüşü yok; onay ister" : "")
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                MapCrop(spot: .square, height: 150)
                    .overlay(LinearGradient(colors: [.clear, Theme.paper], startPoint: .center, endPoint: .bottom))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Label("SABAH", systemImage: "sunrise.fill").font(.caption.weight(.bold))
                    Text("Bu sabah ne yapacaksın?").font(Theme.heading(.title))
                }
                .padding(14)
            }
            Text("Bir işe bakmak sabahı harcamaz; karar verince sabah kullanılır.")
                .font(.footnote).foregroundStyle(Theme.secondary)
            if let due = agenda.dueNote {
                Label(due, systemImage: "calendar.badge.exclamationmark")
                    .font(.callout.weight(.medium))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.rust.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
            ForEach(agenda.suggested) { entry in row(entry, large: true) }
            DisclosureGroup(isExpanded: $showAll) {
                VStack(spacing: 10) {
                    ForEach(agenda.all) { entry in row(entry, large: false) }
                }
                .padding(.top, 8)
            } label: {
                Text("Bütün gündem (\(agenda.all.count))").font(.headline)
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
                .paperNavigationBar()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Kapat") { open = nil } }
                }
            }
            .presentationDragIndicator(.visible)
        }
    }

    private func symbol(_ c: AgendaItemDefinition.Category) -> (String, Color) {
        switch c {
        case .business: ("storefront.fill", Theme.moss)
        case .investigation: ("magnifyingglass", Color(red: 0.25, green: 0.33, blue: 0.5))
        case .people: ("person.2.fill", Color(red: 0.6, green: 0.42, blue: 0.2))
        case .finance: ("banknote.fill", Theme.rust)
        case .rest: ("cup.and.saucer.fill", Theme.secondary)
        }
    }

    private func row(_ entry: AgendaEntry, large: Bool) -> some View {
        let (icon, tint) = symbol(entry.category)
        return Button { open = entry } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: large ? 22 : 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: large ? 48 : 40, height: large ? 48 : 40)
                    .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(entry.title).font(large ? .system(.headline, design: .serif) : .headline)
                        if entry.isNew { tag("Yeni", Theme.moss) }
                        if entry.closesToday { tag("Bugün son", Theme.rust) }
                    }
                    Text(entry.summary).font(.callout).foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(entry.windowNote).font(.caption).foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(large ? 0.7 : 0.45), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.charcoal.opacity(0.1)))
        }
        .buttonStyle(PressScaleStyle())
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: Akşam

struct EveningCard: View {
    let evening: EveningPresentation
    var compact = false
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(evening.day). akşam hesabı", systemImage: "moon.haze")
                    .font(Theme.heading(.headline))
                Spacer()
                Text(evening.net)
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(evening.netValue < 0 ? Theme.rust : Theme.moss)
            }
            .accessibilityElement(children: .combine)
            if !compact || expanded {
                ForEach(evening.incomeLines) { LineRow(line: $0) }
                Divider()
                LineRow(label: "Brüt", amount: evening.gross, note: evening.multiplierNote)
                LineRow(label: "Kasaya giren", amount: evening.adjustedGross)
                ForEach(evening.expenseLines) { LineRow(line: $0) }
                if let fee = evening.pressureFee {
                    LineRow(label: "Alacaklı kesintisi", amount: fee)
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
            if compact {
                Button(expanded ? "Ayrıntıyı gizle" : "Ayrıntıyı göster") {
                    withAnimation { expanded.toggle() }
                }
                .font(.footnote.weight(.semibold))
            }
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
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottomLeading) {
                MapCrop(spot: .whole, height: 160)
                    .overlay(LinearGradient(colors: [Color(red: 0.08, green: 0.1, blue: 0.2).opacity(0.65), Theme.paper],
                                            startPoint: .top, endPoint: .bottom))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Label("GÜN BİTİYOR", systemImage: "moon.stars.fill").font(.caption.weight(.bold))
                    Text("\(recap.day). günün sonu").font(Theme.heading(.largeTitle))
                }
                .padding(14)
            }
            if let last = p.lastOutcome, last.day == recap.day {
                if last.sceneID == MasaView.letterSceneID {
                    LetterSheet(title: "Halanın mektubu", text: last.text)
                        .padding(.vertical, 6)
                } else {
                    OutcomeCard(outcome: last, large: true)
                }
            }
            if !recap.memories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bugün").font(Theme.heading(.headline))
                    ForEach(recap.memories, id: \.self) { m in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(Theme.moss)
                            Text(m).font(.callout)
                        }
                    }
                }
                .paperCard()
            }
            if let evening = recap.evening { EveningCard(evening: evening, compact: true) }
            if let chapter = recap.chapter {
                VStack(alignment: .leading, spacing: 10) {
                    Label("BÖLÜM KAPANDI", systemImage: "bookmark.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(Theme.moss)
                    Text(chapter.title).font(Theme.heading(.title2))
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
                if let guess = p.notebook.firstGuessLine, recap.day == 7 {
                    Label(guess, systemImage: "checkmark.seal")
                        .font(.callout)
                        .foregroundStyle(Theme.secondary)
                }
                if let next = recap.nextDayNote {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "calendar").foregroundStyle(Theme.rust)
                        Text(next).font(.system(.body, design: .serif).italic())
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.rust.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                if p.gateAhead && !entitlements.isUnlocked {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("İlk hafta burada bitiyor.").font(Theme.heading(.title3))
                        Text("Mektuptaki soru açıkta: mühür nerede, imzayı kim attı? Hikâyenin kalanı tek seferlik satın almayla açılır; kaydın korunur.")
                            .font(.callout)
                    }
                    .paperCard()
                    Button("Hikâyeye devam et") { game.paywallRequested = true }
                        .buttonStyle(ActionButtonStyle())
                } else {
                    Button {
                        Task { await game.send(.finishDay, revision: p.revision) }
                    } label: {
                        Label("Günü bitir", systemImage: "moon.zzz.fill")
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

    private var suspects: [PersonPresentation] {
        game.presentation?.notebook.people.filter { $0.eliminated != nil } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("İlk tahminin").font(Theme.heading(.title2))
            Text("Satış yetkisini kim imzaladı sence? Tahminin yalnız deftere yazılır; kimseyi suçlamaz, sonra fikrini değiştirebilirsin.")
                .font(.callout)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(suspects) { person in
                    Button { guess(SuspectID(rawValue: person.id)) } label: {
                        VStack(spacing: 8) {
                            if let portrait = person.portrait {
                                Image(portrait).resizable().scaledToFill()
                                    .frame(width: 88, height: 88)
                                    .background(Theme.paper)
                                    .clipShape(Circle())
                                    .overlay(Circle().strokeBorder(Theme.charcoal.opacity(0.15)))
                            }
                            Text(person.name).font(.footnote.weight(.semibold))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.charcoal.opacity(0.2)))
                    }
                    .buttonStyle(PressScaleStyle())
                }
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
