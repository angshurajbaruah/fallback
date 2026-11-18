import CoreServices
import Foundation
import os

/// PRD 9.6: watches the chosen folders with FSEvents, fingerprints files once they've settled for
/// 2 seconds, follows renames by file identity, and regroups document families after each batch.
/// Everything runs on one low-priority queue.
public final class FileIndexer: @unchecked Sendable { // all mutable state is touched only on `queue`
    public enum Event: Sendable {
        case scanning(done: Int, total: Int)
        case updated
    }

    private let store: Store
    private let analyzer: FileAnalyzer
    private let rules: IndexRules
    private let onEvent: @Sendable (Event) -> Void
    private let queue = DispatchQueue(label: "com.angshurajbaruah.fallback.indexer", qos: .utility)
    private let logger = Logger(subsystem: "com.angshurajbaruah.fallback", category: "indexer")
    private static let debounce: TimeInterval = 2
    /// Bump when FileAnalyzer starts reading something new, so existing files are re-read once.
    static let analysisVersion = "2"

    private var stream: FSEventStreamRef?
    private var folders: [String] = []
    private var pending: [String: Date] = [:]
    private var timer: DispatchSourceTimer?

    public init(store: Store, analyzer: FileAnalyzer, rules: IndexRules = IndexRules(),
                onEvent: @escaping @Sendable (Event) -> Void) {
        self.store = store
        self.analyzer = analyzer
        self.rules = rules
        self.onEvent = onEvent
    }

    /// Starts (or restarts) watching these folders, after a full scan to catch changes made while
    /// Fallback wasn't running.
    public func watch(_ paths: [String]) {
        queue.async { [self] in
            stopStream()
            folders = paths.map(Self.realPath)
            scanAll()
            startStream()
        }
    }

    /// Stops watching. Also happens automatically when the indexer is released.
    public func stop() {
        queue.sync { [self] in
            stopStream()
            timer?.cancel()
            timer = nil
        }
    }

    deinit {
        // Runs off `queue`; the stream must stop before `self` goes away (it holds an unretained pointer).
        stopStream()
        timer?.cancel()
    }

    /// FSEvents reports real paths (/private/var/…, symlinks resolved), so watched folders are stored the same way.
    static func realPath(_ path: String) -> String {
        guard let resolved = realpath((path as NSString).expandingTildeInPath, nil) else { return path }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// Analyses and stores one file right away: used when a file is sent (FR-19), wherever it lives.
    public func analyzeNow(path: String) -> IndexedFile { analyzer.analyze(path: path) }

    public func isInWatchedFolder(_ path: String) -> Bool {
        queue.sync { folders.contains { path.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") } }
    }

    /// Regroups families from everything in the database, then tells the app.
    public func regroup() {
        queue.async { [self] in regroupNow() }
    }

    // MARK: Scanning

    private func scanAll() {
        var paths: [String] = []
        for folder in folders { paths += eligibleFiles(in: folder) }
        let reread = (try? store.setting("analysis_version")) != Self.analysisVersion
        for (done, path) in paths.enumerated() {
            index(path, force: reread)
            if done % 25 == 0 { onEvent(.scanning(done: done, total: paths.count)) }
        }
        // Files deleted while Fallback wasn't running.
        let seen = Set(paths)
        for folder in folders {
            for path in (try? store.indexedPaths(under: folder)) ?? [] where !seen.contains(path) {
                try? store.markMissing(path: path)
            }
        }
        try? store.setSetting("analysis_version", Self.analysisVersion)
        onEvent(.scanning(done: paths.count, total: paths.count))
        regroupNow()
    }

    private func eligibleFiles(in folder: String) -> [String] {
        let url = URL(filePath: folder)
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .fileSizeKey],
                                                          options: [.skipsHiddenFiles]) else { return [] }
        var out: [String] = []
        while let item = walker.nextObject() as? URL {
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .fileSizeKey])
            let name = item.lastPathComponent
            if values?.isDirectory == true {
                if rules.skipsFolder(name) { walker.skipDescendants(); continue }
                if values?.isPackage == true {
                    walker.skipDescendants()
                    if rules.indexes(name: name, sizeBytes: nil, isPackage: true) { out.append(item.path) }
                }
                continue
            }
            if rules.indexes(name: name, sizeBytes: values?.fileSize.map(Int64.init)) { out.append(item.path) }
        }
        return out
    }

    /// Analyses one path unless the index already has it at the same size and date.
    private func index(_ path: String, force: Bool = false) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value
        let modified = attributes?[.modificationDate] as? Date
        if !force, let known = try? store.stamp(path: path), known.size == size, known.modified == modified { return }
        do {
            try store.upsert(analyzer.analyze(path: path), inWatchedFolder: true)
        } catch {
            logger.error("Couldn't index a file: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func regroupNow() {
        do {
            let known = Set(try store.destinations().map(\.label))
            let result = FamilyEngine.build(files: try store.evidence(), decisions: try store.userDecisions(),
                                            knownOrganisations: known)
            try store.apply(result)
            latestSuggestions = result.suggestions
        } catch {
            logger.error("Couldn't regroup documents: \(error.localizedDescription, privacy: .public)")
        }
        onEvent(.updated)
    }

    private var latestSuggestions: [[Int64]] = []

    /// Medium-confidence groups from the last regroup, for "These 3 files look like the same document".
    public var suggestions: [[Int64]] { queue.sync { latestSuggestions } }

    // MARK: FSEvents (FR-15)

    private func startStream() {
        guard !folders.isEmpty else { return }
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, paths, _, _ in
            guard let info else { return }
            let indexer = Unmanaged<FileIndexer>.fromOpaque(info).takeUnretainedValue()
            let changed = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            indexer.received(changed) // already on `queue`
        }
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(nil, callback, &context, folders as CFArray,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5, flags) else { return }
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    private func stopStream() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func received(_ paths: [String]) {
        let now = Date()
        for path in paths { pending[path] = now }
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in self?.processDue() }
        timer.resume()
        self.timer = timer
    }

    /// Handles paths that have been quiet for 2 seconds, so a file being saved isn't read mid-write.
    private func processDue() {
        let now = Date()
        let due = pending.filter { now.timeIntervalSince($0.value) >= Self.debounce }.map(\.key)
        guard !due.isEmpty else { return }
        for path in due { pending[path] = nil }
        if pending.isEmpty { timer?.cancel(); timer = nil }
        for path in due.sorted() { handle(path) }
        regroupNow()
    }

    private func handle(_ path: String) {
        guard let root = folders.first(where: { path == $0 || path.hasPrefix($0 + "/") }),
              !rules.skipsPath(path, under: root) else { return }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            // Deleted, or the old name of a rename: the new name arrives as its own event and
            // is matched to the same row by file identity (FR-17).
            try? store.markMissing(path: path)
            return
        }
        let url = URL(filePath: path)
        let isPackage = (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) == true
        if isDirectory.boolValue && !isPackage {
            if !rules.skipsFolder(url.lastPathComponent) { for file in eligibleFiles(in: path) { index(file) } }
            return
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value
        if rules.indexes(name: url.lastPathComponent, sizeBytes: size, isPackage: isPackage) { index(path) }
    }
}
