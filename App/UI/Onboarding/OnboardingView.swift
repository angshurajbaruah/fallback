import AppKit
import FallbackCore
import SwiftUI

/// S5, onboarding (PRD Flow A, Design/screens/10 to 15): six steps with a progress indicator.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var step: Int

    init(step: Int = 1) { _step = State(initialValue: step) }

    /// Step 1 has no label: the dots and "1 of 6" already say where you are.
    private let labels = ["", "", "Browsers", "Folders", "Indexing", "Try it"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch step {
                case 1: WelcomeStep()
                case 2: PermissionStep(next: { step = 3 })
                case 3: BrowsersStep()
                case 4: FoldersStep(next: { step = 5 })
                case 5: IndexingStep()
                default: TryItStep()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(Theme.line).frame(height: 1)
            footer
        }
        .frame(width: 920, height: 680)
        .background(Theme.surface2)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark) // onboarding is designed dark only
        .onChange(of: step) { model.gotItArmed = step == 6 }
    }

    private var header: some View {
        ZStack {
            HStack(spacing: 6) {
                ForEach(1...6, id: \.self) { index in
                    Capsule().fill(index == step ? Theme.frostedBlue : Theme.grey.opacity(index < step ? 0.9 : 0.5))
                        .frame(width: index == step ? 22 : 6, height: 6)
                }
            }
            HStack {
                Spacer()
                Text("\(step) of 6").font(Theme.body).foregroundStyle(Theme.textMuted)
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 52)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            if step > 1 { Button("Back") { step -= 1 }.buttonStyle(.plain).font(.system(size: 14)) }
            Text(step == 2 ? model.permissionName : labels[step - 1]).font(.system(size: 14)).foregroundStyle(Theme.textMuted)
            Spacer()
            switch step {
            case 1:
                Button("Get started") { step = 2 }.buttonStyle(OnboardingButtonStyle())
            case 2:
                Button("Open System Settings") { PermissionStep.openSettings() }.buttonStyle(OnboardingButtonStyle())
            case 3:
                Button("Skip for now") { step = 4 }.buttonStyle(OnboardingButtonStyle(primary: false))
                Button("Continue") { step = 4 }.buttonStyle(OnboardingButtonStyle())
            case 4:
                Button("Continue") { NotificationCenter.default.post(name: .onboardingSaveFolders, object: nil) }
                    .buttonStyle(OnboardingButtonStyle())
            case 5:
                Button("Close and continue later") { finish() }.buttonStyle(OnboardingButtonStyle(primary: false))
                Button("Continue") { step = 6 }.buttonStyle(OnboardingButtonStyle())
            default:
                Button("Open a test page") {
                    if let page = Bundle.main.url(forResource: "upload-test", withExtension: "html") { NSWorkspace.shared.open(page) }
                }
                .buttonStyle(OnboardingButtonStyle(primary: false))
                Button("Finish") { finish() }.buttonStyle(OnboardingButtonStyle())
            }
        }
        .padding(.horizontal, 28)
        .frame(height: 96)
    }

    private func finish() {
        model.finishOnboarding()
        dismissWindow(id: "onboarding")
    }
}

extension Notification.Name {
    static let onboardingSaveFolders = Notification.Name("onboardingSaveFolders")
}

/// Heading + body under each step's picture.
private struct StepText: View {
    var title: String
    var body_: String

