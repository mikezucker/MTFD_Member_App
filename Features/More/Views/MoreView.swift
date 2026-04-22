import SwiftUI

struct MoreView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var showLogoutConfirm = false

    var body: some View {
        AppScreen(title: "More") {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 20)

                if let member = sessionManager.currentUser {
                    VStack(spacing: 6) {
                        Text(member.name)
                            .font(.headline)
                            .foregroundColor(.white)

                        Text(member.role)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.75))

                        Text("ID: \(member.memberId)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        Text("Expires: \(member.expiration)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.2))
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

                Spacer()
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
