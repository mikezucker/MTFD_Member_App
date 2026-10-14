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

                            if ["ADMIN", "CHIEF"].contains(sessionManager.currentUser?.role ?? "") {
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
                            Task {
                                await sendTestPush()
                            }
                        } label: {
                            Text("Send Test Push")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)

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

    private func sendTestPush() async {
        do {
            try await APIClient.shared.sendTestPush()
        } catch {
            print("Test push failed:", error.localizedDescription)
        }
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
                    Section("Verify the member first") {
                        Text("Do not approve based only on an account name or a push notification. Verify the member using the established department procedure, then ask them to show or read the code on their requesting iPhone.")
                        Picker("Identity verified",selection:$method) {
                            Text("In person").tag("IN_PERSON")
                            Text("Established phone callback").tag("ESTABLISHED_PHONE")
                        }
                        if method == "ESTABLISHED_PHONE" {
                            Text("Use the member’s independently established department directory number. Do not use a new number supplied in a request or a recently changed profile number.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        TextField("Verification record / directory reference",text:$verificationReference,axis:.vertical)
                        Text("Record the procedure reference only; do not enter identity-document numbers, passwords, or other sensitive details.")
                            .font(.footnote).foregroundStyle(.secondary)
                        TextField("Code from the member’s iPhone",text:$matchCode)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    }
                    Section("Confirm your authorization") {
                        SecureField("Your current MTFD password",text:$password).textContentType(.password)
                        Button("Approve reset") { Task { await decide("APPROVE") } }
                            .disabled(verificationReference.trimmingCharacters(in:.whitespacesAndNewlines).count < 8 || matchCode.count != 6 || password.isEmpty)
                        Button("Deny request",role:.destructive) { Task { await decide("DENY") } }
                            .disabled(matchCode.count != 6 || password.isEmpty)
                    }
                }
                if isWorking { ProgressView("Saving decision…") }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .disabled(isWorking)
            .navigationTitle("Review Reset Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Close") { password = ""; dismiss() } } }
        }
    }
    @MainActor private func decide(_ decision: String) async {
        guard !isWorking else { return }
        isWorking = true; errorMessage = nil
        defer { isWorking = false; password = "" }
        do {
            try await APIClient.shared.decidePasswordRecovery(requestId:request.id,password:password,decision:decision,
                matchCode:matchCode.trimmingCharacters(in:.whitespacesAndNewlines).uppercased(),method:method,verificationReference:verificationReference)
            wasApproved = decision == "APPROVE"
            didFinish = true
        } catch { errorMessage = error.localizedDescription }
    }
}
