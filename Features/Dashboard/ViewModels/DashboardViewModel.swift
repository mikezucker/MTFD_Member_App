import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var state: DashboardState = .empty(for: .member)
    @Published var activeDispatches: [APIClient.ActiveDispatch] = []

    private var hasLoaded = false
    private var isLoadingDashboard = false
    private var lastLoadedAt: Date?
    private let minimumRefreshInterval: TimeInterval = 60

    func loadIfNeeded(role: UserRole) {
        guard !hasLoaded else { return }

        Task {
            await loadDashboard(role: role, force: false)
        }
    }

    func refresh(role: UserRole) {
        Task {
            await loadDashboard(role: role, force: true)
        }
    }

    func refreshIfStale(role: UserRole) {
        if let lastLoadedAt, Date().timeIntervalSince(lastLoadedAt) < minimumRefreshInterval {
            return
        }

        Task {
            await loadDashboard(role: role, force: true)
        }
    }

    func addActiveDispatch(from dispatch: DispatchNotificationPayload) {
        let activeDispatch = APIClient.ActiveDispatch(
            id: dispatch.id,
            callType: dispatch.callType ?? dispatch.title,
            address: dispatch.address,
            placeName: nil,
            message: dispatch.address,
            units: dispatch.units,
            dispatchedAt: Date(),
            priority: "HIGH",
            isWorkingFire: isLikelyWorkingFire(dispatch)
        )
        activeDispatches.removeAll { $0.id == activeDispatch.id }
        activeDispatches.insert(activeDispatch, at: 0)
    }

    private func loadDashboard(role: UserRole, force: Bool) async {
        guard !isLoadingDashboard else { return }

        if !force, hasLoaded {
            return
        }

        isLoadingDashboard = true
        defer { isLoadingDashboard = false }

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

            activeDispatches = dashboard.activeDispatches ?? []

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

            hasLoaded = true
            lastLoadedAt = Date()
        } catch {
            activeDispatches = []

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

    private func isLikelyWorkingFire(_ dispatch: DispatchNotificationPayload) -> Bool {
        let combinedText = [
            dispatch.title,
            dispatch.callType,
            dispatch.body
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        return combinedText.contains("working fire") ||
            combinedText.contains("structure fire") ||
            combinedText.contains("confirmed fire") ||
            combinedText.contains("2nd alarm") ||
            combinedText.contains("second alarm")
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
