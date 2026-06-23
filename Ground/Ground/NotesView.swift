import SwiftUI
import Auth

// MARK: - MemoryItem (unifies personal notes and shared memories into one timeline)

private enum MemoryItem: Identifiable {
    case note(Note)
    case shared(CollectiveEvent)

    var id: String {
        switch self {
        case .note(let n):   return "n-\(n.id.uuidString)"
        case .shared(let e): return "s-\(e.id.uuidString)"
        }
    }

    private static func dateParts(_ ds: String?) -> (year: Int?, month: Int?, day: Int?) {
        guard let ds else { return (nil, nil, nil) }
        let parts = ds.split(separator: "-")
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else {
            return (nil, nil, nil)
        }
        return (y, m, d)
    }

    var year: Int? {
        switch self {
        case .note(let n):   return n.year
        case .shared(let e): return Self.dateParts(e.event_date).year
        }
    }

    var month: Int? {
        switch self {
        case .note(let n):   return n.month
        case .shared(let e): return Self.dateParts(e.event_date).month
        }
    }

    var sortKey: Int {
        let parts: (year: Int?, month: Int?, day: Int?)
        switch self {
        case .note(let n):   parts = (n.year, n.month, n.day)
        case .shared(let e): parts = Self.dateParts(e.event_date)
        }
        return (parts.year ?? 0) * 10000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }
}

// MARK: - Grouping helpers

private struct MonthGroup: Identifiable {
    let id: String
    let monthLabel: String?
    let items: [MemoryItem]
}

private struct YearGroup: Identifiable {
    let id: String
    let yearLabel: String
    let monthGroups: [MonthGroup]
}

private func groupItems(_ items: [MemoryItem]) -> [YearGroup] {
    let sorted = items.sorted { $0.sortKey > $1.sortKey }

    var byYear: [String: [MemoryItem]] = [:]
    for item in sorted {
        let key = item.year.map { "\($0)" } ?? "undated"
        byYear[key, default: []].append(item)
    }

    let cal = Calendar.current
    let monthSymbols = cal.shortMonthSymbols

    func monthGroups(for items: [MemoryItem]) -> [MonthGroup] {
        var byMonth: [Int: [MemoryItem]] = [:]
        var noMonth: [MemoryItem] = []
        for item in items {
            if let m = item.month { byMonth[m, default: []].append(item) }
            else { noMonth.append(item) }
        }
        var groups: [MonthGroup] = []
        for m in stride(from: 12, through: 1, by: -1) {
            if let its = byMonth[m] {
                groups.append(MonthGroup(id: "\(m)", monthLabel: monthSymbols[m - 1], items: its))
            }
        }
        if !noMonth.isEmpty {
            groups.append(MonthGroup(id: "none", monthLabel: nil, items: noMonth))
        }
        return groups
    }

    var yearGroups: [YearGroup] = []
    let years = byYear.keys.filter { $0 != "undated" }.sorted(by: >)
    for y in years {
        yearGroups.append(YearGroup(id: y, yearLabel: y, monthGroups: monthGroups(for: byYear[y]!)))
    }
    if let undated = byYear["undated"] {
        yearGroups.append(YearGroup(id: "undated", yearLabel: "undated", monthGroups: monthGroups(for: undated)))
    }
    return yearGroups
}

// MARK: - Flat section model for LazyVStack

private enum FlatSection: Identifiable {
    case yearHeader(YearGroup)
    case monthHeader(yearId: String, MonthGroup)
    case memoryItem(yearId: String, monthId: String, MemoryItem)

    var id: String {
        switch self {
        case .yearHeader(let g):             return "y-\(g.id)"
        case .monthHeader(let y, let m):     return "m-\(y)-\(m.id)"
        case .memoryItem(let y, let m, let i): return "i-\(y)-\(m)-\(i.id)"
        }
    }
}

private func flatSections(from groups: [YearGroup]) -> [FlatSection] {
    var result: [FlatSection] = []
    for group in groups {
        result.append(.yearHeader(group))
        for mGroup in group.monthGroups {
            if mGroup.monthLabel != nil {
                result.append(.monthHeader(yearId: group.id, mGroup))
            }
            for item in mGroup.items {
                result.append(.memoryItem(yearId: group.id, monthId: mGroup.id, item))
            }
        }
    }
    return result
}

// MARK: - NotesView

