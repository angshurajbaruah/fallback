import Foundation
import Testing
@testable import FallbackCore

/// Real FSEvents on a temporary folder: changes show up within 5 seconds (FR-15), renames keep the
/// same file record (FR-17), and similar files are grouped into one family (FR-18).
@Suite(.serialized)
struct FileIndexerTests {
    let folder: URL
    let store: Store
    let indexer: FileIndexer

    init() throws {
        folder = URL(filePath: FileIndexer.realPath(FileManager.default.temporaryDirectory.path)).appending(path: "fallback-index-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        store = try Store.inMemory()
        indexer = FileIndexer(store: store, analyzer: FileAnalyzer(readPDF: { _ in nil })) { _ in }
    }

    func write(_ name: String, _ text: String) throws {
        // Repeat so the file is over the 1 KB minimum (FR-21).
        try Data(String(repeating: text + "\n", count: 8).utf8).write(to: folder.appending(path: name))
    }

    func rows() throws -> [FamilyMember] { try store.files(ids: store.evidence().map(\.id)) }

    /// Polls until the condition holds or the time runs out.
    func eventually(within seconds: Double = 6, _ condition: () throws -> Bool) async throws -> Bool {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while Date() < deadline {
            if try condition() { return true }
            try await Task.sleep(for: .milliseconds(200))
        }
        return try condition()
    }

    @Test func followsChangesRenamesAndDeletes() async throws {
        defer { indexer.stop(); try? FileManager.default.removeItem(at: folder) }
        try write("notes_v1.txt", Fixtures.resume)
        try write("tiny.txt", "") // 8 bytes: under the 1 KB minimum
        indexer.watch([folder.path])
        #expect(try await eventually { try rows().map(\.name) == ["notes_v1.txt"] }) // tiny.txt skipped
        let original = try rows()[0].id

        // A new, similar file joins the same family.
        try write("notes_v2.txt", Fixtures.resumeEdited)
        #expect(try await eventually { try rows().count == 2 })
        #expect(try await eventually {
            let all = try rows()
            return Set(all.map(\.familyID)).count == 1 && all.first?.familyID != nil
        })

        // Rename: same record, new path.
        try FileManager.default.moveItem(at: folder.appending(path: "notes_v1.txt"), to: folder.appending(path: "notes_old.txt"))
        #expect(try await eventually { try rows().first { $0.id == original }?.name == "notes_old.txt" })
        #expect(try rows().first { $0.id == original }?.path == folder.appending(path: "notes_old.txt").path)

        // Delete: history kept, path cleared.
        try FileManager.default.removeItem(at: folder.appending(path: "notes_v2.txt"))
        #expect(try await eventually { try rows().first { $0.name == "notes_v2.txt" }?.path == nil })
    }

    @Test func skipsNoiseFolders() async throws {
        defer { indexer.stop(); try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder.appending(path: "node_modules"), withIntermediateDirectories: true)
        try Data(String(repeating: Fixtures.resume, count: 2).utf8).write(to: folder.appending(path: "node_modules/readme.md"))
        try write("plan.md", Fixtures.proposal)
        indexer.watch([folder.path])
        let found = try await eventually { try rows().map(\.name) == ["plan.md"] }
        let names = try rows().map(\.name)
        #expect(found, "indexed \(names)")
    }
}

struct FamilyStoreTests {
    @Test func applyKeepsFamilyIDsAndUserNames() throws {
        let store = try Store.inMemory()
        let a = try store.upsert(IndexedFile(path: "/x/resume_v3.pdf", name: "resume_v3.pdf", facts: FileFacts(sha256: "1"),
                                             textSignature: TextSignature.make(Fixtures.resume)), inWatchedFolder: true)
        let b = try store.upsert(IndexedFile(path: "/x/resume_v5.pdf", name: "resume_v5.pdf", facts: FileFacts(sha256: "2"),
                                             textSignature: TextSignature.make(Fixtures.resume)), inWatchedFolder: true)
        try store.apply(FamilyEngine.build(files: store.evidence()))
        let family = try #require(store.families().first)
        #expect(family.name == "Resume" && family.memberCount == 2 && family.newestVersion == 2)

        try store.renameFamily(family.id, to: "My CV")
        try store.apply(FamilyEngine.build(files: store.evidence()))
        #expect(try store.families().map(\.name) == ["My CV"])
        #expect(try store.families().first?.id == family.id)

        // Split one off (FR-20): it becomes its own document.
        try store.addDecisions([.separate(a, b)])
        try store.apply(FamilyEngine.build(files: store.evidence(), decisions: store.userDecisions()))
        #expect(try store.families().count == 2)

        // Merge back.
        try store.addDecisions([.same(a, b)])
        try store.apply(FamilyEngine.build(files: store.evidence(), decisions: store.userDecisions()))
        #expect(try store.families().count == 1)
    }

    @Test func atomicSaveKeepsTheSameRecord() throws {
        let store = try Store.inMemory()
        let first = try store.upsert(IndexedFile(path: "/x/a.docx", name: "a.docx", facts: FileFacts(identity: "1:10")), inWatchedFolder: true)
        // Saving by replacing the file gives it a new identity at the same path.
        let second = try store.upsert(IndexedFile(path: "/x/a.docx", name: "a.docx", facts: FileFacts(identity: "1:11")), inWatchedFolder: true)
        #expect(first == second)
    }
}
