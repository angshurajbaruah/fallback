import FallbackCore
import SwiftUI

/// S2, the Ledger window (Design/screens/04 and 05): sidebar plus All sends or By destination.
struct LedgerView: View {
    @Environment(AppModel.self) private var model
    @State private var destinations: [DestinationSummary] = []
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
                case .byDestination: ByDestinationView()
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
            total = (try? model.store.sendCount()) ?? 0
        }
    }

    private var isAllSends: Bool { if case .allSends = model.ledgerRoute { true } else { false } }

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
            // Warnings (M4) and By document (M3) arrive in their milestones.
            SidebarItem(symbol: "person", title: "By destination", count: nil, selected: !isAllSends) {
                model.ledgerRoute = .byDestination(selected: destinations.first?.id)
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
            Spacer()
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 8) {
                Circle().fill(model.isPaused ? Theme.grey : Theme.frostedBlue).frame(width: 7, height: 7)
                Text(model.isPaused ? "Paused" : "Watching").font(Theme.caption).foregroundStyle(Theme.textMuted)
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
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(selected ? Theme.hoverFill : .clear, in: RoundedRectangle(cornerRadius: Theme.tableRowRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
