import Foundation
import Combine
import SwiftUI

struct Quote: Codable, Identifiable {
    var id: String { q }
    let q: String
    let a: String
}

@MainActor
class QuoteService: ObservableObject {
    static let shared = QuoteService()

    private let zenQuotesURL = URL(string: "https://zenquotes.io/api/today")!
    private let cacheKey = "ground_quote_cache"

    @Published var currentQuote: Quote?

    private init() {}

    func getQuoteOfTheDay() async -> Quote {
        let today = ISO8601DateFormatter().string(from: Date()).components(separatedBy: "T")[0]

        if let cachedData = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(QuoteCache.self, from: cachedData),
           cached.date == today {
            currentQuote = cached.quote
            return cached.quote
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: zenQuotesURL)
            if let quotes = try? JSONDecoder().decode([Quote].self, from: data), let quote = quotes.first {
                saveToCache(quote: quote, date: today)
                currentQuote = quote
                return quote
            }
        } catch {
            print("Failed to fetch quote: \(error)")
        }

        let fallback = Quote(q: "Stay grounded.", a: "Ground")
        currentQuote = fallback
        return fallback
    }

    func shouldShowModal(profile: Profile?) -> Bool {
        guard let profile = profile else { return false }

        let now = Date()
        let calendar = Calendar.current
        let components = (profile.quote_start_time ?? "06:00:00").components(separatedBy: ":")
        let hours = Int(components[0]) ?? 6
        let minutes = components.count > 1 ? Int(components[1]) ?? 0 : 0

        var referencePoint = calendar.startOfDay(for: now)
        referencePoint = calendar.date(bySettingHour: hours, minute: minutes, second: 0, of: referencePoint) ?? referencePoint
        if now < referencePoint {
            referencePoint = calendar.date(byAdding: .day, value: -1, to: referencePoint) ?? referencePoint
        }

        if let lastShownStr = profile.last_quote_shown_at,
           let lastShown = ISO8601DateFormatter().date(from: lastShownStr) {
            return lastShown < referencePoint
        }
        return true
    }

    private func saveToCache(quote: Quote, date: String) {
        if let encoded = try? JSONEncoder().encode(QuoteCache(date: date, quote: quote)) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }

    struct QuoteCache: Codable {
        let date: String
        let quote: Quote
    }
}

struct Profile: Codable {
    let id: UUID
    let quote_start_time: String?
    let last_quote_shown_at: String?
}
