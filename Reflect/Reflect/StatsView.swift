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
                    StatCard(label: "avg words/entry", value: stats.avgWords > 0 ? "\(stats.avgWords)" : "—")
                    StatCard(label: "longest streak", value: stats.longestStreak > 0 ? "\(stats.longestStreak)d" : "—")
                    StatCard(label: "most active", value: stats.mostActiveDay ?? "—")
                    StatCard(label: "skip rate", value: stats.totalPrompts > 0 ? "\(Int(stats.skipRate * 100))%" : "—")
                }

                // Chart
                EntryChartView(entries: entries)
            }
            .padding(32)
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
struct ReflectStats {
    let totalEntries: Int
    let totalSkips: Int
    let totalPrompts: Int
    let totalWords: Int
    let avgWords: Int
    let longestStreak: Int
    let mostActiveDay: String?
    let mostActiveHour: Int?
    let topCategory: String?
    let skipRate: Double

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

        // Most active day
        let weekdays = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        var dayCounts = Array(repeating: 0, count: 7)
        answered.forEach { dayCounts[cal.component(.weekday, from: $0.date) - 1] += 1 }
        if let max = dayCounts.max(), max > 0 {
            mostActiveDay = weekdays[dayCounts.firstIndex(of: max)!]
        } else {
            mostActiveDay = nil
        }

        // Most active hour
        var hourCounts = Array(repeating: 0, count: 24)
        answered.forEach { hourCounts[cal.component(.hour, from: $0.date)] += 1 }
        if let max = hourCounts.max(), max > 0 {
            mostActiveHour = hourCounts.firstIndex(of: max)
        } else {
            mostActiveHour = nil
        }

        // Top category
        var catCounts: [String: Int] = [:]
        answered.compactMap { $0.category }.forEach { catCounts[$0, default: 0] += 1 }
        topCategory = catCounts.max(by: { $0.value < $1.value })?.key
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

extension DateFormatter {
    func apply(_ configure: (DateFormatter) -> Void) -> DateFormatter {
        configure(self); return self
    }
}
