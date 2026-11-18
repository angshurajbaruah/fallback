import Testing
@testable import FallbackCore

@Test func appNameIsFallback() {
    #expect(FallbackCore.appName == "Fallback")
}

@Test(arguments: ["Open", "Choose File", "Choose", "Upload", "Attach", "Insert", ""])
func openPanelButtons(title: String) {
    #expect(PanelKind(defaultButtonTitle: title) == .open)
}

@Test(arguments: ["Save", "Save As…", "Export", "Move", "Replace"])
func savePanelButtons(title: String) {
    #expect(PanelKind(defaultButtonTitle: title) == .save)
}
