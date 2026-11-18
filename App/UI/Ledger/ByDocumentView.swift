import FallbackCore
import SwiftUI

/// By document (Design/screens/09): every document family, plus Medium-confidence suggestions (PRD 8.3).
struct ByDocumentView: View {
    @Environment(AppModel.self) private var model
    @State private var families: [FamilySummary] = []
    @State private var suggestionFiles: [FamilyMember] = []
    @State private var reviewing: [Int64]?

    private var suggestion: [Int64]? { model.suggestions.first }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("By document").font(Theme.windowTitle)
                Text(subtitle).font(Theme.caption).foregroundStyle(Theme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.top, 14)
            .frame(height: Theme.toolbarHeight + 14)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }

            ScrollView {
                VStack(spacing: 20) {
                    if let suggestion, !suggestionFiles.isEmpty { banner(suggestion) }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 20)], spacing: 20) {
                        ForEach(families) { family in
                            Button { model.ledgerRoute = .byDocument(family: family.id) } label: { card(family) }
                                .buttonStyle(.plain)
                        }
                    }
                    if families.isEmpty {
                        Text("No documents yet. Fallback groups the files in the folders it watches.")
                            .font(Theme.caption).foregroundStyle(Theme.textMuted).padding(.top, 40)
                    }
                }
                .padding(24)
            }
        }
        .task(id: "\(model.version)|\(suggestion ?? [])") {
            families = (try? model.store.families()) ?? []
            suggestionFiles = (try? model.store.files(ids: suggestion ?? [])) ?? []
        }
        .sheet(item: Binding(get: { reviewing.map(IDs.init) }, set: { reviewing = $0?.ids })) { ids in
            GroupSheet(fileIDs: ids.ids)
        }
    }

    private var subtitle: String {
        let count = model.suggestions.count
        let base = families.count == 1 ? "1 family" : "\(families.count) families"
        return count == 0 ? base : base + " · " + (count == 1 ? "1 suggestion" : "\(count) suggestions")
    }

    private func banner(_ ids: [Int64]) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "square.on.square").foregroundStyle(Theme.primary)
                .frame(width: 36, height: 36).background(Theme.infoTint, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text("These \(ids.count) files look like the same document").font(Theme.bodyMedium)
                Text(suggestionFiles.map(\.name).joined(separator: ", ")).font(Theme.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
            }
            Spacer()
            Button("Not now") { model.dismissSuggestion(ids) }.buttonStyle(FallbackButtonStyle(kind: .ghost))
            Button("Review") { reviewing = ids }.buttonStyle(FallbackButtonStyle(kind: .quiet))
            Button("Group") { model.group(ids, name: GroupSheet.defaultName(suggestionFiles)) }
                .buttonStyle(FallbackButtonStyle(kind: .primary))
        }
        .padding(16)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).strokeBorder(Theme.selectedBorder))
    }

    private func card(_ family: FamilySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "square.on.square").foregroundStyle(Theme.textMuted)
                Text(family.name).font(Theme.bodyMedium).lineLimit(1)
                Spacer()
                if let newest = family.newestVersion { VersionChip(label: "v\(newest)") }
            }
            Text(Self.facts(family)).font(Theme.caption).foregroundStyle(Theme.textMuted)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(height: 150, alignment: .topLeading)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).strokeBorder(Theme.line))
        .contentShape(Rectangle())
    }

    /// "5 versions · 2 variants · 7 sends", or "3 versions · PDF + DOCX · 2 sends".
    static func facts(_ family: FamilySummary) -> String {
        var parts = [family.versionCount == 1 ? "1 version" : "\(family.versionCount) versions"]
        if family.variantCount > 0 { parts.append(family.variantCount == 1 ? "1 variant" : "\(family.variantCount) variants") }
        let exts = (family.extensions ?? "").split(separator: ",").map { $0.uppercased() }
        if exts.count > 1 { parts.append(exts.sorted { $0 == "PDF" || $1 != "PDF" && $0 < $1 }.joined(separator: " + ")) }
        if family.sendCount > 0 { parts.append(family.sendCount == 1 ? "1 send" : "\(family.sendCount) sends") }
        return parts.joined(separator: " · ")
    }

    struct IDs: Identifiable { let ids: [Int64]; var id: [Int64] { ids } }
}

