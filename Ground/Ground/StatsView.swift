import SwiftUI

struct StatsView: View {
    let entries: [Entry]
    var onSelectEntry: (UUID) -> Void = { _ in }
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme
    @State private var sentimentScores: [UUID: Double] = [:]
    @State private var notes: [Note] = []

    private var stats: GroundStats { GroundStats(entries: entries, sentimentScores: sentimentScores) }

    private var notesWordCount: Int { notes.reduce(0) { $0 + $1.wordCount } }
    private var notesAvgWords: Int { notes.isEmpty ? 0 : notesWordCount / notes.count }

    private var topLongestEntries: [RankedEntrySummary] {
        entries.filter { !$0.skipped }
            .sorted { $0.wordCount > $1.wordCount }
            .prefix(3)
            .compactMap { e in e.snippet.map { RankedEntrySummary(id: e.id, snippet: $0, metric: "\(e.wordCount) words") } }
    }

    private var topEmotionalEntries: [RankedEntrySummary] {
        entries.filter { !$0.skipped }
            .compactMap { e -> (Entry, Double)? in
                guard let score = sentimentScores[e.id] else { return nil }
                return (e, score)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .compactMap { e, _ in e.snippet.map { RankedEntrySummary(id: e.id, snippet: $0, metric: e.formattedDate) } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Skip nudge
                if stats.skipRate > 0.5 && stats.totalPrompts > 3 {
                    HStack(spacing: 12) {
                        Image("GroundIcon")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 16, height: 16)
                            .foregroundColor(.rOrange)
                        Text("you've been skipping a lot lately — make some time for yourself to ground")
                            .font(RFont.body(13).italic())
                            .foregroundColor(RColor.text(scheme))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.rOrange.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rOrange.opacity(0.25), lineWidth: 1))
                    )
                }

                Text("entries")
                    .font(RFont.body(13).weight(.semibold))
                    .foregroundColor(RColor.text(scheme))

                // Big stat cards row
                HStack(spacing: 12) {
                    BigStatCard(value: "\(stats.totalEntries)", label: "entries")
                    BigStatCard(value: "\(stats.totalWords)", label: "words written")
                    BigStatCard(value: "\(stats.totalSkips)", label: "skipped")
                }

                // Secondary stats
                HStack(spacing: 12) {
                    StatCard(label: "avg words/entry",  value: stats.avgWords > 0 ? "\(stats.avgWords)" : "—")
                    StatCard(label: "current streak",   value: stats.currentStreak > 0 ? "\(stats.currentStreak)d" : "—")
                    StatCard(label: "longest streak",   value: stats.longestStreak > 0 ? "\(stats.longestStreak)d" : "—")
                    StatCard(label: "skip rate",        value: stats.totalPrompts > 0 ? "\(Int(stats.skipRate * 100))%" : "—")
                }

                // Consistency + most active day
                HStack(spacing: 12) {
                    StatCard(label: "\(stats.consistencyWindowDays)d consistency", value: "\(Int(stats.consistencyLast30 * 100))%")
                    StatCard(label: "most active day",    value: stats.mostActiveDay ?? "—")
                    if let h = stats.mostActiveHour {
                        StatCard(label: "peak hour", value: hourLabel(h))
                    }
                }

                // Category breakdown
                if !stats.categoryBreakdown.isEmpty {
                    CategoryBreakdownView(breakdown: stats.categoryBreakdown)
                }

                // Highlights
                if topLongestEntries.count >= 2 {
                    TopEntriesListCard(title: "top 3 longest entries", accent: .rOrange, items: topLongestEntries, onSelect: onSelectEntry)
                }
                if topEmotionalEntries.count >= 2 {
                    TopEntriesListCard(title: "top 3 most emotional entries", accent: .rPink, items: topEmotionalEntries, onSelect: onSelectEntry)
                }

                // Mood
                if stats.baselineSampleCount >= 1 {
                    MoodTimelineView(stats: stats)
                }

                // When you write
                HourPatternView(distribution: stats.hourDistribution)

                // Chart
                EntryChartView(entries: entries)

                // Memories
                if !notes.isEmpty {
                    Divider().opacity(0.4)

                    Text("memories")
                        .font(RFont.body(13).weight(.semibold))
                        .foregroundColor(RColor.text(scheme))

                    HStack(spacing: 12) {
                        StatCard(label: "notes",          value: "\(notes.count)")
                        StatCard(label: "words written",  value: "\(notesWordCount)")
                        StatCard(label: "avg words/note", value: "\(notesAvgWords)")
                    }
                }
            }
            .padding(32)
        }
        .task(id: entries.map(\.id).hashValue) {
            sentimentScores = await Entry.computeSentiment(for: entries)
        }
        .task {
            notes = (try? await supabase.fetchNotes()) ?? []
        }
    }
}


