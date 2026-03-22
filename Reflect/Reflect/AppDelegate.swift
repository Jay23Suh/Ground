import AppKit
import SwiftUI

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool  { true }
    override var canBecomeMain: Bool { true }
}

// Intercepts close and hides instead, avoiding NSHostingController dealloc crash
class HideOnCloseWindow: NSWindow, NSWindowDelegate {
    override func awakeFromNib() { super.awakeFromNib(); delegate = self }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        orderOut(nil)
        return false
    }
}

class KeyableHideOnCloseWindow: KeyableWindow, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        orderOut(nil)
        return false
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var scheduler: NSBackgroundActivityScheduler?
    private var popupWindow: KeyableHideOnCloseWindow?
    private var mainWindow:  HideOnCloseWindow?
    private var setupWindow: HideOnCloseWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupScheduler()
        let nc = NotificationCenter.default
        nc.addObserver(forName: .showJournalPopup, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.showPopup() }
        }
        nc.addObserver(forName: .showMainWindow,  object: nil, queue: .main) { [weak self] _ in self?.showMain() }
        nc.addObserver(forName: .showSetupWindow, object: nil, queue: .main) { [weak self] _ in self?.showSetup() }
    }

    private func setupScheduler() {
        scheduler = NSBackgroundActivityScheduler(identifier: "com.reflect.popup")
        scheduler?.interval = 2 * 60 * 60
        scheduler?.tolerance = 5 * 60
        scheduler?.repeats = true
        scheduler?.schedule { [weak self] completion in
            DispatchQueue.main.async { self?.showPopup() }
            completion(.finished)
        }
    }

    func showPopup() {
        PopupState.shared.refresh()
        if let w = popupWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = JournalPopupView { [weak self] in
            self?.popupWindow?.orderOut(nil)
        }
        .environmentObject(SupabaseManager.shared)
        .environmentObject(PopupState.shared)

        let w = KeyableHideOnCloseWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        w.delegate = w
        w.contentViewController = NSHostingController(rootView: view)
        w.level = .floating
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        popupWindow = w
    }

    func showMain() {
        if let w = mainWindow { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let w = HideOnCloseWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        w.delegate = w
        w.minSize = NSSize(width: 640, height: 480)
        w.collectionBehavior = [.fullScreenPrimary]
        w.title = "reflect"
        w.titlebarAppearsTransparent = true
        w.contentViewController = NSHostingController(rootView: MainWindowView().environmentObject(SupabaseManager.shared))
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = w
    }

    func showSetup() {
        if let w = setupWindow { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let w = HideOnCloseWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        w.delegate = w
        w.title = "reflect — setup"
        w.contentViewController = NSHostingController(
            rootView: SetupView(onComplete: { [weak self] in
                self?.setupWindow?.orderOut(nil)
            }).environmentObject(SupabaseManager.shared)
        )
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setupWindow = w
    }
}
