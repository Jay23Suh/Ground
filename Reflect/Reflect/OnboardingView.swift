import SwiftUI
import UserNotifications

enum OnboardingStep { case welcome, auth, notifications, done }

struct OnboardingView: View {
    var onComplete: (() -> Void)? = nil
    @EnvironmentObject var supabase: SupabaseManager
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        ZStack {
            ReflectBackground()
            Group {
                switch step {
                case .welcome:
                    WelcomeStep { advance() }
                case .auth:
                    AuthStep { advance() }
                case .notifications:
                    NotificationsStep { advance() }
                case .done:
                    DoneStep {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        onComplete?()
                    }
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.4), value: step)
        }
        .frame(width: 460, height: 540)
        .onChange(of: supabase.user) { _, user in
            if user != nil, step == .auth { advance() }
        }
    }

    private func advance() {
        switch step {
        case .welcome:       step = .auth
        case .auth:          step = .notifications
        case .notifications: step = .done
        case .done:          break
        }
    }
}

// MARK: - Welcome

struct WelcomeStep: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) var scheme
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 10) {
                Text("✦")
                    .font(RFont.header(32))
                    .foregroundColor(.rPink)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                Text("reflect")
                    .font(RFont.header(56))
                    .foregroundColor(RColor.text(scheme))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

                Text("a daily practice for yourself")
                    .font(RFont.body(15).italic())
                    .foregroundColor(RColor.muted(scheme))
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.35), value: appeared)
            }
            Spacer()
            Button(action: onNext) {
                HStack(spacing: 6) {
                    Text("get started")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(OrangeButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true } }
    }
}

// MARK: - Auth

struct AuthStep: View {
    let onNext: () -> Void
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme
    @State private var isLogin = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMsg = ""

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(isLogin ? "welcome back" : "create your account")
                        .font(RFont.header(28))
                        .foregroundColor(RColor.text(scheme))
                    Text(isLogin ? "sign in to continue" : "begin your practice")
                        .font(RFont.body(13).italic())
                        .foregroundColor(RColor.muted(scheme))
                }
                .padding(.top, 36)
                .padding(.bottom, 24)

                VStack(spacing: 12) {
                    if !isLogin {
                        ReflectField(placeholder: "your name", text: $name)
                    }
                    ReflectField(placeholder: "email", text: $email)
                    ReflectField(placeholder: "password", text: $password, secure: true)
                }
                .padding(.horizontal, 32)

                if !errorMsg.isEmpty {
                    Text(errorMsg)
                        .font(RFont.body(12))
                        .foregroundColor(.rOrange)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                        .padding(.horizontal, 32)
                }

                Button(isLogin ? "sign in" : "get started") {
                    Task { await handleSubmit() }
                }
                .buttonStyle(OrangeButtonStyle())
                .padding(.horizontal, 32)
                .padding(.top, 20)
                .disabled(supabase.isLoading)

                Button(isLogin
                       ? "don't have an account? sign up"
                       : "already have an account? sign in") {
                    isLogin.toggle(); errorMsg = ""
                }
                .buttonStyle(.plain)
                .font(RFont.body(12))
                .foregroundColor(RColor.muted(scheme))
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
        }
        .padding(32)
    }

    private func handleSubmit() async {
        errorMsg = ""
        do {
            if isLogin {
                try await supabase.signIn(email: email, password: password)
            } else {
                try await supabase.signUp(name: name, email: email, password: password)
            }
            onNext()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

// MARK: - Notifications

struct NotificationsStep: View {
    let onNext: () -> Void
    @Environment(\.colorScheme) var scheme
    @State private var appeared = false

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.rPink)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.7)
                        .animation(.spring(duration: 0.5).delay(0.1), value: appeared)

                    VStack(spacing: 6) {
                        Text("stay consistent")
                            .font(RFont.header(32))
                            .foregroundColor(RColor.text(scheme))
                        Text("reflect will gently remind you\nevery 2 hours to check in with yourself")
                            .font(RFont.body(13).italic())
                            .foregroundColor(RColor.muted(scheme))
                            .multilineTextAlignment(.center)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)
                }
                Spacer()
                VStack(spacing: 10) {
                    Button("allow notifications") {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
                            DispatchQueue.main.async { onNext() }
                        }
                    }
                    .buttonStyle(OrangeButtonStyle())
                    .padding(.horizontal, 32)

                    Button("maybe later") { onNext() }
                        .buttonStyle(.plain)
                        .font(RFont.body(12))
                        .foregroundColor(RColor.muted(scheme))
                }
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)
            }
        }
        .padding(32)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true } }
    }
}

// MARK: - Done

struct DoneStep: View {
    let onComplete: () -> Void
    @Environment(\.colorScheme) var scheme
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(Color(hex: "#5edb97"))
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .animation(.spring(duration: 0.5).delay(0.1), value: appeared)

                VStack(spacing: 6) {
                    Text("you're all set")
                        .font(RFont.header(40))
                        .foregroundColor(RColor.text(scheme))
                    Text("reflect lives in your menu bar.\ntap ✦ anytime to write, review, or reflect.")
                        .font(RFont.body(13).italic())
                        .foregroundColor(RColor.muted(scheme))
                        .multilineTextAlignment(.center)
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)
            }
            Spacer()
            Button(action: onComplete) {
                HStack(spacing: 6) {
                    Text("open reflect")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(OrangeButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true } }
    }
}
