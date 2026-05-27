import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        AppScreen(title: "Profile") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let member = session.currentUser {
                        profileHeader(member)

                        infoSection(
                            title: "Member Details",
                            rows: [
                                ProfileInfoRow(label: "Role", value: member.role),
                                ProfileInfoRow(label: "Station", value: StationMapper.displayName(from: member.company)),
                                ProfileInfoRow(label: "Member ID", value: member.memberId ?? "N/A"),
                                ProfileInfoRow(label: "Status", value: member.expiration ?? "ACTIVE"),
                                ProfileInfoRow(label: "Email", value: member.email ?? "Not listed")
                            ]
                        )

                        readOnlyNotice
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
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

    private var readOnlyNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile changes")
                .font(.headline)
                .foregroundColor(.white)

            Text("Official profile fields are currently read-only. Future edits should go through the main MTFD backend before syncing approved fields to FirstDue.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
