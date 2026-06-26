import SwiftUI

struct LoginView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var keyboardHeight: CGFloat = 0
    @State private var showForgotPassword = false
    @State private var logoVisible = false
    @State private var shimmerPhase: CGFloat = 0
    @State private var mottoWordCount = 0

    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    private let navy = Color(red: 0.03, green: 0.08, blue: 0.18)
    private let gold = Color(red: 1.0, green: 0.78, blue: 0.05)
    private let fireRed = Color(red: 0.86, green: 0.08, blue: 0.12)
    private let mottoWords = ["INTEGRITY", "SERVICE", "EXCELLENCE"]

    var body: some View {
        ZStack {
            navy.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: keyboardHeight > 0 ? 12 : 18) {
                        logoView

                        mottoView
                    }
                    .padding(.top, keyboardHeight > 0 ? 12 : 34)
                    .animation(.easeOut(duration: 0.25), value: keyboardHeight)

                    VStack(spacing: 5) {
                        Text("Morris Township Fire Dept.")
                            .font(.system(size: keyboardHeight > 0 ? 25 : 31, weight: .semibold, design: .default))
                            .tracking(0.2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .animation(.easeOut(duration: 0.25), value: keyboardHeight)

                    Rectangle()
                        .fill(Color.white.opacity(0.55))
                        .frame(height: 1)
                        .padding(.horizontal, 46)

                    Text("Member Access Portal")
                        .font(.system(size: keyboardHeight > 0 ? 13 : 14, weight: .medium, design: .default))
                        .tracking(0.4)
                        .foregroundColor(.white.opacity(0.82))

                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .email)
                            .onSubmit {
                                focusedField = .password
                            }
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(12)

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .submitLabel(.go)
                            .focused($focusedField, equals: .password)
                            .onSubmit {
                                Task {
                                    await handleLogin()
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(12)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            Task {
                                await handleLogin()
                            }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text("Sign In")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(gold)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                        }
                        .disabled(
                            isLoading ||
                            email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            password.isEmpty
                        )
                        .opacity(isLoading ? 0.7 : 1)

                        Button {
                            showForgotPassword = true
                        } label: {
                            Text("Forgot password?")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(gold)
                                .padding(.top, 2)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: keyboardHeight > 0 ? 180 : 32)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, keyboardHeight > 0 ? 20 : 0)
                .offset(y: keyboardHeight > 0 ? -70 : 0)
                .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                focusedField = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(initialEmail: email)
        }
        .task {
            await runIntroAnimation()
        }
    }

    private var mottoView: some View {
        HStack(spacing: 8) {
            ForEach(Array(mottoWords.enumerated()), id: \.offset) { index, word in
                if index > 0 {
                    Rectangle()
                        .fill(fireRed.opacity(0.9))
                        .frame(width: 1, height: keyboardHeight > 0 ? 12 : 14)
                        .padding(.horizontal, 2)
                        .opacity(mottoWordCount > index ? 1 : 0)
                }

                Text(word)
                    .font(.system(size: keyboardHeight > 0 ? 11 : 12, weight: .semibold, design: .default))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .opacity(mottoWordCount > index ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .animation(.easeOut(duration: 0.55), value: mottoWordCount)
    }

    private var logoView: some View {
        let logoSize: CGFloat = keyboardHeight > 0 ? 118 : 154
        let shimmerTravel = logoSize * 0.9

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            gold.opacity(0.13),
                            Color.white.opacity(0.045),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: logoSize * 0.62
                    )
                )
                .frame(width: logoSize + 16, height: logoSize + 16)
                .blur(radius: 2)

            if !reduceMotion {
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.16),
                                    gold.opacity(0.09),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: logoSize * 0.36, height: logoSize * 1.55)
                        .rotationEffect(.degrees(22))
                        .offset(x: -shimmerTravel + (shimmerTravel * 2 * shimmerPhase))
                        .blendMode(.screen)
                }
                .frame(width: logoSize, height: logoSize)
                .clipShape(Circle())
                .opacity(logoVisible ? 1 : 0)
                .animation(
                    .linear(duration: 3.2)
                        .repeatForever(autoreverses: false),
                    value: shimmerPhase
                )
            }

            Image("MTFDHeaderIcon")
                .resizable()
                .scaledToFill()
                .frame(width: logoSize, height: logoSize)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
        }
        .frame(width: logoSize + 20, height: logoSize + 20)
        .shadow(color: gold.opacity(0.16), radius: 12, y: 0)
        .shadow(color: .black.opacity(0.24), radius: 10, y: 5)
        .opacity(logoVisible ? 1 : 0)
        .scaleEffect(logoVisible || reduceMotion ? 1 : 0.97)
        .animation(.easeOut(duration: 0.85), value: logoVisible)
    }

    @MainActor
    private func runIntroAnimation() async {
        logoVisible = false
        shimmerPhase = 0
        mottoWordCount = 0

        if reduceMotion {
            logoVisible = true
            mottoWordCount = mottoWords.count
            return
        }

        try? await Task.sleep(nanoseconds: 180_000_000)
        logoVisible = true

        try? await Task.sleep(nanoseconds: 280_000_000)
        shimmerPhase = 1

        try? await Task.sleep(nanoseconds: 650_000_000)
        for count in 1...mottoWords.count {
            mottoWordCount = count
            try? await Task.sleep(nanoseconds: 190_000_000)
        }
    }

    @MainActor
    private func handleLogin() async {
        guard !isLoading else { return }

        focusedField = nil
        errorMessage = nil
        isLoading = true

        await sessionManager.login(email: email, password: password)
        errorMessage = sessionManager.errorMessage

        isLoading = false
    }
}

private struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var isSending = false
    @State private var sent = false
    @State private var errorMessage: String?

    private let navy = Color(red: 0.03, green: 0.08, blue: 0.18)
    private let gold = Color(red: 1.0, green: 0.78, blue: 0.05)

    init(initialEmail: String) {
        _email = State(initialValue: initialEmail.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSend: Bool {
        normalizedEmail.contains("@") && !isSending
    }

    var body: some View {
        NavigationStack {
            ZStack {
                navy.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reset Password")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Enter your account email. If it matches a member account, we’ll send a one-time reset link.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if sent {
                        Text("If your email is recognized, you’ll receive a reset link shortly. Open the email to choose a new password.")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.green)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        Task {
                            await sendResetLink()
                        }
                    } label: {
                        HStack {
                            if isSending {
                                ProgressView()
                                    .tint(.black)
                            }

                            Text(isSending ? "Sending..." : "Send Reset Link")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSend ? gold : Color.white.opacity(0.18))
                        .foregroundColor(canSend ? .black : .white.opacity(0.6))
                        .cornerRadius(12)
                    }
                    .disabled(!canSend)

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(gold)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(navy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    @MainActor
    private func sendResetLink() async {
        guard canSend else { return }

        isSending = true
        errorMessage = nil
        sent = false

        do {
            let response = try await APIClient.shared.requestPasswordReset(email: normalizedEmail)

            if response.ok {
                sent = true
            } else {
                errorMessage = response.error ?? "Unable to send reset link."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }
}