    var body: some View {
        VStack(spacing: 14) {
            Text(title).font(Theme.brand(36)).multilineTextAlignment(.center)
            Text(body_).font(.system(size: 15)).foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center).frame(maxWidth: 640).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: 1 Welcome (screen 10, option B)

private struct WelcomeStep: View {
    var body: some View {
        // The Spacers centre the group between the header and the footer.
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            content.background(alignment: .top) { bloom } // behind, and not part of the centring
            Spacer(minLength: 0)
        }
    }

    /// One soft Frosted Blue bloom behind the greeting (BRAND.md: one bloom at most): a 460×280 oval
    /// blurred by 70 at 50%, drawn as a gradient (cheaper than a live blur, and it renders in snapshots).
    private var bloom: some View {
        EllipticalGradient(stops: [.init(color: Theme.frostedBlue.opacity(0.5), location: 0),
                                   .init(color: Theme.frostedBlue.opacity(0.4), location: 0.4),
                                   .init(color: Theme.frostedBlue.opacity(0), location: 1)])
            .frame(width: 460 + 140, height: 280 + 140)
            .offset(y: -50 - 70)
            .allowsHitTesting(false).accessibilityHidden(true)
    }

    private var content: some View {
        VStack(spacing: 0) {
            Text("Welcome to")
                .font(.custom("Sora", size: 27).weight(.regular)).tracking(27 * -0.015)
                .foregroundStyle(Theme.textMuted)
            HStack(spacing: 18) {
                Image("LogoMark").resizable().scaledToFit().frame(height: 54)
                Wordmark(size: 42)
            }
            .padding(.top, 20)
            Text("Never send the wrong file again").font(Theme.brand(23)).multilineTextAlignment(.center)
                .padding(.top, 36)
            Text("Fallback sits quietly in your menu bar, remembers every file you send and where it went, and speaks up before the wrong version goes out.")
                .font(.system(size: 13.5)).foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center).frame(maxWidth: 470).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            HStack(spacing: 10) {
                Circle().fill(Theme.frostedBlue).frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Theme.frostedBlue.opacity(0.3), lineWidth: 4))
                Text("Everything stays on this Mac. Fallback never uploads anything.").font(.system(size: 14)).foregroundStyle(Theme.textMuted)
            }
            .padding(.horizontal, 18).frame(height: 40)
            .overlay(Capsule().strokeBorder(Theme.line2))
            .padding(.top, 20)
        }
    }
}

// MARK: 2 Permission (screen 11)

private struct PermissionStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            illustration
            Spacer().frame(height: 60)
            StepText(title: "Let Fallback see what you attach",
                     body_: "Turn on Fallback under \(model.permissionName), so it can see which file you pick when you attach something. It can't read your screen, keystrokes or messages.")
            HStack(spacing: 10) {
                if model.isTrusted {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.frostedBlue)
                    Text("Access granted.").foregroundStyle(Theme.text)
                } else {
                    ProgressView().controlSize(.small)
                    Text("Waiting for access. This continues by itself.").foregroundStyle(Theme.textMuted)
                }
            }
            .font(.system(size: 14))
            .padding(.top, 24)
            Spacer()
        }
        // Flow A step 2: checks every second and moves on as soon as access is granted, no restart.
        .task(id: model.isTrusted) {
            guard model.isTrusted else { return }
            try? await Task.sleep(for: .seconds(1))
            next()
        }
    }

    /// Adds Fallback to the list (macOS's own prompt) and opens the right pane.
    static func openSettings() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// A picture of the System Settings list, Fallback's switch circled.
    private var illustration: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                Text("Privacy & Security › \(model.permissionName)")
            }
            .font(.system(size: 14)).foregroundStyle(Theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).frame(height: 54)
            Rectangle().fill(Theme.line).frame(height: 1)
            row(icon: AnyView(Image("LogoMark").resizable().scaledToFit().frame(width: 28)), name: "Fallback",
                detail: "Sees which file you pick in an Open panel", on: true, focus: true)
            row(icon: AnyView(Avatar(label: "Terminal", size: 30)), name: "Terminal", detail: nil, on: false)
            row(icon: AnyView(Avatar(label: "Raycast", size: 30)), name: "Raycast", detail: nil, on: true, dim: true, last: true)
        }
        .frame(width: 640)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line2))
        .accessibilityHidden(true)
    }

    private func row(icon: AnyView, name: String, detail: String?, on: Bool, focus: Bool = false, dim: Bool = false, last: Bool = false) -> some View {
        HStack(spacing: 16) {
            icon.frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.system(size: 15)).foregroundStyle(dim || !on ? Theme.textMuted : Theme.text)
                if let detail { Text(detail).font(Theme.body).foregroundStyle(Theme.textMuted) }
            }
            Spacer()
            Capsule().fill(on ? (dim ? Theme.grey.opacity(0.5) : Theme.frostedBlue) : Theme.line2)
                .frame(width: 44, height: 26)
                .overlay(alignment: on ? .trailing : .leading) { Circle().fill(Theme.lavenderBlush.opacity(dim ? 0.5 : 1)).padding(3) }
                .background { if focus { Circle().stroke(Theme.frostedBlue.opacity(0.6), lineWidth: 2).frame(width: 74, height: 74) } }
        }
        .padding(.horizontal, 24).frame(height: 62)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(Theme.line).frame(height: 1) } }
    }
}

// MARK: 3 Browsers (screen 12)