struct BigStatCard: View {
    @Environment(\.colorScheme) var scheme
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(RFont.header(36))
                .foregroundColor(.rOrange)
            Text(label)
                .font(RFont.mono(11))
                .foregroundColor(RColor.muted(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.rOrange.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rOrange.opacity(0.2), lineWidth: 1))
        )
    }
}

struct StatCard: View {
    @Environment(\.colorScheme) var scheme
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(RFont.header(22))
                .foregroundColor(RColor.text(scheme))
            Text(label)
                .font(RFont.mono(10))
                .foregroundColor(RColor.muted(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(RColor.card(scheme))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(RColor.border(scheme), lineWidth: 1))
        )
    }
}

// MARK: - Stats model
struct GroundStats {
    let totalEntries: Int
    let totalSkips: Int
    let totalPrompts: Int
    let totalWords: Int
    let avgWords: Int
    let longestStreak: Int
    let currentStreak: Int
    let consistencyLast30: Double
    let consistencyWindowDays: Int
    let mostActiveDay: String?
    let mostActiveHour: Int?
    let topCategory: String?
    let skipRate: Double
    let categoryBreakdown: [(key: String, label: String, count: Int, pct: Double)]
    let hourDistribution: [Int]
    let moodBaseline: Double?           // avg of first 30 scored entries
    let baselineSampleCount: Int        // how many entries built the baseline (max 30)
    let avgMoodDelta: Double?           // avg deviation from baseline (nil until baseline built)
    let dailyMoodDelta: [(date: Date, delta: Double)]  // post-baseline daily deltas
    let peakMoodHour: Int?
    let moodTrendDirection: String?     // "upward", "downward", "stable", nil

