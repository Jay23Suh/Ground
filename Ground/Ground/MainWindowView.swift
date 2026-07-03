import SwiftUI
import UserNotifications
import Auth

enum GroundTab {
    case home, history, notes, stats, abstract, chill, settings
}

struct MainWindowView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme
    @State private var tab: GroundTab = .home
    @State private var entries: [Entry] = []
    @State private var loading = true
    @State private var showNotificationPrompt = false
    @State private var historyScrollTarget: UUID? = nil

    private var answeredEntries: [Entry] { entries.filter { !$0.skipped } }

    private var isAbstractUnlocked: Bool {
        guard answeredEntries.count >= 10 else { return false }
        guard let oldest = answeredEntries.last?.date else { return false }
        let days = Calendar.current.dateComponents([.day], from: oldest, to: Date()).day ?? 0
        return days >= 7
    }


    var body: some View {
        ZStack(alignment: .top) {
            GroundBackground(animated: tab == .chill)

            VStack(spacing: 0) {
                // Nav
                HStack {
                    HStack(spacing: 4) {
                        Image("GroundIcon")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 18, height: 18)
                            .foregroundColor(scheme == .dark ? .rPink : .rBlue)
                        Text("ground")
                            .font(RFont.header(20))
                            .foregroundColor(scheme == .dark ? .rPink : .rBlue)
                    }

                    Spacer()

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 4) {
                            NavTab(label: "home",     selected: tab == .home)     { tab = .home }
                            NavTab(label: "history",  selected: tab == .history)  { tab = .history }
                            NavTab(label: "memories", selected: tab == .notes,    badge: supabase.collectiveBadge > 0) { tab = .notes }
                            NavTab(label: "stats",    selected: tab == .stats)    { tab = .stats }
                            NavTab(label: "abstract", selected: tab == .abstract) { tab = .abstract }
                            NavTab(label: "settings", selected: tab == .settings) { tab = .settings }
                        }
                        HStack(spacing: 1) {
                            NavTab(label: "home",     selected: tab == .home,     compact: true) { tab = .home }
                            NavTab(label: "history",  selected: tab == .history,  compact: true) { tab = .history }
                            NavTab(label: "memories", selected: tab == .notes,    compact: true, badge: supabase.collectiveBadge > 0) { tab = .notes }
                            NavTab(label: "stats",    selected: tab == .stats,    compact: true) { tab = .stats }
                            NavTab(label: "abstract", selected: tab == .abstract, compact: true) { tab = .abstract }
                            NavTab(label: "settings", selected: tab == .settings, compact: true) { tab = .settings }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    scheme == .dark
                        ? Color.rMint.opacity(0.08)
                        : Color.white.opacity(0.5)
                )
                .overlay(Divider(), alignment: .bottom)

                if let errorMessage = supabase.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(RFont.body(12))
                        .foregroundColor(.rOrange)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .background(Color.rOrange.opacity(0.08))
                        .overlay(Divider(), alignment: .bottom)
                }

                // Content
                if loading {
                    Spacer()
                    ProgressView().progressViewStyle(.circular)
                    Spacer()
                } else {
                    switch tab {
                    case .home:
                        HomeView(entries: entries)
                            .environmentObject(supabase)
                    case .history:
                        HistoryView(entries: entries, scrollTarget: $historyScrollTarget)
                    case .notes:
                        NotesView()
                            .environmentObject(supabase)
                    case .stats:
                        StatsView(entries: entries, onSelectEntry: { id in
                            historyScrollTarget = id
                            tab = .history
                        })
                            .environmentObject(supabase)
                    case .abstract:
                        if isAbstractUnlocked {
                            AbstractView(entries: answeredEntries, onClose: { tab = .home })
                        } else {
                            AbstractLockedView(answeredCount: answeredEntries.count,
                                              oldestDate: answeredEntries.last?.date)
                        }
                    case .chill:
                        ChillView()
                    case .settings:
                        SettingsView()
                            .environmentObject(supabase)
                    }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .sheet(isPresented: $showNotificationPrompt) {
            NotificationPromptView { showNotificationPrompt = false }
        }
        .task { await loadEntries() }
        .task { await checkNotificationPrompt() }
        .onChange(of: supabase.user?.id) { _ in
            entries = []
            Task { await loadEntries() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            NSLog("DIAG didBecomeActive fired")
            Task {
                await loadEntries(showSpinner: false)
                NSLog("DIAG checkForNewCollectivePerspectives starting")
                await supabase.checkForNewCollectivePerspectives()
                NSLog("DIAG checkForNewCollectivePerspectives done")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didJournal)) { _ in
            Task { await loadEntries(showSpinner: false) }
        }
    }

    private func loadEntries(showSpinner: Bool = true) async {
        let requestedUserId = supabase.user?.id
        NSLog("DIAG loadEntries start showSpinner=\(showSpinner) loading=\(loading)")
        if showSpinner { loading = true }
        do {
            let fetched = try await supabase.fetchEntries()
            guard !Task.isCancelled, supabase.user?.id == requestedUserId else {
                NSLog("DIAG loadEntries cancelled/stale, returning early, loading=\(loading)")
                return
            }
            entries = fetched
            scheduleAbstractNotificationIfNeeded()
        } catch {
            NSLog("DIAG loadEntries error: \(error)")
        }
        if showSpinner { loading = false }
        NSLog("DIAG loadEntries end loading=\(loading)")
    }

    private func checkNotificationPrompt() async {
        let shown = UserDefaults.standard.bool(forKey: "ground.notificationPromptShown")
        guard !shown, supabase.user != nil else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            UserDefaults.standard.set(true, forKey: "ground.notificationPromptShown")
            return
        }
        UserDefaults.standard.set(true, forKey: "ground.notificationPromptShown")
        showNotificationPrompt = true
    }

    private func scheduleAbstractNotificationIfNeeded() {
        guard isAbstractUnlocked else { return }
        guard !UserDefaults.standard.bool(forKey: "abstractNotificationScheduled") else { return }
        let content = UNMutableNotificationContent()
        content.title = "your abstract is ready"
        content.body = "your week in journaling — see how it looked"
        content.sound = .default
        var components = DateComponents()
        components.weekday = 1  // Sunday
        components.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "groundAbstractWeekly", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        UserDefaults.standard.set(true, forKey: "abstractNotificationScheduled")
    }
}

