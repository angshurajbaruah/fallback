import AppKit
import FallbackCore
import Observation
import os

/// Which Ledger view to show, and what is selected in it.
enum LedgerRoute: Hashable {
    case allSends(selected: Int64?)
    case warnings
    case byDestination(selected: Int64?)
    /// nil shows every family; an id shows that family's timeline (S3).
    case byDocument(family: Int64?)
}

/// App-wide state: the ledger database, pause (FR-30) and the Accessibility permission (FR-31).
@MainActor @Observable
final class AppModel {
    let store: Store
    let resolver: DestinationResolver
    let log = DetectionLog()

    /// Bumped after every change to the ledger, so views reload.
    private(set) var version = 0
    private(set) var pausedUntil: Date?
    private(set) var isTrusted = AXIsProcessTrusted()
    var ledgerRoute: LedgerRoute = .allSends(selected: nil)
    /// Where the Ledger came from, for the breadcrumb, ⌘[ and swipe-back.
    private(set) var backStack: [LedgerRoute] = []
    var canGoBack: Bool { !backStack.isEmpty }

    /// A drill-in or jump inside the Ledger: remembers the current view so you can go back.
    func open(_ route: LedgerRoute) {
        guard route != ledgerRoute else { return }
        backStack.append(ledgerRoute)
        if backStack.count > 50 { backStack.removeFirst() }
        ledgerRoute = route
    }

    /// Top-level navigation (sidebar, popover): starts fresh, like a browser's address bar.
    func show(_ route: LedgerRoute) {
        backStack.removeAll()
        ledgerRoute = route
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        ledgerRoute = previous
    }

    /// A short name for a Ledger view, for "‹ Resume" back links.
    func title(of route: LedgerRoute) -> String {
        switch route {
        case .allSends: return "All sends"
        case .warnings: return "Warnings"
        case .byDestination(let id?):
            return (try? store.destinations())?.first { $0.id == id }?.label ?? "By destination"
        case .byDestination(nil): return "By destination"
        case .byDocument(let id?):
            return (try? store.families())?.first { $0.id == id }?.name ?? "By document"
        case .byDocument(nil): return "By document"
        }
    }
    /// Folders being watched (FR-15) and the medium-confidence groups to suggest (PRD 8.3).
    private(set) var folders: [String] = []
    private(set) var suggestions: [[Int64]] = []
    private(set) var indexing: (done: Int, total: Int)?

    @ObservationIgnored private var watcher: PanelWatcher?
    @ObservationIgnored private var indexer: FileIndexer?
    @ObservationIgnored private var timer: Timer?
    private let logger = Logger(subsystem: "com.angshurajbaruah.fallback", category: "ledger")

    var isPaused: Bool { pausedUntil.map { $0 > Date() } ?? false }

