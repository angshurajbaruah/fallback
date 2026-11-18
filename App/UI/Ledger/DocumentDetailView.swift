import FallbackCore
import QuickLook
import SwiftUI

/// S3, a document's history (Design/screens/08): its versions, tailored variants and where each went.
struct DocumentDetailView: View {
    @Environment(AppModel.self) private var model
    var familyID: Int64

    @State private var family: FamilySummary?
    @State private var others: [FamilySummary] = []
    @State private var members: [FamilyMember] = []
    @State private var sends: [Int64: [SendRow]] = [:]
    @State private var newestFirst = true
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var previewURL: URL?
    @State private var merging: [Int64]?
    @State private var splitting: FamilyMember?

    private var versions: [FamilyMember] {
        let list = members.filter { !$0.isVariant && matches($0) }.sorted { ($0.versionNumber ?? 0) < ($1.versionNumber ?? 0) }
        return newestFirst ? list.reversed() : list
    }

    private var variants: [FamilyMember] { members.filter { $0.isVariant && matches($0) } }
    private var newestVersion: Int? { members.compactMap(\.versionNumber).max() }

    private func matches(_ member: FamilyMember) -> Bool {
        let text = query.trimmingCharacters(in: .whitespaces)
        return text.isEmpty || member.name.localizedCaseInsensitiveContains(text)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    HStack(alignment: .top, spacing: 0) {
                        timeline.frame(maxWidth: .infinity)
                        Rectangle().fill(Theme.line).frame(width: 1)
                        sidePanel.frame(width: 360)
                    }
                }
            }
        }
        .quickLookPreview($previewURL)
        .task(id: "\(model.version)|\(familyID)") { reload() }
        .sheet(item: Binding(get: { merging.map(ByDocumentView.IDs.init) }, set: { merging = $0?.ids })) { ids in
            GroupSheet(fileIDs: ids.ids, initialName: family?.name)
        }
        .sheet(item: $splitting) { file in SplitSheet(file: file, familyName: family?.name ?? "") }
    }

    // MARK: Header

    private var toolbar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("By document").font(Theme.windowTitle)
                Text(family?.name ?? "").font(Theme.caption).foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Menu {
                Button("Newest first") { newestFirst = true }
                Button("Oldest first") { newestFirst = false }
            } label: {
                Label(newestFirst ? "Newest first" : "Oldest first", systemImage: "chevron.down").font(Theme.body)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().foregroundStyle(Theme.text)
            SearchField(placeholder: "Search this family", text: $query, focused: $searchFocused).frame(width: 300)
        }
        .padding(.horizontal, 24).padding(.top, 14)
        .frame(height: Theme.toolbarHeight + 14)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private var hero: some View {
        HStack(spacing: 40) {
            FamilyFan(count: members.count, height: 150).padding(.leading, 30).clipped()
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Document family")
                Text(family?.name ?? "").font(.system(size: 44, weight: .semibold)).lineLimit(1)
                Text(summaryLine).font(Theme.body).foregroundStyle(Theme.textMuted)
                HStack(spacing: 8) {
                    if let newestVersion {
                        Text("Newest: v\(newestVersion)").font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.primary)
                            .padding(.horizontal, 8).frame(height: Theme.chipHeight + 4)
                            .background(Theme.infoTint, in: RoundedRectangle(cornerRadius: Theme.chipRadius))
                    }
                    if let grouped = groupedBy { OutlineChip(text: grouped) }
                    if let confidence = family?.confidence, members.count > 1 { OutlineChip(text: "\(confidence.capitalized) confidence") }
                }
            }
            Spacer()
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 6) {
                Menu {
                    ForEach(others) { other in
                        Button(other.name) {
                            let theirs = (try? model.store.members(ofFamily: other.id).map(\.id)) ?? []
                            merging = members.map(\.id) + theirs
                        }
                    }
                } label: { Label("Merge…", systemImage: "arrow.triangle.merge").font(Theme.body) }
                    .disabled(others.isEmpty)
                Menu {
                    ForEach(members) { member in Button(member.name) { splitting = member } }
                } label: { Label("Split off…", systemImage: "arrow.triangle.branch").font(Theme.body) }
                    .disabled(members.count < 2)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .foregroundStyle(Theme.text)
            .padding(24)
        }
        .background(RadialGradient(colors: [Theme.frostedBlue.opacity(0.08), .clear], center: .leading, startRadius: 10, endRadius: 600))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    /// "5 versions · 2 tailored variants · sent 7 times to 5 places"
    private var summaryLine: String {
        guard let family else { return "" }
        var parts = [family.versionCount == 1 ? "1 version" : "\(family.versionCount) versions"]
        if family.variantCount > 0 { parts.append(family.variantCount == 1 ? "1 tailored variant" : "\(family.variantCount) tailored variants") }
        if family.sendCount == 0 {
            parts.append("never sent")
        } else {
            parts.append("sent \(family.sendCount == 1 ? "once" : "\(family.sendCount) times") to \(family.placeCount == 1 ? "1 place" : "\(family.placeCount) places")")
        }
        return parts.joined(separator: " · ")
    }

    /// "Grouped by name + content"
    private var groupedBy: String? {
        let names: [String: String] = ["lineage": "source", "metadata": "metadata", "content": "content", "name": "name", "user": "you"]
        let order = ["name", "content", "metadata", "lineage", "user"]
        let signals = (family?.signals ?? "").split(separator: ",").map(String.init)
        let words = order.filter(signals.contains).compactMap { names[$0] }
        return words.isEmpty ? nil : "Grouped by " + words.joined(separator: " + ")
    }

    // MARK: Version timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Version timeline").padding(.bottom, 4)
            ForEach(Array(versions.enumerated()), id: \.element.id) { index, member in
                HStack(alignment: .top, spacing: 16) {
                    VersionChip(label: member.versionLabel ?? "–", current: member.versionNumber == newestVersion)
                        .frame(width: 34).padding(.top, 30)
                    ZStack(alignment: .top) {
                        Rectangle().fill(Theme.line2).frame(width: 1)
                            .padding(.bottom, index == versions.count - 1 ? 60 : -14)
                        Circle().fill(member.versionNumber == newestVersion ? Theme.frostedBlue : Theme.grey)
                            .frame(width: member.versionNumber == newestVersion ? 14 : 9, height: member.versionNumber == newestVersion ? 14 : 9)
                            .padding(.top, member.versionNumber == newestVersion ? 31 : 33)
                    }
                    .frame(width: 14)
                    versionCard(member, newest: member.versionNumber == newestVersion)
                }
            }
        }
        .padding(32)
    }

    private func versionCard(_ member: FamilyMember, newest: Bool) -> some View {
        let url = member.path.flatMap { FileManager.default.fileExists(atPath: $0) ? URL(filePath: $0) : nil }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                DocGlyph(ext: (member.name as NSString).pathExtension, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(member.name).font(Theme.bodyMedium)
                    Text(Self.facts(member, newest: newest)).font(Theme.caption).foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Group {
                    Button { previewURL = url } label: { Image(systemName: "eye") }.disabled(url == nil).help("Quick Look")
                    Button { if let url { NSWorkspace.shared.activateFileViewerSelecting([url]) } } label: { Image(systemName: "arrow.up.forward.square") }
                        .disabled(url == nil).help("Reveal in Finder")
                }
                .buttonStyle(.plain).foregroundStyle(Theme.textMuted)
            }
            HStack(spacing: 8) {
                Text("Sent to").font(Theme.caption).foregroundStyle(Theme.textMuted)
                let mine = sends[member.id] ?? []
                if mine.isEmpty {
                    Text("Never sent").font(Theme.caption).foregroundStyle(Theme.textMuted)
                } else {
                    ForEach(mine.prefix(4)) { send in
                        Button { model.ledgerRoute = .allSends(selected: send.id) } label: {
                            HStack(spacing: 6) {
                                Avatar(label: send.destinationLabel, size: 16)
                                Text("\(send.destinationLabel) · \(SendTime.short(send.sentAt))").font(Theme.caption.weight(.medium))
                            }
                            .padding(.horizontal, 6).frame(height: 24)
                            .overlay(RoundedRectangle(cornerRadius: Theme.chipRadius).strokeBorder(Theme.line2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(newest ? Theme.selectedFill : Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(newest ? Theme.selectedBorder : Theme.line))
    }

    /// "Edited yesterday · 184 KB · 4f2a…9c1e"
    static func facts(_ member: FamilyMember, newest: Bool) -> String {
        var parts: [String] = []
        if let edited = member.editedAt {
            let day = SendTime.day(edited)
            parts.append(newest || day == "today" || day == "yesterday" ? "Edited \(day)" : SendTime.short(edited))
        }
        if let size = member.sizeBytes { parts.append(size.formatted(.byteCount(style: .file))) }
        if let sha = member.sha256, sha.count > 8 { parts.append("\(sha.prefix(4))…\(sha.suffix(4))") }
        if member.path == nil { parts.append("moved or deleted") }
        return parts.joined(separator: " · ")
    }

    // MARK: Variants and where versions went

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !variants.isEmpty {
                SectionLabel(text: "Sibling variants")
                Text("Same document, tailored per company. Never called “older”; only the recipient check applies.")
                    .font(Theme.caption).foregroundStyle(Theme.textMuted).padding(.top, 8).padding(.bottom, 12)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(variants) { member in
                    HStack(spacing: 12) {
                        DocGlyph(ext: (member.name as NSString).pathExtension, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name).font(Theme.bodyMedium).lineLimit(1)
                            Text(variantDetail(member)).font(Theme.caption).foregroundStyle(Theme.textMuted)
                        }
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                }
                Spacer().frame(height: 30)
            }
            SectionLabel(text: "Where versions went").padding(.bottom, 12)
            if wentTo.isEmpty {
                Text("Not sent anywhere yet.").font(Theme.caption).foregroundStyle(Theme.textMuted)
            }
            ForEach(wentTo, id: \.label) { place in
                HStack {
                    Text(place.label).font(Theme.body)
                    Spacer()
                    ForEach(place.versions, id: \.self) { version in
                        VersionChip(label: "v\(version)", current: version == newestVersion)
                    }
                }
                .frame(height: 34)
            }
        }
        .padding(32)
    }

    /// "Tailored for Emergent · edited today"
    private func variantDetail(_ member: FamilyMember) -> String {
        let base = Set(NameStem.stem(family?.name ?? "")?.split(separator: " ").map(String.init) ?? [])
        let extra = NameStem.stem(member.name)?.split(separator: " ").map(String.init).first { !base.contains($0) && $0.count >= 3 }
        var parts: [String] = []
        if let extra { parts.append("Tailored for \(extra.prefix(1).uppercased() + extra.dropFirst())") }
        if let edited = member.editedAt { parts.append("edited \(SendTime.day(edited))") }
        return parts.joined(separator: " · ")
    }

    /// Each destination and the versions it received, newest first.
    private var wentTo: [(label: String, versions: [Int])] {
        var map: [String: Set<Int>] = [:]
        var latest: [String: Date] = [:]
        for member in members where !member.isVariant {
            for send in sends[member.id] ?? [] {
                if let version = member.versionNumber { map[send.destinationLabel, default: []].insert(version) }
                latest[send.destinationLabel] = max(latest[send.destinationLabel] ?? .distantPast, send.sentAt)
            }
        }
        return map.map { (label: $0.key, versions: $0.value.sorted(by: >)) }
            .sorted { (latest[$0.label] ?? .distantPast) > (latest[$1.label] ?? .distantPast) }
    }

    private func reload() {
        let store = model.store
        let all = (try? store.families()) ?? []
        family = all.first { $0.id == familyID }
        others = all.filter { $0.id != familyID }
        members = (try? store.members(ofFamily: familyID)) ?? []
        sends = (try? store.sendsByFile(inFamily: familyID)) ?? [:]
        if family == nil { model.ledgerRoute = .byDocument(family: nil) } // merged away or split apart
    }
}
