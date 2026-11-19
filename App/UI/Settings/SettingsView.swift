import AppKit
import FallbackCore
import SwiftUI

/// S6, Settings (Design/screens/16 to 21, FR-32): General, Folders, Apps, Warnings, Privacy, About.
struct SettingsView: View {
    enum Tab: String, CaseIterable {
        case general = "General", folders = "Folders", apps = "Apps", warnings = "Warnings", privacy = "Privacy", about = "About"
        var symbol: String {
            switch self {
            case .general: "slider.horizontal.3"
            case .folders: "folder"
            case .apps: "square.grid.2x2"
            case .warnings: "exclamationmark.circle"
            case .privacy: "eye"
            case .about: "info.circle"
            }
        }
    }

    @State private var tab: Tab

    init(tab: Tab = .general) { _tab = State(initialValue: tab) }

    var body: some View {
        VStack(spacing: 0) {
            Text(tab.rawValue).font(Theme.windowTitle).padding(.top, 14)
            HStack(spacing: 6) {
                ForEach(Tab.allCases, id: \.self) { item in
                    Button { tab = item } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.symbol).font(.system(size: 18))
                                .foregroundStyle(tab == item ? Theme.primary : Theme.textMuted)
                            Text(item.rawValue).font(Theme.body).foregroundStyle(tab == item ? Theme.text : Theme.textMuted)
                        }
                        .frame(width: 92, height: 66)
                        .background(tab == item ? Theme.hoverFill : .clear, in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 10).padding(.bottom, 10)
            Rectangle().fill(Theme.line).frame(height: 1)
            ScrollView {
                Group {
                    switch tab {
                    case .general: GeneralTab()
                    case .folders: FoldersTab()
                    case .apps: AppsTab()
                    case .warnings: WarningsTab()
                    case .privacy: PrivacyTab()
                    case .about: AboutTab()
                    }
                }
                .padding(28)
            }
        }
        .frame(width: 880, height: 820)
        .background(Theme.surface2.opacity(0.6))
        .background(Theme.surface)
        .foregroundStyle(Theme.text)
        .toggleStyle(FrostToggleStyle())
    }
}

// MARK: General (screen 16)

private struct GeneralTab: View {
    @Environment(AppModel.self) private var model
    @State private var recording = false

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroup {
                SettingsRow(title: "Launch at login", subtitle: "Starts quietly in the menu bar.") {
                    Toggle("", isOn: $model.launchAtLogin).labelsHidden()
                }
                SettingsRow(title: "Tick on every send", subtitle: "A small animation on the menu-bar icon. Off when Reduce Motion is on.") {
                    Toggle("", isOn: $model.tickOnSend).labelsHidden()
                }
                SettingsRow(title: "Search shortcut") { ShortcutRecorder(recording: $recording) }
                SettingsRow(title: "Pause watching", subtitle: "Also in the menu-bar popover.", last: true) {
                    Menu {
                        Button("For 1 Hour") { model.pause(.oneHour) }
                        Button("Until Tomorrow") { model.pause(.untilTomorrow) }
                        Button("Until I Resume") { model.pause(.untilResumed) }
                        if model.isPaused { Divider(); Button("Resume Now") { model.resume() } }
                    } label: { Text(model.isPaused ? "Paused" : "Not paused").font(Theme.body) }
                        .fixedSize()
                }
            }
            SettingsGroup {
                SettingsRow(title: "Appearance") {
                    Segmented(options: AppModel.Appearance.allCases.map { ($0, $0.rawValue) }, selection: $model.appearance)
                }
                SettingsRow(title: "Show send count in menu bar", last: true) {
                    Toggle("", isOn: $model.showSendCount).labelsHidden()
                }
            }
            Text("Fallback has no Dock icon. Open it from the menu bar, or with \(model.searchShortcut.display).")
                .font(Theme.body).foregroundStyle(Theme.textMuted)
        }
    }
}

