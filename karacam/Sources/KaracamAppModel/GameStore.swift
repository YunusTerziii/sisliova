import Foundation
import Observation
import KaracamCore

/// Ses ve haptic gibi sunum geri bildirimleri. Uygulama hedefi UIKit ile uygular.
@MainActor
public protocol FeedbackSink: AnyObject {
    func play(_ events: [PresentationEvent])
}

/// Kayıt yazımı. Gerçek uygulamada `SaveRepository` aktörü; testlerde hata üreten sahte.
public protocol SaveStore: Sendable {
    func beginRun(_ runID: UUID) async
    func save(_ envelope: SaveEnvelope) async throws
    func load() async throws -> SaveRepository.LoadResult
    func deleteAll() async throws
}

extension SaveRepository: SaveStore {}

/// Uygulamanın tek oyun durumu. Akış: görünüm komut üretir → reducer doğrular →
/// yeni snapshot atomik kaydedilir → ancak kayıt başarılıysa arayüze işlenir → geri bildirim.
@MainActor
@Observable
public final class GameStore {
    public enum Screen: Equatable, Sendable {
        case loading
        case title
        case playing
        case failed(String)
    }

    public let engine: Engine
    @ObservationIgnored private let store: any SaveStore
    @ObservationIgnored private weak var feedback: (any FeedbackSink)?

    public private(set) var envelope: SaveEnvelope?
    public private(set) var presentation: PlayPresentation?
    public private(set) var screen: Screen = .loading
    /// Bir komut işlenirken ikinci dokunuş beklemez, düşer.
    public private(set) var isBusy = false
    /// Ana kayıt bozuktu, son geçerli yedekten açıldı.
    public private(set) var recoveredFromBackup = false
    /// Kullanıcıya gösterilecek kısa hata ya da bilgi. Kendiliğinden kaybolmaz.
    public var notice: String?
    /// Ücretsiz bölüm bitti ve tam oyun açık değil: satın alma ekranı istenir.
    public var paywallRequested = false
    /// Doğrulanmış tam oyun hakkı. Uygulama hedefi StoreKit'ten günceller; geri sarmayla değişmez.
    public var isUnlocked = false

    public init(content: GameContent, store: any SaveStore, feedback: (any FeedbackSink)? = nil) {
        self.engine = Engine(content: content)
        self.store = store
        self.feedback = feedback
    }

    public func attachFeedback(_ sink: any FeedbackSink) {
        feedback = sink
    }

    // MARK: Açılış

    public func load() async {
        do {
            switch try await store.load() {
            case .none:
                screen = .title
            case let .loaded(env):
                commit(env)
                screen = .title
            case let .recoveredFromBackup(env):
                commit(env)
                recoveredFromBackup = true
                notice = "Son kayıt okunamadı; bir önceki geçerli kayıttan devam ediliyor."
                screen = .title
            }
        } catch {
            screen = .failed("Kayıt açılamadı. Dosya silinmedi; uygulamayı güncelleyip yeniden deneyebilirsin.")
        }
    }

    /// Ana ekrandaki devam satırı: gün, işletme ve son önemli karar.
    public var continueSummary: String? {
        guard let p = presentation else { return nil }
        if let ending = p.ending { return "Hikâye bitti: \(ending.title)" }
        var parts = ["\(p.day). gün", p.businessLabel]
        if let last = p.lastOutcome { parts.append(last.text) }
        return parts.joined(separator: " · ")
    }

    public var playerName: String? { envelope?.metadata.playerName }

    public func continueGame() {
        guard envelope != nil else { return }
        screen = .playing
    }

    public func returnToTitle() {
        screen = .title
    }

    public func newGame(playerName: String?, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let name = playerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let env = engine.newRun(seed: seed, playerName: (name?.isEmpty ?? true) ? nil : name)
        await store.beginRun(env.state.runID)
        do {
            try await store.save(env)
        } catch {
            notice = "Yeni oyun kaydedilemedi: \(error.localizedDescription)"
            return
        }
        recoveredFromBackup = false
        commit(env)
        screen = .playing
    }

    // MARK: Komut

    /// `revision`, komutu üreten ekranın gördüğü sürümdür. Eski bir ekrandan gelen dokunuş sessizce düşer.
    @discardableResult
    public func send(_ action: Command.Action, revision: Int? = nil) async -> Bool {
        guard !isBusy, let env = envelope else { return false }
        if let revision, revision != env.state.revision { return false }
        isBusy = true
        defer { isBusy = false }
        let command = Command(expectedRevision: env.state.revision, action: action)
        let transition: Transition
        do {
            transition = try engine.reduce(env, command, fullGameUnlocked: isUnlocked)
        } catch CoreError.gateLocked {
            paywallRequested = true
            return false
        } catch CoreError.staleCommand, CoreError.duplicateCommand {
            return false
        } catch {
            notice = Self.describe(error)
            return false
        }
        do {
            try await store.save(transition.envelope)
        } catch {
            // Kayıt yazılamadıysa eski durum korunur; ekran ilerlemez.
            notice = "Kayıt yazılamadı, son durum korunuyor. Tekrar dene. (\(error.localizedDescription))"
            return false
        }
        commit(transition.envelope)
        feedback?.play(transition.events)
        return true
    }

    public func deleteSave() async {
        do {
            try await store.deleteAll()
            envelope = nil
            presentation = nil
            screen = .title
        } catch {
            notice = "Kayıt silinemedi: \(error.localizedDescription)"
        }
    }

    private func commit(_ env: SaveEnvelope) {
        envelope = env
        presentation = engine.present(env)
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case CoreError.insufficientCash: return "Kasada bunun için yeterli para yok."
        case let CoreError.choiceUnavailable(reason): return reason
        case CoreError.gameEnded: return "Hikâye bitti; yeni oyun başlatabilir ya da bölüm başına dönebilirsin."
        case CoreError.duplicateEvening: return "Bu akşamın hesabı zaten kapandı."
        case CoreError.invalidPhase, CoreError.sceneMismatch: return "Bu işlem şu an yapılamıyor."
        case let CoreError.invalidContent(m): return "İçerik hatası: \(m)"
        case let CoreError.unknownScene(id): return "İçerik hatası: sahne bulunamadı (\(id))."
        default: return "Bu işlem şu an yapılamıyor."
        }
    }
}
