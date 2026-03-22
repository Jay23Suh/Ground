import Foundation

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

    var wordCount: Int {
        answer?.split(separator: " ").count ?? 0
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
}
