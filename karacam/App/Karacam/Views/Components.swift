import SwiftUI
import KaracamCore

// MARK: Sekme yönlendirme

/// Sonuç kartındaki "Deftere eklendi" bağlantısı gibi sekmeler arası geçişler.
@MainActor
@Observable
final class TabRouter {
    enum Tab: Hashable { case masa, koy, defter }
    var tab: Tab = .masa
    var defterPage: DefterView.Page = .accounts

    func openEvidence() {
        defterPage = .evidence
        tab = .defter
    }
}

// MARK: Harita dekoru

/// Haritanın bir bölgesini yakınlaştırarak gösterir.
struct MapCrop: View {
    var spot: MapSpot
    var height: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * spot.zoom
            let h = w * 1.5
            Image("map-karacam")
                .resizable()
                .frame(width: w, height: h)
                .offset(x: clamp(geo.size.width / 2 - w * spot.focus.x, min: geo.size.width - w, max: 0),
                        y: clamp(geo.size.height / 2 - h * spot.focus.y, min: geo.size.height - h, max: 0))
        }
        .frame(height: height)
        .clipped()
        .accessibilityHidden(true)
    }

    private func clamp(_ v: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.min(hi, Swift.max(lo, v))
    }
}

// MARK: Sahne

/// Sahnenin üst bandı: çizim ya da haritadan bir köşe; üstüne konuşmacının büyük portresi biner.
struct SceneStage: View {
    let scene: ScenePresentation
    var night: Bool
    private let bandHeight: CGFloat = 230

    private var assets: [String] { Theme.illustrationAssets(scene.illustration ?? fallbackIllustration) }

    private var fallbackIllustration: String? {
        switch scene.speaker.id {
        case "derya": "kaplica"
        case "kamyon": "kamyon"
        case "araba": "araba"
        default: nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            band
                .overlay(alignment: .topLeading) { slotChip.padding(12) }
            HStack(alignment: .bottom, spacing: 14) {
                avatar
                    .offset(y: -44)
                    .padding(.bottom, -44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(scene.speaker.name)
                        .font(.title3.weight(.semibold))
                    if !scene.speaker.role.isEmpty {
                        Text(scene.speaker.role)
                            .font(.subheadline)
                            .foregroundStyle(night ? Theme.nightText.opacity(0.7) : Theme.secondary)
                    }
                }
                .padding(.top, 10)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(scene.slotLabel), \(scene.speaker.name), \(scene.speaker.role)")
    }

    @ViewBuilder private var band: some View {
        ZStack {
            if assets.count > 1 {
                HStack(spacing: 0) {
                    ForEach(assets, id: \.self) { name in
                        Image(name).resizable().scaledToFit().padding(10)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: bandHeight)
                .background(Theme.paper)
            } else if let name = assets.first, name != "map-karacam" {
                let small = Theme.smallIllustrations.contains(name)
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .padding(small ? 24 : 6)
                    .frame(maxWidth: .infinity)
                    .frame(height: bandHeight)
                    .background(Theme.paper)
            } else {
                MapCrop(spot: assets.first == "map-karacam" ? .whole : MapSpot.forSpeaker(scene.speaker.id),
                        height: bandHeight)
            }
            if night {
                LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.18).opacity(0.75),
                                        Color.black.opacity(0.45)],
                               startPoint: .top, endPoint: .bottom)
                    .blendMode(.multiply)
            }
            LinearGradient(colors: [.clear, (night ? Theme.nightCard : Theme.paper).opacity(0.9)],
                           startPoint: UnitPoint(x: 0.5, y: 0.65), endPoint: .bottom)
        }
        .frame(height: bandHeight)
        .clipped()
    }

    @ViewBuilder private var avatar: some View {
        let ring = night ? Theme.nightCard : Theme.paper
        if let portrait = scene.speaker.portrait {
            Image(portrait)
                .resizable()
                .scaledToFill()
                .frame(width: 124, height: 124)
                .background(Theme.paper)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(ring, lineWidth: 5))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        } else if let symbol = SpeakerSymbol.name(scene.speaker.id) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(night ? Theme.nightText : Theme.charcoal)
                .frame(width: 104, height: 104)
                .background(Circle().fill(night ? Theme.night : Theme.paper))
                .overlay(Circle().strokeBorder(ring, lineWidth: 5))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        } else {
            Color.clear.frame(width: 0, height: 60)
        }
    }

    private var slotChip: some View {
        let symbol: String = switch scene.slotLabel {
        case "Sabah": "sunrise.fill"
        case "Gece": "moon.stars.fill"
        case "Gündem": "list.bullet.clipboard"
        default: "sun.max.fill"
        }
        return Label(scene.slotLabel.uppercased(), systemImage: symbol)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(night ? Theme.nightText : Theme.charcoal)
            .background(.ultraThinMaterial, in: Capsule())
    }
}

