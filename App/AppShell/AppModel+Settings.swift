import AppKit
import FallbackCore
import ServiceManagement

/// Settings (S6), onboarding (S5) and Stats (S7): FR-28 to FR-36.
extension AppModel {
    // MARK: Stored settings

    /// Reads a setting; touching `version` makes views refresh when settings change.
    func setting(_ key: String) -> String? {
        _ = version
        return try? store.setting(key)
    }

    func set(_ key: String, _ value: String?) {
        try? store.setSetting(key, value)
        changed()
    }

    func flag(_ key: String, default value: Bool) -> Bool { setting(key).map { $0 == "1" } ?? value }
    func setFlag(_ key: String, _ value: Bool) { set(key, value ? "1" : "0") }

    func loadSettings() {
        onboardingDone = (try? store.setting("onboarding_done")) == "1"
        disabledApps = (try? store.disabledApps()) ?? []
        applyAppearance()
        registerShortcut()
    }

    // MARK: General (screen 16)

    /// FR-29: Apple's login item service. On by default once onboarding finishes.
    var launchAtLogin: Bool {
        get { _ = version; return SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                log.add("SETTINGS", "launch at login: \(error.localizedDescription)")
            }
            changed()
        }
    }

    var tickOnSend: Bool {
        get { flag("tick_on_send", default: true) }
        set { setFlag("tick_on_send", newValue) }
    }

    var showSendCount: Bool {
        get { flag("show_send_count", default: false) }
        set { setFlag("show_send_count", newValue) }
    }

    enum Appearance: String, CaseIterable { case system = "System", light = "Light", dark = "Dark" }

    var appearance: Appearance {
        get { setting("appearance").flatMap(Appearance.init(rawValue:)) ?? .system }
        set { set("appearance", newValue.rawValue); applyAppearance() }
    }

    func applyAppearance() {
        NSApp.appearance = switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// The small tick on the menu-bar icon after each send (Flow B). Off when Reduce Motion is on.
    func pulseTick() {
        guard tickOnSend, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        tickPulse = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            tickPulse = false
        }
    }

    // MARK: Search shortcut (FR-35)

    /// ⌥⌘F by default, stored as "keyCode:carbonModifiers".
    var searchShortcut: HotKey.Combo {
        get { setting("search_shortcut").flatMap(HotKey.Combo.init(storage:)) ?? .defaultSearch }
        set { set("search_shortcut", newValue.storage); registerShortcut() }
    }

    func registerShortcut() {
        hotKey.action = { [weak self] in self?.openPopover() }
        hotKey.register(searchShortcut)
    }

    /// Opens the menu-bar popover, as if its icon were clicked.
    // shortcut: finds MenuBarExtra's status button in the window list; switch to an own NSStatusItem if this ever breaks.
    func openPopover() {
        for window in NSApp.windows where String(describing: type(of: window)).contains("StatusBarWindow") {
            if let button = window.contentView?.firstDescendant(of: NSStatusBarButton.self) {
                button.performClick(nil)
                return
            }
        }
    }

    // MARK: Folders (screen 17)

    var indexRules: IndexRules {
        IndexRules(extraTypes: (setting("index_extra_types") ?? "").split(separator: ",").map(String.init),
                   skipSystem: flag("skip_system", default: true), skipCode: flag("skip_code", default: true),
                   skipTiny: flag("skip_tiny", default: true))
    }

    func setIndexFlag(_ key: String, _ value: Bool) {
        setFlag(key, value)
        indexerUpdateRules()
    }

    func addFileType(_ text: String) {
        let type = IndexRules.normalisedType(text)
        guard !type.isEmpty, type.allSatisfy({ $0.isLetter || $0.isNumber }) else { return }
        var extra = Set((setting("index_extra_types") ?? "").split(separator: ",").map(String.init))
        extra.insert(type)
        set("index_extra_types", extra.sorted().joined(separator: ","))
        indexerUpdateRules()
    }

    func setFolders(_ paths: [String]) {
        for old in folders where !paths.contains(old) { try? store.removeWatchedFolder(old) }
        for path in paths { try? store.addWatchedFolder(path) }
        replaceFolders((try? store.watchedFolders()) ?? paths)
    }

    func removeFolder(_ path: String) {
        try? store.removeWatchedFolder(path)
        replaceFolders(folders.filter { $0 != path })
    }

    // MARK: Apps (screen 18, FR-3)

    func setApp(_ bundleID: String, enabled: Bool) {
        try? store.setApp(bundleID, enabled: enabled)
        disabledApps = (try? store.disabledApps()) ?? []
        changed()
    }

    /// `noAnswer`: macOS says yes, but the browser didn't reply to a real request.
    enum BrowserAccess: Equatable { case allowed, denied, notAsked, notRunning, notInstalled, noAnswer }

    /// Whether Fallback may read this browser's page address, without asking.
    nonisolated static func browserAccess(_ bundleID: String, ask: Bool = false) -> BrowserAccess {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil else { return .notInstalled }
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let desc = target.aeDesc else { return .notAsked }
        switch AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, ask) {
        case noErr: return .allowed
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(procNotFound): return .notRunning
        default: return .notAsked
        }
    }

    /// "Test now": opens the browser in the background if needed, then lets macOS ask (Flow A step 3).
    func testBrowser(_ bundleID: String) async -> BrowserAccess {
        if Self.browserAccess(bundleID) == .notRunning, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            configuration.hides = true
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            try? await Task.sleep(for: .seconds(1.5))
        }
        // Asking blocks until the person answers macOS's prompt, so it runs off the main thread.
        let access = await Task.detached { Self.browserAccess(bundleID, ask: true) }.value
        return access == .allowed ? Self.verifyBrowser(bundleID) : access
    }

    /// Proves it works: asks the browser a real question over Apple Events, the same channel that reads
    /// the page address at pick time (FR-4). macOS saying "allowed" isn't enough on its own.
    static func verifyBrowser(_ bundleID: String) -> BrowserAccess {
        var error: NSDictionary?
        let script = "with timeout of 3 seconds\ntell application id \"\(bundleID)\" to count windows\nend timeout"
        _ = NSAppleScript(source: script)?.executeAndReturnError(&error)
        guard let error else { return .allowed }
        return (error[NSAppleScript.errorNumber] as? Int) == -1743 ? .denied : .noAnswer
    }

    // MARK: Warnings (screen 19)

    var sensitivity: Sensitivity {
        get { setting("sensitivity").flatMap(Sensitivity.init(rawValue:)) ?? .balanced }
        set { set("sensitivity", newValue.rawValue) }
    }

    func isRuleOn(_ rule: WarningRule) -> Bool {
        !(setting("rules_off") ?? "").split(separator: ",").contains { $0 == rule.rawValue }
    }

    func setRule(_ rule: WarningRule, on: Bool) {
        var off = Set((setting("rules_off") ?? "").split(separator: ",").map(String.init))
        if on { off.remove(rule.rawValue) } else { off.insert(rule.rawValue) }
        set("rules_off", off.sorted().joined(separator: ","))
    }

    func unmute(_ item: Store.Muted) {
        try? store.unmute(item)
        changed()
    }

    // MARK: Privacy (screen 20, FR-33, FR-34)

    /// The only network request Fallback makes, once Sparkle arrives (M6).
    var checkForUpdates: Bool {
        get { flag("check_updates", default: true) }
        set { setFlag("check_updates", newValue) }
    }

    /// FR-14: every send as CSV, through the standard Save panel.
    func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Fallback sends.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url, let csv = try? store.exportCSV() else { return }
        do { try csv.write(to: url, atomically: true, encoding: .utf8) } catch {
            log.add("EXPORT", "couldn't save the CSV: \(error.localizedDescription)")
        }
    }

    /// FR-33: removes the database contents and caches completely, then starts onboarding again.
    func deleteEverything() {
        presenter.dismiss(animated: false)
        try? store.deleteEverything()
        try? FileManager.default.removeItem(at: FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/Fallback"))
        replaceFolders([])
        loadSettings()
        changed()
        openWindow("onboarding")
    }

    // MARK: Onboarding (S5)

    func finishOnboarding() {
        set("onboarding_done", "1")
        onboardingDone = true
        gotItArmed = false
        launchAtLogin = true // FR-29: on by default after onboarding
    }

    /// The one-time "Got it" card (Design/screens/02, COPY.md).
    func showGotIt(_ send: SendRow) {
        let site = send.url.flatMap { URL(string: $0)?.host() } ?? send.destinationLabel
        let content = WarningCardContent(gotIt: send.fileName, site: site)
        presenter.show(WarningCardView(content: content,
                                       onPrimary: { [weak self] in self?.presenter.dismiss(); self?.openLedger(.allSends(selected: send.id)) },
                                       onSecondary: {}, onMute: {}, onMore: {},
                                       onClose: { [weak self] in self?.presenter.dismiss() },
                                       onTimeout: { [weak self] in self?.presenter.dismiss() }))
    }
}

extension NSView {
    func firstDescendant<T: NSView>(of type: T.Type) -> T? {
        for view in subviews {
            if let match = view as? T ?? view.firstDescendant(of: type) { return match }
        }
        return nil
    }
}
