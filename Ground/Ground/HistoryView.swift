import SwiftUI

struct HistoryView: View {
    let entries: [Entry]
    @Environment(\.colorScheme) var scheme
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""

    private var categories: [String] {
        let all = entries.compactMap { $0.category }
        return Array(Set(all)).sorted()
    }

    private var filtered: [Entry] {
        var result = selectedCategory == nil ? entries : entries.filter { $0.category == selectedCategory }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return result }
        result = result.filter {
            ($0.answer?.lowercased().contains(q) ?? false) ||
            $0.categoryLabel.lowercased().contains(q)
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar
            SearchBar(text: $searchText, placeholder: "search entries...")
                .padding(.horizontal, 32)
                .padding(.vertical, 12)

            Divider().opacity(0.4)

            // Category filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterPill(label: "all", selected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(categories, id: \.self) { cat in
                        FilterPill(
                            label: Category(rawValue: cat)?.label ?? cat,
                            selected: selectedCategory == cat
                        ) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
            }

            Divider().opacity(0.4)

            if filtered.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Text(searchText.isEmpty ? "no entries yet" : "no results")
                        .font(RFont.body(14).italic())
                        .foregroundColor(RColor.muted(scheme))
                    if !searchText.isEmpty {
                        Text("try a different keyword or category")
                            .font(RFont.mono(10))
                            .foregroundColor(RColor.muted(scheme).opacity(0.55))
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filtered) { entry in
                            EntryCard(entry: entry)
                        }
                    }
                    .padding(32)
                }
            }
        }
    }
}

struct EntryCard: View {
    let entry: Entry
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let cat = entry.category {
                    Text(Category(rawValue: cat)?.label ?? cat)
                        .font(RFont.mono(10))
                        .foregroundColor(.rMint)
                }
                Spacer()
                Text(entry.formattedDate)
                    .font(RFont.mono(10))
                    .foregroundColor(RColor.muted(scheme))
                if entry.skipped {
                    Text("skipped")
                        .font(RFont.mono(9))
                        .foregroundColor(.rOrange.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.rOrange.opacity(0.1)))
                }
            }

            if let q = entry.question {
                Text(q)
                    .font(RFont.header(14, italic: true))
                    .foregroundColor(RColor.soft(scheme))
            }

            if let a = entry.answer, !entry.skipped {
                Text(a)
                    .font(RFont.body(13))
                    .foregroundColor(RColor.text(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(RColor.card(scheme))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(RColor.border(scheme), lineWidth: 1))
        )
    }
}

// MARK: - SearchBar (shared by HistoryView and NotesView)

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    @Environment(\.colorScheme) var scheme
    @FocusState private var isFocused: Bool
    @State private var clearHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(isFocused ? .rMint : RColor.muted(scheme))
                .animation(.easeInOut(duration: 0.15), value: isFocused)
            TextField(placeholder, text: $text)
                .font(RFont.body(13))
                .foregroundColor(RColor.text(scheme))
                .textFieldStyle(.plain)
                .focused($isFocused)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(clearHovered ? RColor.text(scheme) : RColor.muted(scheme))
                }
                .buttonStyle(.plain)
                .onHover { clearHovered = $0 }
                .animation(.easeInOut(duration: 0.1), value: clearHovered)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(RColor.input(scheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isFocused ? Color.rMint.opacity(0.55) : RColor.border(scheme),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                        .animation(.easeInOut(duration: 0.15), value: isFocused)
                )
        )
    }
}

struct FilterPill: View {
    @Environment(\.colorScheme) var scheme
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(RFont.mono(10))
                .foregroundColor(selected ? .white : RColor.text(scheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(selected ? Color.rBlue : RColor.input(scheme))
                )
                .overlay(Capsule().stroke(RColor.border(scheme), lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}
