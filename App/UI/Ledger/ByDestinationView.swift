import FallbackCore
import SwiftUI

/// By destination (Design/screens/05): places on the left, the selected place's timeline on the right.
struct ByDestinationView: View {
    @Environment(AppModel.self) private var model
    @State private var places: [DestinationSummary] = []
    @State private var details: [Int64: String] = [:]
    @State private var filter = ""
    @FocusState private var filterFocused: Bool
    @State private var timeline: [SendRow] = []
    @State private var renaming = false

    private var selectedID: Int64? {
        if case .byDestination(let id) = model.ledgerRoute { id ?? places.first?.id } else { nil }
    }

    private var filtered: [DestinationSummary] {
        let text = filter.trimmingCharacters(in: .whitespaces).lowercased()
        return text.isEmpty ? places : places.filter { $0.label.lowercased().contains(text) || (details[$0.id] ?? "").lowercased().contains(text) }
    }

    var body: some View {
        HStack(spacing: 0) {
            list.frame(width: 300)
            Rectangle().fill(Theme.line).frame(width: 1)
            if let place = places.first(where: { $0.id == selectedID }) {
                detail(place)
            } else {
                Text(places.isEmpty ? "No destinations yet." : "Select a destination.")
                    .font(Theme.caption).foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: "\(model.version)|\(selectedID ?? -1)") { reload() }
    }

    // MARK: Places list

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("By destination").font(Theme.windowTitle)
                Text(places.count == 1 ? "1 place" : "\(places.count) places").font(Theme.caption).foregroundStyle(Theme.textMuted)
            }
            .padding(.horizontal, 20).padding(.top, 14)
            .frame(height: Theme.toolbarHeight + 14, alignment: .leading)
            SearchField(placeholder: "Filter destinations", text: $filter, focused: $filterFocused)
                .padding(.horizontal, 12).padding(.vertical, 10)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filtered) { place in
                        Button { model.ledgerRoute = .byDestination(selected: place.id) } label: {
                            HStack(spacing: 12) {
                                Avatar(label: place.label, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.label).font(Theme.bodyMedium).lineLimit(1)
                                    if details[place.id] != place.label {
                                        Text(details[place.id] ?? "").font(Theme.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Text(place.sendCount == 1 ? "1 send" : "\(place.sendCount) sends")
                                    .font(Theme.caption).foregroundStyle(Theme.textMuted)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 50)
                            .background(selectedID == place.id ? Theme.hoverFill : .clear,
                                        in: RoundedRectangle(cornerRadius: Theme.tableRowRadius))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
            }
        }
    }

    // MARK: Detail

    private func detail(_ place: DestinationSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                Avatar(label: place.label, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.label).font(Theme.detailTitle)
                    Text(details[place.id] ?? "").font(Theme.caption).foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Button { renaming = true } label: { Label("Rename", systemImage: "pencil") }
                    .buttonStyle(FallbackButtonStyle(kind: .ghost))
                // Export (FR-14) arrives with CSV export.
            }
            .padding(.horizontal, 32)
            .frame(height: 96)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 16) {
                        statCard("Sends") { Text("\(place.sendCount)").font(Theme.statNumber) }
                        if let latest = mainFamily {
                            statCard("Latest \(latest.name.lowercased()) they have") {
                                HStack(spacing: 8) {
                                    VersionChip(label: latest.newest.versionLabel ?? "")
                                    Text("sent \(SendTime.day(latest.newest.sentAt))").font(Theme.body)
                                }
                            }
                            if !latest.older.isEmpty {
                                statCard("Also has") {
                                    HStack(spacing: 6) {
                                        ForEach(latest.older, id: \.self) { VersionChip(label: $0, current: false) }
                                        Text("older \(latest.name.lowercased())s").font(Theme.body).foregroundStyle(Theme.textMuted)
                                    }
                                }
                            }
                        }
                    }

                    SectionLabel(text: "Timeline").padding(.top, 28).padding(.bottom, 12)
                    ForEach(Array(timeline.enumerated()), id: \.element.id) { index, send in
                        timelineRow(send, first: index == 0, last: index == timeline.count - 1)
                    }
                }
                .padding(32)
            }
        }
        .sheet(isPresented: $renaming) { RenameSheet(target: .destination(place, seen: details[place.id] ?? place.key)) }
    }

    private func statCard<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: label)
            content()
        }
        .padding(18)
        .frame(maxWidth: 300, minHeight: 100, alignment: .topLeading)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
    }

    /// The document this place received most often: its newest version sent here, and the older ones.
    private var mainFamily: (name: String, newest: SendRow, older: [String])? {
        let versioned = timeline.filter { $0.familyName != nil && $0.versionNumber != nil }
        let counts = Dictionary(versioned.map { ($0.familyID ?? -1, 1) }, uniquingKeysWith: +)
        guard let familyID = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        let sent = versioned.filter { $0.familyID == familyID }
        guard let newest = sent.max(by: { ($0.versionNumber ?? 0) < ($1.versionNumber ?? 0) }) else { return nil }
        let older = Set(sent.compactMap(\.versionNumber)).filter { $0 < (newest.versionNumber ?? 0) }.sorted(by: >).map { "v\($0)" }
        return (newest.familyName ?? "", newest, older)
    }

    private func timelineRow(_ send: SendRow, first: Bool, last: Bool) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(SendTime.long(send.sentAt)).font(Theme.caption).foregroundStyle(Theme.textMuted)
                .frame(width: 110, alignment: .trailing)
            ZStack {
                Rectangle().fill(Theme.line2).frame(width: 1)
                    .padding(.top, first ? 31 : 0).padding(.bottom, last ? 31 : 0)
                Circle().fill(first ? Theme.frostedBlue : Theme.grey).frame(width: first ? 10 : 8, height: first ? 10 : 8)
            }
            .frame(width: 12, height: 62)
            Button { model.ledgerRoute = .allSends(selected: send.id) } label: {
                HStack(spacing: 12) {
                    DocGlyph(ext: (send.fileName as NSString).pathExtension, height: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(send.fileName).font(Theme.rowTitle).foregroundStyle(Theme.text).lineLimit(1)
                        Text([shortAppName(send.appName), send.pageTitle].compactMap { $0 }.joined(separator: " · "))
                            .font(Theme.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
                    }
                    Spacer()
                    if let version = send.versionLabel { VersionChip(label: version, current: first) }
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(first ? Theme.selectedFill : .clear, in: RoundedRectangle(cornerRadius: 10))
                .overlay { if first { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.selectedBorder) } }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func reload() {
        let store = model.store
        places = (try? store.destinations()) ?? []
        // shortcut: one query per place for its detail line; fold into destinations() if this gets slow.
        details = Dictionary(uniqueKeysWithValues: places.compactMap { place in
            (try? store.sends(destinationID: place.id, limit: 1))?.first.map { (place.id, $0.placeDetail) }
        })
        timeline = selectedID.flatMap { try? store.sends(destinationID: $0) } ?? []
    }
}
