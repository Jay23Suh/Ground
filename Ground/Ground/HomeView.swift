import SwiftUI
import UserNotifications

struct HomeView: View {
    let entries: [Entry]
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme
    @StateObject private var quoteService = QuoteService.shared

    private var name: String {
        supabase.userName ?? "there"
    }

    private var recentEntries: [Entry] {
        Array(entries.filter { !$0.skipped }.prefix(3))
    }

    private var answered: [Entry] { entries.filter { !$0.skipped } }
    private var totalWords: Int { answered.reduce(0) { $0 + $1.wordCount } }
    private var streak: Int {
        let cal = Calendar.current
        let days = Set(answered.map { cal.startOfDay(for: $0.date) }).sorted(by: >)
        var s = 0
        for (i, day) in days.enumerated() {
            if i == 0 {
                guard cal.isDateInToday(day) || cal.isDateInYesterday(day) else { break }
                s = 1
            } else {
                guard cal.dateComponents([.day], from: day, to: days[i-1]).day == 1 else { break }
                s += 1
            }
        }
        return s
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                    // Greeting
                    VStack(alignment: .leading, spacing: 6) {
                        Text("hello, \(name)")
                            .font(RFont.header(34))
                            .foregroundColor(scheme == .dark ? .rPink : .rBlue)
                        Text(greetingSubtitle)
                            .font(RFont.body(14).italic())
                            .foregroundColor(RColor.muted(scheme))
                    }

                    // Quote Card (Static Banner)
                    if let quote = quoteService.currentQuote {
                        QuoteCard(quote: quote)
                    }

                    // Quick stats pills
                    HStack(spacing: 10) {
                        QuickPill(value: "\(answered.count)", label: "entries")
                        QuickPill(value: "\(totalWords)", label: "words")
                        if streak > 0 {
                            QuickPill(value: "\(streak)d", label: "streak")
                        }
                    }

                    // Write now button
                    Button {
                        NotificationCenter.default.post(name: .showJournalPopup, object: nil)
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("write now")
                                .font(RFont.body(14).weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.rOrange))
                    }
                    .buttonStyle(.plain)

                    // Recent entries
                    if !recentEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("recent entries")
                                .font(RFont.mono(11))
                                .foregroundColor(RColor.muted(scheme))
                            ForEach(recentEntries) { entry in
                                EntryCard(entry: entry)
                            }
                        }
                    }
                }
                .padding(32)
            }
        .task {
            await quoteService.getQuoteOfTheDay()
            if let profile = await supabase.fetchProfile(),
               quoteService.shouldShowModal(profile: profile),
               let quote = quoteService.currentQuote {
                let content = UNMutableNotificationContent()
                content.title = "a moment to ground ✦"
                content.body = "\"\(quote.q)\" — \(quote.a)"
                let request = UNNotificationRequest(
                    identifier: "daily-quote",
                    content: content,
                    trigger: nil
                )
                try? await UNUserNotificationCenter.current().add(request)
                await supabase.updateLastQuoteShown()
            }
        }
    }

    private var greetingSubtitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "good morning. how are you starting the day?"
        case 12..<17: return "good afternoon. take a moment to check in."
        case 17..<21: return "good evening. how was your day?"
        default:      return "still up? what's on your mind?"
        }
    }
}

struct QuickPill: View {
    @Environment(\.colorScheme) var scheme
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(RFont.header(18))
                .foregroundColor(scheme == .dark ? .rPink : .rBlue)
            Text(label)
                .font(RFont.mono(9))
                .foregroundColor(RColor.muted(scheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(RColor.card(scheme))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(RColor.border(scheme), lineWidth: 1))
        )
    }
}

struct QuoteCard: View {
    @Environment(\.colorScheme) var scheme
    let quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(quote.q)
                .font(RFont.header(20, italic: true))
                .foregroundColor(RColor.text(scheme))
                .lineSpacing(4)
            
            HStack {
                Spacer()
                Text("— \(quote.a)")
                    .font(RFont.mono(10))
                    .foregroundColor(RColor.muted(scheme))
                    .italic()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(RColor.card(scheme))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(RColor.border(scheme), lineWidth: 1))
        )
    }
}
