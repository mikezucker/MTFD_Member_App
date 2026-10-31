import Combine
import SwiftUI

struct MoreView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var showLogoutConfirm = false
    @ObservedObject private var recoveryRouter = NavigationRouter.shared

    var body: some View {
        NavigationStack {
            AppScreen(
                title: "More",
                subtitle: "Settings, profile, and additional tools.",
                systemImage: "ellipsis.circle.fill"
            ) {
                ScrollView {
                    VStack(spacing: 18) {
                        if let member = sessionManager.currentUser {
                            NavigationLink {
                                ProfileView()
                            } label: {
                                profileCard(member: member)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 20)
                        }

                        VStack(spacing: 12) {
                            NavigationLink {
                                MessageCenterView(mode: .combined)
                            } label: {
                                    menuRow(
                                        title: "Messages",
                                        subtitle: "Dispatches, department messages, and announcements",
                                        emoji: "📬"
                                    )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                ScheduleView()
                            } label: {
                                    menuRow(
                                        title: "Schedule",
                                        subtitle: "Today’s FirstDue staffing and assignments",
                                        emoji: "📅"
                                    )
                            }
                            .buttonStyle(.plain)
                            if sessionManager.currentUser?.canAccessUniforms == true {
                                NavigationLink {
                                    UniformsView()
                                } label: {
                                    menuRow(
                                        title: "Uniforms",
                                        subtitle: "Uniform requests and gear information",
                                        emoji: "👕"
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            if sessionManager.currentUser?.canApprovePasswordRecovery == true {
                                Button {
                                    recoveryRouter.showPasswordRecoveryRequests = true
                                } label: {
                                    menuRow(title:"Password Recovery Requests",subtitle:"Review and authorize member account recovery",emoji:"🔐")
                                }
                                .buttonStyle(.plain)
                            }

                            if sessionManager.currentUser?.canManageUsers == true {
                                NavigationLink {
                                    UserAdminView()
                                } label: {
                                    menuRow(
                                        title: "User Admin",
                                        subtitle: "Review members and update reporting details",
                                        emoji: "👥"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            NavigationLink {
                                SettingsView()
                            } label: {
                                    menuRow(
                                        title: "Settings",
                                        subtitle: "Notification filters and app preferences",
                                        emoji: "⚙️"
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)

                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.horizontal, 24)
                            .padding(.top, 4)

                        Button {
                            showLogoutConfirm = true
                        } label: {
                            Text("Log Out")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.gold)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Are you sure you want to log out?",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Log Out", role: .destructive) {
                    sessionManager.logout()
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You will need to sign in again.")
            }
            
        }
        .task {
            if sessionManager.isLoggedIn, let response = try? await APIClient.shared.fetchCurrentUser() {
                sessionManager.currentUser = response.member
            }
        }
        .sheet(isPresented:$recoveryRouter.showPasswordRecoveryRequests) {
            AdminPasswordRecoveryView()
        }
    }


    private func profileCard(member: APIClient.Member) -> some View {
        HStack(spacing: 14) {
            emojiBadge("👤", size: 54, fontSize: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(verbatim: member.role)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))

                Text(verbatim: "ID: \(member.memberId ?? "N/A")")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))

                if let expiration = member.expiration, !expiration.isEmpty {
                    Text(verbatim: "Expires: \(expiration)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding()
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
    }

    private func menuRow(
        title: String,
        subtitle: String,
        emoji: String
    ) -> some View {
        HStack(spacing: 14) {
            emojiBadge(emoji)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding()
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func emojiBadge(_ emoji: String, size: CGFloat = 42, fontSize: CGFloat = 24) -> some View {
        Text(emoji)
            .font(.system(size: fontSize))
            .frame(width: size, height: size)
            .background(AppTheme.gold.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }


    
}

private struct UserAdminView: View {
    @StateObject private var viewModel = UserAdminViewModel()
    @State private var searchText = ""
    @State private var selectedUser: APIClient.MobileAdminUser?

    private var filteredUsers: [APIClient.MobileAdminUser] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return viewModel.users }
        return viewModel.users.filter { $0.searchableText.contains(query) }
    }

    var body: some View {
        AppScreen(
            title: "User Admin",
            subtitle: "Member roles, reporting, and station assignments.",
            systemImage: "person.2.fill"
        ) {
            ScrollView {
                VStack(spacing: 16) {
                    NavigationLink { MemberToursAdminView() } label: { Label("Tours & lieutenant assignments", systemImage: "person.3.fill") }.buttonStyle(.bordered).padding(.horizontal,24)
                    if viewModel.isLoading && viewModel.users.isEmpty {
                        ProgressView()
                            .tint(AppTheme.gold)
                            .padding(.top, 40)
                    } else if let errorMessage = viewModel.errorMessage, viewModel.users.isEmpty {
                        VStack(spacing: 12) {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.72))
                                .multilineTextAlignment(.center)

                            Button("Retry") {
                                Task { await viewModel.loadUsers() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.gold)
                        }
                        .padding(24)
                    } else {
                        searchField

                        LazyVStack(spacing: 10) {
                            ForEach(filteredUsers) { user in
                                Button {
                                    selectedUser = user
                                } label: {
                                    UserAdminRow(user: user)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)

                        if filteredUsers.isEmpty {
                            Text("No users match that search.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.65))
                                .padding(.top, 20)
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            .refreshable {
                await viewModel.loadUsers()
            }
        }
        .task {
            await viewModel.loadUsers()
        }
        .sheet(item: $selectedUser) { user in
            UserAdminEditView(
                user: user,
                users: viewModel.users,
                attributes: viewModel.attributes,
                canEditDepartmentRoles: viewModel.canEditDepartmentRoles
            ) { payload in
                try await viewModel.save(payload)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.52))

            TextField("Search users", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(.white)
        }
        .padding(12)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }
}

@MainActor
private final class UserAdminViewModel: ObservableObject {
    @Published var users: [APIClient.MobileAdminUser] = []
    @Published var attributes: [APIClient.MobileAdminAttribute] = []
    @Published var canEditDepartmentRoles = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.fetchMobileAdminUsers()
            users = response.users
            attributes = response.attributes ?? []
            canEditDepartmentRoles = response.canEditDepartmentRoles
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(_ payload: APIClient.MobileAdminUserUpdateRequest) async throws -> APIClient.MobileAdminUser {
        let response = try await APIClient.shared.updateMobileAdminUser(payload)
        if let index = users.firstIndex(where: { $0.id == response.user.id }) {
            users[index] = response.user
        }
        return response.user
    }
}

private struct UserAdminRow: View {
    let user: APIClient.MobileAdminUser

    var body: some View {
        HStack(spacing: 12) {
            Text(user.roleEmoji)
                .font(.system(size: 24))
                .frame(width: 42, height: 42)
                .background(AppTheme.gold.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(user.roleLabel)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.68))

                Text(user.companyLabel)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.52))
                    .lineLimit(1)

                if let attributes = user.attributes, !attributes.isEmpty {
                    Text(attributes.map(\.name).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(AppTheme.gold.opacity(0.85))
                        .lineLimit(1)
                } else if user.canPostStationMessages == true {
                    Text("Can send station messages")
                        .font(.caption2)
                        .foregroundColor(AppTheme.gold.opacity(0.85))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(user.status == "ACTIVE" ? "Active" : "Suspended")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(user.status == "ACTIVE" ? .green : .orange)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.42))
            }
        }
        .padding()
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct UserAdminEditView: View {
    @Environment(\.dismiss) private var dismiss

    let user: APIClient.MobileAdminUser
    let users: [APIClient.MobileAdminUser]
    let attributes: [APIClient.MobileAdminAttribute]
    let canEditDepartmentRoles: Bool
    let onSave: (APIClient.MobileAdminUserUpdateRequest) async throws -> APIClient.MobileAdminUser

    @State private var role: String
    @State private var status: String
    @State private var company: String?
    @State private var reportsToUserId: String?
    @State private var badgeNumber: String
    @State private var stationMessageDelegate: Bool
    @State private var selectedAttributeIds: Set<String>
    @State private var actorPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        user: APIClient.MobileAdminUser,
        users: [APIClient.MobileAdminUser],
        attributes: [APIClient.MobileAdminAttribute],
        canEditDepartmentRoles: Bool,
        onSave: @escaping (APIClient.MobileAdminUserUpdateRequest) async throws -> APIClient.MobileAdminUser
    ) {
        self.user = user
        self.users = users
        self.attributes = attributes
        self.canEditDepartmentRoles = canEditDepartmentRoles
        self.onSave = onSave
        _role = State(initialValue: user.role)
        _status = State(initialValue: user.status)
        _company = State(initialValue: user.company)
        _reportsToUserId = State(initialValue: user.reportsToUserId)
        _badgeNumber = State(initialValue: user.badgeNumber ?? "")
        _stationMessageDelegate = State(initialValue: user.stationMessageDelegate == true)
        _selectedAttributeIds = State(initialValue: Set(user.attributes?.map(\.id) ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Member") {
                    LabeledContent("Name", value: user.displayName)
                    LabeledContent("Email", value: user.email)
                    if let phone = user.phone, !phone.isEmpty {
                        LabeledContent("Phone", value: phone)
                    }
                }

                Section("Access") {
                    Picker("Role / member type", selection: $role) {
                        ForEach(roleOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    .disabled(!canEditDepartmentRoles)
                    if role != user.role && (["ADMIN", "CHIEF"].contains(role) || ["ADMIN", "CHIEF"].contains(user.role)) {
                        SecureField("Your current password",text:$actorPassword).textContentType(.password)
                    }

                    Picker("Status", selection: $status) {
                        Text("Active").tag("ACTIVE")
                        Text("Suspended").tag("SUSPENDED")
                    }
                }

                Section("Assignment") {
                    Picker("Company", selection: $company) {
                        Text("No company assigned").tag(nil as String?)
                        ForEach(companyOptions, id: \.value) { option in
                            Text(option.label).tag(option.value as String?)
                        }
                    }

                    Picker("Reports to", selection: $reportsToUserId) {
                        Text("No manager").tag(nil as String?)
                        ForEach(managerOptions, id: \.id) { manager in
                            Text("\(manager.displayName) (\(manager.roleLabel))")
                                .tag(manager.id as String?)
                        }
                    }

                    TextField("Badge #", text: $badgeNumber)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Section("Delegates") {
                    Toggle("Can Send Station Messages", isOn: $stationMessageDelegate)
                        .onChange(of: stationMessageDelegate) { _, isEnabled in
                            guard let stationDelegateAttributeId else { return }
                            if isEnabled {
                                selectedAttributeIds.insert(stationDelegateAttributeId)
                            } else {
                                selectedAttributeIds.remove(stationDelegateAttributeId)
                            }
                        }

                    if stationMessageDelegate && company == nil {
                        Text("Assign a company before saving a station message delegate.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if !attributes.isEmpty {
                    Section("Member Attributes") {
                        ForEach(attributes.filter { $0.isActive }) { attribute in
                            Toggle(isOn: attributeBinding(attribute.id)) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(attribute.name)
                                    if let description = attribute.description, !description.isEmpty {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving" : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private var managerOptions: [APIClient.MobileAdminUser] {
        users
            .filter { $0.id != user.id && $0.status == "ACTIVE" }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var roleOptions: [(value: String, label: String)] {
        let allOptions = [
            ("ADMIN", "Admin"),
            ("CHIEF", "Chief"),
            ("BATTALION_CHIEF", "Battalion Chief"),
            ("OFFICER_CAREER", "Officer (Career)"),
            ("OFFICER_VOLUNTEER", "Officer (Volunteer)"),
            ("MEMBER_CAREER", "Member (Career)"),
            ("MEMBER_VOLUNTEER", "Member (Volunteer)")
        ]

        if canEditDepartmentRoles {
            return allOptions
        }

        return allOptions.filter { option in
            option.0 == "OFFICER_VOLUNTEER"
                || option.0 == "MEMBER_CAREER"
                || option.0 == "MEMBER_VOLUNTEER"
        }
    }

    private var companyOptions: [(value: String, label: String)] {
        [
            ("MT_KEMBLE", "Mt. Kemble Fire Company (Station 1)"),
            ("COLLINSVILLE", "Collinsville Fire Company (Station 2)"),
            ("HILLSIDE", "Hillside Fire Company (Station 3)"),
            ("FAIRCHILD", "Fairchild Fire Company (Station 4)"),
            ("WOODLAND", "Woodland Fire Company (Station 5)"),
            ("FIRE_HQ", "Fire Headquarters")
        ]
    }

    private var stationDelegateAttributeId: String? {
        attributes.first { attribute in
            attribute.slug == "station_message_delegate"
        }?.id
    }

    private func attributeBinding(_ attributeId: String) -> Binding<Bool> {
        Binding(
            get: { selectedAttributeIds.contains(attributeId) },
            set: { isSelected in
                if isSelected {
                    selectedAttributeIds.insert(attributeId)
                } else {
                    selectedAttributeIds.remove(attributeId)
                }

                if attributeId == stationDelegateAttributeId {
                    stationMessageDelegate = isSelected
                }
            }
        )
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false; actorPassword = "" }

        let payload = APIClient.MobileAdminUserUpdateRequest(
            id: user.id,
            role: role,
            status: status,
            company: company,
            reportsToUserId: reportsToUserId,
            badgeNumber: badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            stationMessageDelegate: stationMessageDelegate,
            attributeIds: Array(selectedAttributeIds),
            actorPassword: actorPassword.isEmpty ? nil : actorPassword
        )

        do {
            _ = try await onSave(payload)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminPasswordRecoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var requests: [APIClient.AdminRecoveryRequest] = []
    @State private var selected: APIClient.AdminRecoveryRequest?
    @State private var isLoading = false
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PasswordRecoveryApproversView()
                    } label: {
                        Label("Manage Approvers", systemImage: "person.badge.key.fill")
                    }
                }
                if isLoading { ProgressView("Loading requests…") }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                if requests.isEmpty && !isLoading {
                    ContentUnavailableView("No pending requests",systemImage:"checkmark.shield",description:Text("Member password recovery requests will appear here."))
                }
                ForEach(requests) { request in
                    Button { selected = request } label: {
                        VStack(alignment:.leading,spacing:6) {
                            Text(request.user?.name ?? "Member").font(.headline)
                            Text(request.user?.email ?? "").font(.subheadline).foregroundStyle(.secondary)
                            Text("Request code: \(request.matchCode)").font(.body.monospaced())
                            Text("Expires \(request.expiresAt, style:.relative)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Password Recovery")
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement:.primaryAction) { Button("Refresh") { Task { await load() } } }
            }
            .refreshable { await load() }
            .task {
                await load()
                while !Task.isCancelled {
                    try? await Task.sleep(for:.seconds(15))
                    guard !Task.isCancelled else { break }
                    await load()
                }
            }
            .sheet(item:$selected,onDismiss:{Task{await load()}}) { request in
                AdminPasswordRecoveryDecisionView(request:request)
            }
        }
    }
    @MainActor private func load() async {
        guard !isLoading else { return }
        isLoading = true; defer { isLoading = false }
        do { requests = try await APIClient.shared.fetchPasswordRecoveryRequests(); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct AdminPasswordRecoveryDecisionView: View {
    @Environment(\.dismiss) private var dismiss
    let request: APIClient.AdminRecoveryRequest
    @State private var method = "IN_PERSON"
    @State private var verificationReference = ""
    @State private var matchCode = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var didFinish = false
    @State private var wasApproved = false
    @FocusState private var isEditing: Bool
    var body: some View {
        NavigationStack {
            Form {
                if didFinish {
                    Section {
                        Label("Request reviewed",systemImage:"checkmark.shield")
                        Text(wasApproved ? "Only the requesting iPhone can finish this reset. Existing sessions end when the member successfully creates a new password." : "This request was declined and cannot be used to reset the member’s password.")
                        Button("Done") { dismiss() }
                    }
                } else {
                    Section("Member") {
                        Text(request.user?.name ?? "Member").font(.headline)
                        Text(request.user?.email ?? "").foregroundStyle(.secondary)
                        LabeledContent("Requested",value:request.createdAt.formatted(date:.abbreviated,time:.shortened))
                    }
                    Section {
                        Text("Confirm you are speaking with the member before approving a reset.")
                        Picker("How did you confirm their identity?",selection:$method) {
                            Text("In person").tag("IN_PERSON")
                            Text("Phone call").tag("ESTABLISHED_PHONE")
                        }
                        .pickerStyle(.segmented)
                        if method == "ESTABLISHED_PHONE" {
                            Text("Call the member using the number already in the department directory.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        VStack(alignment:.leading,spacing:6) {
                            Text("How you verified the member")
                            TextField(method == "IN_PERSON" ? "Example: Spoke in person at Station 1" : "Example: Called number in department directory",text:$verificationReference,axis:.vertical)
                                .focused($isEditing)
                                .lineLimit(2...3)
                        }
                    } header: {
                        Text("1. Confirm the member")
                    } footer: {
                        Text("To approve, enter a short note of at least 8 characters. Do not include passwords or sensitive personal details.")
                    }
                    Section {
                        Text("Ask the member to read or show the 6-character code on the iPhone they used to request this reset.")
                        VStack(alignment:.leading,spacing:6) {
                            Text("Code from the member’s iPhone")
                            TextField("Enter 6-character code",text:$matchCode)
                                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                                .focused($isEditing)
                        }
                    } header: {
                        Text("2. Enter the member’s code")
                    }
                    Section {
                        VStack(alignment:.leading,spacing:6) {
                            Text("Your MTFD password")
                            SecureField("Enter your own password",text:$password)
                                .textContentType(.password)
                                .focused($isEditing)
                        }
                    } header: {
                        Text("3. Authorize your decision")
                    } footer: {
                        Text("Use your own password, not the member’s. Both Approve and Deny require the member’s code and your password.")
                    }
                    Section {
                        Button("Approve password reset") { Task { await decide("APPROVE") } }
                        Button("Deny request",role:.destructive) { Task { await decide("DENY") } }
                    } footer: {
                        Text("Approval lets the member create a new password on their requesting iPhone.")
                    }
                }
                if isWorking { ProgressView("Saving decision…") }

            }
            .disabled(isWorking)
            .scrollDismissesKeyboard(.interactively)
            .alert("Check reset request",isPresented:Binding(get:{errorMessage != nil},set:{if !$0 { errorMessage = nil }})) {
                Button("OK",role:.cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .navigationTitle("Review Reset Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Close") { password = ""; dismiss() } }
                ToolbarItemGroup(placement:.keyboard) {
                    Spacer()
                    Button("Done") { isEditing = false }
                }
            }
        }
    }
    @MainActor private func decide(_ decision: String) async {
        guard !isWorking else { return }
        isEditing = false
        var missing: [String] = []
        let reference = verificationReference.trimmingCharacters(in:.whitespacesAndNewlines)
        let code = matchCode.trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
        if decision == "APPROVE" && reference.count < 8 {
            missing.append("Add a short note explaining how you verified the member (at least 8 characters).")
        }
        if decision == "APPROVE" && reference.count > 200 {
            missing.append("Keep your verification note to 200 characters or fewer.")
        }
        if code.count != 6 { missing.append("Enter the 6-character code from the member’s requesting iPhone.") }
        if password.isEmpty { missing.append("Enter your own MTFD password to authorize this decision.") }
        guard missing.isEmpty else {
            errorMessage = missing.joined(separator:"\n\n")
            return
        }
        isWorking = true; errorMessage = nil
        defer { isWorking = false; password = "" }
        do {
            try await APIClient.shared.decidePasswordRecovery(requestId:request.id,password:password,decision:decision,
                matchCode:code,method:method,verificationReference:reference)
            wasApproved = decision == "APPROVE"
            didFinish = true
        } catch { errorMessage = error.localizedDescription }
    }
}


private struct PasswordRecoveryApproversView: View {
    @State private var members: [APIClient.RecoveryApproverMember] = []
    @State private var selectedMember: APIClient.RecoveryApproverMember?
    @State private var search = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var filteredMembers: [APIClient.RecoveryApproverMember] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return members.filter { query.isEmpty || ($0.name ?? "").localizedCaseInsensitiveContains(query) || $0.email.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            if isLoading { ProgressView("Loading members…") }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            Section {
                ForEach(filteredMembers.filter { $0.canApprove }) { member in
                    memberRow(member)
                }
            } header: { Text("Current Approvers") } footer: {
                Text("Approvers can review password recovery requests and add or remove other approvers. Admin and Chief access comes from their department role.")
            }
            Section("Add an Approver") {
                ForEach(filteredMembers.filter { !$0.canApprove }) { member in
                    memberRow(member)
                }
            }
        }
        .navigationTitle("Recovery Approvers")
        .searchable(text: $search, prompt: "Find a member")
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selectedMember, onDismiss: { Task { await load() } }) { member in
            RecoveryApproverAccessView(member: member)
        }
    }

    private func memberRow(_ member: APIClient.RecoveryApproverMember) -> some View {
        Button { selectedMember = member } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name ?? "Member").foregroundStyle(.primary)
                    Text(member.email).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if member.inheritedRoleAccess {
                    Text(member.role == "CHIEF" ? "Chief" : "Admin").font(.caption)
                } else if member.isCurrentUser {
                    Text("You").font(.caption)
                } else {
                    Image(systemName: member.canApprove ? "person.badge.minus" : "person.badge.plus")
                }
            }
        }
        .disabled(member.inheritedRoleAccess || member.isCurrentUser)
    }

    @MainActor private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            members = try await APIClient.shared.fetchRecoveryApprovers()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct RecoveryApproverAccessView: View {
    @Environment(\.dismiss) private var dismiss
    let member: APIClient.RecoveryApproverMember
    @State private var password = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Member") {
                    Text(member.name ?? "Member").font(.headline)
                    Text(member.email).foregroundStyle(.secondary)
                }
                Section {
                    Text(member.canApprove
                         ? "Remove this member’s ability to approve password recovery requests and manage other approvers. Pending approvals they issued will be invalidated."
                         : "This member will be able to approve password recovery requests and add or remove other approvers. Their department role stays the same.")
                    SecureField("Your current MTFD password", text: $password).textContentType(.password)
                    if member.canApprove {
                        Button("Remove Approver Access", role: .destructive) { Task { await save() } }
                            .disabled(password.isEmpty || isSaving)
                    } else {
                        Button("Add Approver Access") { Task { await save() } }
                            .disabled(password.isEmpty || isSaving)
                    }
                    if isSaving { ProgressView("Saving access…") }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                } header: { Text("Confirm access change") } footer: {
                    Text("This change is recorded in the security audit log.")
                }
            }
            .navigationTitle(member.canApprove ? "Remove Approver" : "Add Approver")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { password = ""; dismiss() }.disabled(isSaving)
                }
            }
        }
    }

    @MainActor private func save() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false; password = "" }
        do {
            try await APIClient.shared.setRecoveryApprover(userId: member.id, enabled: !member.canApprove, password: password)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct AdminTourRecord: Decodable, Identifiable {
    let id: String
    let name: String
    let isActive: Bool
    let lieutenantId: String?
    let revision: Int
}
private struct AdminTourMember: Decodable, Identifiable {
    let id: String
    let name: String?
    let role: String
    let status: String
    let tourId: String?
}
private struct AdminTourSnapshot: Decodable {
    let tours: [AdminTourRecord]
    let users: [AdminTourMember]
    let token: String
}
private struct AdminTourMutation: Decodable { let success: Bool }
private struct MemberToursAdminView: View {
    @State private var data: AdminTourSnapshot?
    @State private var selected: AdminTourRecord?
    @State private var creating = false
    @State private var newName = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        AppScreen(title: "Tours", subtitle: "Home tours, lieutenants and members", systemImage: "person.3.fill") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tour names and assignments are managed here. The live on-duty roster is separate.").font(.subheadline).foregroundStyle(.secondary)
                    if let error { Text(error).foregroundStyle(.red); Button("Reload") { Task { await load() } } }
                    Button("Add tour") { creating = true }.buttonStyle(.borderedProminent)
                    if let data {
                        ForEach(data.tours.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { tour in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(tour.name + (tour.isActive ? "" : " · Archived")).font(.headline)
                                Text("Lieutenant: " + (data.users.first { $0.id == tour.lieutenantId }?.name ?? "Not assigned"))
                                Text("\(data.users.filter { $0.tourId == tour.id }.count) members assigned").font(.caption).foregroundStyle(.secondary)
                                Button("Edit tour & members") { selected = tour }.buttonStyle(.bordered)
                            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        }
                    } else if error == nil { ProgressView("Loading tours…") }
                }.padding(16)
            }.refreshable { await load() }
        }.task { await load() }.navigationTitle("Tours").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected, onDismiss: { Task { await load() } }) { tour in
            if let data { MemberTourEditor(tour: tour, data: data) }
        }
        .sheet(isPresented: $creating) {
            NavigationStack { Form {
                TextField("Tour name", text: $newName)
                if let error { Text(error).foregroundStyle(.red) }
                Button(busy ? "Creating…" : "Create tour") { Task { await create() } }.disabled(busy || newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.navigationTitle("New tour").toolbar { Button("Cancel") { creating = false }.disabled(busy) }.interactiveDismissDisabled(busy) }
        }
    }
    @MainActor private func load() async {
        do { data = try await APIClient.shared.memberTours(); error = nil }
        catch { if !APIClient.isRequestCancellation(error) { self.error = error.localizedDescription } }
    }
    @MainActor private func create() async {
        guard let data else { return }; busy = true; defer { busy = false }
        do {
            let body: [String:Any] = ["action":"create","token":data.token,"name":newName]
            let _: AdminTourMutation = try await APIClient.shared.memberTours(body: JSONSerialization.data(withJSONObject: body))
            creating = false; newName = ""; await load()
        } catch { self.error = error.localizedDescription }
    }
}
private struct MemberTourEditor: View {
    let tour: AdminTourRecord
    let data: AdminTourSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var lieutenant: String
    @State private var selected: Set<String>
    @State private var active: Bool
    @State private var confirmMoves = false
    @State private var search = ""
    @State private var busy = false
    @State private var error: String?
    init(tour: AdminTourRecord, data: AdminTourSnapshot) {
        self.tour = tour; self.data = data
        _name = State(initialValue: tour.name); _lieutenant = State(initialValue: tour.lieutenantId ?? "")
        _selected = State(initialValue: Set(data.users.filter { $0.tourId == tour.id }.map(\.id)))
        _active = State(initialValue: tour.isActive)
    }
    private var moves: [AdminTourMember] { data.users.filter { selected.contains($0.id) && $0.tourId != nil && $0.tourId != tour.id } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Tour") {
                    TextField("Name", text: $name)
                    Picker("Lieutenant", selection: $lieutenant) {
                        Text("Not assigned").tag("")
                        ForEach(data.users.filter { $0.status == "ACTIVE" && $0.role == "OFFICER_CAREER" }) { Text($0.name ?? "Unnamed officer").tag($0.id) }
                    }.onChange(of: lieutenant) { _,id in if !id.isEmpty { selected.insert(id) } }
                    Toggle("Active tour", isOn: $active)
                    Text("The lieutenant can assign and evaluate this tour’s training. Reassign members and clear the lieutenant before archiving.").font(.caption)
                }
                if let error { Section { Text(error).foregroundStyle(.red); Text("If assignments changed elsewhere, cancel and reload the tour list before editing again.").font(.caption) } }
                Section("Members · \(selected.count) selected") {
                    TextField("Find a member", text: $search)
                    Button("Clear members") { selected = [] }
                    ForEach(data.users.filter { ($0.status == "ACTIVE" || $0.tourId == tour.id) && (search.isEmpty || ($0.name ?? "").localizedCaseInsensitiveContains(search)) }.sorted { ($0.name ?? "") < ($1.name ?? "") }) { member in
                        Toggle(isOn: Binding(get: { selected.contains(member.id) }, set: { if $0 { selected.insert(member.id) } else { selected.remove(member.id) } })) {
                            VStack(alignment: .leading) { Text(member.name ?? "Unnamed member"); Text(data.tours.first { $0.id == member.tourId }?.name ?? "No tour assigned").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                if !moves.isEmpty { Section("Tour transfers") {
                    ForEach(moves) { member in Text((member.name ?? "Member") + " from " + (data.tours.first { $0.id == member.tourId }?.name ?? "another tour")) }
                    Toggle("Confirm moving these members into this tour", isOn: $confirmMoves)
                } }
                Section { Button(busy ? "Saving…" : "Save tour & assignments") { Task { await save() } }.disabled(busy || (!moves.isEmpty && !confirmMoves) || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }.disabled(busy).navigationTitle("Edit tour").toolbar { Button("Cancel") { dismiss() }.disabled(busy) }.interactiveDismissDisabled(busy)
        }
    }
    @MainActor private func save() async {
        busy = true; defer { busy = false }
        do {
            let body: [String:Any] = ["action":"update","id":tour.id,"token":data.token,"name":name,"isActive":active,"lieutenantId":lieutenant.isEmpty ? NSNull() : lieutenant as Any,"memberIds":Array(selected),"confirmMoves":confirmMoves]
            let _: AdminTourMutation = try await APIClient.shared.memberTours(body: JSONSerialization.data(withJSONObject: body)); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
