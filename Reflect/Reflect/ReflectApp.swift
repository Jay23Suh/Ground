import SwiftUI
import CoreText

@main
struct ReflectApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        registerFonts()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(SupabaseManager.shared)
        } label: {
            Image(systemName: "sparkles")
        }
        .menuBarExtraStyle(.menu)
    }

    private func registerFonts() {
        guard let resourcesURL = Bundle.main.resourceURL else { return }
        let enumerator = FileManager.default.enumerator(
            at: resourcesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "ttf" || url.pathExtension == "otf" else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