    init(entries: [Entry], sentimentScores: [UUID: Double] = [:]) {
        let answered = entries.filter { !$0.skipped }
        let skipped  = entries.filter { $0.skipped }

        totalEntries = answered.count
        totalSkips   = skipped.count
        totalPrompts = entries.count
        totalWords   = answered.reduce(0) { $0 + $1.wordCount }
        avgWords     = answered.isEmpty ? 0 : totalWords / answered.count
        skipRate     = totalPrompts == 0 ? 0 : Double(totalSkips) / Double(totalPrompts)

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Longest streak
        let days = Set(answered.map { cal.startOfDay(for: $0.date) }).sorted()
        var streak = 0, best = 0
        for (i, day) in days.enumerated() {
            if i == 0 { streak = 1 }
            else if cal.dateComponents([.day], from: days[i-1], to: day).day == 1 { streak += 1 }
            else { streak = 1 }
            best = max(best, streak)
        }
        longestStreak = best

        // Current (active) streak
        let daysSorted = days.sorted(by: >)
        var cur = 0
        for (i, day) in daysSorted.enumerated() {
            if i == 0 {
                guard day == today || cal.dateComponents([.day], from: day, to: today).day == 1 else { break }
                cur = 1
            } else {
                guard cal.dateComponents([.day], from: day, to: daysSorted[i-1]).day == 1 else { break }
                cur += 1
            }
        }
        currentStreak = cur

        // Consistency: denominator is days since first entry, capped at 30
        let activeDays = Set(answered.map { cal.startOfDay(for: $0.date) })
        if let firstDay = activeDays.min() {
            let daysSinceFirst = max(1, (cal.dateComponents([.day], from: firstDay, to: today).day ?? 0) + 1)
            let window = min(daysSinceFirst, 30)
            let windowDays = (0..<window).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
            consistencyLast30 = Double(windowDays.filter { activeDays.contains($0) }.count) / Double(window)
            consistencyWindowDays = window
        } else {
            consistencyLast30 = 0
            consistencyWindowDays = 0
        }

        // Most active day of week
        let weekdays = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        var dayCounts = Array(repeating: 0, count: 7)
        answered.forEach { dayCounts[cal.component(.weekday, from: $0.date) - 1] += 1 }
        if let max = dayCounts.max(), max > 0, let idx = dayCounts.firstIndex(of: max) {
            mostActiveDay = weekdays[idx]
        } else {
            mostActiveDay = nil
        }

        // Hour distribution (all-time)
        var hourCounts = Array(repeating: 0, count: 24)
        answered.forEach { hourCounts[cal.component(.hour, from: $0.date)] += 1 }
        hourDistribution = hourCounts
        if let max = hourCounts.max(), max > 0 {
            mostActiveHour = hourCounts.firstIndex(of: max)
        } else {
            mostActiveHour = nil
        }

        // Category breakdown
        var catCounts: [String: Int] = [:]
        answered.compactMap { $0.category }.forEach { catCounts[$0, default: 0] += 1 }
        topCategory = catCounts.max(by: { $0.value < $1.value })?.key
        let total = catCounts.values.reduce(0, +)
        categoryBreakdown = catCounts
            .sorted { $0.value > $1.value }
            .map { k, v in (key: k, label: Category(rawValue: k)?.label ?? k, count: v, pct: total > 0 ? Double(v) / Double(total) : 0) }

        // Sentiment (pre-computed off main thread, sorted chronologically)
        let scored = answered
            .compactMap { e -> (date: Date, score: Double)? in
                guard let s = sentimentScores[e.id] else { return nil }
                return (e.date, s)
            }
            .sorted { $0.date < $1.date }

        let baselineEntries = Array(scored.prefix(30))
        baselineSampleCount = baselineEntries.count

        guard baselineEntries.count >= 10 else {
            // Not enough data yet
            moodBaseline = nil; avgMoodDelta = nil; dailyMoodDelta = []
            peakMoodHour = nil; moodTrendDirection = nil
            return
        }

        let baseline = baselineEntries.map(\.score).reduce(0,+) / Double(baselineEntries.count)
        moodBaseline = baseline

        // Only measure mood on entries after the baseline window
        let postBaseline = scored.count > 30 ? Array(scored.dropFirst(30)) : []
        guard !postBaseline.isEmpty else {
            avgMoodDelta = nil; dailyMoodDelta = []; peakMoodHour = nil; moodTrendDirection = nil
            return
        }

        let deltas = postBaseline.map { (date: $0.date, delta: $0.score - baseline) }
        avgMoodDelta = deltas.map(\.delta).reduce(0,+) / Double(deltas.count)

        // Daily average deltas
        var byDay: [Date: [Double]] = [:]
        deltas.forEach { byDay[cal.startOfDay(for: $0.date), default: []].append($0.delta) }
        dailyMoodDelta = byDay
            .map { (date: $0.key, delta: $0.value.reduce(0,+) / Double($0.value.count)) }
            .sorted { $0.date < $1.date }
            .suffix(14)

        // Peak mood hour (from post-baseline only)
        var hourDeltas: [Int: [Double]] = [:]
        deltas.forEach { hourDeltas[cal.component(.hour, from: $0.date), default: []].append($0.delta) }
        peakMoodHour = hourDeltas
            .mapValues { $0.reduce(0,+) / Double($0.count) }
            .max(by: { $0.value < $1.value })?.key

        // Trend
        let dailyVals = dailyMoodDelta.map(\.delta)
        if dailyVals.count >= 4 {
            let mid   = dailyVals.count / 2
            let first = dailyVals.prefix(mid).reduce(0,+) / Double(mid)
            let last  = dailyVals.suffix(mid).reduce(0,+) / Double(mid)
            moodTrendDirection = last - first > 0.06 ? "upward" : last - first < -0.06 ? "downward" : "stable"
        } else {
            moodTrendDirection = nil
        }
    }
}

// MARK: - Mood Timeline

struct MoodTimelineView: View {
    let stats: GroundStats
    @Environment(\.colorScheme) var scheme

    private func deltaLabel(_ d: Double) -> String {
        if d >= 0.15  { return "above baseline" }
        if d >= 0.05  { return "slightly above" }
        if d >= -0.05 { return "at baseline" }
        if d >= -0.15 { return "slightly below" }
        return "below baseline"
    }

