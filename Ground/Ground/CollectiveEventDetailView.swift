import SwiftUI
import Auth

struct CollectiveEventDetailView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme

    let event: CollectiveEvent
    let onBack: () -> Void

    @State private var allPerspectives: [CollectivePerspective] = []
    @State private var content = ""
    @State private var isSubmitted = false
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?
    @State private var showPlacePicker = false
    @FocusState private var editorFocused: Bool

    private var myId: UUID? { supabase.user?.id }

    // Place is local-only (per-person, never synced) — see SupabaseManager.setCollectivePlace.
    private var placeBinding: Binding<String?> {
        Binding(
            get: { supabase.collectiveLocalPlaces[event.id] },
            set: { supabase.setCollectivePlace(event.id, place: $0) }
        )
    }

    private var submittedCount: Int { allPerspectives.filter { $0.submitted }.count }

    private var otherPerspectives: [CollectivePerspective] {
        guard isSubmitted, let myId else { return [] }
        return allPerspectives.filter { $0.user_id != myId && $0.submitted }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header — same pattern as NoteEditorView
            HStack {
                Button {
                    Task {
                        saveTask?.cancel()
                        if !isSubmitted { await saveDraft() }
                        onBack()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .medium))
                        Text("memories")
                            .font(RFont.body(13))
                    }
                    .foregroundColor(RColor.muted(scheme))
                }
                .buttonStyle(.plain)

                Spacer()

                if submittedCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(submittedCount) wrote")
                            .font(RFont.mono(10))
                    }
                    .foregroundColor(.rMint)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .overlay(Divider().opacity(0.4), alignment: .bottom)

            if isLoading {
                Spacer()
                ProgressView().progressViewStyle(.circular)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // Event title + date
                        VStack(alignment: .leading, spacing: 8) {
                            Text(event.title)
                                .font(RFont.header(24))
                                .foregroundColor(RColor.text(scheme))
                            HStack(spacing: 8) {
                                if let date = event.displayDate {
                                    Text(date)
                                        .font(RFont.mono(11))
                                        .foregroundColor(RColor.muted(scheme))
                                }
                                Button { showPlacePicker.toggle() } label: {
                                    Text(placeBinding.wrappedValue ?? "set place")
                                        .font(RFont.mono(10))
                                        .foregroundColor(placeBinding.wrappedValue != nil ? .rMint : RColor.muted(scheme))
                                        .tracking(1)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: 6).fill(RColor.card(scheme))
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(RColor.border(scheme), lineWidth: 1)))
                                }
                                .buttonStyle(.plain)
                                .popover(isPresented: $showPlacePicker, arrowEdge: .bottom) {
                                    PlacePickerPopover(place: placeBinding) {}
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        .padding(.bottom, 20)

                        Divider().opacity(0.3)

                        // Write area
                        VStack(alignment: .leading, spacing: 14) {
                            Text(isSubmitted ? "your memory" : "what do you remember?")
                                .font(isSubmitted ? RFont.mono(10).uppercaseSmallCaps() : RFont.body(13).italic())
                                .foregroundColor(isSubmitted
                                    ? RColor.muted(scheme).opacity(0.7)
                                    : RColor.muted(scheme))
                                .tracking(isSubmitted ? 2 : 0)
                                .padding(.top, 20)

                            TextEditor(text: $content)
                                .font(RFont.body(16))
                                .foregroundColor(RColor.text(scheme))
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .frame(minHeight: 160)
                                .focused($editorFocused)
                                .disabled(isSubmitted)
                                .onChange(of: content) { _, _ in
                                    if !isSubmitted { scheduleSave() }
                                }

                            if !isSubmitted {
                                Button { Task { await submit() } } label: {
                                    Group {
                                        if isSaving {
                                            ProgressView().scaleEffect(0.8)
                                        } else {
                                            Text("submit")
                                                .font(RFont.body(14).weight(.semibold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(
                                        content.trimmingCharacters(in: .whitespaces).isEmpty
                                            ? Color.rMint.opacity(0.4) : Color.rMint
                                    ))
                                }
                                .buttonStyle(.plain)
                                .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)

                                Text("once you submit, you'll see what others remember")
                                    .font(RFont.mono(10))
                                    .foregroundColor(RColor.muted(scheme).opacity(0.55))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding(.horizontal, 32)

                        // Others' perspectives
                        if isSubmitted {
                            if otherPerspectives.isEmpty {
                                Text("waiting for others to write their memories…")
                                    .font(RFont.body(13).italic())
                                    .foregroundColor(RColor.muted(scheme).opacity(0.6))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.horizontal, 32)
                                    .padding(.top, 40)
                            } else {
                                Divider().opacity(0.3).padding(.top, 32)

                                Text("others remember")
                                    .font(RFont.mono(10))
                                    .foregroundColor(RColor.muted(scheme).opacity(0.7))
                                    .tracking(2)
                                    .padding(.horizontal, 32)
                                    .padding(.top, 20)
                                    .padding(.bottom, 12)

                                ForEach(otherPerspectives) { p in
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text(p.author?.handle ?? "@unknown")
                                                .font(RFont.mono(10))
                                                .foregroundColor(.rMint)
                                            Spacer()
                                            Menu {
                                                Button("report this perspective", role: .destructive) {
                                                    Task { try? await supabase.reportContent(
                                                        reportedUserId: p.user_id,
                                                        contentType: "perspective",
                                                        contentId: p.id
                                                    )}
                                                }
                                                Button("block \(p.author?.handle ?? "user")", role: .destructive) {
                                                    Task { try? await supabase.blockUser(p.user_id) }
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(RColor.muted(scheme).opacity(0.4))
                                            }
                                            .menuStyle(.borderlessButton)
                                            .fixedSize()
                                        }
                                        Text(p.content)
                                            .font(RFont.body(15))
                                            .foregroundColor(RColor.text(scheme))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12).fill(RColor.card(scheme))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(RColor.border(scheme), lineWidth: 1))
                                    )
                                    .padding(.horizontal, 32)
                                    .padding(.bottom, 10)
                                }
                            }
                        }

                        Spacer().frame(height: 48)
                    }
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        allPerspectives = (try? await supabase.fetchCollectivePerspectives(eventId: event.id)) ?? []
        if let myId, let mine = allPerspectives.first(where: { $0.user_id == myId }) {
            content = mine.content
            isSubmitted = mine.submitted
        }
        isLoading = false
        if !isSubmitted { editorFocused = true }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await saveDraft()
        }
    }

    private func saveDraft() async {
        guard !isSubmitted else { return }
        try? await supabase.saveCollectivePerspective(eventId: event.id, content: content, submitted: false)
    }

    private func submit() async {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSaving = true
        saveTask?.cancel()
        do {
            try await supabase.saveCollectivePerspective(eventId: event.id, content: content, submitted: true)
            isSubmitted = true
            allPerspectives = (try? await supabase.fetchCollectivePerspectives(eventId: event.id)) ?? []
        } catch {
            print("submit perspective error:", error)
        }
        isSaving = false
    }
}
