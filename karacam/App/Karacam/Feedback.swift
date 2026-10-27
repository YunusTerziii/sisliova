import UIKit
import KaracamCore
import KaracamAppModel

/// Kısa haptic geri bildirim. Her sayıya titreşim yok: yalnız akşam hesabı, kanıt, bölüm ve son.
/// Ses dosyaları henüz yok; ses tercihi şimdilik yalnız saklanır (test raporunda açık iş).
@MainActor
final class FeedbackPlayer: FeedbackSink {
    private let preferences: Preferences
    private let light: UIImpactFeedbackGenerator
    private let notify: UINotificationFeedbackGenerator

    init(preferences: Preferences) {
        self.preferences = preferences
        light = UIImpactFeedbackGenerator(style: .light)
        notify = UINotificationFeedbackGenerator()
    }

    func play(_ events: [PresentationEvent]) {
        guard preferences.haptics else { return }
        for event in events {
            switch event {
            case .evidenceGained, .chapterCompleted:
                light.impactOccurred()
            case let .eveningSettled(net):
                if net < 0 { notify.notificationOccurred(.warning) }
            case let .gameEnded(ending):
                notify.notificationOccurred(ending == .together || ending == .cooperative ? .success : .warning)
            default:
                break
            }
        }
    }
}
