import SwiftUI
import KaracamCore
import KaracamAppModel

/// Kasaba: gerçek duruma bağlı işaretler. Gizli piksel bulmacası değil; her işaret VoiceOver etiketli
/// ve aynı bilgi liste olarak da okunabilir.
struct KasabaView: View {
    @Environment(GameStore.self) private var game
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
        .navigationTitle("Kasaba")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func map(_ markers: [VillageMarker]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image("map-karacam")
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
                .overlay {
                    GeometryReader { geo in
                        ForEach(markers) { m in
                            Button { selectedID = m.id } label: {
                                Image(systemName: m.symbol)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(m.active ? Theme.paper : Theme.charcoal)
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(m.active ? Theme.moss : Theme.paper.opacity(0.9)))
                                    .overlay(Circle().strokeBorder(Theme.charcoal.opacity(0.4)))
                            }
                            .buttonStyle(.plain)
                            .position(x: geo.size.width * m.x, y: geo.size.height * m.y)
                            .accessibilityLabel(m.label)
                            .accessibilityValue(m.status)
                        }
                    }
                }
            if let m = markers.first(where: { $0.id == selectedID }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(m.label).font(.headline)
                    Text(m.status).font(.callout)
                }
                .paperCard()
            } else {
                Text("Bir işarete dokun; durumunu burada okursun.")
                    .font(.footnote).foregroundStyle(Theme.secondary)
            }
        }
    }

    private func list(_ markers: [VillageMarker]) -> some View {
        VStack(spacing: 8) {
            ForEach(markers) { m in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: m.symbol)
                        .frame(width: 28)
                        .foregroundStyle(m.active ? Theme.moss : Theme.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.label).font(.headline)
                        Text(m.status).font(.callout).foregroundStyle(Theme.secondary)
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
