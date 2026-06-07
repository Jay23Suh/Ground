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

    private let zenQuotesURL = URL(string: "https://zenquotes.io/api/random")!
    private let cacheKey = "ground_quote_cache"

    @Published var currentQuote: Quote?

    private init() {}

    private func localDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    func getQuoteOfTheDay() async -> Quote {
        let today = localDateString()

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


    func shouldShowToday() -> Bool {
        UserDefaults.standard.string(forKey: "ground_quote_last_shown") != localDateString()
    }

    func markShownToday() {
        UserDefaults.standard.set(localDateString(), forKey: "ground_quote_last_shown")
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
    let username: String?
}
