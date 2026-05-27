import SwiftUI

struct LoginView: View {
    @EnvironmentObject var sessionManager: SessionManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var keyboardHeight: CGFloat = 0

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
