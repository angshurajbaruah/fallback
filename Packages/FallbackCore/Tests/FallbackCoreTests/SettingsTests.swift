import Foundation
import Testing
@testable import FallbackCore

/// M5: Settings, Stats and Privacy (FR-29 to FR-36).
struct SettingsTests {
    let store = try! Store.inMemory()
    let place = Destination(key: "lever:northwind", label: "Northwind", source: .rule)

    func send(_ name: String, app: String = "Chrome", daysAgo: Double = 0) throws -> Int64 {
        try store.record(NewSend(path: "/t/\(name)", fileName: name, appBundleID: "x", appName: app, url: "https://jobs.lever.co/northwind",
                                 pageTitle: "Apply, \"PM\"", method: .axPanel, sentAt: Date(timeIntervalSinceNow: -daysAgo * 86_400)),
                         destination: place, facts: FileFacts(sha256: name, sizeBytes: 2048))
    }

    @Test func permissionNameComesFromThisMac() {
        let name = SystemNames.accessibility
        // macOS 27 renamed the pane; older versions say "Accessibility".
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        #expect(major >= 27 ? name == "Device Control and Data Access" : name == "Accessibility")
    }

    @Test func statsCountSendsWeeksSavesAndApps() throws {
        _ = try send("a.pdf", daysAgo: 0)
        _ = try send("b.pdf", app: "Mail", daysAgo: 8)
        let w1 = try send("c.pdf", daysAgo: 0)
        let result = WarningResult(fired: [Warning(rule: .w1)], card: Warning(rule: .w1))
        let id = try #require(try store.record(result, forSend: w1, familyID: nil, fileID: nil, sensitivity: .balanced))
        try store.setOutcome(warning: id, "fixed", detail: "Picked")
        let stats = try store.stats()
        #expect(stats.sends == 3 && stats.caught == 1 && stats.cardsShown == 1)
        #expect(stats.perWeek.count == 12 && stats.perWeek.reduce(0, +) == 3)
        #expect(stats.perWeek.last == 2)
        #expect(stats.caughtBy.first?.rule == "W1")
        #expect(stats.busiest.first?.app == "Chrome" && stats.busiest.first?.count == 2)
    }

    @Test func csvExportQuotesAndDefusesFormulas() throws {
        _ = try send("=cmd().pdf")
        let csv = try store.exportCSV()
        #expect(csv.hasPrefix("\u{FEFF}\"Sent (UTC)\""))
        #expect(csv.contains("\"'=cmd().pdf\""))          // formula defused
        #expect(csv.contains("\"Apply, \"\"PM\"\"\""))      // commas and quotes escaped
        #expect(csv.components(separatedBy: "\r\n").count == 3) // header, row, trailing newline
    }

    @Test func deleteEverythingLeavesNothing() throws {
        _ = try send("a.pdf")
        try store.setSetting("onboarding_done", "1")
        try store.addWatchedFolder("/x")
        try store.deleteEverything()
        #expect(try store.sendCount() == 0)
        #expect(try store.search("a").isEmpty)
        #expect(try store.setting("onboarding_done") == nil)
        #expect(try store.watchedFolders().isEmpty)
        #expect(try store.destinations().isEmpty)
    }

    @Test func mutedListAndUnmute() throws {
        let id = try send("a.pdf")
        let destination = try #require(try store.send(id: id)).destinationID
        try store.muteDestination(destination)
        #expect(try store.muted().map(\.name) == ["Northwind"])
        try store.unmute(try store.muted()[0])
        #expect(try store.muted().isEmpty)
    }

    @Test func appsCanBeSwitchedOff() throws {
        try store.setApp("us.zoom.xos", enabled: false)
        #expect(try store.disabledApps() == ["us.zoom.xos"])
        try store.setApp("us.zoom.xos", enabled: true)
        #expect(try store.disabledApps().isEmpty)
    }

    @Test func folderSummaryCountsFilesAndBytes() throws {
        _ = try store.upsert(IndexedFile(path: "/w/a.pdf", name: "a.pdf", facts: FileFacts(sha256: "1", sizeBytes: 1000)), inWatchedFolder: true)
        _ = try store.upsert(IndexedFile(path: "/w/b/c.pdf", name: "c.pdf", facts: FileFacts(sha256: "2", sizeBytes: 500)), inWatchedFolder: true)
        _ = try store.upsert(IndexedFile(path: "/other/d.pdf", name: "d.pdf", facts: FileFacts(sha256: "3", sizeBytes: 9)), inWatchedFolder: true)
        let summary = try store.folderSummary("/w")
        #expect(summary.files == 2 && summary.bytes == 1500)
    }

    @Test func indexRuleSwitches() {
        let defaults = IndexRules()
        #expect(defaults.skipsFolder("node_modules") && defaults.skipsFolder("Library") && !defaults.indexes(name: "a.pdf", sizeBytes: 10))
        let open = IndexRules(skipSystem: false, skipCode: false, skipTiny: false)
        #expect(!open.skipsFolder("node_modules") && !open.skipsFolder("Library"))
        #expect(open.indexes(name: "a.pdf", sizeBytes: 10))
        #expect(open.indexes(name: ".hidden.pdf", sizeBytes: 5000))
    }

    @Test func turnedOffRulesDontFire() {
        let input = WarningInput(sendID: 1, fileID: 1, fileName: "resume_v3.pdf", sha256: "x", editedAt: Date(timeIntervalSinceNow: -86_400 * 10),
                                 familyID: 1, versionNumber: 1, isVariant: false, exportOfID: nil,
                                 family: [FamilyFile(id: 2, name: "resume_v5.pdf", editedAt: Date(), versionNumber: 2, relationToPicked: .version)],
                                 destinationID: 1, destinationKey: "k", destinationLabel: "Northwind", destinationText: "",
                                 destinationIdentified: true, pastSends: [], knownOrganisations: [:])
        #expect(WarningEngine.evaluate(input).card?.rule == .w1)
        var off = input
        off.disabledRules = [.w1]
        #expect(WarningEngine.evaluate(off).fired.isEmpty) // the softer check goes with W1
    }
}
