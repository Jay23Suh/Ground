import SwiftUI

struct JournalPopupView: View {
    let onDismiss: () -> Void

    @EnvironmentObject var supabase: SupabaseManager
    @EnvironmentObject var popupState: PopupState
    @Environment(\.colorScheme) var scheme
    @State private var answer = ""
    @State private var isSaving = false
    @FocusState private var focused: Bool

    private var categoryLabel: String {
        Category(rawValue: popupState.category)?.label ?? popupState.category
    }

    var body: some View {
        ZStack {
            ReflectBackground()

            GlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    // Top row
                    HStack {
                        Text("✦ reflect")
                            .font(RFont.header(13))
                            .foregroundColor(.rPink)
                        Spacer()
                        Text(categoryLabel)
                            .font(RFont.mono(10))
                            .foregroundColor(RColor.muted(scheme))
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(RColor.muted(scheme))
                                .padding(6)
                                .background(Circle().fill(RColor.input(scheme)))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 22)

                    // Question
                    Text(popupState.question)
                        .font(RFont.header(20))
                        .foregroundColor(RColor.text(scheme))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 28)
                        .padding(.top, 18)
                        .frame(maxWidth: .infinity)

                    // Answer box
                    TextEditor(text: $answer)
                        .font(RFont.body(13))
                        .foregroundColor(RColor.text(scheme))
                        .scrollContentBackground(.hidden)
                        .background(RColor.input(scheme))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(RColor.border(scheme), lineWidth: 1))
                        .frame(height: 110)
                        .padding(.horizontal, 28)
                        .padding(.top, 16)
                        .focused($focused)

                    // Buttons
                    HStack(spacing: 10) {
                        Button("skip") { Task { await handleSkip() } }
                            .buttonStyle(SkipButtonStyle())
                        Button("save  ↵") { Task { await handleSave() } }
                            .buttonStyle(SaveButtonStyle())
                            .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                            .keyboardShortcut(.return, modifiers: .command)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .padding(16)
        }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .onExitCommand(perform: onDismiss)
        .onChange(of: popupState.question) { _, _ in
            answer = ""
            focused = true
        }
        .onAppear { focused = true }
    }

    private func handleSave() async {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        try? await supabase.saveEntry(question: popupState.question, category: popupState.category, answer: trimmed)
        onDismiss()
    }

    private func handleSkip() async {
        try? await supabase.saveSkip(question: popupState.question, category: popupState.category)
        onDismiss()
    }
}
