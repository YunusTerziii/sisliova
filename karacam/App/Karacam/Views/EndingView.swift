import SwiftUI
import KaracamCore
import KaracamAppModel

/// Son: ne oldu, neden oldu, hangi karar fark yarattı; ardından kişisel epilog.
struct EndingView: View {
    @Environment(GameStore.self) private var game
    let ending: EndingPresentation
    let canRewindChapter: Bool
    let onRewind: () -> Void
    @State private var confirmNew = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    MapCrop(spot: .whole, height: 220)
                        .overlay(LinearGradient(colors: [.clear, Theme.paper], startPoint: .center, endPoint: .bottom))
                    VStack(alignment: .leading, spacing: 4) {
                        Label("SON", systemImage: "flag.checkered").font(.caption.weight(.bold)).foregroundStyle(Theme.moss)
                        Text(ending.title).font(Theme.heading(.largeTitle))
                    }
                    .padding(16)
                }
                Text(ending.summary)
                    .font(Theme.story)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
            }
            .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            if !ending.why.isEmpty {
                block("Neden böyle bitti", ending.why)
            }
            if !ending.decisive.isEmpty {
                block("Fark yaratan kararlar", ending.decisive)
            }
            if !ending.numbers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sayılar").font(Theme.heading(.title3))
                    ForEach(ending.numbers) { LineRow(line: $0) }
                }
                .paperCard()
            }
            if let guess = ending.guessLine {
                Text(guess).font(.callout).foregroundStyle(Theme.secondary)
            }

            Text("Sonrası").font(Theme.heading(.title2)).padding(.top, 8)
            ForEach(ending.epilogue) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.heading).font(.headline)
                    Text(section.text).font(.system(.body, design: .serif)).fixedSize(horizontal: false, vertical: true)
                }
                .paperCard()
                .accessibilityElement(children: .combine)
            }

            ShareLink(item: ending.shareText) {
                Label("Sonu paylaş", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            if canRewindChapter {
                Button("Bölüm başına dön", action: onRewind)
                    .buttonStyle(ActionButtonStyle(prominent: false))
            }
            Button("Yeni oyun") { confirmNew = true }
                .buttonStyle(ActionButtonStyle())
        }
        .alert("Yeni oyun başlasın mı?", isPresented: $confirmNew) {
            Button("Başlat", role: .destructive) {
                Task { await game.newGame(playerName: game.playerName) }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu son kayıttan silinir. Vaka yeni tohumla yeniden kurulur; tam oyun hakkın korunur.")
        }
    }

    private func block(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Theme.heading(.title3))
            ForEach(lines, id: \.self) { Text("• " + $0).font(.callout).fixedSize(horizontal: false, vertical: true) }
        }
        .paperCard()
    }
}
