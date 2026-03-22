import SwiftUI

struct StatsView: View {
    let entries: [Entry]
    @Environment(\.colorScheme) var scheme

    private var stats: ReflectStats { ReflectStats(entries: entries) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Skip nudge
                if stats.skipRate > 0.5 && stats.totalPrompts > 3 {
                    HStack(spacing: 12) {
                        Text("✦")
                            .font(RFont.header(16))
                            .foregroundColor(.rOrange)
                        Text("you've been skipping a lot lately — make some time for yourself to reflect")
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

                // When you write
                HourPatternView(distribution: stats.hourDistribution)

                // Chart
                EntryChartView(entries: entries)
            }
            .padding(32)
        }
    }
}

private func hourLabel(_ h: Int) -> String {
    if h == 0  { return "12am" }
    if h == 12 { return "12pm" }
    return h < 12 ? "\(h)am" : "\(h - 12)pm"
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
struct ReflectStats {
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

    init(entries: [Entry]) {
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
            let daysSinceFirst = max(1, cal.dateComponents([.day], from: firstDay, to: today).day! + 1)
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
        if let max = dayCounts.max(), max > 0 {
            mostActiveDay = weekdays[dayCounts.firstIndex(of: max)!]
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
