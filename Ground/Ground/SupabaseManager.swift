import Foundation
import Combine
import Supabase
import NaturalLanguage
import UserNotifications

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

    private static let isoFormatter = ISO8601DateFormatter()
    private var backfillRanThisSession = false

    let client: SupabaseClient = {
        let info = Bundle.main.infoDictionary
        let urlStr = info?["SUPABASE_URL"]      as? String ?? ""
        let key    = info?["SUPABASE_ANON_KEY"] as? String ?? ""
        let parsedURL = URL(string: urlStr)
        let resolvedURL = (parsedURL?.host != nil)
            ? parsedURL!
            : URL(string: "https://opilhmterqutsdgdasjz.supabase.co")!
        let resolvedKey = key.isEmpty
            ? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9waWxobXRlcnF1dHNkZ2Rhc2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzNjM4OTUsImV4cCI6MjA4ODkzOTg5NX0.yC2ajoHQyo3gCEDXgDenxOj5juwbbxFqK1R78s55JTI"
            : key
        return SupabaseClient(supabaseURL: resolvedURL, supabaseKey: resolvedKey)
    }()

    @Published var user: User?
    @Published var sessionRestored = false
    @Published var collectiveBadge: Int = 0

    var userName: String? {
        (user?.userMetadata["name"]?.value as? String)
            ?? user?.email?.components(separatedBy: "@").first
    }
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var sessionRestoreTask: Task<Void, Never>?

    private init() {
        sessionRestoreTask = Task { await restoreSession() }
    }

    func waitForSessionRestore() async {
        await sessionRestoreTask?.value
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

    func deleteAccount() async throws {
        try await client.rpc("delete_account").execute()
        try await client.auth.signOut()
        user = nil
    }

    func reportContent(reportedUserId: UUID, contentType: String, contentId: UUID?) async throws {
        guard let uid = user?.id else { throw SupabaseManagerError.notSignedIn }
        struct ReportInsert: Encodable {
            let reporter_id: String
            let reported_user_id: String
            let content_type: String
            let content_id: String?
        }
        try await client.from("reports")
            .insert(ReportInsert(
                reporter_id: uid.uuidString,
                reported_user_id: reportedUserId.uuidString,
                content_type: contentType,
                content_id: contentId?.uuidString
            ))
            .execute()
    }

    func blockUser(_ userId: UUID) async throws {
        guard let uid = user?.id else { throw SupabaseManagerError.notSignedIn }
        struct BlockInsert: Encodable { let blocker_id: String; let blocked_id: String }
        try await client.from("blocks")
            .insert(BlockInsert(blocker_id: uid.uuidString, blocked_id: userId.uuidString))
            .execute()
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
        let now = SupabaseManager.isoFormatter.string(from: Date())
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
            let place: String?; let collective_event_id: String?; let updated_at: String
        }
        try await client
            .from("notes")
            .update(NoteUpdate(content: note.content, year: note.year, month: note.month,
                               day: note.day, place: note.place,
                               collective_event_id: note.collective_event_id?.uuidString,
                               updated_at: SupabaseManager.isoFormatter.string(from: Date())))
            .eq("id", value: note.id.uuidString)
            .execute()
    }

    func shareNote(noteId: UUID, noteContent: String, title: String,
                   noteDateStr: String?, addUserId: UUID, existingEventId: UUID?) async throws -> UUID {
        guard let uid = user?.id else { throw SupabaseManagerError.notSignedIn }
        let now = SupabaseManager.isoFormatter.string(from: Date())
        struct MemberInsert: Encodable { let event_id: String; let user_id: String; let invited_by: String }

        let eventId: UUID
        if let existing = existingEventId {
            eventId = existing
        } else {
            eventId = UUID()
            struct EventInsert: Encodable {
                let id: String; let title: String; let event_date: String?
                let created_by: String; let created_at: String
            }
            try await client.from("collective_events")
                .insert(EventInsert(id: eventId.uuidString, title: title,
                                    event_date: noteDateStr, created_by: uid.uuidString, created_at: now))
                .execute()

            try await client.from("collective_members")
                .insert(MemberInsert(event_id: eventId.uuidString, user_id: uid.uuidString, invited_by: uid.uuidString))
                .execute()

            try await client.from("notes")
                .update(["collective_event_id": eventId.uuidString])
                .eq("id", value: noteId.uuidString)
                .execute()

            struct PerspUpsert: Encodable {
                let event_id: String; let user_id: String
                let content: String; let submitted: Bool; let updated_at: String
            }
            try await client.from("collective_perspectives")
                .upsert(PerspUpsert(event_id: eventId.uuidString, user_id: uid.uuidString,
                                    content: noteContent, submitted: true, updated_at: now),
                        onConflict: "event_id,user_id")
                .execute()
        }

        try await client.from("collective_members")
            .insert(MemberInsert(event_id: eventId.uuidString, user_id: addUserId.uuidString, invited_by: uid.uuidString))
            .execute()

        return eventId
    }

    func backfillPlaces(in notes: [Note]) async {
        guard !backfillRanThisSession else { return }
        guard let uid = user?.id else { return }
        let candidates = notes.filter { $0.place == nil && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !candidates.isEmpty else { backfillRanThisSession = true; return }

        struct PlacePatch: Encodable, Sendable { let place: String; let updated_at: String }

        let now = SupabaseManager.isoFormatter.string(from: Date())
        await Task.detached(priority: .utility) {
            let tagger = NLTagger(tagSchemes: [.nameType])

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
        backfillRanThisSession = true
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
                    last_popup_shown: SupabaseManager.isoFormatter.string(from: Date())
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
        let now = SupabaseManager.isoFormatter.string(from: Date())
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

    // MARK: - Friends

    func isUsernameTaken(_ username: String) async throws -> Bool {
        guard let uid = user?.id else { return true }
        struct MinProfile: Codable { let id: UUID }
        let results: [MinProfile] = try await client
            .from("profiles")
            .select("id")
            .eq("username", value: username)
            .neq("id", value: uid.uuidString)
            .limit(1)
            .execute()
            .value
        return !results.isEmpty
    }

    func setUsername(_ username: String) async throws {
        guard let uid = user?.id else { throw SupabaseManagerError.notSignedIn }
        try await client.from("profiles")
            .update(["username": username])
            .eq("id", value: uid.uuidString)
            .execute()
    }

    func searchUser(username: String) async throws -> FriendProfile? {
        guard let uid = user?.id else { return nil }
        let results: [FriendProfile] = try await client
            .from("profiles")
            .select("id, username")
            .eq("username", value: username.lowercased())
            .neq("id", value: uid.uuidString)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    func sendFriendRequest(to userId: UUID) async throws {
        guard let uid = user?.id else { throw SupabaseManagerError.notSignedIn }
        struct Insert: Encodable { let requester_id: String; let addressee_id: String }
        try await client.from("friendships")
            .insert(Insert(requester_id: uid.uuidString, addressee_id: userId.uuidString))
            .execute()
    }

    func fetchFriends() async throws -> [FriendshipRow] {
        guard let uid = user?.id else { return [] }
        return try await client
            .from("friendships")
            .select("id, requester_id, addressee_id, status, requester:profiles!requester_id(id, username), addressee:profiles!addressee_id(id, username)")
            .or("requester_id.eq.\(uid.uuidString),addressee_id.eq.\(uid.uuidString)")
            .eq("status", value: "accepted")
            .execute()
            .value
    }

    func fetchPendingRequests() async throws -> [PendingRequest] {
        guard let uid = user?.id else { return [] }
        return try await client
            .from("friendships")
            .select("id, requester_id, requester:profiles!requester_id(id, username)")
            .eq("addressee_id", value: uid.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value
    }

    func respondToRequest(_ id: UUID, accept: Bool) async throws {
        if accept {
            try await client.from("friendships")
                .update(["status": "accepted"])
                .eq("id", value: id.uuidString)
                .execute()
        } else {
            try await client.from("friendships")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
        }
    }

    func removeFriend(_ friendshipId: UUID) async throws {
        try await client.from("friendships")
            .delete()
            .eq("id", value: friendshipId.uuidString)
            .execute()
    }

    // MARK: - Collective Memories

    func createCollectiveEvent(title: String, date: Date?, friendIds: [UUID]) async throws -> CollectiveEvent {
        guard let uid = user?.id else { throw SupabaseManagerError.notSignedIn }
        let id = UUID()
        let now = SupabaseManager.isoFormatter.string(from: Date())
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let dateStr = date.map { df.string(from: $0) }

        struct EventInsert: Encodable {
            let id: String; let title: String; let event_date: String?
            let created_by: String; let created_at: String
        }
        try await client.from("collective_events")
            .insert(EventInsert(id: id.uuidString, title: title, event_date: dateStr,
                                created_by: uid.uuidString, created_at: now))
            .execute()

        struct MemberInsert: Encodable { let event_id: String; let user_id: String; let invited_by: String }
        let members = ([uid] + friendIds).map {
            MemberInsert(event_id: id.uuidString, user_id: $0.uuidString, invited_by: uid.uuidString)
        }
        try await client.from("collective_members").insert(members).execute()

        return CollectiveEvent(id: id, title: title, event_date: dateStr, created_by: uid, created_at: now)
    }

    func fetchCollectiveEvents() async throws -> [CollectiveEvent] {
        guard let uid = user?.id else { return [] }
        struct MemberRow: Codable { let event_id: UUID }
        let rows: [MemberRow] = try await client
            .from("collective_members")
            .select("event_id")
            .eq("user_id", value: uid.uuidString)
            .execute()
            .value
        guard !rows.isEmpty else { return [] }
        let filter = rows.map { "id.eq.\($0.event_id.uuidString)" }.joined(separator: ",")
        return try await client
            .from("collective_events")
            .select()
            .or(filter)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchCollectivePerspectives(eventId: UUID) async throws -> [CollectivePerspective] {
        try await client
            .from("collective_perspectives")
            .select("id, event_id, user_id, content, submitted, updated_at, author:profiles!user_id(id, username)")
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value
    }

    func fetchEventMembers(eventId: UUID) async throws -> [FriendProfile] {
        struct MemberRow: Codable { let profile: FriendProfile }
        let rows: [MemberRow] = try await client
            .from("collective_members")
            .select("profile:profiles!user_id(id, username)")
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value
        return rows.map { $0.profile }
    }

    func saveCollectivePerspective(eventId: UUID, content: String, submitted: Bool) async throws {
        guard let uid = user?.id else { throw SupabaseManagerError.notSignedIn }
        let now = SupabaseManager.isoFormatter.string(from: Date())
        struct PerspectiveUpsert: Encodable {
            let event_id: String; let user_id: String
            let content: String; let submitted: Bool; let updated_at: String
        }
        try await client.from("collective_perspectives")
            .upsert(
                PerspectiveUpsert(event_id: eventId.uuidString, user_id: uid.uuidString,
                                  content: content, submitted: submitted, updated_at: now),
                onConflict: "event_id,user_id"
            )
            .execute()
    }

    func checkForNewCollectivePerspectives() async {
        guard let uid = user?.id else { return }

        let lastCheckKey = "ground.collectiveLastCheck"
        let lastCheckTS = UserDefaults.standard.double(forKey: lastCheckKey)
        let lastCheck = lastCheckTS > 0 ? Date(timeIntervalSince1970: lastCheckTS) : Date.distantPast

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)

        let events = (try? await fetchCollectiveEvents()) ?? []
        NSLog("DIAG checkForNewCollectivePerspectives events.count=\(events.count)")
        guard !events.isEmpty else { return }

        var newCount = 0
        for event in events {
            let t0 = Date()
            let perspectives = (try? await fetchCollectivePerspectives(eventId: event.id)) ?? []
            NSLog("DIAG  perspectives for event \(event.id) took \(Date().timeIntervalSince(t0))s, count=\(perspectives.count)")
            let newOnes = perspectives.filter {
                $0.user_id != uid && $0.submitted && parseISO($0.updated_at) > lastCheck
            }
            for p in newOnes {
                await fireCollectiveNotification(event: event, author: p.author)
            }
            newCount += newOnes.count
        }

        collectiveBadge += newCount
    }

    private static let isoParserFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoParserBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parseISO(_ string: String) -> Date {
        if let d = SupabaseManager.isoParserFull.date(from: string) { return d }
        return SupabaseManager.isoParserBasic.date(from: string) ?? Date.distantPast
    }

    private func fireCollectiveNotification(event: CollectiveEvent, author: FriendProfile?) async {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = "\(author?.handle ?? "a friend") added their memory"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "collective-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
