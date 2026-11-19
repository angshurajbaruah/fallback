import SwiftUI

/// BRAND.md toggle: 38×22, Frosted Blue when on.
struct FrostToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack {
                configuration.label
                Spacer(minLength: 12)
                Capsule()
                    .fill(configuration.isOn ? Theme.frostedBlue : Theme.line2)
                    .frame(width: 38, height: 22)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(Theme.lavenderBlush).padding(2.5).shadow(radius: 1, y: 1)
                    }
                    .animation(.easeOut(duration: 0.15), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

/// A rounded group of settings rows with hairlines between them.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
    }
}

/// One row: title, optional quiet subtitle, and a control on the right.
struct SettingsRow<Accessory: View>: View {
    var title: String
    var subtitle: String? = nil
    var last = false
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.body).foregroundStyle(Theme.text)
                if let subtitle { Text(subtitle).font(Theme.caption).foregroundStyle(Theme.textMuted) }
            }
            Spacer()
            accessory
        }
        .padding(.horizontal, 20)
        .padding(.vertical, subtitle == nil ? 14 : 12)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(Theme.line).frame(height: 1) } }
    }
}

/// A segmented choice like "System · Light · Dark" or "Today · 7 days · All".
struct Segmented<Value: Hashable>: View {
    var options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, title in
                Button(title) { selection = value }
                    .buttonStyle(.plain).font(Theme.body)
                    .foregroundStyle(selection == value ? Theme.text : Theme.textMuted)
                    .padding(.horizontal, 12).frame(height: 26)
                    .background(selection == value ? Theme.hoverFill : .clear, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(3)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
    }
}

/// A small chip: "Browser", "Card", "Ledger only", "Allowed".
struct Chip: View {
    var text: String
    var symbol: String? = nil
    var highlighted = false

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .semibold)) }
            Text(text).font(Theme.caption.weight(.semibold))
        }
        .foregroundStyle(highlighted ? Theme.primary : Theme.textMuted)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(highlighted ? Theme.infoTint : Theme.hoverFill, in: RoundedRectangle(cornerRadius: Theme.chipRadius))
    }
}

/// The "fallback" wordmark: Sora Medium, lowercase, tracked +14% (BRAND.md "Lockup").
struct Wordmark: View {
    var size: CGFloat

    var body: some View {
        Text("fallback").font(Theme.brand(size)).tracking(size * 0.14).foregroundStyle(Theme.text)
    }
}

/// The two pill buttons in onboarding's footer (pills appear only in onboarding and on the website).
struct OnboardingButtonStyle: ButtonStyle {
    var primary = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(primary ? Theme.black : Theme.text)
            .padding(.horizontal, 20)
            .frame(height: 40)
            .background(primary ? Theme.lavenderBlush : Theme.surface, in: Capsule())
            .overlay { if !primary { Capsule().strokeBorder(Theme.line2) } }
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
