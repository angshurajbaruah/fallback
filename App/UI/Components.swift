import FallbackCore
import SwiftUI

/// The plain document glyph used in rows, with an optional type badge (PDF, DOCX) as in the Ledger.
struct DocGlyph: View {
    var ext: String? = nil
    var height: CGFloat = 32
    var dimmed = false

    var body: some View {
        let width = height * 0.78
        RoundedRectangle(cornerRadius: height * 0.12)
            .fill(dimmed ? Theme.grey : Theme.docFill)
            .overlay(RoundedRectangle(cornerRadius: height * 0.12).strokeBorder(Theme.line2))
            .frame(width: width, height: height)
            .overlay(alignment: .top) {
                VStack(alignment: .leading, spacing: height * 0.09) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().fill(dimmed ? Theme.black.opacity(0.25) : Theme.grey.opacity(0.45)).frame(height: max(1, height * 0.04))
                    }
                }
                .padding(.horizontal, width * 0.22)
                .padding(.top, height * 0.2)
            }
            .overlay(alignment: .bottom) {
                if let ext, !ext.isEmpty {
                    Text(ext.uppercased())
                        .font(.system(size: height * 0.2, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.lavenderBlush)
                        .padding(.horizontal, 2)
                        .background(Theme.docBadge, in: RoundedRectangle(cornerRadius: 2))
                        .padding(.bottom, height * 0.08)
                }
            }
            .accessibilityHidden(true)
    }
}

/// The stacked documents shown in empty states and the send inspector.
struct DocStack: View {
    var height: CGFloat = 140

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: height * 0.06).fill(Theme.grey.opacity(0.55))
                .frame(width: height * 0.62, height: height * 0.86).offset(x: height * 0.22, y: -height * 0.06)
            RoundedRectangle(cornerRadius: height * 0.06).fill(Theme.grey.opacity(0.8))
                .frame(width: height * 0.62, height: height * 0.86).offset(x: height * 0.11, y: -height * 0.03)
            DocGlyph(height: height * 0.86)
                .overlay(alignment: .topLeading) {
                    Capsule().fill(Theme.black).frame(width: height * 0.2, height: height * 0.035)
                        .padding(.leading, height * 0.1).padding(.top, height * 0.1)
                }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// A destination's initial in a small rounded tile: R for Razorpay.
struct Avatar: View {
    var label: String
    var size: CGFloat = 22

    var body: some View {
        Text(Self.initial(label))
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(Theme.text)
            .frame(width: size, height: size)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: size * 0.3))
            .overlay(RoundedRectangle(cornerRadius: size * 0.3).strokeBorder(Theme.line))
            .accessibilityHidden(true)
    }

    static func initial(_ label: String) -> String {
        label.first { $0.isLetter || $0.isNumber }.map { String($0).uppercased() } ?? "?"
    }
}

/// FR-6: High = solid Frosted Blue, Medium = solid Grey, Low = Grey ring.
struct ConfidenceDot: View {
    var confidence: Confidence

    var body: some View {
        Group {
            switch confidence {
            case .high: Circle().fill(Theme.frostedBlue)
            case .medium: Circle().fill(Theme.grey)
            case .low: Circle().strokeBorder(Theme.grey, lineWidth: 1.5)
            }
        }
        .frame(width: Theme.confidenceDot, height: Theme.confidenceDot)
        .accessibilityLabel("\(confidence.title)")
    }
}

extension Confidence {
    var title: String {
        switch self {
        case .high: "High confidence"
        case .medium: "Medium confidence"
        case .low: "Low confidence"
        }
    }
}

/// Uppercase, tracked section label: "RECENT".
struct SectionLabel: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(Theme.sectionLabel)
            .tracking(Theme.sectionTracking)
            .foregroundStyle(Theme.textMuted)
    }
}

/// The search field used in the popover and the Ledger: 32 pt, radius 9, Frosted Blue focus ring.
struct SearchField: View {
    var placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textMuted)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Theme.body)
                .foregroundStyle(Theme.text)
                .focused(focused)
        }
        .padding(.horizontal, 10)
        .frame(height: Theme.searchHeight)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Theme.searchRadius))
        .overlay {
            if focused.wrappedValue {
                RoundedRectangle(cornerRadius: Theme.searchRadius).strokeBorder(Theme.focusBorder, lineWidth: 1)
                RoundedRectangle(cornerRadius: Theme.searchRadius + 2).stroke(Theme.focusGlow, lineWidth: 3.5).padding(-2)
            }
        }
    }
}

/// Button styles from BRAND.md "Buttons": 28 pt tall, radius 7.
struct FallbackButtonStyle: ButtonStyle {
    enum Kind { case primary, frost, ghost, quiet }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(kind == .quiet ? Theme.body : Theme.bodyMedium)
            .padding(.horizontal, kind == .ghost ? 4 : (kind == .quiet ? 8 : 12))
            .frame(height: Theme.buttonHeight)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.buttonRadius))
            .overlay { if kind == .quiet { RoundedRectangle(cornerRadius: Theme.buttonRadius).strokeBorder(Theme.line2) } }
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch kind {
        case .primary, .frost: Theme.black
        case .ghost: Theme.text
        case .quiet: Theme.text
        }
    }

    private var background: Color {
        switch kind {
        case .primary: Theme.lavenderBlush
        case .frost: Theme.frostedBlue
        case .ghost: .clear
        case .quiet: Theme.surface
        }
    }
}

/// App icon for the Ledger's App column: globe for browsers, envelope for Mail, bubble for chat apps.
func appSymbol(for bundleID: String) -> String {
    if bundleID == WatchedApps.safari || WatchedApps.chromium.contains(bundleID) || bundleID == "org.mozilla.firefox" {
        return "globe"
    }
    if bundleID == "com.apple.mail" || bundleID == "com.microsoft.Outlook" { return "envelope" }
    return "bubble.left"
}

/// Short app name for rows: "Chrome" rather than "Google Chrome".
func shortAppName(_ name: String) -> String {
    name.replacingOccurrences(of: "Google ", with: "").replacingOccurrences(of: "Microsoft ", with: "")
}

/// "{destination} · {app} · {time}", without repeating the app when it is the destination (WhatsApp · WhatsApp).
func sendSubtitle(_ send: SendRow) -> String {
    let app = shortAppName(send.appName)
    let parts = send.destinationLabel == app || send.destinationLabel == send.appName ? [app] : [send.destinationLabel, app]
    return (parts + [SendTime.short(send.sentAt)]).joined(separator: " · ")
}

/// Times as the designs show them, on a 24-hour clock ("09:15", "18:20").
enum SendTime {
    static func clock(_ date: Date) -> String {
        date.formatted(.verbatim("\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
                                 timeZone: .current, calendar: .current))
    }

    /// Row time: "10:42" today, "Yesterday", "Thu" this week, else "2 Nov".
    static func short(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return clock(date) }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Detail time: "Today 10:42", "Yesterday 18:20", "2 Nov 16:08".
    static func long(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = clock(date)
        if calendar.isDateInToday(date) { return "Today \(time)" }
        if calendar.isDateInYesterday(date) { return "Yesterday \(time)" }
        return "\(date.formatted(.dateTime.day().month(.abbreviated))) \(time)"
    }

    /// Relative day for summaries: "today", "yesterday", "Thu", "2 Nov".
    static func day(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInYesterday(date) { return "yesterday" }
        return short(date)
    }

    /// Table group headers: Today, Yesterday, This week, Earlier.
    static func group(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: now).day, days < 7 {
            return "This week"
        }
        return "Earlier"
    }
}
