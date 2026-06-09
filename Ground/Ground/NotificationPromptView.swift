import SwiftUI
import UserNotifications

struct NotificationPromptView: View {
    @Environment(\.colorScheme) var scheme
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.rOrange)

                VStack(spacing: 10) {
                    Text("stay grounded")
                        .font(RFont.header(26))
                        .foregroundColor(RColor.text(scheme))

                    Text("Ground can nudge you to check in with yourself throughout the day. You control how often.")
                        .font(RFont.body(14).italic())
                        .foregroundColor(RColor.muted(scheme))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }

                VStack(spacing: 10) {
                    Button("turn on notifications") {
                        Task { await requestAndDismiss() }
                    }
                    .buttonStyle(.plain)
                    .font(RFont.body(14).weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.rOrange))

                    Button("not now") { onDone() }
                        .buttonStyle(.plain)
                        .font(RFont.body(13))
                        .foregroundColor(RColor.muted(scheme))
                }
            }
            .padding(48)

            Spacer()
        }
        .frame(width: 460, height: 380)
    }

    private func requestAndDismiss() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        onDone()
    }
}
