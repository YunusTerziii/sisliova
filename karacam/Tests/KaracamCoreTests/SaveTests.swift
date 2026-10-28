import Foundation
import Testing
@testable import KaracamCore

@Suite struct SaveTests {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("karacam-test-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("save.json")
    }

    @Test func roundTripKeepsEverything() async throws {
        var d = Driver(culprit: .halil)
        try d.run(to: 9, phase: .agenda)
        let repo = SaveRepository(url: tempURL())
        try await repo.save(d.env)
        let loaded = try await repo.load()
        #expect(loaded == .loaded(d.env))
    }

    @Test func corruptMainFileFallsBackToBackup() async throws {
        let url = tempURL()
        var d = Driver()
        try d.run(to: 2, phase: .anchor)
        let repo = SaveRepository(url: url)
        try await repo.save(d.env)
        let first = d.env
        try d.choose(d.firstFreeChoice()!)
        try await repo.save(d.env)
        try Data("{bozuk".utf8).write(to: url)
        let fresh = SaveRepository(url: url)
        #expect(try await fresh.load() == .recoveredFromBackup(first))
    }

    @Test func staleWritesFromOldRunAreRejected() async throws {
        let repo = SaveRepository(url: tempURL())
        let old = Driver(seed: 1).env
        let new = Driver(seed: 2).env
        try await repo.save(old)
        await repo.beginRun(new.state.runID)
        await #expect(throws: CoreError.staleCommand) { try await repo.save(old) }
        try await repo.save(new)
        #expect(try await repo.load() == .loaded(new))
    }

    @Test func olderRevisionIsNotWrittenOverNewer() async throws {
        var d = Driver()
        let repo = SaveRepository(url: tempURL())
        let early = d.env
        try d.choose(d.firstFreeChoice()!)
        try await repo.save(d.env)
        await #expect(throws: CoreError.staleCommand) { try await repo.save(early) }
    }

    @Test func schemaZeroMigratesFirstGuess() throws {
        let d = Driver()
        struct V0: Encodable {
            var schemaVersion = 0
            var contentVersion: String
            var state: RunState
            var firstGuess: SuspectID?
        }
        let data = try JSONEncoder().encode(V0(contentVersion: "0.9", state: d.s, firstGuess: .sevim))
        let env = try SaveRepository.decode(data)
        #expect(env.schemaVersion == SaveEnvelope.currentSchema)
        #expect(env.metadata.firstGuess == .sevim)
        #expect(env.metadata.firstGuessRecorded)
        #expect(env.state == d.s)
    }

    @Test func unknownSchemaIsRefusedNotWiped() {
        let data = Data(#"{"schemaVersion": 99}"#.utf8)
        #expect(throws: CoreError.self) { try SaveRepository.decode(data) }
    }
}
