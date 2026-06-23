import AppKit
import SwiftUI
import UserNotifications
import CoreGraphics
import Combine

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool  { true }
    override var canBecomeMain: Bool { true }
}

// Intercepts close and hides instead, avoiding NSHostingController dealloc crash
class HideOnCloseWindow: NSWindow, NSWindowDelegate {
    private var hideAfterFullscreenExit = false
    override func awakeFromNib() { super.awakeFromNib(); delegate = self }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if styleMask.contains(.fullScreen) {
            hideAfterFullscreenExit = true
            toggleFullScreen(nil)
        } else {
            orderOut(nil)
        }
        return false
    }
    func windowDidExitFullScreen(_ notification: Notification) {
        if hideAfterFullscreenExit {
            hideAfterFullscreenExit = false
            orderOut(nil)
        }
    }
}

class KeyableHideOnCloseWindow: KeyableWindow, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        orderOut(nil)
        return false
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var checkTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var activeSeconds: TimeInterval = 0
    private var targetActiveSeconds: TimeInterval {
        let minutes = UserDefaults.standard.double(forKey: "groundPopupIntervalMinutes")
        return (minutes >= 20 ? minutes : 100) * 60
    }
    private let idleThreshold: TimeInterval = 5 * 60             // 5 min idle = paused
    private var popupWindow:       KeyableHideOnCloseWindow?
    private var mainWindow:        HideOnCloseWindow?
    private var setupWindow:       HideOnCloseWindow?
    private var onboardingWindow:  HideOnCloseWindow?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        setupScheduler()
        let nc = NotificationCenter.default
        nc.addObserver(forName: .showJournalPopup, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self?.showPopup() }
        }
        nc.addObserver(forName: .showMainWindow,  object: nil, queue: .main) { [weak self] _ in self?.showMain() }
        nc.addObserver(forName: .showSetupWindow, object: nil, queue: .main) { [weak self] _ in self?.showSetup() }
        nc.addObserver(forName: .didJournal,      object: nil, queue: .main) { [weak self] _ in self?.activeSeconds = 0 }

        Task { @MainActor in
            await SupabaseManager.shared.waitForSessionRestore()
            if SupabaseManager.shared.user == nil {
                showOnboarding()
            }
            observeAuthState()
        }
        checkDailyQuote()
    }

    // Once signed in, react to a later sign-out (from Settings) by tearing
    // down the signed-in windows and bringing the onboarding window back.
    private func observeAuthState() {
        SupabaseManager.shared.$user
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard user == nil else { return }
                self?.handleSignedOut()
            }
            .store(in: &cancellables)
    }

    private func handleSignedOut() {
        mainWindow?.orderOut(nil)
        setupWindow?.orderOut(nil)
        popupWindow?.orderOut(nil)
        showOnboarding()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { self.showPopup() }
        completionHandler()
    }

    // Suppress banner if popup is already on screen
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let popupVisible = popupWindow?.isVisible ?? false
        completionHandler(popupVisible ? [] : [.banner, .sound])
    }

    private func setupScheduler() {
        // Tick every 60s; only count time when user is not idle
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.tickActiveTime()
        }
    }

    private func tickActiveTime() {
        let mouse    = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let click    = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)
        let keyDown  = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let idleTime = min(mouse, min(click, keyDown))
        if idleTime < idleThreshold {
            activeSeconds += 60
        }
        if activeSeconds >= targetActiveSeconds {
            activeSeconds = 0
            showPopup()
            fireJournalNotification()
        }
        checkDailyQuote()
    }

    func checkDailyQuote() {
        let quoteService = QuoteService.shared
        guard quoteService.shouldShowToday() else { return }

        let timeString = UserDefaults.standard.string(forKey: "groundQuoteStartTime") ?? "08:00"
        let parts = timeString.components(separatedBy: ":")
        let configuredHour = Int(parts[0]) ?? 8
        let configuredMinute = parts.count > 1 ? Int(parts[1]) ?? 0 : 0

        let cal = Calendar.current
        let now = Date()
        let currentMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let configuredMinutes = configuredHour * 60 + configuredMinute
        guard currentMinutes >= configuredMinutes else { return }

        quoteService.markShownToday()
        Task {
            let quote = await quoteService.getQuoteOfTheDay()
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else { return }
                let content = UNMutableNotificationContent()
                content.title = "a moment to ground ✦"
                content.body = "\"\(quote.q)\" — \(quote.a)"
                let request = UNNotificationRequest(identifier: "daily-quote", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    private func fireJournalNotification() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "time to ground ✦"
            content.body = PopupState.shared.question.isEmpty
                ? "take a moment to check in with yourself."
                : PopupState.shared.question
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    func showPopup() {
        PopupState.shared.refresh()
        if let w = popupWindow {
            w.center()
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .prepareJournalPopup, object: nil)
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
        w.level = .modalPanel
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        popupWindow = w
        NotificationCenter.default.post(name: .prepareJournalPopup, object: nil)
    }

    func showMain() {
        UserDefaults.standard.set(true, forKey: "groundShowIntro")
        if let w = mainWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = HideOnCloseWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        w.delegate = w
        w.minSize = NSSize(width: 640, height: 480)
        w.collectionBehavior = [.fullScreenPrimary]
        w.title = "ground"
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
        w.title = "ground — setup"
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

    func showOnboarding() {
        if let w = onboardingWindow { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let w = HideOnCloseWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 540),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        w.delegate = w
        w.title = ""
        w.titlebarAppearsTransparent = true
        w.contentViewController = NSHostingController(
            rootView: OnboardingView(onComplete: { [weak self] in
                self?.onboardingWindow?.orderOut(nil)
                self?.showMain()
            }).environmentObject(SupabaseManager.shared)
        )
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = w
    }
}
