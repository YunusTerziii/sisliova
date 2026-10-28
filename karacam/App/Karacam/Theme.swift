import SwiftUI

/// Görsel dil: kâğıt, kömür, ikincil metin, yeşil, kırmızı. Başlık sistem serif, anlatı serif, arayüz sistem.
enum Theme {
    static let paper = Color("Paper")
    static let charcoal = Color("Charcoal")
    static let secondary = Color("Secondary")
    static let moss = Color("Moss")
    static let rust = Color("Rust")
    static let card = Color.white.opacity(0.55)
    /// Gece sahnelerinin kartı: kömürden biraz daha mavi, kâğıt yazı.
    static let night = Color(red: 0.13, green: 0.14, blue: 0.17)
    static let nightCard = Color(red: 0.18, green: 0.19, blue: 0.23)
    static let nightText = Color(red: 0.93, green: 0.90, blue: 0.84)

    static func heading(_ style: Font.TextStyle = .title2) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }

    /// Anlatı metni: kitap okur gibi, gövdeden bir boy büyük serif.
    static let story = Font.system(.title3, design: .serif)
    static let storyItalic = Font.system(.title3, design: .serif).italic()

    /// İçerikteki çizim kimliğini varlık adına çevirir. "kaplica,ari" gibi çoklu değerleri böler.
    static func illustrationAssets(_ id: String?) -> [String] {
        guard let id else { return [] }
        return id.split(separator: ",").map { part in
            let key = part.trimmingCharacters(in: .whitespaces)
            return key == "harita" ? "map-karacam" : "illus-\(key)"
        }
    }

    /// Düşük çözünürlüklü çizimler büyütülünce bulanıklaşır; çerçeveli ve ölçülü gösterilir.
    static let smallIllustrations: Set<String> = ["illus-araba", "illus-kamyon"]
}

/// Haritanın bir bölgesi: portresi ya da çizimi olmayan sahnelerin dekoru.
enum MapSpot {
    case whole, bridge, spa, bees, square, office, nine, road

    var focus: UnitPoint {
        switch self {
        case .whole: UnitPoint(x: 0.5, y: 0.45)
        case .bridge: UnitPoint(x: 0.505, y: 0.79)
        case .spa: UnitPoint(x: 0.80, y: 0.36)
        case .bees: UnitPoint(x: 0.17, y: 0.30)
        case .square: UnitPoint(x: 0.50, y: 0.53)
        case .office: UnitPoint(x: 0.48, y: 0.42)
        case .nine: UnitPoint(x: 0.15, y: 0.55)
        case .road: UnitPoint(x: 0.50, y: 0.92)
        }
    }

    var zoom: CGFloat { self == .whole ? 1.0 : 2.4 }

    /// Konuşmacının sahnesinin geçtiği yer.
    static func forSpeaker(_ id: String) -> MapSpot {
        switch id {
        case "selim", "sevim", "kurul", "mektup", "not": .office
        case "halil", "ekip", "derya": .spa
        case "elif", "koy": .square
        case "nine": .nine
        case "nermin", "rauf", "kamyon", "araba", "avukat", "haber": .bridge
        case "sicil": .road
        default: .whole
        }
    }
}

/// Portresi olmayan konuşmacının simgesi.
enum SpeakerSymbol {
    static func name(_ id: String) -> String? {
        switch id {
        case "not": "envelope.fill"
        case "haber": "newspaper.fill"
        case "mektup": "doc.text.fill"
        case "kurul": "building.columns.fill"
        case "ekip": "person.2.fill"
        case "koy": "person.3.fill"
        case "sicil": "archivebox.fill"
        case "derya": "hammer.fill"
        case "anlatici": "mountain.2.fill"
        case "kamyon": "truck.box.fill"
        case "araba": "car.side.fill"
        default: nil
        }
    }
}

struct PaperCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.charcoal.opacity(0.12)))
    }
}

extension View {
    func paperCard() -> some View { modifier(PaperCard()) }

    /// Kâğıt rengi, her zaman görünür gezinme çubuğu: kaydırılan içerik saatin altından bulanık geçmez.
    func paperNavigationBar() -> some View {
        toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

/// Büyük, somut eylem düğmesi. Büyük yazıda kesilmez; en az 44 pt.
struct ActionButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .foregroundStyle(prominent ? Theme.paper : Theme.charcoal)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(prominent ? Theme.charcoal : Theme.card)
            )
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.charcoal.opacity(prominent ? 0 : 0.25)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
    }
}