    private func deltaColor(_ d: Double) -> Color {
        if d >= 0.1  { return Color(hex: "#5edb97") }
        if d >= 0.0  { return Color(hex: "#60d4e8") }
        if d >= -0.1 { return Color(hex: "#ffc840") }
        return Color(hex: "#FFA6C9")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("mood over time")
                    .font(RFont.body(13).weight(.semibold))
                    .foregroundColor(RColor.text(scheme))
                Spacer()
                if let avg = stats.avgMoodDelta {
                    Text(deltaLabel(avg))
                        .font(RFont.mono(9))
                        .foregroundColor(deltaColor(avg))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(deltaColor(avg).opacity(0.12)))
                }
            }

            if stats.moodBaseline == nil {
                // Still building baseline
                let remaining = 10 - stats.baselineSampleCount
                Text("building your baseline — \(max(0, remaining)) more answered \(remaining == 1 ? "entry" : "entries") needed")
                    .font(RFont.body(12).italic())
                    .foregroundColor(RColor.muted(scheme))
            } else if stats.avgMoodDelta == nil {
                Text("baseline established — keep grounding to see your mood trend")
                    .font(RFont.body(12).italic())
                    .foregroundColor(RColor.muted(scheme))
            } else {
                // Insight line
                if let trend = stats.moodTrendDirection, let hour = stats.peakMoodHour {
                    let hourStr = hour == 0 ? "midnight" : hour == 12 ? "noon" : hour < 12 ? "\(hour)am" : "\(hour-12)pm"
                    let trendStr = trend == "upward" ? "trending above your baseline lately"
                                 : trend == "downward" ? "dipping below your baseline recently"
                                 : "tracking close to your baseline"
                    Text("\(trendStr) — you write most positively around \(hourStr)")
                        .font(RFont.body(12).italic())
                        .foregroundColor(RColor.muted(scheme))
                }

                // Line chart — zero line = personal baseline
                if stats.dailyMoodDelta.count >= 2 {
                    MoodLineChart(points: stats.dailyMoodDelta.map { (date: $0.date, score: $0.delta) },
                                  moodColor: deltaColor)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(RColor.card(scheme))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(RColor.border(scheme), lineWidth: 1))
        )
    }
}

struct MoodLineChart: View {
    let points: [(date: Date, score: Double)]
    let moodColor: (Double) -> Color
    @Environment(\.colorScheme) var scheme

    private let h: CGFloat = 60

    private func minS() -> Double { min(-0.1, points.map(\.score).min()! - 0.05) }
    private func maxS() -> Double { max( 0.1, points.map(\.score).max()! + 0.05) }

    private func xPos(_ i: Int, width: CGFloat) -> CGFloat {
        CGFloat(i) / CGFloat(points.count - 1) * width
    }
    private func yPos(_ s: Double) -> CGFloat {
        let range = maxS() - minS()
        return h - CGFloat((s - minS()) / range) * h
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let zy = yPos(0)
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: zy))
                    p.addLine(to: CGPoint(x: w, y: zy))
                }
                .stroke(RColor.border(scheme).opacity(0.4), style: StrokeStyle(lineWidth: 0.5, dash: [4]))

                Path { p in
                    p.move(to: CGPoint(x: xPos(0, width: w), y: zy))
                    for i in points.indices { p.addLine(to: CGPoint(x: xPos(i, width: w), y: yPos(points[i].score))) }
                    p.addLine(to: CGPoint(x: xPos(points.count - 1, width: w), y: zy))
                    p.closeSubpath()
                }
                .fill(Color(hex: "#5edb97").opacity(0.08))

                Path { p in
                    p.move(to: CGPoint(x: xPos(0, width: w), y: yPos(points[0].score)))
                    for i in 1..<points.count {
                        p.addLine(to: CGPoint(x: xPos(i, width: w), y: yPos(points[i].score)))
                    }
                }
                .stroke(Color(hex: "#5edb97").opacity(0.7), lineWidth: 1.5)

                ForEach(points.indices, id: \.self) { i in
                    Circle()
                        .fill(moodColor(points[i].score))
                        .frame(width: 5, height: 5)
                        .position(x: xPos(i, width: w), y: yPos(points[i].score))
                }
            }
        }
        .frame(height: h)
    }
}

// MARK: - Chart
struct EntryChartView: View {
    let entries: [Entry]
    @Environment(\.colorScheme) var scheme
    @State private var period: ChartPeriod = .week

    enum ChartPeriod: String, CaseIterable { case day, week, month, year }

