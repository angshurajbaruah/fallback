import FallbackCore
import SwiftUI

/// S1, the menu-bar popover (Design/screens/01): normal, empty, search results, no results, paused,
/// and permission problem.
struct PopoverView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    @State private var query: String
    @FocusState private var searchFocused: Bool

    init(query: String = "") { _query = State(initialValue: query) }
    @State private var recent: [SendRow] = []
    @State private var total = 0
    @State private var results: [SendRow] = []
    @State private var summary: DestinationSummary?
    @State private var suggestion: DestinationSummary?
    @State private var alsoMatching: [FamilyMember] = []
    @State private var showWhy = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                SearchField(placeholder: "Search what you sent", text: $query, focused: $searchFocused)
                content
            }
            .padding(12)
            Rectangle().fill(Theme.line).frame(height: 1)
            footer
        }
        .frame(width: Theme.popoverWidth)
        .background(Theme.popoverBackground)
        .overlay(RoundedRectangle(cornerRadius: Theme.popoverRadius).strokeBorder(Theme.popoverBorder))
        .background(keyboardShortcuts)
        .task(id: "\(model.version)|\(query)") { reload() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            searchFocused = true // BRAND.md: the search is focused when the popover opens
            reload()
        }
    }

    // MARK: States

    @ViewBuilder private var content: some View {
        if !model.isTrusted {
            permissionBanner
            SectionLabel(text: "Last recorded").padding(.leading, 8)
            rows(Array(recent.prefix(3)))
        } else if model.isPaused {
            pausedBanner
            SectionLabel(text: "Recent").padding(.leading, 8)
            rows(Array(recent.prefix(3)), dimmed: true)
        } else if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            if results.isEmpty && alsoMatching.isEmpty { noResults } else { searchResults }
        } else if total == 0 {
            statusLine(detail: "ready")
            emptyState
        } else {
            statusLine(detail: total == 1 ? "1 send" : "\(total) sends")
            SectionLabel(text: "Recent").padding(.leading, 8)
            rows(recent)
        }
    }

    private func statusLine(detail: String) -> some View {
        HStack(spacing: 7) {
            Circle().fill(Theme.frostedBlue).frame(width: 7, height: 7)
                .overlay(Circle().stroke(Theme.frostedBlue.opacity(0.3), lineWidth: 3))
            Text("\(model.folders.isEmpty ? "Watching" : model.foldersPhrase) · \(detail)").font(Theme.caption).foregroundStyle(Theme.text)
            Spacer()
        }
        .padding(.horizontal, 8)
    }

    private func rows(_ sends: [SendRow], dimmed: Bool = false) -> some View {
        VStack(spacing: 0) {
            ForEach(sends) { send in
                PopoverRow(title: send.fileName, subtitle: sendSubtitle(send), version: send.versionLabel, dimmed: dimmed) { openLedger(.allSends(selected: send.id)) }
            }
        }
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let summary {
                Button { openLedger(.byDestination(selected: summary.id)) } label: {
                    HStack(spacing: 12) {
                        Avatar(label: summary.label, size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.label).font(Theme.bodyMedium).foregroundStyle(Theme.primary)
                            Text("\(summary.sendCount == 1 ? "1 send" : "\(summary.sendCount) sends") · last \(SendTime.day(summary.lastSentAt))")
                                .font(Theme.caption).foregroundStyle(Theme.textMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(Theme.caption).foregroundStyle(Theme.textMuted)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: Theme.popoverRowHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            ForEach(results.prefix(10)) { send in
                PopoverRow(title: send.fileName,
                           subtitle: [SendTime.long(send.sentAt), shortAppName(send.appName), send.pageTitle ?? send.destinationLabel]
                            .joined(separator: " · "),
                           version: send.versionLabel) { openLedger(.allSends(selected: send.id)) }
            }
            if !alsoMatching.isEmpty {
                SectionLabel(text: "Also matching").padding(.leading, 8).padding(.top, 8).padding(.bottom, 4)
                ForEach(alsoMatching) { file in
                    PopoverRow(title: file.name, subtitle: file.whereFrom == nil ? "Not sent" : "Downloaded · not sent",
                               dimmed: true) {
                        if let path = file.path { NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)]) }
                    }
                }
            }
        }
    }

    private var noResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18)).foregroundStyle(Theme.textMuted)
                .frame(width: 44, height: 44)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
            Text("No sends match “\(query)”").font(Theme.bodyMedium).foregroundStyle(Theme.text)
            if let suggestion {
                HStack(spacing: 0) {
                    Text("Did you mean ")
                    Button(suggestion.label) { query = suggestion.label }
                        .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    Text("? \(suggestion.sendCount == 1 ? "1 send" : "\(suggestion.sendCount) sends").")
                }
                .font(Theme.caption).foregroundStyle(Theme.textMuted)
            }
            Text("Search runs on this Mac only. Nothing leaves it.")
                .font(Theme.captionSmall).foregroundStyle(Theme.textMuted).padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            DocStack(height: 120).padding(.bottom, 8)
            Text("Nothing sent yet").font(Theme.brand(20)).foregroundStyle(Theme.text)
            Text("Attach a file anywhere, in Chrome, Mail, Slack or WhatsApp, and it shows up here.")
                .font(Theme.caption).foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center).frame(maxWidth: 270)
            Button("Try it on a test page") {
                if let page = Bundle.main.url(forResource: "upload-test", withExtension: "html") {
                    NSWorkspace.shared.open(page)
                }
            }
            .buttonStyle(PillButtonStyle())
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var pausedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "pause.fill").font(.system(size: 11)).foregroundStyle(Theme.textMuted)
                .frame(width: 30, height: 30)
                .background(Theme.hoverFill, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(pausedTitle).font(Theme.bodyMedium).foregroundStyle(Theme.text)
                Text("Sends made now won't be recorded.").font(Theme.caption).foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Resume") { model.resume() }.buttonStyle(FallbackButtonStyle(kind: .frost)).fixedSize()
        }
        .padding(10)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
    }

    private var pausedTitle: String {
        guard let until = model.pausedUntil, until != .distantFuture else { return "Paused until you resume" }
        if Calendar.current.isDateInTomorrow(until), until == Calendar.current.startOfDay(for: until) {
            return "Paused until tomorrow"
        }
        return "Paused until \(until.formatted(date: .omitted, time: .shortened))"
    }

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(Theme.warningText).font(.system(size: 15))
            VStack(alignment: .leading, spacing: 6) {
                Text("Fallback can't see file pickers").font(Theme.bodyMedium).foregroundStyle(Theme.text)
                Text("Accessibility was turned off. Turn it back on to keep your trail complete.")
                    .font(Theme.caption).foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                    .buttonStyle(FallbackButtonStyle(kind: .primary))
                    Button("Why?") { showWhy.toggle() }
                        .buttonStyle(FallbackButtonStyle(kind: .ghost))
                        .popover(isPresented: $showWhy) {
                            // Wording from PRD Flow A, step 2.
                            Text("Fallback needs Accessibility so it can see which file you pick when you attach something.")
                                .font(Theme.caption).frame(width: 240).padding(12)
                        }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warningTint, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.warning.opacity(0.45)))
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 14) {
            Button { openLedger(model.ledgerRoute) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                    Text("Open Ledger").foregroundStyle(Theme.text)
                    Text("⌘L").font(Theme.captionSmall)
                }
                .font(Theme.body).foregroundStyle(Theme.textMuted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("l", modifiers: .command)
            Spacer()
            if model.isPaused {
                Button { model.resume() } label: { Image(systemName: "play.fill") }
                    .buttonStyle(.plain).foregroundStyle(Theme.textMuted).help("Resume")
            } else {
                PauseMenu()
            }
            // Settings (S6) arrives in M5.
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    /// ⌘Q to quit (the popover has no Quit item by design), and the debug log in development builds.
    private var keyboardShortcuts: some View {
        ZStack {
            Button("Quit Fallback") { NSApp.terminate(nil) }.keyboardShortcut("q", modifiers: .command)
            #if DEBUG
            Button("Detection Log") { openWindow(id: "detection-log"); NSApp.activate() }
                .keyboardShortcut("d", modifiers: [.command, .option])
            #endif
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    // MARK: Data

    private func openLedger(_ route: LedgerRoute) {
        model.show(route)
        openWindow(id: "ledger")
        NSApp.activate()
    }

    private func reload() {
        let store = model.store
        recent = (try? store.sends(limit: 10)) ?? []
        total = (try? store.sendCount()) ?? 0
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { results = []; summary = nil; suggestion = nil; alsoMatching = []; return }
        results = (try? store.search(text)) ?? []
        alsoMatching = (try? store.unsentFiles(matching: text)) ?? []
        let lowered = text.lowercased()
        summary = (try? store.destinations())?.first { $0.label.lowercased().contains(lowered) }
        suggestion = results.isEmpty ? (try? store.closestDestination(to: text)) : nil
    }
}

/// A 48 pt popover row: document glyph, file name, and "{destination} · {app} · {time}".
private struct PopoverRow: View {
    var title: String
    var subtitle: String
    var version: String? = nil
    var dimmed = false
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                DocGlyph(height: 30, dimmed: dimmed)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.rowTitle).foregroundStyle(dimmed ? Theme.textMuted : Theme.text).lineLimit(1)
                    Text(subtitle).font(Theme.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if let version { VersionChip(label: version).opacity(dimmed ? 0.5 : 1) }
            }
            .padding(.horizontal, 8)
            .frame(height: Theme.popoverRowHeight)
            .background(hovering ? Theme.hoverFill : .clear, in: RoundedRectangle(cornerRadius: Theme.popoverRowRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Pause for 1 hour, until tomorrow, or until resumed (FR-30).
struct PauseMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Button("For 1 Hour") { model.pause(.oneHour) }
            Button("Until Tomorrow") { model.pause(.untilTomorrow) }
            Button("Until I Resume") { model.pause(.untilResumed) }
        } label: {
            Image(systemName: "pause")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(Theme.textMuted)
        .help("Pause")
    }
}

/// The white pill used for "Try it on a test page".
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bodyMedium)
            .foregroundStyle(Theme.black)
            .padding(.horizontal, 16)
            .frame(height: 30)
            .background(Theme.lavenderBlush, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
