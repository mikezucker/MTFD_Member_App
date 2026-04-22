import SwiftUI

struct LoginView: View {
    @EnvironmentObject var sessionManager: SessionManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ZStack {
            AppTheme.navy
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 40)

                    Image("MTFDLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)

                    VStack(spacing: 2) {
                        Text("Morris Township")
                        Text("Fire Department")
                        Text("Member App")
                    }
                    .font(.custom("Didot", size: 30))
                    .kerning(1.2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)

                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(height: 1)
                        .padding(.horizontal, 40)

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
                            .cornerRadius(10)

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
                            .cornerRadius(10)

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
                            .background(AppTheme.gold)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                        }
                        .disabled(
                            isLoading ||
                            email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            password.isEmpty
                        )
                        .opacity(isLoading ? 0.7 : 1)
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                        .frame(height: 40)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                focusedField = nil
            }
        }
    }

    @MainActor
    private func handleLogin() async {
        guard !isLoading else { return }

        focusedField = nil
        errorMessage = nil
        isLoading = true

        do {
            try await sessionManager.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