    private var buckets: [(label: String, count: Int)] {
        let answered = entries.filter { !$0.skipped }
        let cal = Calendar.current
        let now = Date()

        switch period {
        case .day:
            return (0..<24).map { h in
                let label = h == 0 ? "12am" : h == 12 ? "12pm" : h % 6 == 0 ? "\(h < 12 ? h : h-12)\(h < 12 ? "am" : "pm")" : ""
                let count = answered.filter {
                    cal.isDateInToday($0.date) && cal.component(.hour, from: $0.date) == h
                }.count
                return (label, count)
            }
        case .week:
            return (0..<7).map { offset in
                let day = cal.date(byAdding: .day, value: -(6 - offset), to: now)!
                let label = offset % 2 == 0 ? DateFormatter().apply({ $0.dateFormat = "EEE" }).string(from: day) : ""
                let count = answered.filter { cal.isDate($0.date, inSameDayAs: day) }.count
                return (label, count)
            }
        case .month:
            return (0..<5).map { w in
                let weekStart = cal.date(byAdding: .weekOfYear, value: -(4 - w), to: now)!
                let weekEnd   = cal.date(byAdding: .day, value: 7, to: weekStart)!
                let label = w % 2 == 0 ? DateFormatter().apply({ $0.dateFormat = "MMM d" }).string(from: weekStart) : ""
                let count = answered.filter { $0.date >= weekStart && $0.date < weekEnd }.count
                return (label, count)
            }
        case .year:
            return (0..<12).map { m in
                let month = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: m + 1))!
                let next  = cal.date(byAdding: .month, value: 1, to: month)!
                let label = DateFormatter().apply({ $0.dateFormat = "MMM" }).string(from: month)
                let count = answered.filter { $0.date >= month && $0.date < next }.count
                return (label, count)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("entries over time")
                    .font(RFont.body(13).weight(.semibold))
                    .foregroundColor(RColor.text(scheme))
                Spacer()
                HStack(spacing: 6) {
                    ForEach(ChartPeriod.allCases, id: \.self) { p in
                        Button(p.rawValue) { period = p }
                            .buttonStyle(.plain)
                            .font(RFont.mono(10))
                            .foregroundColor(period == p ? .white : RColor.muted(scheme))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(period == p ? Color.rBlue : RColor.input(scheme)))
                    }
                }
            }

            // Bar chart with y-axis labels
            let maxCount = max(buckets.map(\.count).max() ?? 1, 1)
            let yTicks: [Int] = {
                if maxCount <= 4 { return Array(0...maxCount) }
                let step = max(1, maxCount / 4)
                return stride(from: 0, through: maxCount, by: step).map { $0 }
            }()

            let chartH: CGFloat = 140
            let padB:   CGFloat = 20
            let barAreaH = chartH - padB

            GeometryReader { geo in
                let w = geo.size.width
                let yLabelW: CGFloat = 26
                let barAreaW = w - yLabelW - 6

                ZStack(alignment: .topLeading) {
                    // Y-axis labels + gridlines
                    ForEach(yTicks, id: \.self) { tick in
                        let y = barAreaH - (CGFloat(tick) / CGFloat(maxCount)) * barAreaH
                        // gridline
                        Path { p in
                            p.move(to:    CGPoint(x: yLabelW + 6, y: y))
                            p.addLine(to: CGPoint(x: w,           y: y))
                        }
                        .stroke(RColor.border(scheme).opacity(0.4), lineWidth: 0.5)
                        // label
                        Text("\(tick)")
                            .font(RFont.mono(8))
                            .foregroundColor(RColor.muted(scheme))
                            .frame(width: yLabelW, alignment: .trailing)
                            .position(x: yLabelW / 2, y: y)
                    }

                    // Bars + x labels
                    let barW = max(4, (barAreaW / CGFloat(buckets.count)) * 0.55)
                    let gap  = barAreaW / CGFloat(buckets.count)
                    ForEach(Array(buckets.enumerated()), id: \.offset) { i, bucket in
                        let barH = bucket.count == 0 ? 2.0 : (CGFloat(bucket.count) / CGFloat(maxCount)) * barAreaH
                        let cx = yLabelW + 6 + CGFloat(i) * gap + gap / 2

                        RoundedRectangle(cornerRadius: 3)
                            .fill(bucket.count > 0 ? Color.rLavender.opacity(0.85) : RColor.border(scheme).opacity(0.3))
                            .frame(width: barW, height: barH)
                            .position(x: cx, y: barAreaH - barH / 2)

                        if !bucket.label.isEmpty {
                            Text(bucket.label)
                                .font(RFont.mono(8))
                                .foregroundColor(RColor.muted(scheme))
                                .position(x: cx, y: barAreaH + 12)
                        }
                    }
                }
            }
            .frame(height: chartH)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(RColor.card(scheme))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(RColor.border(scheme), lineWidth: 1))
        )
    }
}

// MARK: - Category Breakdown

