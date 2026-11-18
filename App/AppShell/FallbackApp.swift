import SwiftUI
import FallbackCore

@main
struct FallbackApp: App {
    var body: some Scene {
        MenuBarExtra {
            Button("Quit Fallback") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image("MenuBarIcon")
                .accessibilityLabel(FallbackCore.appName)
        }
    }
}
