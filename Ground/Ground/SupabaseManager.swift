import Foundation
import Combine
import Supabase
import NaturalLanguage

enum SupabaseManagerError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You're no longer signed in. Please sign in again and try once more."
        }
    }
}

@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    let client = SupabaseClient(
        supabaseURL: URL(string: "https://opilhmterqutsdgdasjz.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9waWxobXRlcnF1dHNkZ2Rhc2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzNjM4OTUsImV4cCI6MjA4ODkzOTg5NX0.yC2ajoHQyo3gCEDXgDenxOj5juwbbxFqK1R78s55JTI"
    )

    @Published var user: User?
    @Published var sessionRestored = false

    var userName: String? {
        (user?.userMetadata["name"]?.value as? String)
            ?? user?.email?.components(separatedBy: "@").first
    }
    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {
        Task { await restoreSession() }
    }

    func restoreSession() async {
        do {
            let session = try await client.auth.session
            user = session.user
            errorMessage = nil
        } catch {
            user = nil
        }
        sessionRestored = true
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            user = session.user
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signUp(name: String, email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            let session = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["name": .string(name)]
            )
            user = session.user
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func resetPassword(email: String) async throws {
        do {
            try await client.auth.resetPasswordForEmail(email)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func updatePassword(_ newPassword: String) async throws {
        do {
            try await client.auth.update(user: UserAttributes(password: newPassword))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
            user = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func saveEntry(question: String, category: String, answer: String) async throws {
        guard let uid = user?.id else {
            let error = SupabaseManagerError.notSignedIn
            errorMessage = error.localizedDescription
            throw error
        }
        struct Entry: Encodable {
            let user_id: String
            let question: String
            let category: String
            let answer: String
            let skipped: Bool
        }
        do {
            try await client.from("journal_entries")
                .insert(Entry(user_id: uid.uuidString, question: question, category: category, answer: answer, skipped: false))
                .execute()
            try await updateActivity(uid: uid)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func saveSkip(question: String, category: String) async throws {
        guard let uid = user?.id else {
            let error = SupabaseManagerError.notSignedIn
            errorMessage = error.localizedDescription
            throw error
        }
        struct Skip: Encodable {
            let user_id: String
            let question: String
            let category: String
            let answer: String
            let skipped: Bool
        }
        do {
            try await client.from("journal_entries")
                .insert(Skip(user_id: uid.uuidString, question: question, category: category, answer: "", skipped: true))
                .execute()
            try await updateActivity(uid: uid)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Notes

    func fetchNotes() async throws -> [Note] {
        guard let uid = user?.id else { return [] }
        return try await client
            .from("notes")
            .select()
            .eq("user_id", value: uid.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createNote() async throws -> Note {
        guard let uid = user?.id else { throw SupabaseManagerError.notSignedIn }
        let now = ISO8601DateFormatter().string(from: Date())
        let id = UUID()
        struct InsertNote: Encodable {
            let id: String; let user_id: String; let content: String
            let created_at: String; let updated_at: String
        }
        try await client
            .from("notes")
            .insert(InsertNote(id: id.uuidString, user_id: uid.uuidString, content: "",
                               created_at: now, updated_at: now))
            .execute()
        return Note(id: id, user_id: uid.uuidString, content: "",
                    year: nil, month: nil, day: nil, created_at: now, updated_at: now)
    }

    func updateNote(_ note: Note) async throws {
        struct NoteUpdate: Encodable {
            let content: String; let year: Int?; let month: Int?; let day: Int?
            let place: String?; let updated_at: String
        }
        try await client
            .from("notes")
            .update(NoteUpdate(content: note.content, year: note.year, month: note.month,
                               day: note.day, place: note.place,
                               updated_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: note.id.uuidString)
            .execute()
    }

    func backfillPlaces(in notes: [Note]) async {
        guard let uid = user?.id else { return }
        let candidates = notes.filter { $0.place == nil && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !candidates.isEmpty else { return }

        struct PlacePatch: Encodable, Sendable { let place: String; let updated_at: String }

        await Task.detached(priority: .utility) {
            let tagger = NLTagger(tagSchemes: [.nameType])
            let now = ISO8601DateFormatter().string(from: Date())

            for note in candidates {
                tagger.string = note.content
                var detected: String? = nil
                tagger.enumerateTags(in: note.content.startIndex..<note.content.endIndex,
                                     unit: .word, scheme: .nameType) { tag, range in
                    guard tag == .placeName else { return true }
                    let token = String(note.content[range])
                    if token.count >= 4 { detected = token.lowercased() }
                    return detected == nil
                }
                guard let place = detected else { continue }
                try? await self.client
                    .from("notes")
                    .update(PlacePatch(place: place, updated_at: now))
                    .eq("id", value: note.id.uuidString)
                    .eq("user_id", value: uid.uuidString)
                    .execute()
            }
        }.value
    }

    func deleteNote(id: UUID) async throws {
        try await client.from("notes").delete().eq("id", value: id.uuidString).execute()
    }

    // MARK: - Entries

    func fetchEntries() async throws -> [Entry] {
        guard let uid = user?.id else { return [] }
        do {
            let response: [Entry] = try await client
                .from("journal_entries")
                .select()
                .eq("user_id", value: uid.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            errorMessage = nil
            return response
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func updateActivity(uid: UUID) async throws {
        struct Activity: Encodable {
            let user_id: String
            let last_popup_shown: String
        }
        try await client.from("activity_tracker")
            .upsert(
                Activity(
                    user_id: uid.uuidString,
                    last_popup_shown: ISO8601DateFormatter().string(from: Date())
                ),
                onConflict: "user_id"
            )
            .execute()
    }

    func fetchProfile() async -> Profile? {
        guard let uid = user?.id else { return nil }
        do {
            let profile: Profile = try await client
                .from("profiles")
                .select()
                .eq("id", value: uid.uuidString)
                .single()
                .execute()
                .value
            return profile
        } catch {
            print("Error fetching profile: \(error)")
            return nil
        }
    }

    func updateLastQuoteShown() async {
        guard let uid = user?.id else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        do {
            try await client.from("profiles")
                .update(["last_quote_shown_at": now])
                .eq("id", value: uid.uuidString)
                .execute()
        } catch {
            print("Error updating last quote shown: \(error)")
        }
    }

    func updateProfile(startTime: String) async throws {
        guard let uid = user?.id else { return }
        try await client.from("profiles")
            .update(["quote_start_time": startTime])
            .eq("id", value: uid.uuidString)
            .execute()
    }
}