// MARK: - Abstract Locked

struct AbstractLockedView: View {
    let answeredCount: Int
    let oldestDate: Date?
    @Environment(\.colorScheme) var scheme

    private var daysIn: Int {
        guard let d = oldestDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0
    }
    private var daysLeft: Int { max(0, 7 - daysIn) }
    private var entriesLeft: Int { max(0, 10 - answeredCount) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Text("✦")
                    .font(RFont.header(36))
                    .foregroundColor(.rPink)

                VStack(spacing: 8) {
                    Text("abstract")
                        .font(RFont.header(34))
                        .foregroundColor(RColor.text(scheme))
                    Text("a short, visual review of your week in journaling — your patterns, your words, your mood.")
                        .font(RFont.body(14).italic())
                        .foregroundColor(RColor.muted(scheme))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }

                VStack(spacing: 10) {
                    Text("available after:")
                        .font(RFont.mono(11))
                        .foregroundColor(RColor.muted(scheme))
                    HStack(spacing: 12) {
                        UnlockPill(met: daysLeft == 0, label: daysLeft == 0 ? "7 days ✓" : "\(daysLeft) day\(daysLeft == 1 ? "" : "s") left")
                        UnlockPill(met: entriesLeft == 0, label: entriesLeft == 0 ? "10 entries ✓" : "\(entriesLeft) entr\(entriesLeft == 1 ? "y" : "ies") left")
                    }
                }

                Text("come back on Sunday once you've settled in.")
                    .font(RFont.body(13).italic())
                    .foregroundColor(RColor.muted(scheme).opacity(0.7))
            }
            .padding(40)
            Spacer()
        }
    }
}

struct UnlockPill: View {
    let met: Bool
    let label: String
    @Environment(\.colorScheme) var scheme

    var body: some View {
        Text(label)
            .font(RFont.mono(12))
            .foregroundColor(met ? Color(hex: "#5edb97") : RColor.muted(scheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(met ? Color(hex: "#5edb97").opacity(0.12) : RColor.input(scheme))
            )
    }
}

// MARK: - Intro Overlay

struct IntroOverlay: View {
    let onDone: () -> Void
    @State private var slide = 0
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(hex: "#130f08").ignoresSafeArea()

