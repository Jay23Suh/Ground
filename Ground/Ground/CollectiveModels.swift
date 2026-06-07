import Foundation

struct CollectiveEvent: Codable, Identifiable {
    let id: UUID
    let title: String
    let event_date: String?
    let created_by: UUID
    let created_at: String

    var displayDate: String? {
        guard let ds = event_date else { return nil }
        let parts = ds.split(separator: "-")
        guard parts.count == 3,
              let m = Int(parts[1]), let d = Int(parts[2]),
              m >= 1, m <= 12 else { return nil }
        let name = Calendar.current.monthSymbols[m - 1]
        return "\(name) \(d), \(parts[0])"
    }
}

struct CollectivePerspective: Codable, Identifiable {
    let id: UUID
    let event_id: UUID
    let user_id: UUID
    var content: String
    var submitted: Bool
    let updated_at: String
    let author: FriendProfile?
}
