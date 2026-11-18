import FallbackCore
import SwiftUI

/// S2, the Ledger window (Design/screens/04 and 05): sidebar plus All sends or By destination.
struct LedgerView: View {
    @Environment(AppModel.self) private var model
    @State private var destinations: [DestinationSummary] = []
    @State private var families: [FamilySummary] = []
    @State private var warningCount = 0
    @State private var total = 0

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: Theme.sidebarWidth)
                .background(Theme.surface2)
            Rectangle().fill(Theme.line).frame(width: 1)
            Group {
                switch model.ledgerRoute {
                case .allSends: AllSendsView()
                case .warnings: WarningsView()
                case .byDestination: ByDestinationView()
                case .byDocument(let family?): DocumentDetailView(familyID: family)
                case .byDocument(nil): ByDocumentView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.surface)
        .foregroundStyle(Theme.text)
        .frame(minWidth: 1080, minHeight: 620)
        .ignoresSafeArea()
        .task(id: model.version) {
            destinations = (try? model.store.destinations()) ?? []
            families = (try? model.store.families()) ?? []
            warningCount = ((try? model.store.warnings()) ?? []).filter { $0.outcome == nil }.count
            total = (try? model.store.sendCount()) ?? 0
        }
    }

    private var isAllSends: Bool { if case .allSends = model.ledgerRoute { true } else { false } }
    private var isWarnings: Bool { model.ledgerRoute == .warnings }
    private var isByDestination: Bool { if case .byDestination = model.ledgerRoute { true } else { false } }
    private var isByDocument: Bool { if case .byDocument = model.ledgerRoute { true } else { false } }

    private var selectedFamily: Int64? {
        if case .byDocument(let id) = model.ledgerRoute { id } else { nil }
    }

    private var selectedDestination: Int64? {
        if case .byDestination(let id) = model.ledgerRoute { id } else { nil }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer().frame(height: 52) // room for the window buttons
            SidebarHeading(text: "Ledger")
            SidebarItem(symbol: "list.bullet", title: "All sends", count: total, selected: isAllSends) {
                model.ledgerRoute = .allSends(selected: nil)
            }
            SidebarItem(symbol: "exclamationmark.circle", title: "Warnings", badge: warningCount, selected: isWarnings) {
                model.ledgerRoute = .warnings
            }
            SidebarItem(symbol: "person", title: "By destination", count: nil, selected: isByDestination) {
                model.ledgerRoute = .byDestination(selected: destinations.first?.id)
            }
            SidebarItem(symbol: "square.on.square", title: "By document", count: nil, selected: isByDocument && selectedFamily == nil) {
                model.ledgerRoute = .byDocument(family: nil)
            }
            if !destinations.isEmpty {
                SidebarHeading(text: "Destinations").padding(.top, 18)
                ForEach(destinations.prefix(6)) { place in
                    SidebarItem(avatar: place.label, title: place.label, count: place.sendCount,
                                selected: selectedDestination == place.id) {
                        model.ledgerRoute = .byDestination(selected: place.id)
                    }
                }
            }
            let documents = families.filter { $0.memberCount > 1 }
            if !documents.isEmpty {
                SidebarHeading(text: "Documents").padding(.top, 18)
                ForEach(documents.prefix(6)) { family in
                    SidebarItem(symbol: "square.on.square", title: family.name, count: family.memberCount,
                                selected: selectedFamily == family.id) {
                        model.ledgerRoute = .byDocument(family: family.id)
                    }
                }
            }
            Spacer()
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 8) {
                Circle().fill(model.isPaused ? Theme.grey : Theme.frostedBlue).frame(width: 7, height: 7)
                Text(model.isPaused ? "Paused" : model.foldersPhrase).font(Theme.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
                Spacer()
                if model.isPaused {
                    Button { model.resume() } label: { Image(systemName: "play.fill") }
                        .buttonStyle(.plain).foregroundStyle(Theme.textMuted).help("Resume")
                } else {
                    PauseMenu()
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
        }
        .padding(.horizontal, 10)
    }
}

private struct SidebarHeading: View {
    var text: String
    var body: some View {
        Text(text).font(Theme.caption.weight(.medium)).foregroundStyle(Theme.textMuted)
            .padding(.horizontal, 10).padding(.bottom, 4)
    }
}

private struct SidebarItem: View {
    var symbol: String? = nil
    var avatar: String? = nil
    var title: String
    var count: Int?
    var badge: Int = 0
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let symbol {
                    Image(systemName: symbol).frame(width: 18).foregroundStyle(Theme.textMuted)
                } else if let avatar {
                    Avatar(label: avatar, size: 18)
                }
                Text(title).font(Theme.body).lineLimit(1)
                Spacer()
                if let count { Text("\(count)").font(Theme.caption).foregroundStyle(Theme.textMuted) }
                if badge > 0 {
                    Text("\(badge)").font(Theme.captionSmall.weight(.semibold)).foregroundStyle(Theme.warningText)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Theme.warningTint, in: Circle())
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(selected ? Theme.hoverFill : .clear, in: RoundedRectangle(cornerRadius: Theme.tableRowRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
