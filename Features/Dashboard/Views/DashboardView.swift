import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var viewModel = DashboardViewModel()

    @State private var showContent = false
    @State private var showMessageModal = false
    @AppStorage("dashboardTotalsWindow") private var selectedWindowRawValue = DashboardTotalsWindow.ytd.rawValue

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.18, blue: 0.38),
                        Color(red: 0.03, green: 0.10, blue: 0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    DashboardHeaderView(
                        firstName: firstName,
                        roleTitle: memberRoleDisplayName(from: session.currentUser?.role),
                        unreadCount: 0,
                        onTapMessages: {
                            handleNavigation(to: .messageCenter)
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.06, green: 0.18, blue: 0.38),
                                Color(red: 0.03, green: 0.10, blue: 0.22)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            DashboardCallSummarySection(
                                selectedWindowRawValue: $selectedWindowRawValue,
                                department: viewModel.state.dashboardDepartment,
                                station: viewModel.state.dashboardStation,
                                isLoading: viewModel.state.isLoading
                            )

                            if !viewModel.state.stationUpdates.isEmpty {
                                sectionTitle("Station Update")

                                VStack(spacing: 10) {
                                    ForEach(viewModel.state.stationUpdates) { update in
                                        DashboardUpdateBlock(update: update)
                                    }
                                }
                            }

                            if !viewModel.state.departmentUpdates.isEmpty {
                                sectionTitle("Dept. Update")

                                VStack(spacing: 10) {
                                    ForEach(viewModel.state.departmentUpdates) { update in
                                        DashboardUpdateBlock(update: update)
                                    }
                                }
                            }

                            if !viewModel.state.attentionItems.isEmpty {
                                sectionTitle("Needs Attention")

                                ForEach(viewModel.state.attentionItems) { item in
                                    DashboardAttentionCard(item: item) {
                                        handleNavigation(to: item.destination)
                                    }
                                }
                            }

                            if !viewModel.state.progressItems.isEmpty {
                                sectionTitle("Progress")

                                ForEach(viewModel.state.progressItems) { item in
                                    ProgressCard(
                                        title: item.title,
                                        progress: item.progress
                                    )
                                    .onTapGesture {
                                        handleNavigation(to: item.destination)
                                    }
                                }
                            }

                            if !viewModel.state.quickActions.isEmpty {
                                sectionTitle("Quick Actions")

                                LazyVGrid(columns: gridColumns, spacing: 12) {
                                    ForEach(viewModel.state.quickActions) { action in
                                        DashboardQuickActionTile(action: action) { destination in
                                            handleNavigation(to: destination)
                                        }
                                    }
                                }
                            }

                            if let errorMessage = viewModel.state.errorMessage, !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.78))
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 16)
                        .animation(.easeInOut(duration: 0.35), value: showContent)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                showContent = true
                viewModel.load(role: mappedUserRole(from: session.currentUser?.role))

                if hasNewMessage {
                    showMessageModal = true
                }
            }
            .sheet(isPresented: $showMessageModal) {
                Text("New Message")
                    .font(.title)
                    .padding()
            }
        }
    }

    private var firstName: String {
        let fullName = session.currentUser?.name ?? ""

        if fullName.isEmpty {
            return "Member"
        }

        return fullName.components(separatedBy: " ").first ?? "Member"
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }

    private var hasNewMessage: Bool {
        false
    }

    @ViewBuilder
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.top, 4)
    }

    private func mappedUserRole(from rawRole: String?) -> UserRole {
        guard let rawRole = rawRole?.uppercased() else {
            return .member
        }

        if rawRole == "ADMIN" || rawRole == "CHIEF" {
            return .chief
        } else if rawRole == "OFFICER" || rawRole == "OFFICER_CAREER" || rawRole == "OFFICER_VOLUNTEER" {
            return .officer
        } else {
            return .member
        }
    }

    private func memberRoleDisplayName(from rawRole: String?) -> String {
        guard let rawRole = rawRole?.uppercased() else {
            return "Member"
        }

        switch rawRole {
        case "ADMIN":
            return "Administrator"
        case "CHIEF":
            return "Chief"
        case "OFFICER_CAREER":
            return "Career Officer"
        case "OFFICER_VOLUNTEER":
            return "Volunteer Officer"
        case "MEMBER_CAREER":
            return "Career Member"
        case "MEMBER_VOLUNTEER":
            return "Volunteer Member"
        default:
            return "Member"
        }
    }

    private func handleNavigation(to destination: AppDestination) {
        print("Navigate to: \(destination)")
    }
}

private struct DashboardUpdateBlock: View {
    let update: DashboardBulletin

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(update.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Text(update.message)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.82))

            if let updatedAt = update.updatedAt, !updatedAt.isEmpty {
                Text(updatedAt)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}

#Preview {
    DashboardView()
        .environmentObject(SessionManager.shared)
}
