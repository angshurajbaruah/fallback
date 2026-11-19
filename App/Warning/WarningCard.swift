import FallbackCore
import SwiftUI

/// What one card shows, built from a Warning with the wording in Design/COPY.md.
struct WarningCardContent: Equatable {
    enum Tone { case warning, info, neutral, confirm }
    struct Pill: Equatable {
        enum Kind { case bad, good, neutral }
        var title: String
        var subtitle: String
        var kind: Kind
    }

    var warning: Warning
    var tone: Tone
    var title: String
    /// Body text; segments in `bold` are file and destination names (bold in the designs).
    var body: [(text: String, bold: Bool)]
    var pills: [Pill] = []
    /// W4: the file name with the organisation name highlighted, and where it's going.
    var mismatch: (file: String, token: String, destination: String)?
    var primary: String
    var secondary: String
    var mute: String?
    var moreChecks: Int

    static func == (a: Self, b: Self) -> Bool { a.warning == b.warning && a.moreChecks == b.moreChecks }

    /// COPY.md's cards, rule by rule.
    init(_ warning: Warning, input: WarningInput, moreChecks: Int, appName: String) {
        self.warning = warning
        self.moreChecks = moreChecks
        let file = input.fileName
        let destination = input.destinationLabel
        let other = warning.otherFile
        switch warning.rule {
        case .w1:
            tone = .warning
            title = "Older version"
            body = [(file, true), (" is older than ", false), (other?.name ?? "another version", true), (", which you edited \(Self.when(other?.editedAt)).", false)]
            // Pills show dates, not family version numbers: "v1" next to resume_v3.pdf read as a contradiction.
            pills = [Pill(title: Self.when(input.editedAt, on: false), subtitle: "picking now", kind: .bad),
                     Pill(title: Self.when(other?.editedAt, on: false), subtitle: "edited \(Self.when(other?.editedAt, on: false))", kind: .good)]
            primary = "Show newer file"; secondary = "Send anyway"; mute = "Don't warn for this document"
        case .w2:
            tone = .info
            title = "Already sent"
            body = [("You sent this exact file to ", false), (destination, true), (" on \(Self.date(warning.previousSend?.sentAt)).", false)]
            primary = "Show previous send"; secondary = "Send anyway"; mute = "Don't warn for this destination"
        case .w3:
            tone = .info
            title = "Heads up"
            let old = warning.previousSend
            body = [(destination, true), (" has an earlier version (\(old?.fileName ?? "another file"), \(Self.date(old?.sentAt))).", false)]
            pills = [Pill(title: Self.when(other?.editedAt, on: false), subtitle: "\(destination) has", kind: .neutral),
                     Pill(title: Self.when(input.editedAt, on: false), subtitle: "sending now", kind: .good)]
            primary = "Show what they have"; secondary = "Send anyway"; mute = "Don't warn for this document"
        case .w4:
            tone = .warning
            title = "Check the recipient"
            let token = warning.token ?? ""
            body = [("This file mentions ", false), (token, true), (", but you're sending it to ", false), (destination, true), (".", false)]
            mismatch = (file, token, "\(destination) · \(appName)")
            primary = "Show sends to \(token)"; secondary = "Send anyway"; mute = "Don't warn for this document"
        case .w5:
            tone = .warning
            title = "Out-of-date export"
            body = [(other?.name ?? "The source document", true), (" was edited after this PDF was made.", false)]
            pills = [Pill(title: "PDF", subtitle: "made \(Self.date(input.editedAt))", kind: .bad),
                     Pill(title: (other?.ext ?? "").uppercased(), subtitle: "edited \(Self.when(other?.editedAt, on: false))", kind: .good)]
            primary = "Reveal source document"; secondary = "Send anyway"; mute = "Don't warn for this document"
        case .softer:
            tone = .info
            title = "Another version exists"
            body = [("There's another version of this document (", false), (other?.name ?? "another file", true),
                    (", edited \(Self.when(other?.editedAt, on: false))). Check you've picked the right one.", false)]
            primary = "Show other version"; secondary = "It's the right one"; mute = "Don't warn for this document"
        case .unknownDestination:
            tone = .neutral
            title = "Recorded, destination unknown"
            body = [("Recorded ", false), (file, true), (". Couldn't tell where it was going, so add a label.", false)]
            primary = "Add a label"; secondary = "Not a send"; mute = nil
        }
    }

