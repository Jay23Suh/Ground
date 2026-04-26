import SwiftUI
import Auth
import Supabase

struct SettingsView: View {
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme

    @AppStorage("groundPopupIntervalMinutes") private var intervalMinutes: Double = 100

    @State private var quoteStartTime = Date()
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var statusMessage: String?
    @State private var isError = false
    @State private var isSaving = false
    @State private var isProfileLoading = true

    private func formatInterval(_ minutes: Double) -> String {
        let m = Int(minutes)
        if m < 60 { return "\(m) min" }
        let h = m / 60; let rem = m % 60
        return rem == 0 ? "\(h)h" : "\(h)h \(rem)m"
    }

    private var minutesFieldBinding: Binding<String> {
        Binding(
            get: { "\(Int(intervalMinutes))" },
            set: { if let v = Double($0) { intervalMinutes = min(max(v, 20), 1440) } }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Daily Grounding Setting
                SettingsSection(title: "daily grounding") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("start each day at")
                                .font(RFont.body(13))
                                .foregroundColor(RColor.muted(scheme))
                            Spacer()
                            if isProfileLoading {
                                ProgressView().scaleEffect(0.5)
                            } else {
                                DatePicker("", selection: $quoteStartTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.stepperField)
                                    .onChange(of: quoteStartTime) { _, newValue in
                                        Task { await handleUpdateStartTime(newValue) }
                                    }
                            }
                        }
                        Text("This controls when your daily quote resets and the grounding modal appears.")
                            .font(RFont.body(11))
                            .foregroundColor(RColor.muted(scheme).opacity(0.8))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12).fill(RColor.card(scheme))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(RColor.border(scheme), lineWidth: 1))
                    )
                }

                // Check-in frequency
                SettingsSection(title: "check-in frequency") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("popup appears after")
                                .font(RFont.body(13))
                                .foregroundColor(RColor.muted(scheme))
                            Spacer()
                            Text(formatInterval(intervalMinutes) + " of activity")
                                .font(RFont.header(15))
                                .foregroundColor(RColor.text(scheme))
                        }

                        Slider(value: $intervalMinutes, in: 20...1440, step: 5)
                            .tint(.rOrange)

                        HStack {
                            Text("20 min")
                                .font(RFont.mono(9))
                                .foregroundColor(RColor.muted(scheme))
                            Spacer()
                            Text("24 hrs")
                                .font(RFont.mono(9))
                                .foregroundColor(RColor.muted(scheme))
                        }

                        HStack(spacing: 8) {
                            Text("or type minutes:")
                                .font(RFont.mono(10))
                                .foregroundColor(RColor.muted(scheme))
                            TextField("", text: minutesFieldBinding)
                                .textFieldStyle(.plain)
                                .font(RFont.body(13))
                                .foregroundColor(RColor.text(scheme))
                                .multilineTextAlignment(.center)
                                .frame(width: 60)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8).fill(RColor.input(scheme))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(RColor.border(scheme), lineWidth: 1))
                                )
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12).fill(RColor.card(scheme))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(RColor.border(scheme), lineWidth: 1))
                    )
                }

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
        .task {
            await loadProfile()
        }
    }

    private func loadProfile() async {
        guard let profile = await supabase.fetchProfile() else {
            isProfileLoading = false
            return
        }
        
        let timeString = profile.quote_start_time ?? "06:00:00"
        let components = timeString.components(separatedBy: ":")
        let hours = Int(components[0]) ?? 6
        let minutes = components.count > 1 ? Int(components[1]) ?? 0 : 0
        
        let calendar = Calendar.current
        var date = calendar.startOfDay(for: Date())
        date = calendar.date(bySettingHour: hours, minute: minutes, second: 0, of: date) ?? date
        
        await MainActor.run {
            self.quoteStartTime = date
            self.isProfileLoading = false
        }
    }

    private func handleUpdateStartTime(_ newDate: Date) async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
        let hours = components.hour ?? 6
        let minutes = components.minute ?? 0
        let timeString = String(format: "%02d:%02d:00", hours, minutes)
        
        try? await supabase.updateProfile(startTime: timeString)
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
