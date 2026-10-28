import SwiftUI

/// Görsel dil: kâğıt, kömür, ikincil metin, yeşil, kırmızı. Başlık sistem serif, gövde sistem.
enum Theme {
    static let paper = Color("Paper")
    static let charcoal = Color("Charcoal")
    static let secondary = Color("Secondary")
    static let moss = Color("Moss")
    static let rust = Color("Rust")
    static let card = Color.white.opacity(0.55)

    static func heading(_ style: Font.TextStyle = .title2) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }

    /// İçerikteki çizim kimliğini varlık adına çevirir. "kaplica,ari" gibi çoklu değerleri böler.
    static func illustrationAssets(_ id: String?) -> [String] {
        guard let id else { return [] }
        return id.split(separator: ",").map { part in
            let key = part.trimmingCharacters(in: .whitespaces)
            return key == "harita" ? "map-karacam" : "illus-\(key)"
        }
    }
}

struct PaperCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.charcoal.opacity(0.12)))
    }
}

extension View {
    func paperCard() -> some View { modifier(PaperCard()) }
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
            .padding(.vertical, 12)
            .foregroundStyle(prominent ? Theme.paper : Theme.charcoal)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(prominent ? Theme.charcoal : Theme.card)
            )
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.charcoal.opacity(prominent ? 0 : 0.25)))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}
