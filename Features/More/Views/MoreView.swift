import Combine
import SwiftUI

struct MoreView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            AppScreen(
                title: "More",
                subtitle: "Settings, profile, and additional tools.",
                systemImage: "gearshape.fill"
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
                                ScheduleView()
                            } label: {
                                menuRow(
                                    title: "Schedule",
                                    subtitle: "Today’s FirstDue staffing and assignments",
                                    systemImage: "calendar.badge.clock"
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
                                        systemImage: "tshirt.fill"
                                    )
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
                                        systemImage: "person.2.badge.gearshape.fill"
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
                                    systemImage: "gearshape.fill"
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
    }

    private func profileCard(member: APIClient.Member) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 46))
                .foregroundStyle(AppTheme.gold)

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
        systemImage: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.gold)
                .frame(width: 28)

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

    private func sendTestPush() async {
        guard let authToken = APIClient.shared.authToken, !authToken.isEmpty else {
            print("❌ No auth token available")
            return
        }

        guard let url = URL(string: "https://new-mtfd-site.vercel.app/api/admin/push/test") else {
            print("❌ Invalid test push URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "title": "MTFD Test Push",
            "body": "If this buzzes, the pipeline is alive."
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse {
                print("✅ Test push status: \(http.statusCode)")
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Test push response: \(responseString)")
            }
        } catch {
            print("❌ Test push failed: \(error)")
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
            systemImage: "person.2.badge.gearshape.fill"
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
            ZStack {
                Circle()
                    .fill(AppTheme.gold.opacity(0.18))
                    .frame(width: 42, height: 42)

                Image(systemName: "person.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.gold)
            }

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
    let canEditDepartmentRoles: Bool
    let onSave: (APIClient.MobileAdminUserUpdateRequest) async throws -> APIClient.MobileAdminUser

    @State private var role: String
    @State private var status: String
    @State private var company: String?
    @State private var reportsToUserId: String?
    @State private var badgeNumber: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        user: APIClient.MobileAdminUser,
        users: [APIClient.MobileAdminUser],
        canEditDepartmentRoles: Bool,
        onSave: @escaping (APIClient.MobileAdminUserUpdateRequest) async throws -> APIClient.MobileAdminUser
    ) {
        self.user = user
        self.users = users
        self.canEditDepartmentRoles = canEditDepartmentRoles
        self.onSave = onSave
        _role = State(initialValue: user.role)
        _status = State(initialValue: user.status)
        _company = State(initialValue: user.company)
        _reportsToUserId = State(initialValue: user.reportsToUserId)
        _badgeNumber = State(initialValue: user.badgeNumber ?? "")
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

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let payload = APIClient.MobileAdminUserUpdateRequest(
            id: user.id,
            role: role,
            status: status,
            company: company,
            reportsToUserId: reportsToUserId,
            badgeNumber: badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            _ = try await onSave(payload)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