    /// The one-time "Got it" card at the end of onboarding (COPY.md: Info, check icon).
    init(gotIt file: String, site: String) {
        warning = Warning(rule: .softer)
        moreChecks = 0
        tone = .confirm
        title = "Got it"
        body = [("Fallback saw you pick ", false), (file, true), (" on \(site). That's all it takes.", false)]
        primary = "Open Ledger"
        secondary = ""
        mute = nil
    }

    /// "today", "yesterday", "on 2 Nov" (or "2 Nov" in a pill).
    static func when(_ date: Date?, on: Bool = true) -> String {
        guard let date else { return "recently" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInYesterday(date) { return "yesterday" }
        return (on ? "on " : "") + self.date(date)
    }

    static func date(_ date: Date?) -> String {
        date?.formatted(.dateTime.day().month(.abbreviated)) ?? "an earlier date"
    }
}

/// S4, the warning card (Design/screens/02, BRAND.md "Warning card"): 372 pt, radius 18, vibrancy,
/// at most three actions, a 10-second countdown hairline that pauses while hovered.
struct WarningCardView: View {
    let content: WarningCardContent
    var onPrimary: () -> Void
    /// FR-37: "Add a label" with what was typed.
    var onLabel: (String) -> Void = { _ in }
    var onSecondary: () -> Void
    var onMute: () -> Void
    var onMore: () -> Void
    var onClose: () -> Void
    var onTimeout: () -> Void

