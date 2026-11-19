import AppKit
import FallbackCore
import SwiftUI

/// S7, Your stats (Design/screens/22, FR-36).
struct StatsView: View {
    @Environment(AppModel.self) private var model
    @State private var stats: Store.Stats?

    static let ruleNames = ["W1": "Older version", "W2": "Already sent", "W3": "Changed since last send",
                            "W4": "Name mismatch", "W5": "Stale export", "S": "Another version exists"]

    var body: some View {
        VStack(spacing: 18) {
            if let stats {
                HStack(spacing: 18) {
                    card {
                        SectionLabel(text: "Sends recorded")
                        Text("\(stats.sends)").font(Theme.brand(52))
                        Text(stats.since.map { "since \($0.formatted(.dateTime.day().month(.abbreviated)))" } ?? "none yet")
                            .font(Theme.body).foregroundStyle(Theme.textMuted)
                    }
                    card {
                        SectionLabel(text: "Mistakes caught")
                        Text("\(stats.caught)").font(Theme.brand(52)).foregroundStyle(Theme.primary)
                        Text("you switched files after a warning").font(Theme.body).foregroundStyle(Theme.textMuted)
                    }
                    .overlay {
                        // The faint Frosted glow in screen 22's top-right corner.
                        RadialGradient(colors: [Theme.frostedBlue.opacity(0.10), .clear], center: .topTrailing, startRadius: 0, endRadius: 220).allowsHitTesting(false)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                    }
                }
                card {
                    HStack {
                        SectionLabel(text: "Sends per week")
                        Spacer()
                        Text("Last 12 weeks").font(Theme.caption).foregroundStyle(Theme.textMuted)
                    }
                    let highest = max(stats.perWeek.max() ?? 1, 1)
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(Array(stats.perWeek.enumerated()), id: \.offset) { index, count in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(index == 11 ? Theme.frostedBlue : Theme.frostedBlue.opacity(0.3))
                                .frame(height: max(4, 180 * CGFloat(count) / CGFloat(highest)))
                                .help("\(count) sends")
                        }
                    }
                    .frame(height: 190, alignment: .bottom)
                    .accessibilityLabel("Sends per week: \(stats.perWeek.map(String.init).joined(separator: ", "))")
                }
                HStack(alignment: .top, spacing: 18) {
                    card {
                        SectionLabel(text: "Caught by")
                        if stats.caughtBy.isEmpty { Text("Nothing yet").font(Theme.body).foregroundStyle(Theme.textMuted) }
                        ForEach(stats.caughtBy.prefix(3), id: \.rule) { item in
                            line(Self.ruleNames[item.rule] ?? item.rule, item.count)
                        }
                    }
                    card {
                        SectionLabel(text: "Busiest")
                        if stats.busiest.isEmpty { Text("Nothing yet").font(Theme.body).foregroundStyle(Theme.textMuted) }
                        ForEach(stats.busiest, id: \.app) { item in line(shortAppName(item.app), item.count) }
                    }
                }
                HStack(spacing: 10) {
                    Spacer()
                    Button { copyImage(stats) } label: { Label("Copy image", systemImage: "doc.on.doc") }
                        .buttonStyle(FallbackButtonStyle(kind: .quiet))
                    if let image = Self.shareImage(stats) {
                        ShareLink(item: Image(nsImage: image), preview: SharePreview("Fallback stats", image: Image(nsImage: image))) {
                            Label("Share…", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(FallbackButtonStyle(kind: .primary))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(width: 640, height: 760)
        .background(Theme.surface)
        .foregroundStyle(Theme.text)
        .task(id: model.version) { stats = try? model.store.stats() }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
    }

    private func line(_ label: String, _ count: Int) -> some View {
        HStack {
            Text(label).font(Theme.body)
            Spacer()
            Text("\(count)").font(Theme.bodyMedium)
        }
    }

    private func copyImage(_ stats: Store.Stats) {
        guard let image = Self.shareImage(stats) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    /// The 1200 × 630 image: counts only, never file names (FR-36). Made locally, never uploaded by Fallback.
    static func shareImage(_ stats: Store.Stats) -> NSImage? {
        let renderer = ImageRenderer(content: ShareCard(sends: stats.sends, caught: stats.caught))
        renderer.scale = 1
        return renderer.nsImage
    }
}

/// The shareable card (screen 22, right).
struct ShareCard: View {
    var sends: Int
    var caught: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 18) {
                Image("LogoMark").resizable().scaledToFit().frame(height: 40)
                Wordmark(size: 30)
            }
            Spacer().frame(height: 80)
            Text("\(sends) sends recorded.\n\(caught) \(caught == 1 ? "mistake" : "mistakes") caught before they left.")
                .font(Theme.brand(64)).lineSpacing(6)
            Spacer()
            Text("Open source · runs on your Mac · fallback.app").font(.system(size: 22)).foregroundStyle(Theme.grey)
        }
        .padding(70)
        .frame(width: 1200, height: 630, alignment: .topLeading)
        .background {
            ZStack {
                Theme.black
                RadialGradient(colors: [Theme.frostedBlue.opacity(0.45), Color(dark: 0x3E7F88, light: 0x3E7F88).opacity(0.25), .clear],
                               center: .bottom, startRadius: 20, endRadius: 520)
                    .offset(x: 160, y: 120)
            }
        }
        .foregroundStyle(Theme.lavenderBlush)
        .environment(\.colorScheme, .dark)
    }
}
