import SwiftUI

struct LoginView: View {
    @EnvironmentObject var sessionManager: SessionManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var keyboardHeight: CGFloat = 0
    @State private var showForgotPassword = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    private let navy = Color(red: 0.03, green: 0.08, blue: 0.18)
    private let gold = Color(red: 1.0, green: 0.78, blue: 0.05)

    var body: some View {
        ZStack {
            navy.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    Image("MTFDLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: keyboardHeight > 0 ? 135 : 185)
                        .padding(.top, keyboardHeight > 0 ? 12 : 34)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                        .animation(.easeOut(duration: 0.25), value: keyboardHeight)

                    VStack(spacing: 2) {
                        Text("Morris Township")
                        Text("Fire Department")
                        Text("Member App")
                    }
                    .font(.system(size: keyboardHeight > 0 ? 24 : 30, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .animation(.easeOut(duration: 0.25), value: keyboardHeight)

                    Rectangle()
                        .fill(Color.white.opacity(0.55))
                        .frame(height: 1)
                        .padding(.horizontal, 46)

                    Text("Member Access Portal")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))

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