/// Click, then press the new combination (it needs ⌘, ⌥ or ⌃). Escape cancels.
private struct ShortcutRecorder: View {
    @Environment(AppModel.self) private var model
    @Binding var recording: Bool
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "Press a shortcut…" : model.searchShortcut.display.map(String.init).joined(separator: " "))
                .font(.system(size: 14, weight: .medium))
                .frame(width: 200, height: 40)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(recording ? Theme.focusBorder : Theme.line2))
        }
        .buttonStyle(.plain)
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                if event.keyCode == 53 { stop(); return }
                if let combo = HotKey.Combo(event: event) {
                    model.searchShortcut = combo
                    stop()
                }
            }
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

// MARK: Folders (screen 17)

private struct FoldersTab: View {
    @Environment(AppModel.self) private var model
    @State private var selected: String?
    @State private var summaries: [String: (files: Int, bytes: Int64)] = [:]
    @State private var fingerprints = 0
    @State private var updated: Date?
    @State private var addingType = false
    @State private var newType = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroup {
                ForEach(model.folders, id: \.self) { path in
                    Button { selected = path } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "folder").foregroundStyle(Theme.frostedBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text((path as NSString).lastPathComponent).font(Theme.body)
                                Text((path as NSString).abbreviatingWithTildeInPath).font(Theme.mono).foregroundStyle(Theme.textMuted)
                            }
                            Spacer()
                            if let summary = summaries[path] {
                                Text("\(summary.files.formatted()) files · \(summary.bytes.formatted(.byteCount(style: .file)))")
                                    .font(Theme.body).foregroundStyle(Theme.textMuted)
                            }
                        }
                        .padding(.horizontal, 20).frame(height: 58)
                        .background(selected == path ? Theme.selectedFill : .clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
                }
                HStack(spacing: 20) {
                    Button(action: addFolder) { Image(systemName: "plus") }.buttonStyle(.plain).help("Add a folder")
                    Button {
                        if let selected { model.removeFolder(selected) }
                        selected = nil
                    } label: { Image(systemName: "minus") }
                        .buttonStyle(.plain).disabled(selected == nil).help("Stop watching the selected folder")
                    Spacer()
                    Text("\(fingerprints.formatted()) files fingerprinted" + (updated.map { " · updated \($0.formatted(.relative(presentation: .named)))" } ?? ""))
                        .font(Theme.body).foregroundStyle(Theme.textMuted)
                }
                .font(.system(size: 15))
                .padding(.horizontal, 20).frame(height: 46)
            }
            SectionLabel(text: "File types")
            WrapLayout(spacing: 8) {
                ForEach(model.indexRules.types.sorted(by: Self.typeOrder), id: \.self) { type in
                    Text(".\(type)").font(Theme.body).padding(.horizontal, 10).frame(height: 28)
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.line2))
                }
                Button { addingType = true } label: { Label("Add", systemImage: "plus").font(Theme.bodyMedium) }
                    .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    .padding(.horizontal, 10).frame(height: 28)
                    .background(Theme.infoTint, in: RoundedRectangle(cornerRadius: 7))
                    .popover(isPresented: $addingType) {
                        HStack {
                            TextField("e.g. sketch", text: $newType).textFieldStyle(.roundedBorder).frame(width: 140)
                                .onSubmit(addType)
                            Button("Add", action: addType)
                        }
                        .padding(12)
                    }
            }
            SectionLabel(text: "Always skipped")
            SettingsGroup {
                SettingsRow(title: "Hidden files, app bundles, Library, caches") {
                    Toggle("", isOn: Binding(get: { model.flag("skip_system", default: true) }, set: { model.setIndexFlag("skip_system", $0) })).labelsHidden()
                }
                SettingsRow(title: "node_modules and .git folders") {
                    Toggle("", isOn: Binding(get: { model.flag("skip_code", default: true) }, set: { model.setIndexFlag("skip_code", $0) })).labelsHidden()
                }
                SettingsRow(title: "Files under 1 KB", last: true) {
                    Toggle("", isOn: Binding(get: { model.flag("skip_tiny", default: true) }, set: { model.setIndexFlag("skip_tiny", $0) })).labelsHidden()
                }
            }
        }
        .task(id: model.version) {
            for path in model.folders { summaries[path] = try? model.store.folderSummary(path) }
            fingerprints = (try? model.store.fingerprintCount()) ?? 0
            updated = try? model.store.lastIndexed()
        }
    }

    /// The PRD's order first (FR-22), then the user's own types.
    static func typeOrder(_ a: String, _ b: String) -> Bool {
        let order = ["pdf", "doc", "docx", "pages", "ppt", "pptx", "key", "xls", "xlsx", "numbers", "csv", "txt", "md", "rtf", "png", "jpg", "jpeg", "heic", "zip"]
        return (order.firstIndex(of: a) ?? 100, a) < (order.firstIndex(of: b) ?? 100, b)
    }

    private func addType() {
        model.addFileType(newType)
        newType = ""
        addingType = false
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Watch"
        if panel.runModal() == .OK { model.setFolders(model.folders + panel.urls.map(\.path)) }
    }
}