struct BrowserInfo: Identifiable {
    let id: String
    let name: String
    static let all = [
        BrowserInfo(id: "com.apple.Safari", name: "Safari"),
        BrowserInfo(id: "com.google.Chrome", name: "Google Chrome"),
        BrowserInfo(id: "company.thebrowser.Browser", name: "Arc"),
        BrowserInfo(id: "com.brave.Browser", name: "Brave"),
        BrowserInfo(id: "com.microsoft.edgemac", name: "Microsoft Edge"),
    ]
}

private struct BrowsersStep: View {
    @Environment(AppModel.self) private var model
    @State private var access: [String: AppModel.BrowserAccess] = [:]
    @State private var testing: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                ForEach(Array(BrowserInfo.all.enumerated()), id: \.element.id) { index, browser in
                    HStack(spacing: 16) {
                        Avatar(label: browser.name, size: 30)
                        Text(browser.name).font(.system(size: 15))
                        Spacer()
                        status(browser)
                    }
                    .padding(.horizontal, 24).frame(height: 56)
                    .overlay(alignment: .bottom) { if index < BrowserInfo.all.count - 1 { Rectangle().fill(Theme.line).frame(height: 1) } }
                }
            }
            .frame(width: 560)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line2))
            Spacer().frame(height: 60)
            StepText(title: "Know where each file went",
                     body_: "macOS will ask if Fallback can control each browser. That only lets it read the address of the page you're uploading to, nothing else.")
            Spacer()
        }
        .task {
            for browser in BrowserInfo.all {
                let stored = AppModel.browserAccess(browser.id)
                // "Allowed" only once the browser has actually answered.
                access[browser.id] = stored == .allowed ? AppModel.verifyBrowser(browser.id) : stored
            }
        }
    }

    @ViewBuilder private func status(_ browser: BrowserInfo) -> some View {
        switch access[browser.id] {
        case .allowed?: Chip(text: "Allowed", symbol: "checkmark", highlighted: true)
        case .notInstalled?: Chip(text: "Not installed")
        case .denied?:
            Chip(text: "Not allowed").help("Turn it on in System Settings › Privacy & Security › Automation › Fallback.")
        default:
            Button(testing == browser.id ? "Testing…" : access[browser.id] == .noAnswer ? "Test again" : "Test now") {
                testing = browser.id
                Task {
                    access[browser.id] = await model.testBrowser(browser.id)
                    testing = nil
                }
            }
            .buttonStyle(FallbackButtonStyle(kind: .quiet))
            .disabled(testing != nil)
            .help(access[browser.id] == .noAnswer ? "\(browser.name) didn't answer. Make sure it isn't showing a dialog, then test again." : "")
        }
    }
}

// MARK: 4 Folders (screen 13)

private struct FoldersStep: View {
    @Environment(AppModel.self) private var model
    var next: () -> Void
    @State private var rows: [(path: String, checked: Bool)] = []
    @State private var counts: [String: Int] = [:]

    static let suggested = ["Documents", "Desktop", "Downloads"].map {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: $0).path
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    folderRow(index)
                }
                Button(action: addFolder) {
                    Label("Add folder…", systemImage: "plus").font(.system(size: 15)).foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24).frame(height: 52)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(width: 600)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line2))
            Spacer().frame(height: 40)
            StepText(title: "Choose folders to keep track of",
                     body_: "Fallback fingerprints files here so it can tell versions apart. It skips app bundles, caches, hidden files and code folders.")
            Spacer()
        }
        .task {
            // PRD Flow A step 4: Documents, Desktop and Downloads pre-ticked, plus anything already watched.
            let current = model.folders
            rows = (Self.suggested + current.filter { !Self.suggested.contains($0) }).map { ($0, current.isEmpty || current.contains($0)) }
            await countFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingSaveFolders)) { _ in
            model.setFolders(rows.filter(\.checked).map(\.path))
            next()
        }
    }

    private func folderRow(_ index: Int) -> some View {
        let row = rows[index]
        let name = (row.path as NSString).lastPathComponent
        return Button { rows[index].checked.toggle() } label: {
            HStack(spacing: 16) {
                Image(systemName: row.checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20)).foregroundStyle(row.checked ? Theme.frostedBlue : Theme.grey)
                Image(systemName: "folder").foregroundStyle(Theme.frostedBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 15))
                    Text((row.path as NSString).abbreviatingWithTildeInPath).font(Theme.mono).foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Text(counts[row.path].map { "\($0.formatted()) files" } ?? "").font(.system(size: 14)).foregroundStyle(Theme.textMuted)
            }
            .padding(.horizontal, 24).frame(height: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !rows.contains(where: { $0.path == url.path }) { rows.append((url.path, true)) }
        Task { await countFiles() }
    }

    /// How many files each folder would index. Reading Desktop, Documents or Downloads makes macOS ask first (PRD 11.1).
    private func countFiles() async {
        let rules = model.indexRules
        for row in rows where counts[row.path] == nil {
            let path = row.path
            counts[path] = await Task.detached { Self.count(path, rules: rules) }.value
        }
    }

    nonisolated static func count(_ path: String, rules: IndexRules) -> Int {
        guard let walker = FileManager.default.enumerator(at: URL(filePath: path), includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                                                          options: [.skipsHiddenFiles]) else { return 0 }
        var total = 0, seen = 0
        while let item = walker.nextObject() as? URL, seen < 200_000 {
            seen += 1
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if values?.isDirectory == true {
                if rules.skipsFolder(item.lastPathComponent) { walker.skipDescendants() }
            } else if rules.indexes(name: item.lastPathComponent, sizeBytes: values?.fileSize.map(Int64.init)) {
                total += 1
            }
        }
        return total
    }
}

