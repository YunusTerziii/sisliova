import SwiftUI
import KaracamCore
import KaracamAppModel

/// Köy: gerçek duruma bağlı işaretler. Gizli piksel bulmacası değil; her işaret VoiceOver etiketli
/// ve aynı bilgi liste olarak da okunabilir. Seçilen yerin kartı haritanın üstünde açılır.
struct KasabaView: View {
    @Environment(GameStore.self) private var game
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: Mode = .map
    @State private var selectedID: String?

    enum Mode: String, CaseIterable, Identifiable {
        case map = "Harita"
        case list = "Liste"
        var id: Self { self }
    }

    var body: some View {
        let markers = game.presentation?.village ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Görünüm", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                switch mode {
                case .map: map(markers)
                case .list: list(markers)
                }
            }
            .padding(16)
        }
        .background(Theme.paper)
        .navigationTitle("Karaçam")
        .navigationBarTitleDisplayMode(.inline)
        .paperNavigationBar()
    }

    private func map(_ markers: [VillageMarker]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("map-karacam")
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
                .overlay {
                    GeometryReader { geo in
                        ForEach(markers) { m in
                            let selected = m.id == selectedID
                            Button {
                                withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
                                    selectedID = selected ? nil : m.id
                                }
                            } label: {
                                Image(systemName: m.symbol)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(m.active || selected ? Theme.paper : Theme.charcoal)
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(selected ? Theme.rust : (m.active ? Theme.moss : Theme.paper.opacity(0.95))))
                                    .overlay(Circle().strokeBorder(selected ? Theme.paper : Theme.charcoal.opacity(0.4),
                                                                   lineWidth: selected ? 3 : 1))
                                    .shadow(color: .black.opacity(0.25), radius: selected ? 8 : 3, y: 2)
                                    .scaleEffect(selected ? 1.15 : 1)
                            }
                            .buttonStyle(.plain)
                            .position(x: geo.size.width * m.x, y: geo.size.height * m.y)
                            .accessibilityLabel(m.label)
                            .accessibilityValue(m.status)
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if let m = markers.first(where: { $0.id == selectedID }) {
                        placeCard(m)
                            .padding(12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            if selectedID == nil {
                Label("Bir işarete dokun; o yerin bugünkü hâlini görürsün.", systemImage: "hand.tap")
                    .font(.footnote).foregroundStyle(Theme.secondary)
            }
        }
    }

    private func placeCard(_ m: VillageMarker) -> some View {
        HStack(alignment: .center, spacing: 12) {
            placeImage(m)
            VStack(alignment: .leading, spacing: 4) {
                Text(m.label).font(Theme.heading(.title3))
                Text(m.status).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation { selectedID = nil }
            } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(Theme.secondary)
            }
            .accessibilityLabel("Kapat")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }

    @ViewBuilder private func placeImage(_ m: VillageMarker) -> some View {
        let asset: String? = switch m.id {
        case "spa": "illus-kaplica"
        case "bees": "illus-ari"
        case "nine": "portrait-nine"
        case "office": "portrait-sevim"
        default: nil
        }
        if let asset {
            Image(asset).resizable().scaledToFit()
                .frame(width: 72, height: 72)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
        } else {
            Image(systemName: m.symbol)
                .font(.title)
                .frame(width: 72, height: 72)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func list(_ markers: [VillageMarker]) -> some View {
        VStack(spacing: 10) {
            ForEach(markers) { m in
                HStack(alignment: .center, spacing: 14) {
                    placeImage(m)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(m.label).font(.headline)
                            if m.active {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.moss)
                            }
                        }
                        Text(m.status).font(.callout).foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .frame(minHeight: 44)
                .paperCard()
                .accessibilityElement(children: .combine)
            }
        }
    }
}