/// Lays chips out in rows, wrapping to the next line.
struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 800
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing
            row = max(row, size.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}

// MARK: Apps (screen 18, FR-3)

private struct AppsTab: View {
    @Environment(AppModel.self) private var model
    @State private var access: [String: AppModel.BrowserAccess] = [:]

    static let apps: [(id: String, name: String, kind: String)] = [
        ("com.apple.Safari", "Safari", "Browser"), ("com.google.Chrome", "Google Chrome", "Browser"),
        ("company.thebrowser.Browser", "Arc", "Browser"), ("com.brave.Browser", "Brave", "Browser"),
        ("com.microsoft.edgemac", "Microsoft Edge", "Browser"), ("org.mozilla.firefox", "Firefox", "Browser"),
        ("com.apple.mail", "Mail", "Email"), ("com.microsoft.Outlook", "Outlook", "Email"),
        ("com.tinyspeck.slackmacgap", "Slack", "Messaging"), ("net.whatsapp.WhatsApp", "WhatsApp", "Messaging"),
        ("ru.keepcoder.Telegram", "Telegram", "Messaging"), ("com.microsoft.teams2", "Microsoft Teams", "Messaging"),
        ("com.hnc.Discord", "Discord", "Messaging"), ("us.zoom.xos", "Zoom", "Meetings"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Fallback only watches file pickers in these apps. Picking a file in Preview or Word is ignored.")
                .font(Theme.body).foregroundStyle(Theme.textMuted)
            SettingsGroup {
                ForEach(Array(Self.apps.enumerated()), id: \.element.id) { index, app in
                    let installed = access[app.id] != .notInstalled
                    HStack(spacing: 16) {
                        Avatar(label: app.name, size: 30)
                        Text(app.name).font(Theme.body).foregroundStyle(installed ? Theme.text : Theme.textMuted)
                        Spacer()
                        Text(detail(app)).font(Theme.body).foregroundStyle(Theme.textMuted)
                        Chip(text: app.kind).frame(width: 110)
                        Toggle("", isOn: Binding(get: { !model.disabledApps.contains(app.id) },
                                                 set: { model.setApp(app.id, enabled: $0) })).labelsHidden()
                    }
                    .padding(.horizontal, 20).frame(height: 54)
                    .overlay(alignment: .bottom) { if index < Self.apps.count - 1 { Rectangle().fill(Theme.line).frame(height: 1) } }
                }
            }
        }
        .task {
            for app in Self.apps {
                access[app.id] = app.kind == "Browser" || NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.id) == nil
                    ? AppModel.browserAccess(app.id) : .allowed
            }
        }
    }

    private func detail(_ app: (id: String, name: String, kind: String)) -> String {
        if access[app.id] == .notInstalled { return "Not installed" }
        guard app.kind == "Browser" else { return "" }
        if app.id == "org.mozilla.firefox" { return "Window title only" }
        return switch access[app.id] {
        case .allowed?: "Page address: allowed"
        case .denied?: "Page address: not allowed"
        default: "Page address: not asked yet"
        }
    }
}

