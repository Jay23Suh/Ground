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
}
