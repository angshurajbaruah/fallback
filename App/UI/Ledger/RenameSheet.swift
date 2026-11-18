import FallbackCore
import SwiftUI

/// "Edit destination label" (Design/screens/23, FR-13).
struct RenameSheet: View {
    enum Target {
        case send(SendRow)
        /// From By destination: always renames every send to that place.
        case destination(DestinationSummary, seen: String)
    }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var target: Target

    @State private var label = ""
    @State private var forFuture = true
    @State private var others = 0
    @FocusState private var focused: Bool

    private var seen: String {
        switch target {
        case .send(let send): send.url.flatMap { URL(string: $0)?.host() } ?? send.pageTitle ?? send.appName
        case .destination(_, let seen): seen
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit destination label").font(Theme.windowTitle)
            (Text("Fallback saw ") + Text(seen).font(Theme.mono))
                .font(Theme.caption).foregroundStyle(Theme.textMuted).padding(.top, 4)

            HStack(spacing: 12) {
                Text("Label").font(Theme.body).foregroundStyle(Theme.textMuted)
                TextField("", text: $label)
                    .textFieldStyle(.plain)
                    .font(Theme.body)
                    .padding(.horizontal, 10).frame(height: Theme.searchHeight)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.searchRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.searchRadius).strokeBorder(focused ? Theme.focusBorder : Theme.line2))
                    .focused($focused)
                    .onSubmit(save)
            }
            .padding(.top, 20)

            if case .send = target {
                Toggle(isOn: $forFuture) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use for future sends to this address").font(Theme.body)
                        if others > 0 {
                            Text(others == 1 ? "Also renames 1 earlier send." : "Also renames \(others) earlier sends.")
                                .font(Theme.caption).foregroundStyle(Theme.textMuted)
                        }
                    }
                }
                .toggleStyle(.checkbox)
                .tint(Theme.frostedBlue)
                .padding(.leading, 50).padding(.top, 14)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(FallbackButtonStyle(kind: .ghost))
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(FallbackButtonStyle(kind: .primary))
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 22)
        }
        .padding(28)
        .frame(width: 420)
        .background(Theme.surface2)
        .onAppear {
            switch target {
            case .send(let send):
                label = send.destinationLabel
                others = (try? model.store.otherSendCount(sameDestinationAs: send.id)) ?? 0
            case .destination(let place, _):
                label = place.label
            }
            focused = true
        }
    }

    private func save() {
        let text = label.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        switch target {
        case .send(let send): model.renameDestination(ofSend: send.id, to: text, includingOthers: forFuture)
        case .destination(let place, _): model.renameDestination(id: place.id, to: text)
        }
        dismiss()
    }
}