// MARK: Warnings (screen 19, PRD 8.2)

private struct WarningsTab: View {
    @Environment(AppModel.self) private var model
    @State private var muted: [Store.Muted] = []

    private let rules: [(WarningRule, String, String)] = [
        (.w1, "W1 · Older version", "A newer version of the same file exists"),
        (.w4, "W4 · Name mismatch", "File name mentions a different company"),
        (.w5, "W5 · Stale export", "The PDF is older than the doc it came from"),
        (.w3, "W3 · Changed since last send", "They already have a different version"),
        (.w2, "W2 · Already sent", "Same exact file, same place, last 90 days"),
    ]

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 20) {
            SectionLabel(text: "Sensitivity")
            HStack(spacing: 16) {
                level(.strict, "Strict", "Every rule as a card")
                level(.balanced, "Balanced", "W1, W4, W5 as cards")
                level(.quiet, "Quiet", "Only W4 and W1")
            }
            SettingsGroup {
                ForEach(Array(rules.enumerated()), id: \.offset) { index, item in
                    let (rule, title, detail) = item
                    SettingsRow(title: title, subtitle: detail, last: index == rules.count - 1) {
                        let card = model.sensitivity.showsCard(rule)
                        Chip(text: card ? "Card" : "Ledger only", highlighted: card)
                        Toggle("", isOn: Binding(get: { model.isRuleOn(rule) }, set: { model.setRule(rule, on: $0) })).labelsHidden()
                    }
                }
            }
            if !muted.isEmpty {
                SectionLabel(text: "Muted")
                SettingsGroup {
                    ForEach(Array(muted.enumerated()), id: \.element.id) { index, item in
                        SettingsRow(title: "\(item.name) · \(item.kind.rawValue)",
                                    subtitle: item.mutedAt.map { "Muted \($0.formatted(.dateTime.day().month(.abbreviated))) from a card" },
                                    last: index == muted.count - 1) {
                            Button("Unmute") { model.unmute(item) }.buttonStyle(FallbackButtonStyle(kind: .quiet))
                        }
                    }
                }
            }
        }
        .task(id: model.version) { muted = (try? model.store.muted()) ?? [] }
    }

    private func level(_ value: Sensitivity, _ title: String, _ detail: String) -> some View {
        let selected = model.sensitivity == value
        return Button { model.sensitivity = value } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.system(size: 15, weight: .semibold))
                    Spacer()
                    if selected { Image(systemName: "checkmark").foregroundStyle(Theme.primary) }
                }
                Text(detail).font(Theme.body).foregroundStyle(Theme.textMuted)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.selectedFill : Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Theme.focusBorder : Theme.line, lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Privacy (screen 20, FR-33)