    convenience init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        do {
            try self.init(store: Store(path: support.appending(path: "Fallback/fallback.sqlite").path))
        } catch {
            // The ledger can't work without its database; nothing is lost by stopping here.
            fatalError("Fallback couldn't open its ledger: \(error)")
        }
    }

    init(store: Store) throws {
        self.store = store
        let json = try Data(contentsOf: Bundle.main.url(forResource: "destinations", withExtension: "json")!)
        resolver = try DestinationResolver(json: json)
        if let saved = try? store.setting("paused_until"), let seconds = Double(saved) {
            pausedUntil = Date(timeIntervalSince1970: seconds)
        }
    }

    #if DEBUG
    /// Snapshots only: show the permission-problem state without changing real permissions.
    func debugSetTrusted(_ trusted: Bool) { isTrusted = trusted }
    func debugSet(suggestions: [[Int64]], folders: [String]) {
        self.suggestions = suggestions
        self.folders = folders
    }
    #endif

    func start() {
        watcher = PanelWatcher(log: log) { [weak self] picks, context, method in
            self?.record(picks, context: context, method: method)
        }
        watcher?.start()
        startIndexer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkState() }
        }
    }

    private func checkState() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
        if let until = pausedUntil, until <= Date() { resume() }
    }

    // MARK: Indexing (FR-15 to FR-22)

    private func startIndexer() {
        let rules = IndexRules(
            extraTypes: (try? store.setting("index_extra_types"))?.split(separator: ",").map(String.init) ?? [],
            extraExcludes: (try? store.setting("index_extra_excludes"))?.split(separator: ",").map(String.init) ?? [])
        indexer = FileIndexer(store: store, analyzer: FileAnalyzer(readPDF: PDFContents.read), rules: rules) { [weak self] event in
            Task { @MainActor in self?.indexerEvent(event) }
        }
        var saved = (try? store.watchedFolders()) ?? []
        if saved.isEmpty {
            // shortcut: M3 watches ~/FallbackTest only (owner's choice); onboarding (M5) asks for real folders.
            let test = NSString(string: "~/FallbackTest").expandingTildeInPath
            if FileManager.default.fileExists(atPath: test) {
                try? store.addWatchedFolder(test)
                saved = [test]
            }
        }
        folders = saved
        indexer?.watch(saved)
    }

    private func indexerEvent(_ event: FileIndexer.Event) {
        switch event {
        case .scanning(let done, let total): indexing = done < total ? (done, total) : nil
        case .updated:
            suggestions = indexer?.suggestions ?? []
            if let (file, name) = pendingFamilyName, let family = (try? store.files(ids: [file]))?.first?.familyID {
                try? store.renameFamily(family, to: name)
                pendingFamilyName = nil
            }
            changed()
        }
    }

    /// "Choose folders" on the empty Ledger: adds folders and starts watching them.
    func addFolders(_ urls: [URL]) {
        for url in urls { try? store.addWatchedFolder(url.path) }
        folders = (try? store.watchedFolders()) ?? folders
        indexer?.watch(folders)
    }

    /// "Watching 3 folders" (BRAND/COPY), or the folder's name when there's one.
    var foldersPhrase: String {
        folders.count == 1 ? "Watching \((folders[0] as NSString).lastPathComponent)" : "Watching \(folders.count) folders"
    }

    /// "Documents, Desktop and Downloads" for the empty Ledger.
    var folderNames: String {
        let names = folders.map { ($0 as NSString).lastPathComponent }
        guard names.count > 1 else { return names.first ?? "no folders" }
        return names.dropLast().joined(separator: ", ") + " and " + names.last!
    }

    // MARK: Families (FR-18, FR-20)

    func group(_ fileIDs: [Int64], name: String) {
        guard let first = fileIDs.first else { return }
        try? store.addDecisions(fileIDs.dropFirst().map { .same(first, $0) })
        pendingFamilyName = (first, name)
        indexer?.regroup()
    }

    /// Splits a file off its family: it becomes its own document, and warnings follow right away.
    func splitOff(_ fileID: Int64, from members: [Int64]) {
        try? store.addDecisions(members.filter { $0 != fileID }.map { .separate(fileID, $0) })
        indexer?.regroup()
    }

    /// "Not now" on a suggestion.
    func dismissSuggestion(_ fileIDs: [Int64]) {
        var decisions: [UserDecision] = []
        for (index, a) in fileIDs.enumerated() { for b in fileIDs[(index + 1)...] { decisions.append(.dismissed(a, b)) } }
        try? store.addDecisions(decisions)
        suggestions.removeAll { $0 == fileIDs }
        indexer?.regroup()
    }

    func renameFamily(_ id: Int64, to name: String) {
        try? store.renameFamily(id, to: name)
        changed()
    }

    @ObservationIgnored private var pendingFamilyName: (file: Int64, name: String)?

    // MARK: Recording (FR-9)

    private func record(_ picks: [Pick], context: PanelContext, method: DetectionMethod) {
        guard !isPaused else {
            log.add("PAUSED", "not recorded: Fallback is paused")
            return
        }
        let destination = resolver.resolve(url: context.url, title: context.pageTitle,
                                           appBundleID: context.bundleID, appName: context.appName)
        let store = store
        let sentAt = Date()
        let indexer = indexer
        Task {
            for pick in picks {
                let send = NewSend(path: pick.path, fileName: pick.name, appBundleID: context.bundleID,
                                   appName: context.appName, url: context.url, pageTitle: context.pageTitle,
                                   method: method, sentAt: sentAt)
                // Fingerprinted and analysed at the moment of sending, wherever the file lives (FR-19).
                // Reading the file runs off the main thread.
                let file = await Task.detached { () -> IndexedFile? in
                    guard let path = pick.path else { return nil }
                    return indexer?.analyzeNow(path: path) ?? IndexedFile(path: path, name: pick.name, facts: FileFacts.read(path: path))
                }.value
                let watched = pick.path.map { indexer?.isInWatchedFolder($0) ?? false } ?? false
                do {
                    try store.record(send, destination: destination, file: file, inWatchedFolder: watched)
                } catch {
                    logger.error("Couldn't record a send: \(error.localizedDescription, privacy: .public)")
                }
            }
            log.add("RECORDED", "\(picks.count) file(s) → \(destination.label)")
            indexer?.regroup() // new files join their families (and the regroup bumps `version`)
            changed()
        }
    }

    func changed() { version += 1 }

    // MARK: Pause (FR-30)

    enum PauseLength { case oneHour, untilTomorrow, untilResumed }

    func pause(_ length: PauseLength) {
        let until: Date = switch length {
        case .oneHour: Date(timeIntervalSinceNow: 3600)
        case .untilTomorrow: Calendar.current.startOfDay(for: Date(timeIntervalSinceNow: 86_400))
        case .untilResumed: .distantFuture
        }
        pausedUntil = until
        try? store.setSetting("paused_until", String(until.timeIntervalSince1970))
    }

    func resume() {
        pausedUntil = nil
        try? store.setSetting("paused_until", nil)
    }

    // MARK: Ledger actions (FR-13)

    func renameDestination(ofSend id: Int64, to label: String, includingOthers: Bool) {
        try? store.renameDestination(ofSend: id, to: label, includingOthers: includingOthers)
        changed()
    }

    func renameDestination(id: Int64, to label: String) {
        try? store.renameDestination(id: id, to: label)
        changed()
    }

    func markNotASend(_ id: Int64) {
        try? store.markNotASend(id: id)
        changed()
    }

    func deleteSend(_ id: Int64) {
        try? store.deleteSend(id: id)
        changed()
    }
}