struct NotesView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme
    @State private var notes: [Note] = []
    @State private var loading = true
    @State private var editingNote: Note? = nil
    @State private var debugError: String = ""
    @State private var selectedPlace: String? = nil
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchDebounceTask: Task<Void, Never>?

    @State private var selectedCollectiveEvent: CollectiveEvent?
    @State private var collectiveEvents: [CollectiveEvent] = []
    @State private var collectiveActivity: [UUID: Date] = [:]

    @State private var visibleYears: Set<String> = []
    @State private var visibleMonthKeys: Set<String> = []
    @State private var drillYear: String? = nil

    private var myId: UUID? { supabase.user?.id }

    private var activeYear: String? {
        visibleYears.compactMap { Int($0) }.max().map { String($0) }
    }

    private var activeMonthKey: String? {
        visibleMonthKeys
            .compactMap { key -> (String, Int)? in
                let p = key.split(separator: "-")
                guard p.count == 2, let y = Int(p[0]), let m = Int(p[1]) else { return nil }
                return (key, y * 100 + m)
            }
            .max(by: { $0.1 < $1.1 })?
            .0
    }

    // All items, deduped: a note that's been shared is represented once, as its CollectiveEvent.
    private var allItems: [MemoryItem] {
        notes.filter { $0.collective_event_id == nil }.map(MemoryItem.note)
            + collectiveEvents.map(MemoryItem.shared)
    }

    private var datedGroups: [YearGroup] {
        groupItems(allItems).filter { $0.id != "undated" }
    }

    // A note's place is its own field; a shared memory's place is local-only
    // (per-person, never synced) so it never reaches other members.
    private func place(for item: MemoryItem) -> String? {
        switch item {
        case .note(let n):   return n.place
        case .shared(let e): return supabase.collectiveLocalPlaces[e.id]
        }
    }

    private var places: [String] {
        Array(Set(allItems.compactMap(place(for:)))).sorted()
    }

    private var filteredItems: [MemoryItem] {
        var result = selectedPlace == nil ? allItems : allItems.filter { place(for: $0) == selectedPlace }
        let q = debouncedSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return result }
        let parsed = parseSearchQuery(q)
        if let kw = parsed.keyword {
            result = result.filter { item in
                switch item {
                case .note(let n):   return n.content.lowercased().contains(kw.lowercased())
                case .shared(let e): return e.title.lowercased().contains(kw.lowercased())
                }
            }
        }
        if let y = parsed.year  { result = result.filter { $0.year  == y } }
        if let m = parsed.month { result = result.filter { $0.month == m } }
        return result
    }

    private func activityDate(_ event: CollectiveEvent) -> Date {
        collectiveActivity[event.id] ?? supabase.parseISO(event.created_at)
    }

    private func isUnread(_ event: CollectiveEvent) -> Bool {
        let defaultSeen = event.created_by == myId ? supabase.parseISO(event.created_at) : Date.distantPast
        let lastSeen = supabase.collectiveSeenAt[event.id] ?? defaultSeen
        return activityDate(event) > lastSeen
    }

    // Shared memories with unseen activity float to the top, above the dated timeline.
    private var unreadSharedItems: [MemoryItem] {
        filteredItems
            .compactMap { item -> (MemoryItem, CollectiveEvent)? in
                guard case .shared(let e) = item, isUnread(e) else { return nil }
                return (item, e)
            }
            .sorted { activityDate($0.1) > activityDate($1.1) }
            .map { $0.0 }
    }

    private var remainingItems: [MemoryItem] {
        let pinnedIds = Set(unreadSharedItems.map { $0.id })
        return filteredItems.filter { !pinnedIds.contains($0.id) }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(RColor.border(scheme))
            .frame(height: 1.5)
    }

    private func parseSearchQuery(_ raw: String) -> (keyword: String?, year: Int?, month: Int?) {
        let monthMap: [String: Int] = [
            "january":1,"february":2,"march":3,"april":4,"may":5,"june":6,
            "july":7,"august":8,"september":9,"october":10,"november":11,"december":12,
            "jan":1,"feb":2,"mar":3,"apr":4,"jun":6,"jul":7,"aug":8,
            "sep":9,"sept":9,"oct":10,"nov":11,"dec":12
        ]
        var year: Int? = nil
        var month: Int? = nil
        var keyTokens: [String] = []
        for token in raw.lowercased().components(separatedBy: .whitespacesAndNewlines) where !token.isEmpty {
            if let y = Int(token), y >= 1900, y <= 2100 { year = y }
            else if let m = monthMap[token]              { month = m }
            else                                         { keyTokens.append(token) }
        }
        let kw = keyTokens.joined(separator: " ")
        return (kw.isEmpty ? nil : kw, year, month)
    }

    var body: some View {
        Group {
            if let note = editingNote {
                NoteEditorView(note: note) { result in
                    switch result {
                    case .saved(let updated):
                        if let idx = notes.firstIndex(where: { $0.id == updated.id }) {
                            notes[idx] = updated
                        } else {
                            notes.insert(updated, at: 0)
                        }
                        Task { await reloadCollectiveEvents() }
                    case .deleted:
                        notes.removeAll { $0.id == note.id }
                    }
                    editingNote = nil
                }
                .environmentObject(supabase)
            } else if let event = selectedCollectiveEvent {
                CollectiveEventDetailView(event: event) {
                    selectedCollectiveEvent = nil
                }
                .environmentObject(supabase)
            } else {
                listView
            }
        }
        .task { await loadNotes() }
    }

    private var listView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("memories")
                    .font(RFont.header(28))
                    .foregroundColor(RColor.text(scheme))
                Spacer()
                Button { Task { await newNote() } } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(RColor.text(scheme))
                        .padding(8)
                        .background(Circle().fill(RColor.card(scheme))
                            .overlay(Circle().stroke(RColor.border(scheme), lineWidth: 1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)

            sectionDivider

            SearchBar(text: $searchText, placeholder: "search by keyword, year, or month…")
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .onChange(of: searchText) { _, new in
                    searchDebounceTask?.cancel()
                    if new.isEmpty {
                        debouncedSearch = ""
                    } else {
                        searchDebounceTask = Task {
                            try? await Task.sleep(for: .milliseconds(250))
                            guard !Task.isCancelled else { return }
                            debouncedSearch = new
                        }
                    }
                }

            if !places.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(label: "all", selected: selectedPlace == nil) {
                            selectedPlace = nil
                        }
                        ForEach(places, id: \.self) { p in
                            FilterPill(label: p, selected: selectedPlace == p) {
                                selectedPlace = selectedPlace == p ? nil : p
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                }
                sectionDivider
            }

            if loading {
                Spacer()
                ProgressView().progressViewStyle(.circular).frame(maxWidth: .infinity)
                Spacer()
            } else if allItems.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Text("no memories yet")
                        .font(RFont.body(15).italic())
                        .foregroundColor(RColor.muted(scheme))
                    Text("write memories, thoughts, anything.")
                        .font(RFont.body(13))
                        .foregroundColor(RColor.muted(scheme).opacity(0.7))
                    Button("start writing") { Task { await newNote() } }
                        .buttonStyle(.plain)
                        .font(RFont.body(13))
                        .foregroundColor(.rOrange)
                        .padding(.top, 6)
                    if !debugError.isEmpty {
                        Text(debugError)
                            .font(RFont.mono(10))
                            .foregroundColor(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else if filteredItems.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Text("no memories found")
                        .font(RFont.body(15).italic())
                        .foregroundColor(RColor.muted(scheme))
                    Text("try a keyword, year, or \"march 2023\"")
                        .font(RFont.mono(10))
                        .foregroundColor(RColor.muted(scheme).opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(unreadSharedItems) { item in
                                    if case .shared(let event) = item {
                                        SharedMemoryRow(event: event, scheme: scheme,
                                                         place: supabase.collectiveLocalPlaces[event.id], isNew: true) {
                                            supabase.markCollectiveSeen(event.id)
                                            selectedCollectiveEvent = event
                                        }
                                    }
                                }

                                ForEach(flatSections(from: groupItems(remainingItems))) { section in
                                    switch section {
                                    case .yearHeader(let yearGroup):
                                        Text(yearGroup.yearLabel)
                                            .font(RFont.mono(11))
                                            .foregroundColor(RColor.muted(scheme))
                                            .tracking(3)
                                            .textCase(.uppercase)
                                            .padding(.horizontal, 24)
                                            .padding(.top, 28)
                                            .padding(.bottom, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .id("year-\(yearGroup.id)")
                                            .onAppear {
                                                if yearGroup.id != "undated" {
                                                    visibleYears.insert(yearGroup.id)
                                                }
                                            }
                                            .onDisappear {
                                                visibleYears.remove(yearGroup.id)
                                            }

                                    case .monthHeader(let yearId, let mGroup):
                                        Text(mGroup.monthLabel ?? "")
                                            .font(RFont.body(11).italic())
                                            .foregroundColor(RColor.muted(scheme).opacity(0.65))
                                            .padding(.horizontal, 24)
                                            .padding(.bottom, 4)
                                            .padding(.top, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .id("month-\(yearId)-\(mGroup.id)")
                                            .onAppear {
                                                visibleMonthKeys.insert("\(yearId)-\(mGroup.id)")
                                            }
                                            .onDisappear {
                                                visibleMonthKeys.remove("\(yearId)-\(mGroup.id)")
                                            }

                                    case .memoryItem(_, _, let item):
                                        switch item {
                                        case .note(let note):
                                            NoteRow(note: note, scheme: scheme) {
                                                editingNote = note
                                            }
                                            .contextMenu {
                                                Button("delete", role: .destructive) {
                                                    Task { await deleteNote(note) }
                                                }
                                            }
                                        case .shared(let event):
                                            SharedMemoryRow(event: event, scheme: scheme,
                                                             place: supabase.collectiveLocalPlaces[event.id]) {
                                                supabase.markCollectiveSeen(event.id)
                                                selectedCollectiveEvent = event
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 40)
                        }

                        if !datedGroups.isEmpty {
                            Divider().opacity(0.4)
                            MemoryTimelineStrip(
                                datedGroups: datedGroups,
                                drillYear: $drillYear,
                                activeYear: activeYear,
                                activeMonthKey: activeMonthKey,
                                proxy: proxy
                            )
                        }
                    }
                }
            }
        }
        .onAppear { supabase.collectiveBadge = 0 }
    }

    private func loadNotes() async {
        NSLog("DIAG NotesView.loadNotes start")
        loading = true
        notes = (try? await supabase.fetchNotes()) ?? []
        loading = false
        NSLog("DIAG NotesView.loadNotes end, count=\(notes.count)")
        Task { await supabase.backfillPlaces(in: notes) }
        Task { await reloadCollectiveEvents() }
    }

    private func reloadCollectiveEvents() async {
        NSLog("DIAG reloadCollectiveEvents start")
        let events = (try? await supabase.fetchCollectiveEvents()) ?? []
        collectiveEvents = events
        NSLog("DIAG reloadCollectiveEvents end, count=\(events.count)")
        collectiveActivity = await supabase.fetchCollectiveActivity(events: events)
    }

    private func deleteNote(_ note: Note) async {
        try? await supabase.deleteNote(id: note.id)
        notes.removeAll { $0.id == note.id }
    }

    private func newNote() async {
        debugError = ""
        do {
            let note = try await supabase.createNote()
            editingNote = note
        } catch {
            debugError = error.localizedDescription
            print("createNote error: \(error)")
        }
    }
}

// MARK: - MemoryTimelineStrip

private struct MemoryTimelineStrip: View {
    let datedGroups: [YearGroup]
    @Binding var drillYear: String?
    let activeYear: String?
    let activeMonthKey: String?
    let proxy: ScrollViewProxy
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(spacing: 0) {
            if let year = drillYear,
               let group = datedGroups.first(where: { $0.id == year }) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { drillYear = nil }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(RColor.muted(scheme))
                        .frame(width: 36, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(RColor.border(scheme))
                    .frame(width: 1, height: 16)
                    .opacity(0.6)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(group.monthGroups.filter { $0.monthLabel != nil }) { mGroup in
                            let key = "\(year)-\(mGroup.id)"
                            let isActive = activeMonthKey == key
                            Button {
                                withAnimation {
                                    proxy.scrollTo("month-\(year)-\(mGroup.id)", anchor: .top)
                                }
                            } label: {
                                Text(mGroup.monthLabel!)
                                    .font(RFont.mono(11))
                                    .foregroundColor(isActive ? .rOrange : RColor.muted(scheme))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isActive ? Color.rOrange.opacity(0.1) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(datedGroups) { yearGroup in
                            let isActive = activeYear == yearGroup.id
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { drillYear = yearGroup.id }
                                proxy.scrollTo("year-\(yearGroup.id)", anchor: .top)
                            } label: {
                                Text(yearGroup.yearLabel)
                                    .font(RFont.mono(11))
                                    .foregroundColor(isActive ? .rOrange : RColor.muted(scheme))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isActive ? Color.rOrange.opacity(0.1) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .frame(height: 40)
        .background(RColor.card(scheme))
    }
}

// MARK: - MemoryCard (shared floating-card chrome for NoteRow / SharedMemoryRow)

private struct MemoryCardChrome: ViewModifier {
    let scheme: ColorScheme
    var borderColor: Color? = nil

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(RColor.card(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor ?? RColor.border(scheme), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.22 : 0.05), radius: 6, x: 0, y: 2)
            .padding(.horizontal, 24)
            .padding(.vertical, 5)
    }
}

private extension View {
    // Padding + contentShape must live on the button's label (not wrapped on
    // afterward) so the whole padded area is actually clickable, not just the
    // intrinsic size of the inner HStack content.
    func memoryCardLabel() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
    }
}

// MARK: - NoteRow

struct NoteRow: View {
    let note: Note
    let scheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(note.preview)
                        .font(RFont.body(14))
                        .foregroundColor(RColor.text(scheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let meta = note.displayMeta {
                        Text(meta)
                            .font(RFont.mono(10))
                            .foregroundColor(RColor.muted(scheme))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(RColor.muted(scheme).opacity(0.4))
            }
            .memoryCardLabel()
        }
        .buttonStyle(.plain)
        .modifier(MemoryCardChrome(scheme: scheme))
    }
}

// MARK: - SharedMemoryRow

private struct SharedMemoryRow: View {
    let event: CollectiveEvent
    let scheme: ColorScheme
    var place: String? = nil
    var isNew: Bool = false
    let onTap: () -> Void

    private var displayMeta: String? {
        switch (event.displayDate, place) {
        case (let d?, let p?): return "\(d) · \(p)"
        case (let d?, nil):    return d
        case (nil, let p?):    return p
        case (nil, nil):       return nil
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(Color.rMint.opacity(0.18))
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.rMint)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(event.title)
                            .font(RFont.body(14))
                            .foregroundColor(RColor.text(scheme))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if isNew {
                            Circle().fill(Color.rOrange).frame(width: 6, height: 6)
                        }
                    }
                    if let meta = displayMeta {
                        Text(meta)
                            .font(RFont.mono(10))
                            .foregroundColor(RColor.muted(scheme))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(RColor.muted(scheme).opacity(0.4))
            }
            .memoryCardLabel()
        }
        .buttonStyle(.plain)
        .modifier(MemoryCardChrome(scheme: scheme, borderColor: Color.rMint.opacity(0.4)))
    }
}

// MARK: - NoteEditorView

enum NoteEditorResult {
    case saved(Note)
    case deleted
}

struct NoteEditorView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme

    private let original: Note
    let onDone: (NoteEditorResult) -> Void

    @State private var content: String
    @State private var yearText: String
    @State private var month: Int?
    @State private var day: Int?
    @State private var place: String?
    @State private var collectiveEventId: UUID?
    @State private var showDatePicker = false
    @State private var showPlacePicker = false
    @State private var showInvite = false
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var editorFocused: Bool

    init(note: Note, onDone: @escaping (NoteEditorResult) -> Void) {
        self.original = note
        self.onDone = onDone
        _content          = State(initialValue: note.content)
        _yearText         = State(initialValue: note.year.map { "\($0)" } ?? "")
        _month            = State(initialValue: note.month)
        _day              = State(initialValue: note.day)
        _place            = State(initialValue: note.place)
        _collectiveEventId = State(initialValue: note.collective_event_id)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    saveTask?.cancel()
                    Task { await saveAndDismiss() }
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

                Button { showDatePicker.toggle() } label: {
                    Text(displayDate)
                        .font(RFont.mono(10))
                        .foregroundColor(RColor.muted(scheme))
                        .tracking(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(RColor.card(scheme))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(RColor.border(scheme), lineWidth: 1)))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                    DatePickerPopover(yearText: $yearText, month: $month, day: $day) {
                        scheduleAutoSave()
                    }
                }

                Button { showPlacePicker.toggle() } label: {
                    Text(place ?? "set place")
                        .font(RFont.mono(10))
                        .foregroundColor(place != nil ? .rMint : RColor.muted(scheme))
                        .tracking(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(RColor.card(scheme))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(RColor.border(scheme), lineWidth: 1)))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPlacePicker, arrowEdge: .bottom) {
                    PlacePickerPopover(place: $place) {
                        scheduleAutoSave()
                    }
                }

                Button { showInvite.toggle() } label: {
                    HStack(spacing: 3) {
                        Image(systemName: collectiveEventId != nil ? "person.2.fill" : "person.2")
                            .font(.system(size: 11))
                        if collectiveEventId == nil {
                            Text("@")
                                .font(RFont.mono(10))
                        }
                    }
                    .foregroundColor(collectiveEventId != nil ? .rMint : RColor.muted(scheme))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(RColor.card(scheme))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                            collectiveEventId != nil ? Color.rMint.opacity(0.4) : RColor.border(scheme),
                            lineWidth: 1
                        )))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showInvite, arrowEdge: .bottom) {
                    NoteInvitePopover(
                        noteId: original.id,
                        noteContent: content,
                        noteDateStr: {
                            guard let y = Int(yearText), let m = month, let d = day else { return nil }
                            return String(format: "%04d-%02d-%02d", y, m, d)
                        }(),
                        notePlace: place,
                        collectiveEventId: $collectiveEventId
                    )
                    .environmentObject(supabase)
                }

                Spacer()

                Button { Task { await deleteNote() } } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(RColor.muted(scheme).opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .overlay(Divider().opacity(0.4), alignment: .bottom)

            TextEditor(text: $content)
                .font(RFont.body(16))
                .foregroundColor(RColor.text(scheme))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .focused($editorFocused)
                .onChange(of: content) { _, _ in scheduleAutoSave() }
        }
        .onAppear { editorFocused = true }
    }

    private var displayDate: String {
        guard let y = Int(yearText) else { return "set date" }
        guard let m = month else { return "\(y)" }
        let name = Calendar.current.shortMonthSymbols[m - 1]
        guard let d = day else { return "\(name) \(y)" }
        return "\(name) \(d), \(y)"
    }

    private func scheduleAutoSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await performSave()
        }
    }

    @discardableResult
    private func performSave() async -> Note {
        var updated = original
        updated.content = content
        updated.year = Int(yearText)
        updated.month = month
        updated.day = day
        updated.place = place?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().nilIfEmpty
        updated.collective_event_id = collectiveEventId
        try? await supabase.updateNote(updated)
        return updated
    }

    private func saveAndDismiss() async {
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try? await supabase.deleteNote(id: original.id)
            onDone(.deleted)
        } else {
            let saved = await performSave()
            onDone(.saved(saved))
        }
    }

    private func deleteNote() async {
        try? await supabase.deleteNote(id: original.id)
        onDone(.deleted)
    }
}

