import FallbackCore
import QuickLook
import SwiftUI

/// All sends (Design/screens/04): grouped table, newest first, with the send inspector (FR-11, FR-12).
struct AllSendsView: View {
    @Environment(AppModel.self) private var model

    enum Period: String, CaseIterable { case today = "Today", week = "7 days", all = "All" }

    @State private var period: Period = .all
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var newestFirst = true
    @State private var sends: [SendRow] = []
    @State private var selection: Int64?
    @State private var total = 0

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                toolbar
                if total == 0 {
                    LedgerEmptyView()
                } else {
                    columnHeader
                    table
                }
            }
            if total > 0 {
            Rectangle().fill(Theme.line).frame(width: 1)
            Group {
                if let send = sends.first(where: { $0.id == selection }) {
                    SendInspector(send: send)
                } else {
                    Text(sends.isEmpty ? "" : "Select a send to see its details.")
                        .font(Theme.caption).foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: Theme.inspectorWidth)
            .background(Theme.surface2)
            }
        }
        .task(id: "\(model.version)|\(period)|\(query)|\(newestFirst)") { reload() }
        .onAppear { applyRoute() }
        .onChange(of: model.ledgerRoute) { applyRoute() }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 14) {
            if model.canGoBack {
                BackLink()
                Rectangle().fill(Theme.line2).frame(width: 1, height: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("All sends").font(Theme.windowTitle)
                Text(total == 1 ? "1 send" : "\(total) sends").font(Theme.caption).foregroundStyle(Theme.textMuted)
            }
            Spacer()
            HStack(spacing: 2) {
                ForEach(Period.allCases, id: \.self) { item in
                    Button(item.rawValue) { period = item }
                        .buttonStyle(.plain)
                        .font(Theme.body)
                        .foregroundStyle(period == item ? Theme.text : Theme.textMuted)
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(period == item ? Theme.hoverFill : .clear, in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(3)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 9))
            // Filter and Export (FR-14) icons arrive with their features.
            SearchField(placeholder: "Search sends", text: $query, focused: $searchFocused).frame(width: 300)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .frame(height: Theme.toolbarHeight + 14)
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("File").frame(maxWidth: .infinity, alignment: .leading)
            Text("Ver.").frame(width: 50, alignment: .leading)
            Text("Destination").frame(width: 240, alignment: .leading)
            Text("App").frame(width: 110, alignment: .leading)
            Button { newestFirst.toggle() } label: {
                HStack(spacing: 3) {
                    Text("Sent")
                    Image(systemName: newestFirst ? "chevron.down" : "chevron.up").font(.system(size: 8, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .help(newestFirst ? "Newest first" : "Oldest first")
            .frame(width: 90, alignment: .leading)
        }
        .font(Theme.caption)
        .foregroundStyle(Theme.textMuted)
        .padding(.horizontal, 36)
        .frame(height: 32)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    // MARK: Table

    private var table: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(groups, id: \.title) { group in
                        Text(group.title).font(Theme.caption.weight(.medium)).foregroundStyle(Theme.textMuted)
                            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 4)
                        ForEach(group.sends) { send in
                            SendTableRow(send: send, selected: selection == send.id) { selection = send.id }
                                .id(send.id)
                        }
                    }
                    if sends.isEmpty {
                        Text(query.isEmpty ? "No sends in this period." : "No sends match “\(query)”")
                            .font(Theme.caption).foregroundStyle(Theme.textMuted)
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 20)
            }
            .onChange(of: selection) { if let selection { withAnimation { proxy.scrollTo(selection) } } }
        }
    }

    private var groups: [(title: String, sends: [SendRow])] {
        var result: [(title: String, sends: [SendRow])] = []
        for send in sends {
            let title = SendTime.group(send.sentAt)
            if result.last?.title == title { result[result.count - 1].sends.append(send) } else { result.append((title, [send])) }
        }
        return result
    }

    // MARK: Data

    private func applyRoute() {
        if case .allSends(let selected?) = model.ledgerRoute {
            period = .all
            query = ""
            selection = selected
        }
    }

    private func reload() {
        let store = model.store
        let since: Date? = switch period {
        case .today: Calendar.current.startOfDay(for: Date())
        case .week: Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date()))
        case .all: nil
        }
        total = (try? store.sendCount()) ?? 0
        let text = query.trimmingCharacters(in: .whitespaces)
        var rows = text.isEmpty ? ((try? store.sends(since: since, newestFirst: newestFirst)) ?? [])
                                : ((try? store.search(text, limit: 2000)) ?? [])
        if !text.isEmpty {
            if let since { rows = rows.filter { $0.sentAt >= since } }
            if !newestFirst { rows.reverse() }
        }
        sends = rows
        if selection == nil || !rows.contains(where: { $0.id == selection }) { selection = rows.first?.id }
    }
}

