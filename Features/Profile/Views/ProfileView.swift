import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: SessionManager

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""

    @State private var hasLoadedInitialValues = false
    @State private var isSaving = false
    @State private var showConfirmUpdate = false
    @State private var successMessage: String?
    @State private var errorMessage: String?

    private var member: APIClient.Member? {
        session.currentUser
    }

    private var hasChanges: Bool {
        guard let member else { return false }

        return name.trimmingCharacters(in: .whitespacesAndNewlines) != member.name.trimmingCharacters(in: .whitespacesAndNewlines)
            || email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != (member.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            || phone.trimmingCharacters(in: .whitespacesAndNewlines) != (member.phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        AppScreen(title: "Profile") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let member {
                        profileHeader(member)

                        infoSection(
                            title: "Member Details",
                            rows: [
                                ProfileInfoRow(label: "Role", value: member.role),
                                ProfileInfoRow(label: "Station", value: StationMapper.displayName(from: member.company)),
                                ProfileInfoRow(label: "Member ID", value: member.memberId ?? "N/A"),
                                ProfileInfoRow(label: "Status", value: member.expiration ?? "ACTIVE"),
                                ProfileInfoRow(label: "Email", value: member.email ?? "Not listed"),
                                ProfileInfoRow(label: "Phone", value: member.phone?.isEmpty == false ? member.phone! : "Not listed")
                            ]
                        )

                        editSection
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .task {
            loadInitialValuesIfNeeded()
        }
        .onChange(of: session.currentUser?.email) { _, _ in
            loadInitialValues(force: true)
        }
        .alert("Confirm Profile Update", isPresented: $showConfirmUpdate) {
            Button("Cancel", role: .cancel) {}

            Button("Update & Sync") {
                Task {
                    await saveProfile()
                }
            }
        } message: {
            Text("These changes will update your department profile and sync to FirstDue. Confirm the information is accurate before submitting.")
        }
    }

    private func loadInitialValuesIfNeeded() {
        guard !hasLoadedInitialValues else { return }
        loadInitialValues(force: true)
    }

    private func loadInitialValues(force: Bool = false) {
        guard force || !hasLoadedInitialValues else { return }
        guard let member else { return }

        name = member.name
        email = member.email ?? ""
        phone = member.phone ?? ""
        hasLoadedInitialValues = true
    }

    private func saveProfile() async {
        guard !isSaving else { return }

        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedName.isEmpty else {
            errorMessage = "Name cannot be blank."
            successMessage = nil
            return
        }

        guard !cleanedEmail.isEmpty else {
            errorMessage = "Email cannot be blank."
            successMessage = nil
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            try await session.updateProfile(
                name: cleanedName,
                email: cleanedEmail,
                phone: cleanedPhone.isEmpty ? nil : cleanedPhone
            )

            loadInitialValues(force: true)
            successMessage = "Profile updated and synced to FirstDue."
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func submitTapped() {
        successMessage = nil
        errorMessage = nil

        guard hasChanges else {
            errorMessage = "No profile changes detected."
            return
        }

        showConfirmUpdate = true
    }

    private func profileHeader(_ member: APIClient.Member) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 76, height: 76)

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(AppTheme.gold)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(member.name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)

                Text(member.role)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.gold)

                Text(StationMapper.displayName(from: member.company))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.68))
            }

            Spacer()
        }
        .padding(18)
        .background(Color.white.opacity(0.09))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var editSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Edit Profile")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Safe contact fields can be updated here. Changes sync to FirstDue after confirmation.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            profileTextField(title: "Name", text: $name, keyboardType: .default)
            profileTextField(title: "Email", text: $email, keyboardType: .emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            profileTextField(title: "Phone", text: $phone, keyboardType: .phonePad)

            if let successMessage {
                statusMessage(successMessage, systemImage: "checkmark.circle.fill", color: .green)
            }

            if let errorMessage {
                statusMessage(errorMessage, systemImage: "exclamationmark.triangle.fill", color: .orange)
            }

            Button {
                submitTapped()
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(isSaving ? "Updating..." : "Review & Update")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(hasChanges && !isSaving ? AppTheme.gold : Color.white.opacity(0.14))
                .foregroundColor(hasChanges && !isSaving ? .black : .white.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isSaving || !hasChanges)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func profileTextField(
        title: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.62))
                .textCase(.uppercase)

            TextField(title, text: text)
                .keyboardType(keyboardType)
                .textContentType(textContentType(for: title))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .tint(AppTheme.gold)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func textContentType(for title: String) -> UITextContentType? {
        switch title {
        case "Name":
            return .name
        case "Email":
            return .emailAddress
        case "Phone":
            return .telephoneNumber
        default:
            return nil
        }
    }

    private func statusMessage(_ message: String, systemImage: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func infoSection(title: String, rows: [ProfileInfoRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack(alignment: .top) {
                        Text(row.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.58))
                            .frame(width: 105, alignment: .leading)

                        Text(row.value)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.90))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 12)

                    if row.id != rows.last?.id {
                        Divider()
                            .background(Color.white.opacity(0.12))
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No profile loaded")
                .font(.headline)
                .foregroundColor(.white)

            Text("Sign in again to view your member profile.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.68))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct ProfileInfoRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

#Preview {
    ProfileView()
        .environmentObject(SessionManager.shared)
}
