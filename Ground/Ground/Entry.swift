import Foundation
import NaturalLanguage

struct Entry: Codable, Identifiable {
    let id: UUID
    let user_id: String
    let question: String?
    let answer: String?
    let category: String?
    let skipped: Bool
    let created_at: String

    var date: Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: created_at) ?? Date()
    }

    var wordCount: Int { answer?.wordCount ?? 0 }

    // Run off the main thread — use computeSentiment(for:) in a Task
    static func sentimentScore(for text: String) -> Double? {
        guard text.count > 3 else { return nil }
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return tag.flatMap { Double($0.rawValue) }
    }

    static func computeSentiment(for entries: [Entry]) async -> [UUID: Double] {
        await Task.detached(priority: .utility) {
            var result: [UUID: Double] = [:]
            for entry in entries where !entry.skipped {
                if let text = entry.answer, let score = Entry.sentimentScore(for: text) {
                    result[entry.id] = score
                }
            }
            return result
        }.value
    }

    var categoryLabel: String {
        guard let c = category else { return "" }
        return Category(rawValue: c)?.label ?? c
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    /// First sentence of `answer` long enough to stand alone, or a truncated prefix
    /// if no such sentence boundary is found. Collapses embedded line breaks so a
    /// multi-paragraph entry never renders as a broken snippet.
    var snippet: String? {
        guard let text = answer else { return nil }
        let cleaned = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > 15 else { return nil }
        let enders = CharacterSet(charactersIn: ".!?")
        var searchStart = cleaned.startIndex
        while let range = cleaned.rangeOfCharacter(from: enders, range: searchStart..<cleaned.endIndex) {
            let sentence = String(cleaned[..<range.upperBound])
            if sentence.count > 15 { return sentence }
            searchStart = range.upperBound
        }
        return cleaned.count > 120 ? String(cleaned.prefix(120)) + "…" : cleaned
    }
}

// MARK: - Ground calendar week (Sunday–Saturday)
// Explicit Gregorian/firstWeekday=1 calendar so this is stable regardless of
// the user's locale (Calendar.current.firstWeekday varies by region and would
// otherwise drift out of sync with the fixed Sunday abstract notification).
extension Date {
    static let groundWeekCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday
        cal.timeZone = .current
        return cal
    }()

    /// Sunday 00:00 local time that begins the calendar week (Sun–Sat) containing this date.
    var startOfGroundWeek: Date {
        let cal = Date.groundWeekCalendar
        let weekday = cal.component(.weekday, from: self) // 1 = Sun ... 7 = Sat
        let day = cal.startOfDay(for: self)
        return cal.date(byAdding: .day, value: -(weekday - 1), to: day) ?? day
    }
}

extension Array where Element == Entry {
    /// Entries whose date falls in the calendar week offset by `offsetWeeks` from `reference`
    /// (0 = the week containing `reference`, -1 = the prior week, etc).
    /// Assumes `self` is already filtered to answered (non-skipped) entries.
    func inGroundWeek(offsetWeeks: Int, from reference: Date = Date()) -> [Entry] {
        let cal = Date.groundWeekCalendar
        let thisStart = reference.startOfGroundWeek
        guard let start = cal.date(byAdding: .day, value: offsetWeeks * 7, to: thisStart),
              let end = cal.date(byAdding: .day, value: 7, to: start) else { return [] }
        return filter { $0.date >= start && $0.date < end }
    }
}
