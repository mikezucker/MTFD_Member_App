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

                        if let errorMessage = errorMessage ?? sessionManager.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        if sessionManager.hasSavedSession, sessionManager.errorMessage != nil {
                            Button("Retry saved sign-in") {
                                Task { await sessionManager.restoreSession() }
                            }
                            .foregroundColor(gold)
                            .disabled(isLoading)
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
                            Text("Forgot password or check reset approval?")
                                .multilineTextAlignment(.center)
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(gold)
                                .padding(.top, 2)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 24)

                    Link("Privacy & Support", destination: URL(string: "https://new-mtfd-site.vercel.app/app-privacy")!)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(gold)

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

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @State private var identifier: String
    @State private var pending: PendingPasswordRecovery?
    @State private var status = "PENDING"
    @State private var password = ""
    @State private var confirmation = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var completed = false
    @State private var operation: Task<Void, Never>?
    @State private var isFindingAccount = false
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var station = ""
    @State private var foundAccount: APIClient.RecoveryAccountLookupResponse?
    @Environment(\.scenePhase) private var scenePhase

    init(initialEmail: String) {
        let saved = PendingPasswordRecovery.load()
        _pending = State(initialValue:saved)
        _identifier = State(initialValue:saved?.identifier ?? initialEmail.trimmingCharacters(in:.whitespacesAndNewlines))
    }
    var body: some View {
        NavigationStack {
            Form {
                if completed {
                    Section {
                        Label("Password updated",systemImage:"checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Your previous sign-ins have ended. Sign in with your new password to return to MTFD.")
                        LabeledContent("Sign-in email", value: identifier)
                        Button("Sign in to MTFD") { operation = Task { await signIn() } }
                    }
                } else if let pending {
                    Section("Recovery request") {
                        LabeledContent("Account sign-in",value:pending.identifier)
                        Text("Request code")
                        Text(pending.matchCode).font(.largeTitle.monospaced()).textSelection(.enabled)
                        Text("Your request has been sent to your Chief or Admin. They will verify your identity and match this code before approving. This code alone cannot reset your password.")
                        Label(statusLabel,systemImage:status == "APPROVED" ? "checkmark.shield.fill" : "clock")
                        if status == "PENDING" {
                            Text("Keep this request on this iPhone. It expires after 15 minutes. You can close this screen and return while the request remains valid.")
                            Button("Check approval") { Task { await checkStatus() } }
                        }
                    }
                    if status == "APPROVED" {
                        Section("Create a new password") {
                            SecureField("New password",text:$password).textContentType(.newPassword)
                            SecureField("Confirm new password",text:$confirmation).textContentType(.newPassword)
                            Text("Use at least 12 characters. Your device will verify you before the password is changed.")
                                .font(.footnote).foregroundStyle(.secondary)
                            Button("Verify device & update password") { operation = Task { await complete(pending) } }
                                .disabled(password.count < 12 || password != confirmation)
                        }
                    }
                    if status == "CONSUMED" {
                        Section {
                            Text("This reset has already completed. Try signing in with your new password.")
                            if !password.isEmpty { Button("Sign in with new password") { operation = Task { await signIn() } } }
                            else { Button("Return to sign in") { dismiss() } }
                        }
                    } else if status == "DENIED" || status == "EXPIRED" {
                        Section { Text("This request can no longer be used. Start again if you still need help.") }
                    }
                    Section {
                        Button("Start a new request",role:.destructive) {
                            PasswordRecoveryDeviceKey.remove(); self.pending = nil; status = "PENDING"; errorMessage = nil
                            foundAccount = nil
                        }
                    }
                } else if let foundAccount {
                    Section("Account found") {
                        LabeledContent("Sign-in email", value: foundAccount.maskedEmail)
                        Text("This is the email you use for FirstDue. You can request recovery without entering the full address.")
                        Button("Request password recovery") { operation = Task { await requestReset() } }
                        Text("Your Chief or Admin will verify your identity before approving the request.")
                            .font(.footnote)
                        Button("Search again") { self.foundAccount = nil; errorMessage = nil }
                    }
                } else if isFindingAccount {
                    Section("Find my sign-in email") {
                        Text("Enter your name and select the station assigned to your MTFD account.")
                        TextField("First name", text: $firstName)
                            .textContentType(.givenName)
                            .textInputAutocapitalization(.words).autocorrectionDisabled()
                        TextField("Last name", text: $lastName)
                            .textContentType(.familyName)
                            .textInputAutocapitalization(.words).autocorrectionDisabled()
                        Picker("Station", selection: $station) {
                            Text("Select your station").tag("")
                            Text("Station 1 — Mt. Kemble").tag("1")
                            Text("Station 2 — Collinsville").tag("2")
                            Text("Station 3 — Hillside").tag("3")
                            Text("Station 4 — Fairchild").tag("4")
                            Text("Station 5 — Woodland").tag("5")
                            Text("Fire Headquarters").tag("HQ")
                        }
                        .pickerStyle(.menu)
                        Button("Find my sign-in email") { operation = Task { await findAccount() } }
                            .disabled(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                      lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || station.isEmpty)
                        Button("I know my email address") { isFindingAccount = false; errorMessage = nil }
                    }
                } else {
                    Section("Request Chief or Admin approval") {
                        Text("Enter the same email address you use to sign in to FirstDue. Your Chief or Admin can approve your request in their app. No email is sent.")
                        TextField("FirstDue email address",text:$identifier)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .textContentType(.username).keyboardType(.emailAddress)
                        Button("Request password reset") { operation = Task { await requestReset() } }
                            .disabled(identifier.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                    }
                    Section {
                        Button("Find my sign-in email") { isFindingAccount = true; errorMessage = nil }
                    }
                }
                if isWorking { Section { ProgressView("Please wait…") } }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently) } }
            }
            .disabled(isWorking)
            .navigationTitle("Password Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Close") { dismiss() } } }
            .task(id:pending?.requestId) {
                guard pending != nil else { return }
                await checkStatus()
                while !Task.isCancelled && status == "PENDING" && !completed {
                    try? await Task.sleep(for:.seconds(10))
                    guard !Task.isCancelled else { break }
                    if scenePhase == .active { await checkStatus() }
                }
            }
            .onDisappear { operation?.cancel(); password = ""; confirmation = "" }
            .onChange(of:scenePhase) { _,phase in if phase == .active { Task { await checkStatus() } } }
        }
    }
    private var statusLabel: String {
        switch status { case "APPROVED": return "Approved — create your new password"
        case "DENIED": return "Request declined"
        case "EXPIRED": return "Request expired"
        case "CONSUMED": return "Request already completed"
        default: return "Waiting for Chief or Admin approval" }
    }
    @MainActor private func requestReset() async {
        guard !isWorking else { return }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let publicKey = try PasswordRecoveryDeviceKey.createPublicKey()
            let result: APIClient.RecoveryStartResponse
            if let foundAccount {
                result = try await APIClient.shared.startPasswordRecovery(lookupToken: foundAccount.lookupToken, publicKey: publicKey)
            } else {
                result = try await APIClient.shared.startPasswordRecovery(identifier:identifier,publicKey:publicKey)
            }
            try Task.checkCancellation()
            let savedIdentifier = result.maskedEmail ?? identifier.trimmingCharacters(in:.whitespacesAndNewlines)
            let saved = PendingPasswordRecovery(identifier:savedIdentifier,
                requestId:result.requestId,statusToken:result.statusToken,matchCode:result.matchCode,expiresAt:result.expiresAt)
            try saved.save(); pending = saved; status = "PENDING"
        } catch {
            if let apiError = error as? APIClient.APIError,
               case let .serverError(_, message) = apiError,
               let message, !message.isEmpty {
                errorMessage = message
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
    @MainActor private func findAccount() async {
        guard !isWorking else { return }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let result = try await APIClient.shared.findRecoveryAccount(firstName: firstName, lastName: lastName, station: station)
            try Task.checkCancellation()
            foundAccount = result
        } catch {
            if let apiError = error as? APIClient.APIError,
               case let .serverError(_, message) = apiError, let message, !message.isEmpty {
                errorMessage = message
            } else { errorMessage = error.localizedDescription }
        }
    }
    @MainActor private func checkStatus() async {
        guard let pending, !isWorking, !completed else { return }
        do { status = try await APIClient.shared.passwordRecoveryStatus(pending).status; errorMessage = nil }
        catch { errorMessage = "Unable to check approval. Your request has been kept; please try again." }
    }
    @MainActor private func complete(_ pending: PendingPasswordRecovery) async {
        guard !isWorking else { return }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let challenge = try await APIClient.shared.passwordRecoveryChallenge(pending)
            let candidate = password
            let signature = try await Task.detached { try PasswordRecoveryDeviceKey.sign(challenge,password:candidate) }.value
            try Task.checkCancellation()
            let recoveredEmail = try await APIClient.shared.completePasswordRecovery(pending,signature:signature,password:password,confirmation:confirmation)
            if let recoveredEmail { identifier = recoveredEmail }
            PasswordRecoveryDeviceKey.remove(); completed = true; confirmation = ""
        } catch { errorMessage = error.localizedDescription }
    }
    @MainActor private func signIn() async {
        isWorking = true
        await session.login(email:identifier,password:password)
        isWorking = false
        if session.isLoggedIn { password = ""; dismiss() } else { errorMessage = session.errorMessage }
    }
}