/// Bir seçimin etkileri: renkli küçük çipler. Para tutarı kalır; güven ve baskı yön gösterir.
struct BadgeChips: View {
    let badges: [String]
    var night = false

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(badges, id: \.self) { b in
                Text(b)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .foregroundStyle(color(b))
                    .background(color(b).opacity(night ? 0.22 : 0.12), in: Capsule())
            }
        }
    }

    private func color(_ b: String) -> Color {
        let up = b.contains("▲") || b.contains("+")
        let down = b.contains("▼") || b.contains("−")
        let good: Color = night ? Color(red: 0.62, green: 0.78, blue: 0.55) : Theme.moss
        let bad: Color = night ? Color(red: 0.92, green: 0.55, blue: 0.48) : Theme.rust
        let neutral = night ? Theme.nightText : Theme.charcoal
        if b.hasPrefix("Baskı") { return up ? bad : (down ? good : neutral) }
        if b.hasPrefix("Günlük gider") { return up ? bad : (down ? good : neutral) }
        if b.hasPrefix("Güven") || b.hasPrefix("Kasa") || b.hasPrefix("Her akşam") {
            return up ? good : (down ? bad : neutral)
        }
        if b.contains("biter") || b.contains("kapanır") { return bad }
        return neutral
    }
}

/// Satır sığmazsa alta geçen basit akış düzeni.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + s.width > width {
                x = 0
                y += rowH + spacing
                rowH = 0
            }
            x += s.width + spacing
            maxX = max(maxX, x - spacing)
            rowH = max(rowH, s.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX && x + s.width > bounds.maxX {
                x = bounds.minX
                y += rowH + spacing
                rowH = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

// MARK: Sonuç

/// Son kararın sonucu. Deftere yeni kanıt düştüyse adıyla gösterilir ve Defter'e götürür.
struct OutcomeCard: View {
    @Environment(TabRouter.self) private var router
    let outcome: Outcome
    var large = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(outcome.sceneTitle, systemImage: "quote.opening")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondary)
            Text(outcome.text)
                .font(large ? Theme.storyItalic : .system(.body, design: .serif).italic())
                .fixedSize(horizontal: false, vertical: true)
            if let gained = outcome.newEvidence, !gained.isEmpty {
                Button { router.openEvidence() } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "book.pages.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Deftere eklendi").font(.caption.weight(.bold))
                            Text(gained.joined(separator: " · ")).font(.callout.weight(.semibold))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .padding(10)
                    .foregroundStyle(Theme.moss)
                    .background(Theme.moss.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Defter'in kanıt sayfasını açar")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.charcoal.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.moss).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(.vertical, 10)
        }
    }
}

// MARK: Mektup

/// El yazısı mektup: kâğıt, eğik serif, imza. Hem tam ekran hem gün sonu kartında.
struct LetterSheet: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "envelope.open.fill").font(.title2)
                Text(title).font(Theme.heading(.title2))
            }
            .foregroundStyle(Theme.charcoal)
            Text(letterBody)
                .font(.system(size: 21, design: .serif).italic())
                .lineSpacing(6)
                .foregroundStyle(Color(red: 0.20, green: 0.17, blue: 0.13))
                .fixedSize(horizontal: false, vertical: true)
            Text("— Halan")
                .font(.system(size: 22, design: .serif).italic().weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Color(red: 0.98, green: 0.95, blue: 0.87),
                                              Color(red: 0.93, green: 0.88, blue: 0.77)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
        )
        .overlay(
            VStack(spacing: 28) {
                ForEach(0..<14, id: \.self) { _ in
                    Rectangle().fill(Color.brown.opacity(0.07)).frame(height: 1)
                }
            }
            .padding(.top, 90)
            .allowsHitTesting(false),
            alignment: .top
        )
        .rotationEffect(.degrees(-0.8))
    }

    /// Sonuç metnindeki anlatıcı girişini ("Halanın eğik yazısı:") ve tırnakları ayıklar.
    private var letterBody: String {
        var t = text
        if let r = t.range(of: ":"), t.distance(from: t.startIndex, to: r.lowerBound) < 40 {
            t = String(t[r.upperBound...])
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
    }
}

struct LetterScreen: View {
    let outcome: Outcome
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Label("7. gece · Halil kapıda bekliyor", systemImage: "moon.stars.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.nightText.opacity(0.85))
                    .padding(.top, 24)
                LetterSheet(title: "Halanın mektubu", text: outcome.text)
                Button("Mektubu katla", action: onClose)
                    .buttonStyle(ActionButtonStyle())
            }
            .padding(20)
        }
        .background {
            GeometryReader { g in
                MapCrop(spot: .office, height: g.size.height)
                    .overlay(LinearGradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.12).opacity(0.85),
                                                     Color.black.opacity(0.6)],
                                            startPoint: .top, endPoint: .bottom))
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: Küçük parçalar

struct SectionTitle: View {
    let text: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 8) {
            if let symbol { Image(systemName: symbol).foregroundStyle(Theme.moss) }
            Text(text).font(Theme.heading(.title2))
        }
        .padding(.top, 4)
    }
}

extension Outcome: @retroactive Identifiable {
    public var id: String { "\(day)-\(sceneID ?? sceneTitle)" }
}
