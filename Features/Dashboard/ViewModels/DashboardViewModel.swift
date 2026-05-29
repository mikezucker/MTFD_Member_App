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
            quickActions: [],
            progressItems: state.progressItems,
            assignedTrainingPreview: state.assignedTrainingPreview,
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
                attentionItems: mapAttentionItems(from: dashboard.attentionItems ?? []),
                quickActions: [],
                progressItems: buildProgressItems(for: role, summary: dashboard.trainingSummary),
                assignedTrainingPreview: mapTrainingPreview(from: dashboard.assignedTrainingPreview ?? []),
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
                attentionItems: [],
                quickActions: [],
                progressItems: [],
                assignedTrainingPreview: [],
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

    private func mapAttentionItems(from items: [APIClient.AttentionItem]) -> [DashboardAttentionItem] {
        items.map { item in
            let normalized = item.destination?.lowercased() ?? ""

            return DashboardAttentionItem(
                title: item.title,
                subtitle: item.subtitle,
                actionLabel: item.actionLabel ?? "Open",
                destination: normalized.contains("training")
                    ? .trainingAssigned
                    : .messageCenter
            )
        }
    }

    private func mapTrainingPreview(
        from items: [APIClient.DashboardTrainingPreviewItem]
    ) -> [DashboardTrainingPreviewItem] {
        items.map {
            DashboardTrainingPreviewItem(
                id: $0.id,
                courseId: $0.courseId,
                title: $0.title,
                progressText: $0.progressText,
                progressPercent: $0.progressPercent,
                isOverdue: $0.isOverdue ?? false
            )
        }
    }

    private func buildProgressItems(
        for role: UserRole,
        summary: APIClient.TrainingSummary?
    ) -> [DashboardProgressItem] {
        guard let summary else {
            return []
        }

        let assigned = summary.assignedTrainingCount ?? 0
        let completed = summary.completedTrainingCount ?? 0

        guard assigned > 0 else {
            return []
        }

        let progress = min(Double(completed) / Double(assigned), 1.0)

        switch role {
        case .chief, .officer:
            return [
                DashboardProgressItem(
                    title: "Training Completion",
                    progress: progress,
                    subtitle: "\(completed) of \(assigned) assigned training items completed",
                    destination: .trainingAssigned
                )
            ]

        case .member:
            return [
                DashboardProgressItem(
                    title: "Assigned Training",
                    progress: progress,
                    subtitle: "\(completed) of \(assigned) assigned training items completed",
                    destination: .trainingAssigned
                )
            ]
        }
    }
}