// MARK: - DatePickerPopover

private struct DatePickerPopover: View {
    @Binding var yearText: String
    @Binding var month: Int?
    @Binding var day: Int?
    let onChange: () -> Void
    @Environment(\.colorScheme) var scheme

    private let monthSymbols = Calendar.current.shortMonthSymbols

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("date")
                .font(RFont.mono(10))
                .foregroundColor(RColor.muted(scheme))
                .tracking(3)
                .textCase(.uppercase)

            HStack {
                Text("year").font(RFont.body(13)).foregroundColor(RColor.muted(scheme))
                Spacer()
                TextField("e.g. 2021", text: $yearText)
                    .textFieldStyle(.plain)
                    .font(RFont.body(13))
                    .foregroundColor(RColor.text(scheme))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .onChange(of: yearText) { _, _ in
                        if Int(yearText) == nil { month = nil; day = nil }
                        onChange()
                    }
                if !yearText.isEmpty {
                    Button("×") { yearText = ""; month = nil; day = nil; onChange() }
                        .buttonStyle(.plain)
                        .foregroundColor(RColor.muted(scheme))
                }
            }

            if Int(yearText) != nil {
                HStack {
                    Text("month").font(RFont.body(13)).foregroundColor(RColor.muted(scheme))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { month ?? 0 },
                        set: { month = $0 == 0 ? nil : $0; day = nil; onChange() }
                    )) {
                        Text("—").tag(0)
                        ForEach(1...12, id: \.self) { m in Text(monthSymbols[m - 1]).tag(m) }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 90)
                }

                if let m = month {
                    HStack {
                        Text("day").font(RFont.body(13)).foregroundColor(RColor.muted(scheme))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { day ?? 0 },
                            set: { day = $0 == 0 ? nil : $0; onChange() }
                        )) {
                            Text("—").tag(0)
                            ForEach(1...daysIn(month: m, yearText: yearText), id: \.self) { d in
                                Text("\(d)").tag(d)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 70)
                    }
                }
            }

            Button("clear") { yearText = ""; month = nil; day = nil; onChange() }
                .buttonStyle(.plain)
                .font(RFont.body(12))
                .foregroundColor(.rOrange)
        }
        .padding(20)
        .frame(width: 230)
    }

    private func daysIn(month: Int, yearText: String) -> Int {
        var c = DateComponents()
        c.year = Int(yearText) ?? 2024
        c.month = month
        return Calendar.current.range(of: .day, in: .month,
            for: Calendar.current.date(from: c) ?? Date())?.count ?? 31
    }
}

