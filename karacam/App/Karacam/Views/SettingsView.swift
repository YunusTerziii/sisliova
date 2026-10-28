import SwiftUI
import KaracamCore
import KaracamAppModel

struct SettingsView: View {
    @Environment(Preferences.self) private var preferences
    @Environment(EntitlementStore.self) private var store
    @Environment(GameStore.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        @Bindable var preferences = preferences
        NavigationStack {
            Form {
                Section {
                    Toggle("Hareketi azalt", isOn: $preferences.reduceMotion)
                    Toggle("Ses efektleri", isOn: $preferences.sound)
                    Toggle("Titreşim (haptic)", isOn: $preferences.haptics)
                } header: {
                    Text("Sunum")
                } footer: {
                    Text("Kapalıyken bütün bilgi metinde kalır. Ses dosyaları bu sürümde henüz yok.")
                }
                Section("Satın alma") {
                    LabeledContent("Tam oyun", value: store.isUnlocked ? "Açık" : "İlk bölüm (1–7. gün)")
                    Button("Satın alımları geri yükle") { Task { await store.restore() } }
                        .disabled(store.isRestoring)
                }
                Section {
                    Button("Kaydı sil", role: .destructive) { confirmDelete = true }
                        .disabled(game.envelope == nil)
                } footer: {
                    Text("Kayıt bu cihazda tutulur. Silmek tam oyun hakkını etkilemez.")
                }
                Section("Hakkında") {
                    LabeledContent("İçerik sürümü", value: GameContent.version)
                    if let n = game.presentation?.rewindCount, n > 0 {
                        LabeledContent("Geri sarma", value: "\(n) kez")
                    }
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Bitti") { dismiss() } }
            }
            .alert("Kayıt silinsin mi?", isPresented: $confirmDelete) {
                Button("Sil", role: .destructive) {
                    Task {
                        await game.deleteSave()
                        dismiss()
                    }
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Bu işlem geri alınamaz.")
            }
        }
    }
}