    static let duration: Double = 10
    @State private var remaining = WarningCardView.duration
    @State private var hovering = false
    @State private var label = ""
    @FocusState private var labelFocused: Bool
    private var asksForLabel: Bool { content.warning.rule == .unknownDestination }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            HStack(alignment: .top, spacing: 12) {
                tile
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(content.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                        bodyText.font(.system(size: 12)).foregroundStyle(Theme.textMuted).fixedSize(horizontal: false, vertical: true)
                    }
                    if !content.pills.isEmpty { pillStrip }
                    if let mismatch = content.mismatch { mismatchStrip(mismatch) }
                    if asksForLabel { labelField }
                    HStack(spacing: 8) {
                        Button(content.primary) {
                            if !asksForLabel { onPrimary() }
                            else if label.trimmingCharacters(in: .whitespaces).isEmpty { labelFocused = true }
                            else { onLabel(label.trimmingCharacters(in: .whitespaces)) }
                        }
                        .buttonStyle(CardButtonStyle(primary: true))
                        if !content.secondary.isEmpty {
                            Button(content.secondary, action: onSecondary).buttonStyle(CardButtonStyle(primary: false))
                        }
                    }
                    if content.mute != nil || content.moreChecks > 0 {
                        HStack {
                            if let mute = content.mute {
                                Button(mute, action: onMute).buttonStyle(.plain)
                                    .font(.system(size: 11)).foregroundStyle(Theme.textMuted)
                            }
                            Spacer()
                            if content.moreChecks > 0 {
                                Button(content.moreChecks == 1 ? "1 more check ›" : "\(content.moreChecks) more checks ›", action: onMore)
                                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Theme.textMuted)
                            }
                        }
                    }
                }
            }
            .padding(.top, 12)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16))
        .frame(width: 372, alignment: .leading)
        .background(.ultraThinMaterial)
        .background(Theme.popoverBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .bottomLeading) {
            // The countdown hairline (2 pt) along the bottom.
            GeometryReader { proxy in
                Rectangle().fill(Theme.text.opacity(0.35))
                    .frame(width: proxy.size.width * remaining / Self.duration, height: 2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.popoverBorder))
        .onHover { hovering = $0 }
        .task {
            while remaining > 0 {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled { return }
                // Paused while hovered, or while a label is being typed.
                if !hovering && !labelFocused && label.isEmpty { remaining = max(0, remaining - 0.05) }
            }
            onTimeout()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image("LogoMark").resizable().scaledToFit().frame(width: 14, height: 14)
            Text("Fallback").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
            Text("· now").font(.system(size: 12)).foregroundStyle(Theme.textMuted)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textMuted)
                    .frame(width: 22, height: 22).background(Theme.hoverFill, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Close")
        }
    }

    /// Severity tile: Tangerine for warnings, Frosted Blue for info, neutral (Lavender Blush 8%) otherwise.
    private var tile: some View {
        let (symbol, colour, tint): (String, Color, Color) = switch content.tone {
        case .warning: ("exclamationmark.circle", Theme.warningText, Theme.warningTint)
        case .info: ("info.circle", Theme.primary, Theme.infoTint)
        case .neutral: ("doc.text", Theme.text, Theme.line)
        case .confirm: ("checkmark", Theme.primary, Theme.infoTint)
        }
        return Image(systemName: symbol)
            .font(.system(size: 15))
            .foregroundStyle(colour)
            .frame(width: 30, height: 30)
            .background(tint, in: RoundedRectangle(cornerRadius: 9))
    }

    /// "Label this send", placeholder "e.g. Acme finance". Typing starts only once it's clicked (FR-26).
    private var labelField: some View {
        HStack(spacing: 8) {
            Text("Label this send").font(.system(size: 12)).foregroundStyle(Theme.text)
            TextField("", text: $label, prompt: Text("e.g. Acme finance").foregroundStyle(Theme.textMuted))
                .textFieldStyle(.plain).font(.system(size: 12)).multilineTextAlignment(.trailing)
                .focused($labelFocused)
                .onSubmit { if !label.trimmingCharacters(in: .whitespaces).isEmpty { onLabel(label.trimmingCharacters(in: .whitespaces)) } }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(labelFocused ? Theme.focusBorder : Theme.line2)
            if labelFocused { RoundedRectangle(cornerRadius: 10).stroke(Theme.focusGlow, lineWidth: 3.5).padding(-2) }
        }
    }

    private var bodyText: Text {
        content.body.reduce(Text("")) { result, part in
            result + (part.bold ? Text(part.text).foregroundStyle(Theme.text).fontWeight(.medium) : Text(part.text))
        }
    }

    private var pillStrip: some View {
        HStack(spacing: 8) {
            ForEach(Array(content.pills.enumerated()), id: \.offset) { index, pill in
                if index > 0 { Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(Theme.textMuted) }
                HStack(spacing: 7) {
                    DocGlyph(height: 18)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(pill.title).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Theme.text)
                        Text(pill.subtitle).font(.system(size: 10.5)).foregroundStyle(Theme.textMuted)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(pill.kind == .good ? Theme.infoTint : Theme.hoverFill, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(
                    pill.kind == .bad ? Theme.warning.opacity(0.55) : pill.kind == .good ? Theme.selectedBorder : Theme.line2))
            }
        }
    }

    private func mismatchStrip(_ mismatch: (file: String, token: String, destination: String)) -> some View {
        let parts = mismatch.file.components(separatedBy: mismatch.token)
        let name = parts.enumerated().reduce(Text("")) { text, item in
            text + Text(item.element) + (item.offset < parts.count - 1 ? Text(mismatch.token).foregroundStyle(Theme.warningText) : Text(""))
        }
        return HStack(spacing: 6) {
            name.font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                .padding(.horizontal, 8).frame(height: 24)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line2))
            Text("→ \(mismatch.destination)").font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                .padding(.horizontal, 8).frame(height: 24)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line2))
        }
        .foregroundStyle(Theme.text)
    }
}

/// Card buttons: 26 pt; the fix is filled Lavender Blush with black text, the other is grey.
private struct CardButtonStyle: ButtonStyle {
    var primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(primary ? Theme.black : Theme.text)
            .padding(.horizontal, 11)
            .frame(height: 26)
            .background(primary ? Theme.lavenderBlush : Theme.hoverFill, in: RoundedRectangle(cornerRadius: 7))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