// MARK: - PlacePickerPopover

struct PlacePickerPopover: View {
    @Binding var place: String?
    let onChange: () -> Void
    @Environment(\.colorScheme) var scheme
    @State private var text: String = ""

    private let recentKey = "ground.recentPlaces"

    private var recentPlaces: [String] {
        (UserDefaults.standard.array(forKey: recentKey) as? [String]) ?? []
    }

    init(place: Binding<String?>, onChange: @escaping () -> Void) {
        _place = place
        self.onChange = onChange
        _text = State(initialValue: place.wrappedValue ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("place")
                .font(RFont.mono(10))
                .foregroundColor(RColor.muted(scheme))
                .tracking(3)
                .textCase(.uppercase)

            HStack {
                TextField("e.g. home, café, park", text: $text)
                    .textFieldStyle(.plain)
                    .font(RFont.body(13))
                    .foregroundColor(RColor.text(scheme))
                    .onSubmit { commit() }
                if !text.isEmpty {
                    Button("×") { text = ""; place = nil; onChange() }
                        .buttonStyle(.plain)
                        .foregroundColor(RColor.muted(scheme))
                }
            }

            if !recentPlaces.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recentPlaces, id: \.self) { p in
                            Button(p) {
                                text = p
                                commit()
                            }
                            .buttonStyle(.plain)
                            .font(RFont.mono(10))
                            .foregroundColor(place == p ? .white : RColor.text(scheme))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(place == p ? Color.rMint : RColor.input(scheme)))
                            .overlay(Capsule().stroke(RColor.border(scheme), lineWidth: place == p ? 0 : 1))
                        }
                    }
                }
            }

            if place != nil {
                Button("clear") { text = ""; place = nil; onChange() }
                    .buttonStyle(.plain)
                    .font(RFont.body(12))
                    .foregroundColor(.rOrange)
            }
        }
        .padding(20)
        .frame(width: 260)
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { place = nil; onChange(); return }
        place = trimmed
        var recent = recentPlaces.filter { $0 != trimmed }
        recent.insert(trimmed, at: 0)
        UserDefaults.standard.set(Array(recent.prefix(8)), forKey: recentKey)
        onChange()
    }
}

