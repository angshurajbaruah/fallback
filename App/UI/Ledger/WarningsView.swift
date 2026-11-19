import FallbackCore
import SwiftUI

/// Warnings (Design/screens/06): every check Fallback ran and what happened next. Rows arrive in M4.
struct WarningsView: View {
    @Environment(AppModel.self) private var model

    enum Filter: String, CaseIterable {
        case all = "All", saved = "Saved", sentAnyway = "Sent anyway", muted = "Muted"
        var outcome: String? {
            switch self {
            case .all: nil
            case .saved: "fixed"
            case .sentAnyway: "sent_anyway"
            case .muted: "muted"
            }
        }
    }

    @State private var filter: Filter = .all
    @State private var rows: [WarningRow] = []
    @State private var month: [WarningRow] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Warnings").font(Theme.windowTitle)
                    Text("Every check Fallback ran, and what you did next").font(Theme.caption).foregroundStyle(Theme.textMuted)
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach(Filter.allCases, id: \.self) { item in
                        Button(item.rawValue) { filter = item }
                            .buttonStyle(.plain).font(Theme.body)
                            .foregroundStyle(filter == item ? Theme.text : Theme.textMuted)
                            .padding(.horizontal, 10).frame(height: 26)
                            .background(filter == item ? Theme.hoverFill : .clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(3)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 9))
            }
            .padding(.horizontal, 24).padding(.top, 14)
            .frame(height: Theme.toolbarHeight + 14)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    summary.padding(24)
                    header
                    if rows.isEmpty {
                        Text("No warnings yet.").font(Theme.caption).foregroundStyle(Theme.textMuted)
                            .frame(maxWidth: .infinity).padding(.top, 40)
                    }
                    ForEach(rows) { row in WarningTableRow(row: row) }
                }
                .padding(.bottom, 24)
            }
        }
        .task(id: "\(model.version)|\(filter)") {
            rows = (try? model.store.warnings(outcome: filter.outcome)) ?? []
            let start = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? .distantPast
            month = ((try? model.store.warnings()) ?? []).filter { $0.createdAt >= start }
        }
    }

    private var summary: some View {
        let cards = month.filter(\.shownAsCard)
        let saves = month.filter { $0.outcome == "fixed" }.count
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "This month")
                Text(saves == 1 ? "1 save" : "\(saves) saves").font(.system(size: 40, weight: .medium))
                Text("You changed the file after a warning, \(saves) \(saves == 1 ? "time" : "times") out of \(cards.count).")
                    .font(Theme.caption).foregroundStyle(Theme.textMuted)
            }
            Spacer()
            stat("Cards shown", "\(cards.count)")
            stat("False alarms", "\(month.filter { $0.outcome == "false_alarm" }.count)")
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Sensitivity")
                // Sensitivity (PRD 8.2) becomes changeable in Settings (M5); Balanced is the default.
                Text("Balanced").font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.primary)
                    .padding(.horizontal, 8).frame(height: 22)
                    .background(Theme.infoTint, in: RoundedRectangle(cornerRadius: Theme.chipRadius))
            }
            .padding(.leading, 24)
        }
        .padding(24)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).strokeBorder(Theme.line))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: label)
            Text(value).font(.system(size: 28))
        }
        .padding(.leading, 32)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("Warning").frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 56)
            Text("What happened").frame(width: 300, alignment: .leading)
            Text("When").frame(width: 110, alignment: .leading)
            Text("Outcome").frame(width: 130, alignment: .leading)
        }
        .font(Theme.caption).foregroundStyle(Theme.textMuted)
        .padding(.horizontal, 24).frame(height: 32)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

private struct WarningTableRow: View {
    var row: WarningRow

    /// Card titles from Design/COPY.md, and the Ledger's names for W2/W3.
    private var title: String {
        switch row.rule {
        case "W1": "Older version"
        case "W2": "Already sent"
        case "W3": "Changed since last send"
        case "W4": "Check the recipient"
        case "W5": "Out-of-date export"
        default: "Another version exists"
        }
    }

    private var isWarning: Bool { ["W1", "W4", "W5"].contains(row.rule) }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: isWarning ? "exclamationmark.circle" : "info.circle")
                    .foregroundStyle(isWarning ? Theme.warningText : Theme.primary)
                    .frame(width: 30, height: 30)
                    .background(isWarning ? Theme.warningTint : Theme.infoTint, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(Theme.bodyMedium)
                        Text(row.rule).font(Theme.caption).foregroundStyle(Theme.textMuted)
                    }
                    Text("\(row.fileName) → \(row.destinationLabel) · \(shortAppName(row.appName))")
                        .font(Theme.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.detail ?? (row.shownAsCard ? "Card shown" : "Ledger only")).font(Theme.body).lineLimit(1)
                .frame(width: 300, alignment: .leading)
            Text(SendTime.long(row.createdAt)).font(Theme.body).frame(width: 110, alignment: .leading)
            outcome.frame(width: 130, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .frame(height: 60)
    }

    @ViewBuilder private var outcome: some View {
        let (text, tint, colour): (String, Color, Color) = switch row.outcome {
        case "fixed": ("Saved", Theme.infoTint, Theme.primary)
        case "sent_anyway": ("Sent anyway", Theme.hoverFill, Theme.text)
        case "muted": ("Muted", Theme.warningTint, Theme.warningText)
        case nil where !row.shownAsCard: ("Ledger only", Theme.hoverFill, Theme.textMuted)
        default: ("Dismissed", Theme.hoverFill, Theme.text)
        }
        Text(text).font(Theme.caption.weight(.medium)).foregroundStyle(colour)
            .padding(.horizontal, 8).frame(height: 22)
            .background(tint, in: RoundedRectangle(cornerRadius: Theme.chipRadius))
    }
}