            Group {
                if slide == 0 {
                    IntroSlideOne(appeared: appeared) { withAnimation(.easeInOut(duration: 0.5)) { slide = 1; appeared = false } }
                } else {
                    IntroSlideTwo(appeared: appeared, onDone: onDone)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)
            ))

            // Dots
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { i in
                        Capsule()
                            .fill(i == slide ? Color(hex: "#f0c060") : Color(hex: "#f0c060").opacity(0.25))
                            .frame(width: i == slide ? 16 : 6, height: 6)
                            .animation(.spring(duration: 0.3), value: slide)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true } }
        .onChange(of: slide) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { appeared = true }
        }
    }
}

struct IntroSlideOne: View {
    let appeared: Bool
    let onNext: () -> Void

    private let lines = [
        "we are all busy with something.",
        "it's important to ground ourselves —",
        "be grateful. be present.",
        "get to know yourself.",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("GroundIcon")
                .resizable()
                .renderingMode(.template)
                .frame(width: 36, height: 36)
                .foregroundColor(Color(hex: "#f0c060"))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

            Text("ground")
                .font(.custom("Cormorant Garamond", size: 48))
                .foregroundColor(Color(hex: "#f0c060"))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)
                .padding(.bottom, 32)

            VStack(spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                    Text(line)
                        .font(.custom("Cormorant Garamond", size: 20).italic())
                        .foregroundColor(Color(hex: "#f0c060").opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.easeOut(duration: 0.5).delay(0.5 + Double(i) * 0.25), value: appeared)
                }
            }

            Spacer()

            Button("next →") { onNext() }
                .buttonStyle(.plain)
                .font(.custom("Quicksand", size: 14).weight(.medium))
                .foregroundColor(Color(hex: "#f0c060").opacity(0.8))
                .padding(.vertical, 12)
                .padding(.horizontal, 36)
                .overlay(RoundedRectangle(cornerRadius: 40).stroke(Color(hex: "#f0c060").opacity(0.35), lineWidth: 1))
                .padding(.bottom, 48)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(1.8), value: appeared)
        }
        .padding(.horizontal, 48)
    }
}

struct IntroSlideTwo: View {
    let appeared: Bool
    let onDone: () -> Void

    private let points: [(icon: String, text: String)] = [
        ("clock", "every 2 hours of active use, a prompt appears asking you to check in with yourself."),
        ("menubar.rectangle", "ground lives in your menu bar — keep it running even when you hide the window."),
        ("square.and.pencil", "you can also write anytime by clicking the icon in your menu bar."),
        ("sparkles", "after a week and 10 entries, your abstract unlocks — a visual review of your journey."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("how it works")
                .font(.custom("Cormorant Garamond", size: 36))
                .foregroundColor(Color(hex: "#f0c060"))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(points.enumerated()), id: \.offset) { i, point in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: point.icon)
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#f0c060").opacity(0.7))
                            .frame(width: 20)
                            .padding(.top, 2)
                        Text(point.text)
                            .font(.custom("Cormorant Garamond", size: 18).italic())
                            .foregroundColor(Color(hex: "#f0c060").opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.easeOut(duration: 0.5).delay(0.3 + Double(i) * 0.2), value: appeared)
                }
            }

            Spacer()

            Button("let's begin") { onDone() }
                .buttonStyle(.plain)
                .font(.custom("Quicksand", size: 14).weight(.medium))
                .foregroundColor(Color(hex: "#f0c060").opacity(0.8))
                .padding(.vertical, 12)
                .padding(.horizontal, 36)
                .overlay(RoundedRectangle(cornerRadius: 40).stroke(Color(hex: "#f0c060").opacity(0.35), lineWidth: 1))
                .padding(.bottom, 48)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(1.4), value: appeared)
        }
        .padding(.horizontal, 48)
    }
}

struct NavTab: View {
    @Environment(\.colorScheme) var scheme
    let label: String
    let selected: Bool
    var compact: Bool = false
    var badge: Bool = false
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(label, action: action)
                .buttonStyle(.plain)
                .font(RFont.body(compact ? 11 : 13).weight(selected ? .semibold : .regular))
                .foregroundColor(selected ? RColor.text(scheme) : RColor.muted(scheme))
                .padding(.horizontal, compact ? 8 : 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? RColor.input(scheme) : .clear)
                )
            if badge {
                Circle()
                    .fill(Color.rMint)
                    .frame(width: 6, height: 6)
                    .offset(x: -2, y: 2)
            }
        }
    }
}