// MARK: - NoteInvitePopover

struct NoteInvitePopover: View {
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme

    let noteId: UUID
    let noteContent: String
    let noteDateStr: String?
    let notePlace: String?
    @Binding var collectiveEventId: UUID?
    @Environment(\.dismiss) var dismiss

    @State private var eventTitle = ""
    @State private var friends: [FriendshipRow] = []
    @State private var members: [FriendProfile] = []
    @State private var inviteHandle = ""
    @State private var inviteStatus: InviteStatus = .idle
    @State private var isSaving = false
    @State private var errorMsg: String?

    private var myId: UUID? { supabase.user?.id }
    private var titleIsValid: Bool { !eventTitle.trimmingCharacters(in: .whitespaces).isEmpty }
    private var canInvite: Bool { collectiveEventId != nil || titleIsValid }

    enum InviteStatus: Equatable { case idle, searching, notFound, alreadyMember }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(collectiveEventId == nil ? "share this memory" : "shared with")
                .font(RFont.mono(10))
                .foregroundColor(RColor.muted(scheme))
                .tracking(3)
                .textCase(.uppercase)

            if collectiveEventId == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("what's this memory about?")
                        .font(RFont.mono(10))
                        .foregroundColor(RColor.muted(scheme))
                    TextField("e.g. mom's 60th birthday", text: $eventTitle)
                        .textFieldStyle(.plain)
                        .font(RFont.body(14))
                        .foregroundColor(RColor.text(scheme))
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(RColor.input(scheme))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(RColor.border(scheme), lineWidth: 1)))
                }
            }

            // Current members
            if !members.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(members) { p in
                            Text(p.handle)
                                .font(RFont.mono(10))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.rMint))
                        }
                    }
                }
            }

            // Handle search
            HStack(spacing: 6) {
                Text("@")
                    .font(RFont.body(14))
                    .foregroundColor(RColor.muted(scheme))
                TextField("add by handle", text: $inviteHandle)
                    .textFieldStyle(.plain)
                    .font(RFont.body(14))
                    .foregroundColor(RColor.text(scheme))
                    .autocorrectionDisabled()
                    .onChange(of: inviteHandle) { _, _ in inviteStatus = .idle }
                    .onSubmit { Task { await addByHandle() } }
                Spacer()
                if inviteStatus == .searching || isSaving {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Button("add") { Task { await addByHandle() } }
                        .buttonStyle(.plain)
                        .font(RFont.body(12).weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.rBlue))
                        .disabled(inviteHandle.trimmingCharacters(in: .whitespaces).isEmpty || !canInvite)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(RColor.input(scheme))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(RColor.border(scheme), lineWidth: 1)))

            if collectiveEventId == nil && !titleIsValid {
                Text("give this memory a title before sharing")
                    .font(RFont.mono(10)).foregroundColor(RColor.muted(scheme))
            } else if inviteStatus == .notFound {
                Text("no user found with that handle")
                    .font(RFont.mono(10)).foregroundColor(RColor.muted(scheme))
            } else if inviteStatus == .alreadyMember {
                Text("already sharing with this person")
                    .font(RFont.mono(10)).foregroundColor(RColor.muted(scheme))
            }

            // Friends quick-add
            let uninvited: [FriendProfile] = friends.compactMap { f in
                guard let myId else { return nil }
                let other = f.otherUser(myId: myId)
                return members.contains(where: { $0.id == other.id }) ? nil : other
            }
            if !uninvited.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(uninvited) { p in
                            Button { Task { await invite(profile: p) } } label: {
                                HStack(spacing: 4) {
                                    Text(p.handle).font(RFont.mono(10))
                                    Image(systemName: "plus").font(.system(size: 9))
                                }
                                .foregroundColor(RColor.text(scheme))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(RColor.input(scheme))
                                    .overlay(Capsule().stroke(RColor.border(scheme), lineWidth: 1)))
                            }
                            .buttonStyle(.plain)
                            .disabled(!canInvite)
                            .opacity(canInvite ? 1 : 0.4)
                        }
                    }
                }
            }

            if let msg = errorMsg {
                Text(msg).font(RFont.mono(10)).foregroundColor(.rOrange)
            }
        }
        .padding(20)
        .frame(width: 300)
        .task { await load() }
    }

    private func load() async {
        async let f = supabase.fetchFriends()
        friends = (try? await f) ?? []
        if let eventId = collectiveEventId {
            members = (try? await supabase.fetchEventMembers(eventId: eventId)) ?? []
        }
    }

    private func addByHandle() async {
        let query = inviteHandle.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty, canInvite else { return }
        inviteStatus = .searching
        if let found = try? await supabase.searchUser(username: query) {
            if members.contains(where: { $0.id == found.id }) {
                inviteStatus = .alreadyMember
            } else {
                inviteStatus = .idle
                inviteHandle = ""
                await invite(profile: found)
            }
        } else {
            inviteStatus = .notFound
        }
    }

    private func invite(profile: FriendProfile) async {
        guard canInvite else {
            errorMsg = "give this memory a title before sharing"
            return
        }
        isSaving = true
        errorMsg = nil
        do {
            let eventId = try await supabase.shareNote(
                noteId: noteId,
                noteContent: noteContent,
                title: eventTitle.trimmingCharacters(in: .whitespaces),
                noteDateStr: noteDateStr,
                notePlace: notePlace,
                addUserId: profile.id,
                existingEventId: collectiveEventId
            )
            collectiveEventId = eventId
            members.append(profile)
        } catch {
            print("shareNote error:", error)
            errorMsg = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Helpers

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