/// One 44 pt row: file, destination, app, time and the confidence dot (FR-6).
private struct SendTableRow: View {
    @Environment(AppModel.self) private var model
    var send: SendRow
    var selected: Bool
    var select: () -> Void
    @State private var renaming = false
    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                DocGlyph(ext: (send.fileName as NSString).pathExtension, height: 30)
                Text(send.fileName).font(Theme.rowTitle).lineLimit(1).truncationMode(.middle)
                // Caught/Saved badges arrive with warnings (M4).
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if let label = send.versionLabel { VersionChip(label: label) }
            }
            .frame(width: 50, alignment: .leading)
            HStack(spacing: 10) {
                Avatar(label: send.destinationLabel)
                VStack(alignment: .leading, spacing: 1) {
                    Text(send.destinationLabel).font(Theme.rowTitle).lineLimit(1)
                    if send.placeDetail != send.destinationLabel {
                        Text(send.placeDetail).font(Theme.captionSmall).foregroundStyle(Theme.textMuted).lineLimit(1)
                    }
                }
            }
            .frame(width: 240, alignment: .leading)
            HStack(spacing: 7) {
                Image(systemName: appSymbol(for: send.appBundleID)).font(Theme.caption).foregroundStyle(Theme.textMuted)
                Text(shortAppName(send.appName)).font(Theme.body).lineLimit(1)
            }
            .frame(width: 110, alignment: .leading)
            Text(SendTime.short(send.sentAt)).font(Theme.body).frame(width: 66, alignment: .leading)
            ConfidenceDot(confidence: send.confidence).frame(width: 24)
        }
        .padding(.horizontal, 14)
        .frame(height: Theme.tableRowHeight)
        .background(selected ? Theme.selectedFill : Theme.hoverFill.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: Theme.tableRowRadius))
        .overlay {
            if selected { RoundedRectangle(cornerRadius: Theme.tableRowRadius).strokeBorder(Theme.selectedBorder) }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .contextMenu {
            Button("Edit Destination Label…") { renaming = true }
            Button("Not a Send") { model.markNotASend(send.id) }
            Divider()
            Button("Delete…", role: .destructive) { confirmingDelete = true }
        }
        .sheet(isPresented: $renaming) { RenameSheet(target: .send(send)) }
        .deleteConfirmation(isPresented: $confirmingDelete) { model.deleteSend(send.id) }
    }
}

/// The right-hand send detail (FR-12): preview, facts, and Quick Look / Reveal / Open page / Copy file.
struct SendInspector: View {
    @Environment(AppModel.self) private var model
    var send: SendRow
    @State private var previewURL: URL?
    @State private var renaming = false
    @State private var confirmingDelete = false
    @State private var family: FamilySummary?
    @State private var alsoHas: String?

    private var fileURL: URL? {
        guard let path = send.path, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(filePath: path)
    }