/// "Group into one document" (Design/screens/09). Checked files become versions of one document.
struct GroupSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var fileIDs: [Int64]
    var initialName: String? = nil

    @State private var files: [FamilyMember] = []
    @State private var reasons: [Int64: [String]] = [:]
    @State private var checked: Set<Int64> = []
    @State private var name = ""
    @State private var splitting: FamilyMember?
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image("LogoMark").resizable().scaledToFit().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Group into one document").font(Theme.windowTitle)
                    Text("Fallback will treat these as versions of the same file.").font(Theme.caption).foregroundStyle(Theme.textMuted)
                }
            }
            .padding(.bottom, 18)
            Rectangle().fill(Theme.line).frame(height: 1)
            ForEach(files) { file in
                HStack(spacing: 12) {
                    Toggle("", isOn: Binding(get: { checked.contains(file.id) },
                                             set: { if $0 { checked.insert(file.id) } else { checked.remove(file.id) } }))
                        .toggleStyle(.checkbox).labelsHidden()
                    DocGlyph(ext: (file.name as NSString).pathExtension, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name).font(Theme.bodyMedium)
                        Text(Self.whereText(file)).font(Theme.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
                    }
                    Spacer()
                    if let reason = reasons[file.id]?.first { OutlineChip(text: reason) }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
            }
            HStack(spacing: 12) {
                Text("Family name").font(Theme.body).foregroundStyle(Theme.textMuted).frame(width: 90, alignment: .trailing)
                TextField("", text: $name)
                    .textFieldStyle(.plain).font(Theme.body)
                    .padding(.horizontal, 10).frame(height: Theme.searchHeight)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.searchRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.searchRadius).strokeBorder(nameFocused ? Theme.focusBorder : Theme.line2))
                    .focused($nameFocused)
            }
            .padding(.top, 20)
            HStack {
                Menu {
                    ForEach(files) { file in Button(file.name) { splitting = file } }
                } label: {
                    Label("Split one off instead…", systemImage: "arrow.triangle.branch").font(Theme.body)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().foregroundStyle(Theme.textMuted)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(FallbackButtonStyle(kind: .ghost)).keyboardShortcut(.cancelAction)
                Button(checked.count == 1 ? "Group 1 file" : "Group \(checked.count) files") {
                    model.group(files.map(\.id).filter(checked.contains), name: name.trimmingCharacters(in: .whitespaces))
                    dismiss()
                }
                .buttonStyle(FallbackButtonStyle(kind: .primary))
                .disabled(checked.count < 2 || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 22)
        }
        .padding(28)
        .frame(width: 560)
        .background(Theme.surface2)
        .task {
            files = (try? model.store.files(ids: fileIDs)) ?? []
            reasons = (try? model.store.linkReasons(among: fileIDs)) ?? [:]
            checked = Set(fileIDs)
            name = initialName ?? Self.defaultName(files)
        }
        .sheet(item: $splitting) { file in
            SplitSheet(file: file, familyName: name.isEmpty ? "this document" : name) { dismiss() }
        }
    }

    /// A document title they all share, else the most common name stem, else the first file's name.
    static func defaultName(_ files: [FamilyMember]) -> String {
        if let title = files.first?.docTitle, files.allSatisfy({ $0.docTitle == title }) { return title }
        let stems = files.compactMap { NameStem.stem($0.name) }
        let best = Dictionary(stems.map { ($0, 1) }, uniquingKeysWith: +).max { $0.value < $1.value }?.key
        return best.map { $0.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ") }
            ?? files.first.map { ($0.name as NSString).deletingPathExtension } ?? ""
    }

    /// "Downloads · from mail.google.com" or just the folder.
    static func whereText(_ file: FamilyMember) -> String {
        let folder = file.path.map { (($0 as NSString).deletingLastPathComponent as NSString).lastPathComponent } ?? "Moved or deleted"
        guard let source = file.whereFrom.flatMap({ URL(string: $0)?.host() }) else { return folder }
        return "\(folder) · from \(source)"
    }
}

/// "Split off from “Resume”" (Design/screens/09).
struct SplitSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var file: FamilyMember
    var familyName: String
    var done: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Split off from “\(familyName)”").font(Theme.windowTitle)
            Text("\(file.name) becomes its own document. Warnings update right away.")
                .font(Theme.caption).foregroundStyle(Theme.textMuted).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                DocGlyph(ext: (file.name as NSString).pathExtension, height: 34)
                Text(file.name).font(Theme.bodyMedium)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(FallbackButtonStyle(kind: .ghost)).keyboardShortcut(.cancelAction)
                Button("Split off") {
                    let members = (try? file.familyID.map { try model.store.members(ofFamily: $0).map(\.id) }) ?? nil
                    model.splitOff(file.id, from: members ?? [])
                    dismiss()
                    done()
                }
                .buttonStyle(FallbackButtonStyle(kind: .primary))
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(Theme.surface2)
    }
}
