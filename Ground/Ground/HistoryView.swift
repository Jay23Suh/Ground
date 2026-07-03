import SwiftUI

struct HistoryView: View {
    let entries: [Entry]
    @Binding var scrollTarget: UUID?
    @Environment(\.colorScheme) var scheme
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    @State private var highlightedID: UUID? = nil

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
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filtered) { entry in
                                EntryCard(entry: entry, isHighlighted: entry.id == highlightedID)
                                    .id(entry.id)
                            }
                        }
                        .padding(32)
                    }
                    .onAppear { jumpToTarget(using: proxy) }
                    .onChange(of: scrollTarget) { _, _ in jumpToTarget(using: proxy) }
                }
            }
        }
    }

    private func jumpToTarget(using proxy: ScrollViewProxy) {
        guard let target = scrollTarget else { return }
        selectedCategory = nil
        searchText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(target, anchor: .center) }
            highlightedID = target
            scrollTarget = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeOut(duration: 0.6)) { highlightedID = nil }
            }
        }
    }
}

struct EntryCard: View {
    let entry: Entry
    var isHighlighted: Bool = false
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
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isHighlighted ? Color.rOrange : RColor.border(scheme), lineWidth: isHighlighted ? 2 : 1)
                )
                .shadow(color: Color.rOrange.opacity(isHighlighted ? 0.35 : 0), radius: 12)
        )
    }
}