    private var pageURL: URL? {
        guard let url = send.url.flatMap(URL.init(string:)), ["http", "https"].contains(url.scheme ?? "") else { return nil }
        return url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 18) {
                iconButton("eye", "Quick Look", enabled: fileURL != nil) { previewURL = fileURL }
                iconButton("arrow.up.forward.square", "Reveal in Finder", enabled: fileURL != nil, action: reveal)
                iconButton("doc.on.doc", "Copy file", enabled: fileURL != nil, action: copyFile)
                Spacer()
                iconButton("pencil", "Edit destination label", enabled: true) { renaming = true }
                iconButton("trash", "Delete", enabled: true) { confirmingDelete = true }
            }
            .padding(.horizontal, 24)
            .frame(height: Theme.toolbarHeight + 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DocStack(height: 200).frame(maxWidth: .infinity).padding(.vertical, 12)
                    Text(send.fileName).font(Theme.windowTitle.weight(.medium)).lineLimit(2)
                    (Text("Sent to ") + Text(send.destinationLabel).foregroundStyle(Theme.text)
                     + Text(" from \(shortAppName(send.appName)) · \(SendTime.long(send.sentAt))"))
                        .font(Theme.caption).foregroundStyle(Theme.textMuted).padding(.top, 4)
                    HStack(spacing: 6) {
                        if send.exportOfID != nil {
                            Text("\((send.fileExt ?? "PDF").uppercased()) export")
                                .font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.textMuted)
                                .padding(.horizontal, 8).frame(height: Theme.chipHeight + 4)
                                .background(Theme.hoverFill, in: RoundedRectangle(cornerRadius: Theme.chipRadius))
                        } else if let label = send.versionLabel {
                            let newest = send.versionNumber == family?.newestVersion && send.fileExt == family?.mainFormat
                            Text(label + (newest ? " · newest" : ""))
                                .font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.primary)
                                .padding(.horizontal, 8).frame(height: Theme.chipHeight + 4)
                                .background(Theme.infoTint, in: RoundedRectangle(cornerRadius: Theme.chipRadius))
                        }
                        HStack(spacing: 6) {
                            ConfidenceDot(confidence: send.confidence)
                            Text(send.confidence.title).font(Theme.caption.weight(.medium))
                        }
                        .padding(.horizontal, 8).frame(height: Theme.chipHeight + 4)
                        .overlay(RoundedRectangle(cornerRadius: Theme.chipRadius).strokeBorder(Theme.line2))
                    }
                    .padding(.top, 10)

                    Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 18)

                    Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 10) {
                        if let url = send.url { fact("Page", Self.shortURL(url), lines: 1) }
                        if let title = send.pageTitle { fact("Page title", title) }
                        fact("App", send.appName)
                        fact("Location", locationText)
                        if let size = send.sizeBytes { fact("Size", size.formatted(.byteCount(style: .file))) }
                        if let sha = send.sha256 { fact("Fingerprint", Self.shortFingerprint(sha), mono: true) }
                    }
                    if let family, family.versionCount > 1 {
                        Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 18)
                        familyStrip(family)
                    }
                }
                .padding(.horizontal, 24)
            }

            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    actionButton("eye", "Quick Look", enabled: fileURL != nil) { previewURL = fileURL }
                    actionButton("arrow.up.forward.square", "Reveal in Finder", enabled: fileURL != nil, action: reveal)
                }
                GridRow {
                    actionButton("globe", "Open page", enabled: pageURL != nil) { if let pageURL { NSWorkspace.shared.open(pageURL) } }
                    actionButton("doc.on.doc", "Copy file", enabled: fileURL != nil, action: copyFile)
                }
            }
            .padding(24)
        }
        .quickLookPreview($previewURL)
        .sheet(isPresented: $renaming) { RenameSheet(target: .send(send)) }
        .deleteConfirmation(isPresented: $confirmingDelete) { model.deleteSend(send.id) }
        .task(id: "\(model.version)|\(send.id)") { loadFamily() }
    }

    /// "Resume family · 5 versions", a dot per version, and what else this destination has.
    private func familyStrip(_ family: FamilySummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(family.name + " family") { model.open(.byDocument(family: family.id)) }
                    .buttonStyle(.plain).font(Theme.bodyMedium)
                Spacer()
                Text("\(family.versionCount) versions").font(Theme.caption).foregroundStyle(Theme.textMuted)
            }
            let count = min(family.versionCount, 8)
            HStack(spacing: 0) {
                ForEach(1...count, id: \.self) { version in
                    VStack(spacing: 6) {
                        Circle().fill(version == send.versionNumber ? Theme.frostedBlue : Theme.grey)
                            .frame(width: version == send.versionNumber ? 12 : 7, height: version == send.versionNumber ? 12 : 7)
                            .frame(height: 12)
                        Text("v\(version)").font(Theme.captionSmall)
                            .foregroundStyle(version == send.versionNumber ? Theme.primary : Theme.textMuted)
                    }
                    if version < count { Rectangle().fill(Theme.line2).frame(height: 1).offset(y: -9) }
                }
            }
            if let alsoHas { Text(alsoHas).font(Theme.caption).foregroundStyle(Theme.textMuted) }
        }
    }

    private func loadFamily() {
        guard let familyID = send.familyID else { family = nil; alsoHas = nil; return }
        family = (try? model.store.families())?.first { $0.id == familyID }
        // "Razorpay also has v3, sent 2 Nov."
        let earlier = ((try? model.store.sends(destinationID: send.destinationID)) ?? [])
            .filter { $0.familyID == familyID && $0.id != send.id && $0.versionNumber != send.versionNumber && $0.versionNumber != nil }
        alsoHas = earlier.first.map { "\(send.destinationLabel) also has \($0.versionLabel ?? ""), sent \(SendTime.short($0.sentAt))." }
    }

    /// FR-12: say so when the file has moved or been deleted. (Finding it again by fingerprint needs watched folders, M3.)
    private var locationText: String {
        guard let path = send.path else { return "Not known" }
        guard fileURL != nil else { return "Moved or deleted since it was sent" }
        return ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
    }

    private func fact(_ label: String, _ value: String, mono: Bool = false, lines: Int = 2) -> some View {
        GridRow {
            Text(label).font(Theme.caption).foregroundStyle(Theme.textMuted).frame(width: 90, alignment: .leading)
            Text(value).font(mono ? Theme.mono : Theme.caption).foregroundStyle(Theme.text)
                .lineLimit(lines).truncationMode(.middle).textSelection(.enabled)
        }
    }

    private func iconButton(_ symbol: String, _ help: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 14)) }
            .buttonStyle(.plain).foregroundStyle(Theme.textMuted).disabled(!enabled).help(help)
    }

    private func actionButton(_ symbol: String, _ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity)
        }
        .buttonStyle(FallbackButtonStyle(kind: .quiet))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private func reveal() {
        if let fileURL { NSWorkspace.shared.activateFileViewerSelecting([fileURL]) }
    }

    private func copyFile() {
        guard let fileURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([fileURL as NSURL])
    }

    static func shortURL(_ url: String) -> String {
        guard let parsed = URL(string: url), let host = parsed.host() else { return url }
        return host + parsed.path()
    }

    /// "4f2a 91c0 … 9c1e"
    static func shortFingerprint(_ sha: String) -> String {
        let chars = Array(sha)
        guard chars.count > 12 else { return sha }
        return "\(String(chars[0..<4])) \(String(chars[4..<8])) … \(String(chars[(chars.count - 4)...]))"
    }
}

extension View {
    /// Deleting a send can't be undone, so it asks first.
    func deleteConfirmation(isPresented: Binding<Bool>, delete: @escaping () -> Void) -> some View {
        confirmationDialog("Delete this send from the ledger?", isPresented: isPresented) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }
}
