import SwiftUI

// MARK: - Shared utilities

func hourLabel(_ h: Int) -> String {
    if h == 0  { return "midnight" }
    if h == 12 { return "noon" }
    return h < 12 ? "\(h)am" : "\(h - 12)pm"
}

extension String {
    var wordCount: Int { split(whereSeparator: \.isWhitespace).count }
}

// MARK: - SearchBar

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

// MARK: - FilterPill

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
