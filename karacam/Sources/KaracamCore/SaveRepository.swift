import Foundation

/// Atomik kayıt. Ana dosya bozulursa son geçerli yedeğe döner.
/// Yeni oyun başladığında eski oyunun geç kalan yazıları reddedilir.
public actor SaveRepository {
    public enum LoadResult: Sendable, Equatable {
        case none
        case loaded(SaveEnvelope)
        /// Ana dosya okunamadı, yedekten açıldı.
        case recoveredFromBackup(SaveEnvelope)
    }

    private let url: URL
    private let backupURL: URL
    private var activeRunID: UUID?
    private var lastRevision = -1

    public init(url: URL) {
        self.url = url
        self.backupURL = url.deletingPathExtension().appendingPathExtension("backup.json")
    }

    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Karacam", isDirectory: true).appendingPathComponent("save.json")
    }

    /// Yeni oyun: önceki oyunun kuyruktaki yazıları artık geçersiz.
    public func beginRun(_ runID: UUID) {
        activeRunID = runID
        lastRevision = -1
    }

    public func save(_ envelope: SaveEnvelope) throws {
        if let active = activeRunID, active != envelope.state.runID {
            throw CoreError.staleCommand
        }
        if envelope.state.revision < lastRevision {
            throw CoreError.staleCommand
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        // Önceki geçerli kayıt yedeğe taşınır, sonra yeni kayıt atomik yazılır.
        if FileManager.default.fileExists(atPath: url.path),
           let old = try? Data(contentsOf: url), (try? SaveRepository.decode(old)) != nil {
            try old.write(to: backupURL, options: .atomic)
        }
        try data.write(to: url, options: .atomic)
        activeRunID = envelope.state.runID
        lastRevision = envelope.state.revision
    }

    public func load() throws -> LoadResult {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url), let env = try? SaveRepository.decode(data) {
                remember(env)
                return .loaded(env)
            }
            if let data = try? Data(contentsOf: backupURL), let env = try? SaveRepository.decode(data) {
                remember(env)
                return .recoveredFromBackup(env)
            }
            throw CoreError.invalidContent("Kayıt dosyası okunamadı")
        }
        return .none
    }

    public func deleteAll() throws {
        let fm = FileManager.default
        for u in [url, backupURL] where fm.fileExists(atPath: u.path) {
            try fm.removeItem(at: u)
        }
        activeRunID = nil
        lastRevision = -1
    }

    private func remember(_ env: SaveEnvelope) {
        activeRunID = env.state.runID
        lastRevision = env.state.revision
    }

    /// Şema göçü burada yapılır. İçerik sürümü değişmesi (metin düzeltmesi) kaydı silmez.
    public static func decode(_ data: Data) throws -> SaveEnvelope {
        struct Header: Decodable { var schemaVersion: Int }
        let header = try JSONDecoder().decode(Header.self, from: data)
        switch header.schemaVersion {
        case SaveEnvelope.currentSchema:
            return try JSONDecoder().decode(SaveEnvelope.self, from: data)
        case 0:
            return try migrateV0(data)
        default:
            throw CoreError.invalidContent("Bilinmeyen kayıt şeması \(header.schemaVersion)")
        }
    }

    /// Alfa öncesi şema 0: `metadata` alanı yoktu, ilk tahmin durum içindeydi.
    static func migrateV0(_ data: Data) throws -> SaveEnvelope {
        struct V0: Decodable {
            var contentVersion: String
            var state: RunState
            var firstGuess: SuspectID?
        }
        let old = try JSONDecoder().decode(V0.self, from: data)
        let meta = RunMetadata(firstGuess: old.firstGuess, firstGuessRecorded: old.firstGuess != nil,
                               firstGuessDay: nil, rewindCount: 0, attemptID: old.state.runID,
                               eliminated: [], playerName: nil)
        return SaveEnvelope(schemaVersion: SaveEnvelope.currentSchema, contentVersion: old.contentVersion,
                            state: old.state, metadata: meta, dayCheckpoint: nil, chapterCheckpoint: nil)
    }
}
