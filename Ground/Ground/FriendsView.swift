import SwiftUI
import Auth

// MARK: - Models

struct FriendProfile: Codable, Identifiable {
    let id: UUID
    let username: String?

    var handle: String { "@\(username ?? "unknown")" }
}

struct FriendshipRow: Codable, Identifiable {
    let id: UUID
    let requester_id: UUID
    let addressee_id: UUID
    let status: String
    let requester: FriendProfile
    let addressee: FriendProfile

    func otherUser(myId: UUID) -> FriendProfile {
        requester_id == myId ? addressee : requester
    }
}

struct PendingRequest: Codable, Identifiable {
    let id: UUID
    let requester_id: UUID
    let requester: FriendProfile
}

// MARK: - FriendsView

struct FriendsView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme
    @Environment(\.dismiss) var dismiss

    @State private var myUsername: String?
    @State private var usernameInput = ""
    @State private var usernameStatus: UsernameStatus = .idle

    @State private var searchQuery = ""
    @State private var searchResult: FriendProfile?
    @State private var searchStatus: SearchStatus = .idle

    @State private var friends: [FriendshipRow] = []
    @State private var pending: [PendingRequest] = []
    @State private var isLoading = true

    private var myId: UUID? { supabase.user?.id }

    enum UsernameStatus: Equatable {
        case idle, checking, taken, saved
        case error(String)
    }

    enum SearchStatus: Equatable {
        case idle, searching, found, notFound, sent, alreadyFriends
        case error(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().opacity(0.4)
            if isLoading {
                Spacer()
                ProgressView().progressViewStyle(.circular)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        usernameSection
                        if myUsername != nil {
                            addFriendSection
                            if !pending.isEmpty { pendingSection }
                            friendsSection
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 440, height: 560)
        .task { await loadAll() }
    }

    // MARK: Header

    private var headerBar: some View {
        HStack {
            Text("friends")
                .font(RFont.header(20))
                .foregroundColor(RColor.text(scheme))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(RColor.muted(scheme))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    // MARK: Username

    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("your handle")

            if let username = myUsername {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("@\(username)")
                            .font(RFont.header(16))
                            .foregroundColor(RColor.text(scheme))
                        Text("share this so friends can find you")
                            .font(RFont.mono(10))
                            .foregroundColor(RColor.muted(scheme))
                    }
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(card)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("claim your @handle so friends can find you")
                        .font(RFont.body(13).italic())
                        .foregroundColor(RColor.muted(scheme))

                    HStack(spacing: 6) {
                        Text("@")
                            .font(RFont.body(14))
                            .foregroundColor(RColor.muted(scheme))
                        TextField("username", text: $usernameInput)
                            .textFieldStyle(.plain)
                            .font(RFont.body(14))
                            .foregroundColor(RColor.text(scheme))
                            .autocorrectionDisabled()
                            .onChange(of: usernameInput) { _, _ in usernameStatus = .idle }
                            .onSubmit { Task { await claimUsername() } }
                        Spacer()
                        if case .checking = usernameStatus {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Button("claim") { Task { await claimUsername() } }
                                .buttonStyle(.plain)
                                .font(RFont.body(12).weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.rMint))
                                .disabled(usernameInput.trimmingCharacters(in: .whitespaces).count < 3)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10).fill(RColor.input(scheme))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(RColor.border(scheme), lineWidth: 1))
                    )

                    if case .taken = usernameStatus {
                        statusText("already taken — try another", color: .rOrange)
                    } else if case .error(let msg) = usernameStatus {
                        statusText(msg, color: .rOrange)
                    } else {
                        statusText("3–20 chars, letters, numbers, underscores", color: RColor.muted(scheme).opacity(0.6))
                    }
                }
                .padding(14)
                .background(card)
            }
        }
    }

    // MARK: Add Friend

    private var addFriendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("add a friend")

            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text("@")
                        .font(RFont.body(14))
                        .foregroundColor(RColor.muted(scheme))
                    TextField("their handle", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(RFont.body(14))
                        .foregroundColor(RColor.text(scheme))
                        .autocorrectionDisabled()
                        .onChange(of: searchQuery) { _, _ in
                            searchStatus = .idle
                            searchResult = nil
                        }
                        .onSubmit { Task { await searchUser() } }
                    Spacer()
                    if case .searching = searchStatus {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Button("find") { Task { await searchUser() } }
                            .buttonStyle(.plain)
                            .font(RFont.body(12).weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.rBlue))
                            .disabled(searchQuery.trimmingCharacters(in: .whitespaces).count < 2)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10).fill(RColor.input(scheme))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(RColor.border(scheme), lineWidth: 1))
                )

                if let result = searchResult, case .found = searchStatus {
                    HStack {
                        Text(result.handle)
                            .font(RFont.body(14).weight(.medium))
                            .foregroundColor(RColor.text(scheme))
                        Spacer()
                        Button("send request") { Task { await sendRequest(to: result) } }
                            .buttonStyle(.plain)
                            .font(RFont.body(12).weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.rMint))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10).fill(RColor.input(scheme))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rMint.opacity(0.35), lineWidth: 1))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Group {
                    if case .notFound = searchStatus {
                        statusText("no user found with that handle", color: RColor.muted(scheme))
                    } else if case .sent = searchStatus {
                        statusText("friend request sent", color: .rMint)
                    } else if case .alreadyFriends = searchStatus {
                        statusText("already friends", color: RColor.muted(scheme))
                    } else if case .error(let msg) = searchStatus {
                        statusText(msg, color: .rOrange)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: searchStatus)
            }
        }
    }

    // MARK: Pending Requests

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("requests (\(pending.count))")

            VStack(spacing: 8) {
                ForEach(pending) { req in
                    HStack {
                        Text(req.requester.handle)
                            .font(RFont.body(14))
                            .foregroundColor(RColor.text(scheme))
                        Spacer()
                        Button("decline") { Task { await respond(to: req, accept: false) } }
                            .buttonStyle(.plain)
                            .font(RFont.body(12))
                            .foregroundColor(RColor.muted(scheme))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(RColor.input(scheme)))

                        Button("accept") { Task { await respond(to: req, accept: true) } }
                            .buttonStyle(.plain)
                            .font(RFont.body(12).weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.rMint))
                    }
                    .padding(12)
                    .background(card)
                }
            }
        }
    }

    // MARK: Friends List

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(friends.isEmpty ? "friends" : "friends (\(friends.count))")

            if friends.isEmpty {
                Text("add a friend above to get started")
                    .font(RFont.body(13).italic())
                    .foregroundColor(RColor.muted(scheme).opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(20)
            } else {
                VStack(spacing: 6) {
                    ForEach(friends) { friendship in
                        if let myId {
                            let other = friendship.otherUser(myId: myId)
                            HStack {
                                Text(other.handle)
                                    .font(RFont.body(14))
                                    .foregroundColor(RColor.text(scheme))
                                Spacer()
                                Button { Task { await removeFriend(friendship) } } label: {
                                    Image(systemName: "person.fill.xmark")
                                        .font(.system(size: 11))
                                        .foregroundColor(RColor.muted(scheme).opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(card)
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private var card: some View {
        RoundedRectangle(cornerRadius: 12).fill(RColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(RColor.border(scheme), lineWidth: 1))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(RFont.mono(10))
            .foregroundColor(RColor.muted(scheme))
            .textCase(.uppercase)
            .tracking(2)
    }

    private func statusText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(RFont.mono(10))
            .foregroundColor(color)
    }

    // MARK: Actions

    private func loadAll() async {
        isLoading = true
        async let profile = supabase.fetchProfile()
        async let fetchedFriends = supabase.fetchFriends()
        async let fetchedPending = supabase.fetchPendingRequests()
        myUsername = await profile?.username
        friends = (try? await fetchedFriends) ?? []
        pending = (try? await fetchedPending) ?? []
        isLoading = false
    }

    private func claimUsername() async {
        let clean = usernameInput.lowercased().trimmingCharacters(in: .whitespaces)
        guard clean.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil else {
            usernameStatus = .error("3–20 chars, letters, numbers, underscores only")
            return
        }
        usernameStatus = .checking
        do {
            let taken = try await supabase.isUsernameTaken(clean)
            if taken {
                usernameStatus = .taken
            } else {
                try await supabase.setUsername(clean)
                myUsername = clean
                usernameStatus = .saved
            }
        } catch {
            usernameStatus = .error(error.localizedDescription)
        }
    }

    private func searchUser() async {
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        searchStatus = .searching
        searchResult = nil
        do {
            if let found = try await supabase.searchUser(username: query) {
                if let myId, friends.contains(where: { $0.otherUser(myId: myId).id == found.id }) {
                    searchStatus = .alreadyFriends
                } else if pending.contains(where: { $0.requester_id == found.id }) {
                    searchStatus = .alreadyFriends
                } else {
                    searchResult = found
                    searchStatus = .found
                }
            } else {
                searchStatus = .notFound
            }
        } catch {
            searchStatus = .error(error.localizedDescription)
        }
    }

    private func sendRequest(to user: FriendProfile) async {
        do {
            try await supabase.sendFriendRequest(to: user.id)
            withAnimation { searchStatus = .sent }
            searchResult = nil
            searchQuery = ""
        } catch {
            searchStatus = .error("couldn't send request")
        }
    }

    private func respond(to request: PendingRequest, accept: Bool) async {
        do {
            try await supabase.respondToRequest(request.id, accept: accept)
            await loadAll()
        } catch { }
    }

    private func removeFriend(_ friendship: FriendshipRow) async {
        do {
            try await supabase.removeFriend(friendship.id)
            withAnimation { friends.removeAll { $0.id == friendship.id } }
        } catch { }
    }
}
