import SwiftUI

enum ReflectTab {
    case home, history, stats, abstract, settings
}

struct MainWindowView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme
    @State private var tab: ReflectTab = .home
    @State private var entries: [Entry] = []
    @State private var loading = true

    var body: some View {
        ZStack(alignment: .top) {
            ReflectBackground()

            VStack(spacing: 0) {
                // Nav
                HStack {
                    Text("✦ reflect")
                        .font(RFont.header(20))
                        .foregroundColor(scheme == .dark ? .rPink : .rBlue)

                    Spacer()

                    HStack(spacing: 4) {
                        NavTab(label: "home",     selected: tab == .home)     { tab = .home }
                        NavTab(label: "history",  selected: tab == .history)  { tab = .history }
                        NavTab(label: "stats",    selected: tab == .stats)    { tab = .stats }
                        NavTab(label: "abstract", selected: tab == .abstract) { tab = .abstract }
                        NavTab(label: "settings", selected: tab == .settings) { tab = .settings }
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
                        HistoryView(entries: entries)
                    case .stats:
                        StatsView(entries: entries)
                    case .abstract:
                        AbstractView(entries: entries, onClose: { tab = .home })
                    case .settings:
                        SettingsView()
                            .environmentObject(supabase)
                    }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .task { await loadEntries() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await loadEntries() }
        }
    }

    private func loadEntries() async {
        loading = true
        do {
            let fetched = try await supabase.fetchEntries()
            guard !Task.isCancelled else { return }
            entries = fetched
        } catch { }
        loading = false
    }
}

struct NavTab: View {
    @Environment(\.colorScheme) var scheme
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(label, action: action)
            .buttonStyle(.plain)
            .font(RFont.body(13).weight(selected ? .semibold : .regular))
            .foregroundColor(selected ? RColor.text(scheme) : RColor.muted(scheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? RColor.input(scheme) : .clear)
            )
    }
}