private struct PrivacyTab: View {
    @Environment(AppModel.self) private var model
    @State private var counts = (sends: 0, fingerprints: 0, bytes: Int64(0))
    @State private var confirmDelete = false

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 24) {
                Image("LogoMark").resizable().scaledToFit().frame(width: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Everything stays on this Mac").font(.system(size: 17, weight: .semibold))
                    Text("No account, no servers. Fallback stores fingerprints and details, never copies of your files.")
                        .font(Theme.body).foregroundStyle(Theme.textMuted)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Theme.surface2, Theme.frostedBlue.opacity(0.06)], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line))
            SettingsGroup {
                SettingsRow(title: "Stored on this Mac") {
                    Text("\(counts.sends.formatted()) sends · \(counts.fingerprints.formatted()) fingerprints · \(counts.bytes.formatted(.byteCount(style: .file)))")
                        .font(Theme.body).foregroundStyle(Theme.textMuted)
                }
                SettingsRow(title: "Location") {
                    Text("~/Library/Application Support/Fallback").font(Theme.mono).foregroundStyle(Theme.textMuted).textSelection(.enabled)
                }
                SettingsRow(title: "Check for updates", subtitle: "The only network request Fallback makes. Signed updates only.", last: true) {
                    Toggle("", isOn: $model.checkForUpdates).labelsHidden()
                }
            }
            SettingsGroup {
                SettingsRow(title: "Export data", subtitle: "Every send, all columns, opens in Numbers or Excel.") {
                    Button("Export as CSV…") { model.exportCSV() }.buttonStyle(FallbackButtonStyle(kind: .quiet))
                }
                SettingsRow(title: "Delete all data", subtitle: "Removes the database and caches completely.", last: true) {
                    Button("Delete All…") { confirmDelete = true }.buttonStyle(DestructiveButtonStyle())
                }
            }
        }
        .task(id: model.version) {
            counts = ((try? model.store.sendCount()) ?? 0, (try? model.store.fingerprintCount()) ?? 0, model.store.fileSize)
        }
        .sheet(isPresented: $confirmDelete) {
            DeleteAllDialog(sends: counts.sends, fingerprints: counts.fingerprints)
        }
    }
}

/// Destructive = Tangerine fill with white text (BRAND.md "Buttons").
struct DestructiveButtonStyle: ButtonStyle {
    var wide = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bodyMedium)
            .foregroundStyle(Color(dark: 0xFFFFFF, light: 0xFFFFFF))
            .padding(.horizontal, 12)
            .frame(maxWidth: wide ? .infinity : nil)
            .frame(height: wide ? 36 : Theme.buttonHeight)
            .background(Theme.warning, in: RoundedRectangle(cornerRadius: Theme.buttonRadius))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// "Delete everything Fallback has recorded?" (Design/screens/23).
struct DeleteAllDialog: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var sends: Int
    var fingerprints: Int

    var body: some View {
        VStack(spacing: 16) {
            Image("LogoMark").resizable().scaledToFit().frame(height: 60)
            Text("Delete everything Fallback has recorded?").font(.system(size: 16, weight: .semibold)).multilineTextAlignment(.center)
            Text("This removes \(sends.formatted()) sends, \(fingerprints.formatted()) fingerprints and all document groups from this Mac. It can't be undone.")
                .font(Theme.body).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 8) {
                Button("Delete All Data") {
                    dismiss()
                    model.deleteEverything()
                }
                .buttonStyle(DestructiveButtonStyle(wide: true))
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain).font(Theme.bodyMedium)
                    .frame(maxWidth: .infinity).frame(height: 36)
                    .overlay(RoundedRectangle(cornerRadius: Theme.buttonRadius).strokeBorder(Theme.line2))
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.top, 6)
        }
        .padding(24)
        .frame(width: 400)
        .background(Theme.surface2)
    }
}

// MARK: About (screen 21)

private struct AboutTab: View {
    @Environment(AppModel.self) private var model

    private var version: String {
        let info = Bundle.main.infoDictionary
        return "Version \(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?")) · macOS 14 or later"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 180, height: 180)
            Wordmark(size: 40)
            Text(version).font(Theme.body).foregroundStyle(Theme.textMuted)
            Text("Never send the wrong file again, and always know what you sent.").font(Theme.body).foregroundStyle(Theme.textMuted)
                .padding(.top, 8)
            HStack(spacing: 10) {
                Button { NSWorkspace.shared.open(URL(string: "https://github.com/angshurajbaruah/fallback")!) } label: {
                    Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .buttonStyle(FallbackButtonStyle(kind: .quiet))
                // "Check for Updates" arrives with Sparkle (M6).
                Button("Fallback saved me") { model.openWindow("stats") }.buttonStyle(FallbackButtonStyle(kind: .primary))
            }
            .padding(.top, 8)
            Text("Open source under the MIT licence.").font(Theme.caption).foregroundStyle(Theme.textMuted).padding(.top, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }
}
