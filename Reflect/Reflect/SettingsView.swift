import SwiftUI
import Auth

struct SettingsView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var statusMessage: String?
    @State private var isError = false
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Account section
                SettingsSection(title: "account") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("signed in as")
                            .font(RFont.mono(10))
                            .foregroundColor(RColor.muted(scheme))
                        Text(supabase.user?.email ?? "—")
                            .font(RFont.body(14))
                            .foregroundColor(RColor.text(scheme))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(RColor.card(scheme))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(RColor.border(scheme), lineWidth: 1)))
                }

                // Change password section
                SettingsSection(title: "change password") {
                    VStack(spacing: 10) {
                        SecureField("new password", text: $newPassword)
                            .textFieldStyle(.plain)
                            .font(RFont.body(13))
                            .foregroundColor(RColor.text(scheme))
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(RColor.input(scheme))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(RColor.border(scheme), lineWidth: 1)))

                        SecureField("confirm new password", text: $confirmPassword)
                            .textFieldStyle(.plain)
                            .font(RFont.body(13))
                            .foregroundColor(RColor.text(scheme))
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(RColor.input(scheme))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(RColor.border(scheme), lineWidth: 1)))

                        if let msg = statusMessage {
                            Text(msg)
                                .font(RFont.mono(10))
                                .foregroundColor(isError ? Color.red.opacity(0.8) : Color(hex: "#5edb97"))
                        }

                        Button {
                            Task { await handleChangePassword() }
                        } label: {
                            Text(isSaving ? "saving…" : "update password")
                                .font(RFont.body(13).weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.rOrange))
                        }
                        .buttonStyle(.plain)
                        .disabled(newPassword.isEmpty || isSaving)
                    }
                }

                // Sign out
                SettingsSection(title: "session") {
                    Button {
                        Task { try? await supabase.signOut() }
                    } label: {
                        Text("sign out")
                            .font(RFont.body(13))
                            .foregroundColor(RColor.muted(scheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(RColor.card(scheme))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(RColor.border(scheme), lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
        }
    }

    private func handleChangePassword() async {
        guard newPassword == confirmPassword else {
            statusMessage = "passwords don't match"; isError = true; return
        }
        guard newPassword.count >= 6 else {
            statusMessage = "password must be at least 6 characters"; isError = true; return
        }
        isSaving = true
        do {
            try await supabase.updatePassword(newPassword)
            statusMessage = "password updated"
            isError = false
            newPassword = ""
            confirmPassword = ""
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
        isSaving = false
    }
}

struct SettingsSection<Content: View>: View {
    @Environment(\.colorScheme) var scheme
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(RFont.mono(10))
                .foregroundColor(RColor.muted(scheme))
                .textCase(.uppercase)
                .tracking(2)
            content
        }
    }
}