private func categoryColor(_ key: String) -> Color {
    switch key {
    case "gratitude":  return .rOrange
    case "compassion": return Color(hex: "#5edb97")
    case "values":     return Color(hex: "#b088ff")
    case "emotions":   return Color(hex: "#60d4e8")
    case "grounding":  return Color(hex: "#ffc840")
    default:           return .rMint
    }
}

struct CategoryBreakdownView: View {
    let breakdown: [(key: String, label: String, count: Int, pct: Double)]
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("by category")
                .font(RFont.body(13).weight(.semibold))
                .foregroundColor(RColor.text(scheme))

            VStack(spacing: 10) {
                ForEach(breakdown, id: \.key) { item in
                    HStack(spacing: 10) {
                        Text(item.label)
                            .font(RFont.mono(9))
                            .foregroundColor(RColor.muted(scheme))
                            .frame(width: 150, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(RColor.border(scheme).opacity(0.5))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(categoryColor(item.key))
                                    .frame(width: geo.size.width * item.pct, height: 6)
                            }
                        }
                        .frame(height: 6)

                        Text("\(Int(item.pct * 100))%")
                            .font(RFont.mono(9))
                            .foregroundColor(RColor.muted(scheme))
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(RColor.card(scheme))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(RColor.border(scheme), lineWidth: 1))
        )
    }
}

// MARK: - Top Entries

struct RankedEntrySummary: Identifiable {
    let id: UUID   // the underlying Entry's id, so a row can link back to it in History
    let snippet: String
    let metric: String
}

struct TopEntriesListCard: View {
    @Environment(\.colorScheme) var scheme
    let title: String
    let accent: Color
    let items: [RankedEntrySummary]
    var onSelect: (UUID) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(RFont.body(13).weight(.semibold))
                .foregroundColor(RColor.text(scheme))

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    Button { onSelect(item.id) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)")
                                .font(RFont.mono(11))
                                .foregroundColor(accent)
                                .frame(width: 14, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.snippet)
                                    .font(RFont.body(13).italic())
                                    .foregroundColor(RColor.text(scheme))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                Text(item.metric)
                                    .font(RFont.mono(9))
                                    .foregroundColor(RColor.muted(scheme))
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(RColor.muted(scheme).opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if i < items.count - 1 {
                        Divider().opacity(0.3)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(RColor.card(scheme))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(RColor.border(scheme), lineWidth: 1))
        )
    }
}

// MARK: - Hour Pattern Chart

struct HourPatternView: View {
    let distribution: [Int]
    @Environment(\.colorScheme) var scheme

    private var maxCount: Int { distribution.max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("when you write")
                .font(RFont.body(13).weight(.semibold))
                .foregroundColor(RColor.text(scheme))

            let chartH: CGFloat = 60
            GeometryReader { geo in
                let barW = geo.size.width / 24
                ZStack(alignment: .bottomLeading) {
                    ForEach(0..<24, id: \.self) { h in
                        let count = distribution[h]
                        let barH = maxCount > 0 ? (CGFloat(count) / CGFloat(maxCount)) * chartH : 0
                        let color = categoryColor(dominantCategory(at: h))

                        VStack(spacing: 3) {
                            Spacer()
                            RoundedRectangle(cornerRadius: 2)
                                .fill(count > 0 ? color.opacity(0.75) : RColor.border(scheme).opacity(0.25))
                                .frame(width: max(2, barW - 2), height: max(2, barH))
                            Text(h % 6 == 0 ? hourShort(h) : "")
                                .font(RFont.mono(7))
                                .foregroundColor(RColor.muted(scheme))
                                .frame(width: barW)
                        }
                        .frame(width: barW, height: chartH + 14, alignment: .bottom)
                        .offset(x: CGFloat(h) * barW)
                    }
                }
            }
            .frame(height: 78)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(RColor.card(scheme))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(RColor.border(scheme), lineWidth: 1))
        )
    }

    private func hourShort(_ h: Int) -> String {
        if h == 0  { return "12a" }
        if h == 12 { return "12p" }
        return h < 12 ? "\(h)a" : "\(h-12)p"
    }

    // Color bars by the time-of-day they fall in
    private func dominantCategory(at h: Int) -> String {
        switch h {
        case 5..<9:   return "grounding"   // morning  → yellow
        case 9..<13:  return "values"      // midday   → purple
        case 13..<18: return "emotions"    // afternoon → cyan
        case 18..<22: return "gratitude"   // evening  → orange
        default:      return "compassion"  // night    → green
        }
    }
}

extension DateFormatter {
    func apply(_ configure: (DateFormatter) -> Void) -> DateFormatter {
        configure(self); return self
    }
}
