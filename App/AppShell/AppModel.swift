import AppKit
import FallbackCore
import Observation
import os

/// Which Ledger view to show, and what is selected in it.
enum LedgerRoute: Hashable {
    case allSends(selected: Int64?)
    case byDestination(selected: Int64?)
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

    @ObservationIgnored private var watcher: PanelWatcher?
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
    #endif

    func start() {
        watcher = PanelWatcher(log: log) { [weak self] picks, context, method in
            self?.record(picks, context: context, method: method)
        }
        watcher?.start()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkState() }
        }
    }

    private func checkState() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
        if let until = pausedUntil, until <= Date() { resume() }
    }

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
        Task {
            for pick in picks {
                let send = NewSend(path: pick.path, fileName: pick.name, appBundleID: context.bundleID,
                                   appName: context.appName, url: context.url, pageTitle: context.pageTitle,
                                   method: method, sentAt: sentAt)
                // Fingerprinting reads the whole file, so it runs off the main thread.
                let facts = await Task.detached { pick.path.map(FileFacts.read(path:)) }.value
                do {
                    try store.record(send, destination: destination, facts: facts)
                } catch {
                    logger.error("Couldn't record a send: \(error.localizedDescription, privacy: .public)")
                }
            }
            log.add("RECORDED", "\(picks.count) file(s) → \(destination.label)")
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
