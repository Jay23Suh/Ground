import Foundation
import Combine
import Supabase

@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    let client = SupabaseClient(
        supabaseURL: URL(string: "https://opilhmterqutsdgdasjz.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9waWxobXRlcnF1dHNkZ2Rhc2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzNjM4OTUsImV4cCI6MjA4ODkzOTg5NX0.yC2ajoHQyo3gCEDXgDenxOj5juwbbxFqK1R78s55JTI"
    )

    @Published var user: User?

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
        } catch {
            user = nil
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        let session = try await client.auth.signIn(email: email, password: password)
        user = session.user
    }

    func signUp(name: String, email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        let session = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["name": .string(name)]
        )
        user = session.user
    }

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    func signOut() async throws {
        try await client.auth.signOut()
        user = nil
    }

    func saveEntry(question: String, category: String, answer: String) async throws {
        guard let uid = user?.id else { return }
        struct Entry: Encodable {
            let user_id: String
            let question: String
            let category: String
            let answer: String
            let skipped: Bool
        }
        try await client.from("journal_entries")
            .insert(Entry(user_id: uid.uuidString, question: question, category: category, answer: answer, skipped: false))
            .execute()
        try await updateActivity(uid: uid)
    }

    func saveSkip(question: String, category: String) async throws {
        guard let uid = user?.id else { return }
        struct Skip: Encodable {
            let user_id: String
            let question: String
            let category: String
            let answer: String?
            let skipped: Bool
        }
        try await client.from("journal_entries")
            .insert(Skip(user_id: uid.uuidString, question: question, category: category, answer: nil, skipped: true))
            .execute()
        try await updateActivity(uid: uid)
    }

    func fetchEntries() async throws -> [Entry] {
        guard let uid = user?.id else { return [] }
        let response: [Entry] = try await client
            .from("journal_entries")
            .select()
            .eq("user_id", value: uid.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }

    private func updateActivity(uid: UUID) async throws {
        struct Activity: Encodable {
            let user_id: String
            let last_popup_shown: String
        }
        try await client.from("activity_tracker")
            .upsert(Activity(user_id: uid.uuidString, last_popup_shown: ISO8601DateFormatter().string(from: Date())))
            .execute()
    }
}
