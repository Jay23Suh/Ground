import SwiftUI

struct OnboardingView: View {
    var onComplete: (() -> Void)? = nil
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme
    @State private var isLogin = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMsg = ""
    @State private var showingIntro = false

    var body: some View {
        ZStack {
            GroundBackground()
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
                            GroundField(placeholder: "your name", text: $name)
                        }
                        GroundField(placeholder: "email", text: $email)
                        GroundField(placeholder: "password", text: $password, secure: true)
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
        .frame(width: 460, height: 540)
        .onReceive(supabase.$user) { user in
            if user != nil { onComplete?() }
        }
        .overlay {
            if showingIntro {
                IntroOverlay { onComplete?() }
                    .transition(.opacity)
            }
        }
    }

    private func handleSubmit() async {
        errorMsg = ""
        do {
            if isLogin {
                try await supabase.signIn(email: email, password: password)
            } else {
                try await supabase.signUp(name: name, email: email, password: password)
            }
            withAnimation(.easeInOut(duration: 0.4)) { showingIntro = true }
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
