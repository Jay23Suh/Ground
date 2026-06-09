import Foundation

struct Note: Codable, Identifiable {
    let id: UUID
    let user_id: String
    var content: String
    var year: Int?
    var month: Int?
    var day: Int?
    var place: String?
    var collective_event_id: UUID?
    let created_at: String
    var updated_at: String

    var preview: String {
        let first = content
            .components(separatedBy: "\n")
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            ?? ""
        return first.isEmpty ? "empty note" : String(first.prefix(80))
    }

    var wordCount: Int { content.wordCount }

    var displayDate: String {
        guard let y = year else { return "undated" }
        guard let m = month else { return "\(y)" }
        let name = Calendar.current.shortMonthSymbols[m - 1]
        guard let d = day else { return "\(name) \(y)" }
        return "\(name) \(d), \(y)"
    }

    var displayMeta: String? {
        let hasDate = year != nil
        let p = place
        switch (hasDate, p) {
        case (true, let pl?): return "\(displayDate) · \(pl)"
        case (true, nil):     return displayDate
        case (false, let pl?): return pl
        case (false, nil):    return nil
        }
    }

    // Descending sort: most recent year/month/day first; undated last
    var sortKey: Int {
        let y = year ?? 0
        let m = month ?? 0
        let d = day ?? 0
        return y * 10000 + m * 100 + d
    }
}
