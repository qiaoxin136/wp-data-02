//
//  LoginView.swift
//  test
//
//  Login / sign-up / confirm-code screen.
//

import SwiftUI

struct LoginView: View {

    // Three screens in a single view
    enum Mode: Equatable {
        case signIn
        case signUp
        case confirm(username: String)
    }

    @State private var mode: Mode = .signIn

    // Sign-in fields
    @State private var siUsername = ""
    @State private var siPassword = ""

    // Sign-up fields
    @State private var suUsername = ""
    @State private var suEmail    = ""
    @State private var suPassword = ""
    @State private var suConfirm  = ""

    // Confirm-code fields
    @State private var confirmCode     = ""
    @State private var confirmUsername = ""  // filled from sign-up or error

    @State private var isLoading   = false
    @State private var errorMsg:   String?
    @State private var successMsg: String?

    @FocusState private var focusedField: Field?
    fileprivate enum Field { case f1, f2, f3, f4 }

    private let auth = AuthService.shared

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Background (matches splash) ──────────────────────────
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.10, blue: 0.22),
                         Color(red: 0.08, green: 0.16, blue: 0.32)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle grid decoration
            GridDecoration()
                .opacity(0.08)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // ── Logo ─────────────────────────────────────────
                    AppLogoView(size: 80, cornerRadius: 18)
                        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                        .padding(.top, 64)

                    Text("Washington Park")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 14)

                    Text("Field Data Collector")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 2)
                        .padding(.bottom, 32)

                    // ── Card ─────────────────────────────────────────
                    VStack(spacing: 0) {
                        cardContent
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

                    Spacer(minLength: 40)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .onTapGesture { focusedField = nil }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: mode)
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        switch mode {
        case .signIn:   signInCard
        case .signUp:   signUpCard
        case .confirm:  confirmCard
        }
    }

    // ── Sign In ───────────────────────────────────────────────────────

    private var signInCard: some View {
        VStack(spacing: 16) {
            cardHeader(title: "Sign In", icon: "person.fill")

            AuthField("Username", text: $siUsername,
                      type: .username, focused: $focusedField, tag: .f1)
            AuthField("Password", text: $siPassword,
                      type: .password, focused: $focusedField, tag: .f2)

            errorBanner
            successBanner

            ActionButton(title: "Sign In", icon: "arrow.right",
                         color: .blue, isLoading: isLoading) {
                Task { await doSignIn() }
            }
            .disabled(siUsername.isEmpty || siPassword.isEmpty)

            Divider().padding(.horizontal, 8)

            Button {
                clearMessages()
                withAnimation { mode = .signUp }
            } label: {
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundStyle(.secondary)
                    Text("Sign Up")
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
                .font(.subheadline)
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // ── Sign Up ───────────────────────────────────────────────────────

    private var signUpCard: some View {
        VStack(spacing: 16) {
            cardHeader(title: "Create Account", icon: "person.badge.plus")

            AuthField("Username",         text: $suUsername,
                      type: .username, focused: $focusedField, tag: .f1)
            AuthField("Email",            text: $suEmail,
                      type: .email,    focused: $focusedField, tag: .f2)
            AuthField("Password",         text: $suPassword,
                      type: .password, focused: $focusedField, tag: .f3)
            AuthField("Confirm Password", text: $suConfirm,
                      type: .password, focused: $focusedField, tag: .f4)

            if !suConfirm.isEmpty && suPassword != suConfirm {
                Text("Passwords do not match")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            errorBanner
            successBanner

            ActionButton(title: "Create Account", icon: "checkmark",
                         color: .green, isLoading: isLoading) {
                Task { await doSignUp() }
            }
            .disabled(suUsername.isEmpty || suEmail.isEmpty ||
                      suPassword.isEmpty || suPassword != suConfirm)

            Divider().padding(.horizontal, 8)

            Button {
                clearMessages()
                withAnimation { mode = .signIn }
            } label: {
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(.secondary)
                    Text("Sign In")
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
                .font(.subheadline)
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // ── Confirm Code ──────────────────────────────────────────────────

    private var confirmCard: some View {
        VStack(spacing: 16) {
            cardHeader(title: "Verify Email", icon: "envelope.badge.fill")

            Text("We sent a confirmation code to your email address. Enter it below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)

            AuthField("6-digit code", text: $confirmCode,
                      type: .code, focused: $focusedField, tag: .f1)

            errorBanner
            successBanner

            ActionButton(title: "Confirm", icon: "checkmark.seal",
                         color: .blue, isLoading: isLoading) {
                Task { await doConfirm() }
            }
            .disabled(confirmCode.count < 6)

            Button {
                Task { await doResend() }
            } label: {
                Text("Resend Code")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }

            Divider().padding(.horizontal, 8)

            Button {
                clearMessages()
                withAnimation { mode = .signIn }
            } label: {
                Text("Back to Sign In")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: - Shared card helpers

    private func cardHeader(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.blue)
            Text(title)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    @ViewBuilder private var errorBanner: some View {
        if let msg = errorMsg {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .padding(.top, 1)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder private var successBanner: some View {
        if let msg = successMsg {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(msg).font(.caption).foregroundStyle(.green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Actions

    private func doSignIn() async {
        isLoading = true
        clearMessages()
        do {
            try await auth.signIn(username: siUsername.trimmingCharacters(in: .whitespaces),
                                   password: siPassword)
            // Success — AuthService.isSignedIn flips → RootView shows ContentView
        } catch AuthService.AuthError.notConfirmed(let u) {
            confirmUsername = u
            withAnimation { mode = .confirm(username: u) }
            errorMsg = "Your account isn't confirmed yet. Enter the code we emailed you."
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    private func doSignUp() async {
        isLoading = true
        clearMessages()
        do {
            try await auth.signUp(
                username: suUsername.trimmingCharacters(in: .whitespaces),
                password: suPassword,
                email:    suEmail.trimmingCharacters(in: .whitespaces)
            )
            confirmUsername = suUsername.trimmingCharacters(in: .whitespaces)
            withAnimation { mode = .confirm(username: confirmUsername) }
            successMsg = "Account created! Check your email for a confirmation code."
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    private func doConfirm() async {
        isLoading = true
        clearMessages()
        do {
            try await auth.confirmSignUp(username: confirmUsername, code: confirmCode)
            successMsg = "Email confirmed! Signing you in…"
            // Auto sign-in after confirm
            if case .confirm = mode {
                try? await Task.sleep(for: .milliseconds(800))
                try await auth.signIn(username: confirmUsername, password: suPassword)
            }
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    private func doResend() async {
        clearMessages()
        do {
            try await auth.resendCode(username: confirmUsername)
            successMsg = "Code resent — check your email."
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func clearMessages() {
        errorMsg   = nil
        successMsg = nil
    }
}

// MARK: - Auth Field

private struct AuthField: View {
    enum FieldType { case username, email, password, code }

    let placeholder: String
    @Binding var text: String
    let type: FieldType
    var focused: FocusState<LoginView.Field?>.Binding
    let tag: LoginView.Field

    init(_ placeholder: String, text: Binding<String>, type: FieldType,
         focused: FocusState<LoginView.Field?>.Binding, tag: LoginView.Field) {
        self.placeholder = placeholder
        self._text       = text
        self.type        = type
        self.focused     = focused
        self.tag         = tag
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Group {
                if type == .password {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .focused(focused, equals: tag)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var icon: String {
        switch type {
        case .username: return "person"
        case .email:    return "envelope"
        case .password: return "lock"
        case .code:     return "number"
        }
    }

    private var keyboardType: UIKeyboardType {
        switch type {
        case .email: return .emailAddress
        case .code:  return .numberPad
        default:     return .default
        }
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: icon)
                }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isLoading)
    }
}

// MARK: - Grid decoration (matches splash aesthetic)

private struct GridDecoration: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = size.width / 6
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0,          y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            ctx.stroke(path, with: .color(.white), lineWidth: 0.5)
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView()
}
