import SwiftUI

/// The Ledger before anything has been sent (Design/screens/07).
struct LedgerEmptyView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 18) {
            DocStack(height: 230).padding(.bottom, 20)
            Text("Your trail starts with the next file you send").font(Theme.brand(30)).multilineTextAlignment(.center)
            Text("Fallback is watching \(model.folderNames). Nothing is recorded until you attach something.")
                .font(Theme.body).foregroundStyle(Theme.textMuted).multilineTextAlignment(.center).frame(maxWidth: 560)
            HStack(alignment: .top, spacing: 16) {
                step(1, "Pick a file to attach", "In Chrome, Safari, Mail, Slack or WhatsApp. Any upload button works.")
                step(2, "Fallback records it", "File, version and destination, kept only on this Mac.")
                step(3, "Ask it later", "“What did I send Razorpay?” One search, the exact file.")
            }
            .frame(maxWidth: 1100)
            .padding(.top, 24)
            HStack(spacing: 12) {
                Button("Try it on a test page") {
                    if let page = Bundle.main.url(forResource: "upload-test", withExtension: "html") { NSWorkspace.shared.open(page) }
                }
                .buttonStyle(PillButtonStyle())
                Button("Choose folders", action: chooseFolders).buttonStyle(FallbackButtonStyle(kind: .ghost))
            }
            .padding(.top, 20)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func step(_ number: Int, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)").font(Theme.bodyMedium).foregroundStyle(Theme.primary)
                .frame(width: 30, height: 30).background(Theme.infoTint, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(Theme.bodyMedium)
                Text(body).font(Theme.caption).foregroundStyle(Theme.textMuted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
    }

    /// The standard macOS folder picker.
    private func chooseFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Watch"
        if panel.runModal() == .OK { model.addFolders(panel.urls) }
    }
}
