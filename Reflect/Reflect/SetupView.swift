import SwiftUI

struct SetupView: View {
    var onComplete: (() -> Void)? = nil
    @EnvironmentObject var supabase: SupabaseManager
    @Environment(\.colorScheme) var scheme
    @State private var isLogin = false
    @State private var isForgot = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMsg = ""

    var body: some View {
        ZStack {
            ReflectBackground()

            GlassCard {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("✦")
                            .font(RFont.header(24))
                            .foregroundColor(.rPink)
                        Text("reflect")
                            .font(RFont.header(34))
                            .foregroundColor(RColor.text(scheme))
                        Text(isForgot ? "reset password" : isLogin ? "welcome back" : "begin your practice")
                            .font(RFont.body(14).italic())
                            .foregroundColor(RColor.muted(scheme))
                    }
                    .padding(.top, 36)
                    .padding(.bottom, 28)

                    // Fields
                    VStack(spacing: 12) {
                        if !isLogin && !isForgot {
                            ReflectField(placeholder: "your name", text: $name)
                        }
                        ReflectField(placeholder: "email", text: $email)
                        if !isForgot {
                            ReflectField(placeholder: "password", text: $password, secure: true)
                        }
                    }
                    .padding(.horizontal, 32)

                    // Error
                    if !errorMsg.isEmpty {
                        Text(errorMsg)
                            .font(RFont.body(12))
                            .foregroundColor(.rOrange)
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                            .padding(.horizontal, 32)
                    }

                    // Submit
                    Button(isForgot ? "send reset link" : isLogin ? "sign in" : "get started") {
                        Task { isForgot ? await handleForgot() : await handleSubmit() }
                    }
                    .buttonStyle(OrangeButtonStyle())
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                    .disabled(supabase.isLoading)

                    // Toggle row
                    VStack(spacing: 6) {
                        if isForgot {
                            Button("back to sign in") {
                                isForgot = false; errorMsg = ""
                            }
                        } else {
                            if isLogin {
                                Button("forgot password?") {
                                    isForgot = true; errorMsg = ""
                                }
                            }
                            Button(isLogin
                                   ? "don't have an account? sign up"
                                   : "already have an account? sign in") {
                                isLogin.toggle(); errorMsg = ""
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .font(RFont.body(12))
                    .foregroundColor(RColor.muted(scheme))
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
            }
            .padding(32)
        }
        .frame(width: 420, height: 500)
    }

    private func handleForgot() async {
        errorMsg = ""
        do {
            try await supabase.resetPassword(email: email)
            errorMsg = "check your email for a reset link"
        } catch {
            errorMsg = error.localizedDescription
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
            onComplete?()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

struct ReflectField: View {
    @Environment(\.colorScheme) var scheme
    let placeholder: String
    @Binding var text: String
    var secure = false

    var body: some View {
        Group {
            if secure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(RFont.body(14))
        .foregroundColor(RColor.text(scheme))
        .padding(12)
        .background(RColor.input(scheme))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(RColor.border(scheme), lineWidth: 1))
        .textFieldStyle(.plain)
    }
}
