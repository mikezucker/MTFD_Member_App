import SwiftUI

struct MoreView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            AppScreen(title: "More") {
                AppDetailHeader(
                    title: "More",
                    subtitle: "Settings, profile, and additional tools.",
                    systemImage: "gearshape.fill"
                )

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