// MARK: 5 Indexing (screen 14)

private struct IndexingStep: View {
    @Environment(AppModel.self) private var model

    private var fraction: Double {
        guard let indexing = model.indexing, indexing.total > 0 else { return 1 }
        return Double(indexing.done) / Double(indexing.total)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Theme.surface).frame(width: 300, height: 300)
                    .shadow(color: Theme.frostedBlue.opacity(0.12), radius: 50)
                Circle().stroke(Theme.line2, lineWidth: 16).frame(width: 300, height: 300)
                Circle().trim(from: 0, to: fraction).stroke(Theme.frostedBlue, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                    .rotationEffect(.degrees(-90)).frame(width: 300, height: 300)
                    .animation(.easeOut(duration: 0.3), value: fraction)
                VStack(spacing: 8) {
                    Text("\(Int((fraction * 100).rounded()))%").font(Theme.brand(56))
                    Text(model.indexing.map { "\($0.done.formatted()) of \($0.total.formatted())" } ?? "Done")
                        .font(.system(size: 15)).foregroundStyle(Theme.textMuted)
                }
            }
            Spacer().frame(height: 60)
            StepText(title: "Fingerprinting your files",
                     body_: "This runs in the background and takes a few minutes. You can close this window, and Fallback carries on.")
            Text(model.indexingFile.map { ($0 as NSString).abbreviatingWithTildeInPath } ?? " ")
                .font(Theme.mono).foregroundStyle(Theme.textMuted).lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: 600).padding(.top, 20)
            Spacer()
        }
    }
}

// MARK: 6 Try it (screen 15)

private struct TryItStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            illustration
            Spacer().frame(height: 60)
            StepText(title: "Try it once",
                     body_: "Open any website with an upload button and pick a file. When Fallback sees it, you'll get a confirmation like this one.")
            Spacer()
        }
        .onAppear { model.gotItArmed = !model.gotItSeen }
    }

    /// A browser page with a file attached, and the "Got it" card beside it.
    private var illustration: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    ForEach([0xFF5F57, 0xFEBC2E, 0x28C840] as [UInt32], id: \.self) { _ in Circle().fill(Theme.grey).frame(width: 10, height: 10) }
                }
                .padding(.horizontal, 18).frame(height: 36, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Upload a file").font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.black)
                    HStack(spacing: 14) {
                        DocGlyph(ext: "pdf", height: 40)
                        Text("resume_v5.pdf").font(.system(size: 17)).foregroundStyle(Theme.black)
                        Spacer()
                    }
                    .padding(16)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.grey, style: StrokeStyle(lineWidth: 1.5, dash: [5])))
                    .frame(width: 380)
                }
                .padding(36)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.lavenderBlush)
            }
            .frame(width: 720)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            WarningCardView(content: WarningCardContent(gotIt: "resume_v5.pdf", site: "careers.razorpay.com"),
                            onPrimary: {}, onSecondary: {}, onMute: {}, onMore: {}, onClose: {}, onTimeout: {})
                .allowsHitTesting(false)
                .offset(x: 390, y: 104)
        }
        .frame(width: 780, height: 260, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}
