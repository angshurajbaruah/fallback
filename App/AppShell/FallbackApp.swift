import SwiftUI
import FallbackCore

@main
struct FallbackApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image("MenuBarIcon")
                .accessibilityLabel(FallbackCore.appName)
        }
        Window("Detection Log", id: "detection-log") {
            DetectionLogView(log: delegate.log)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let log = DetectionLog()
    private lazy var watcher = PanelWatcher(log: log)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Adds Fallback to the Accessibility list and shows macOS's prompt if access isn't granted yet.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        watcher.start()
    }
}

private struct MenuContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Detection Log…") {
            openWindow(id: "detection-log")
            NSApp.activate()
        }
        Divider()
        Button("Quit Fallback") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
