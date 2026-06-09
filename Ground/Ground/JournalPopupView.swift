import SwiftUI

struct JournalPopupView: View {
    let onDismiss: () -> Void

    @EnvironmentObject var supabase: SupabaseManager
    @EnvironmentObject var popupState: PopupState
    @Environment(\.colorScheme) var scheme
    @State private var answer = ""
    @State private var isSaving = false
    private let charLimit = 2000
    @FocusState private var focused: Bool

    private var categoryLabel: String {
        Category(rawValue: popupState.category)?.label ?? popupState.category
    }

    var body: some View {
        ZStack {
            GroundBackground()

            GlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    // Top row
                    HStack {
                        HStack(spacing: 4) {
                            Image("GroundIcon")
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 12, height: 12)
                                .foregroundColor(.rPink)
                            Text("ground")
                                .font(RFont.header(13))
                                .foregroundColor(.rPink)
                        }
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
                        .onChange(of: answer) { _, new in
                            if new.count > charLimit { answer = String(new.prefix(charLimit)) }
                        }

                    if answer.count > charLimit - 200 {
                        Text("\(charLimit - answer.count) left")
                            .font(RFont.mono(10))
                            .foregroundColor(answer.count > charLimit - 50 ? .rOrange : RColor.muted(scheme).opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 28)
                    }

                    if let errorMessage = supabase.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(RFont.body(12))
                            .foregroundColor(.rOrange)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 28)
                            .padding(.top, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Buttons
                    HStack(spacing: 10) {
                        Button("skip") { Task { await handleSkip() } }
                            .buttonStyle(SkipButtonStyle())
                        Button("save  ↵") { Task { await handleSave() } }
                            .buttonStyle(SaveButtonStyle())
                            .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || answer.count > charLimit)
                            .keyboardShortcut(.return, modifiers: .command)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .padding(16)
        }
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onExitCommand(perform: onDismiss)
        .onChange(of: popupState.question) { _, _ in
            answer = ""
            isSaving = false
            supabase.errorMessage = nil
            focused = true
        }
        .onAppear {
            supabase.errorMessage = nil
            focused = true
        }
    }

    private func handleSave() async {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        do {
            try await supabase.saveEntry(question: popupState.question, category: popupState.category, answer: trimmed)
            NotificationCenter.default.post(name: .didJournal, object: nil)
            onDismiss()
        } catch {
            isSaving = false
        }
    }

    private func handleSkip() async {
        do {
            try await supabase.saveSkip(question: popupState.question, category: popupState.category)
            NotificationCenter.default.post(name: .didJournal, object: nil)
            onDismiss()
        } catch {
            isSaving = false
        }
    }
}
