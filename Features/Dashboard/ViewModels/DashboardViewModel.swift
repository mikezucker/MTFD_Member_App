import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var state: DashboardState = .empty(for: .member)

    func load(role: UserRole) {
        Task {
            await loadDashboard(role: role)
        }
    }

    private func loadDashboard(role: UserRole) async {
        state = DashboardState(
            greeting: state.greeting,
            role: role,
            alerts: state.alerts,
            stationUpdates: state.stationUpdates,
            departmentUpdates: state.departmentUpdates,
            attentionItems: state.attentionItems,
            quickActions: state.quickActions,
            progressItems: state.progressItems,
            stationCallTotal: state.stationCallTotal,
            departmentCallTotal: state.departmentCallTotal,
            dashboardDepartment: state.dashboardDepartment,
            dashboardStation: state.dashboardStation,
            lastUpdated: state.lastUpdated,
            recentDepartmentCalls: state.recentDepartmentCalls,
            isLoading: true,
            errorMessage: nil
        )

        do {
            let dashboard = try await APIClient.shared.fetchDashboard()

            let departmentYtd = dashboard.department?.totalYtd
            let stationYtd = dashboard.station?.totalYtd

            state = DashboardState(
                greeting: "Welcome",
                role: role,
                alerts: [],
                stationUpdates: mapBulletins(from: dashboard.stationUpdates ?? []),
                departmentUpdates: mapBulletins(from: dashboard.departmentUpdates ?? []),
                attentionItems: buildAttentionItems(for: role),
                quickActions: buildQuickActions(for: role),
                progressItems: buildProgressItems(for: role),
                stationCallTotal: stationYtd,
                departmentCallTotal: departmentYtd,
                dashboardDepartment: dashboard.department,
                dashboardStation: dashboard.station,
                lastUpdated: dashboard.lastUpdated,
                recentDepartmentCalls: [],
                isLoading: false,
                errorMessage: nil
            )
        } catch {
            state = DashboardState(
                greeting: "Welcome",
                role: role,
                alerts: [],
                stationUpdates: [],
                departmentUpdates: [],
                attentionItems: buildAttentionItems(for: role),
                quickActions: buildQuickActions(for: role),
                progressItems: buildProgressItems(for: role),
                stationCallTotal: nil,
                departmentCallTotal: nil,
                dashboardDepartment: nil,
                dashboardStation: nil,
                lastUpdated: nil,
                recentDepartmentCalls: [],
                isLoading: false,
                errorMessage: error.localizedDescription
            )

            print("Dashboard load failed: \(error.localizedDescription)")
        }
    }

    private func mapBulletins(from updates: [APIClient.DashboardUpdate]) -> [DashboardBulletin] {
        updates.map {
            DashboardBulletin(
                id: $0.id,
                title: $0.title,
                message: $0.message,
                updatedAt: $0.updatedAt
            )
        }
    }

    private func buildAttentionItems(for role: UserRole) -> [DashboardAttentionItem] {
        switch role {
        case .chief:
            return [
                DashboardAttentionItem(
                    title: "Training Reviews Pending",
                    subtitle: "Officer and member training items need review",
                    actionLabel: "Open",
                    destination: .trainingAssigned
                ),
                DashboardAttentionItem(
                    title: "Department Messages",
                    subtitle: "Review important department communication",
                    actionLabel: "Open",
                    destination: .messageCenter
                )
            ]

        case .officer:
            return [
                DashboardAttentionItem(
                    title: "Crew Training Queue",
                    subtitle: "Assigned training and approvals need attention",
                    actionLabel: "Open",
                    destination: .trainingAssigned
                ),
                DashboardAttentionItem(
                    title: "Company Messages",
                    subtitle: "Review important company communication",
                    actionLabel: "Open",
                    destination: .messageCenter
                )
            ]

        case .member:
            return [
                DashboardAttentionItem(
                    title: "Assigned Training",
                    subtitle: "You have training items ready to complete",
                    actionLabel: "Open",
                    destination: .trainingAssigned
                ),
                DashboardAttentionItem(
                    title: "Department Messages",
                    subtitle: "Check the latest department communication",
                    actionLabel: "Open",
                    destination: .messageCenter
                )
            ]
        }
    }

    private func buildQuickActions(for role: UserRole) -> [DashboardQuickAction] {
        [
            DashboardQuickAction(
                title: "Training",
                systemImage: "graduationcap.fill",
                destination: .trainingAssigned
            ),
            DashboardQuickAction(
                title: "Messages",
                systemImage: "bubble.left.and.bubble.right.fill",
                destination: .messageCenter
            )
        ]
    }

    private func buildProgressItems(for role: UserRole) -> [DashboardProgressItem] {
        switch role {
        case .chief, .officer:
            return [
                DashboardProgressItem(
                    title: "Training Completion",
                    progress: 0.65,
                    subtitle: "Crew assigned vs completed",
                    destination: .trainingAssigned
                )
            ]

        case .member:
            return [
                DashboardProgressItem(
                    title: "Assigned Training",
                    progress: 0.40,
                    subtitle: "Your assigned vs completed training",
                    destination: .trainingAssigned
                )
            ]
        }
    }
}
