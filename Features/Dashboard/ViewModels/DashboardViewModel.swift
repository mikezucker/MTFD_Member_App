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

    private func timedDashboardRequest<T>(_ label: String, operation: () async throws -> T) async throws -> T {
        let startedAt = Date()
        print("⏱️ Dashboard request started: \(label)")

        do {
            let result = try await operation()
            print("✅ Dashboard request finished: \(label) in \(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s")
            return result
        } catch {
            print("🧨 Dashboard request failed: \(label) in \(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s - \(error.localizedDescription)")
            throw error
        }
    }

    private func loadDashboard(role: UserRole, force: Bool) async {
        guard !isLoadingDashboard else { return }

        let dashboardLoadStartedAt = Date()
        print("⏱️ Dashboard load started. force=\(force), role=\(role.rawValue)")

        if !force, hasLoaded {
            return
        }

        isLoadingDashboard = true
        defer {
            isLoadingDashboard = false
            print("⏱️ Dashboard load finished in \(String(format: "%.2f", Date().timeIntervalSince(dashboardLoadStartedAt)))s")
        }

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
            pendingDocumentSignatures: state.pendingDocumentSignatures,
            stationCallTotal: state.stationCallTotal,
            departmentCallTotal: state.departmentCallTotal,
            dashboardDepartment: state.dashboardDepartment,
            dashboardStation: state.dashboardStation,
            lastUpdated: state.lastUpdated,
            recentDepartmentCalls: state.recentDepartmentCalls,
            apparatusWorkOrders: state.apparatusWorkOrders,
            apparatusWorkOrdersMessage: state.apparatusWorkOrdersMessage,
            upcomingSchedule: state.upcomingSchedule,
            isLoading: true,
            errorMessage: nil
        )

        do {
            async let dashboardResponse = timedDashboardRequest("mobile dashboard") {
                try await APIClient.shared.fetchDashboard()
            }
            async let dispatchHistoryResponse = timedDashboardRequest("dispatch history 24h") {
                try await APIClient.shared.fetchDispatchHistory(window: "24h")
            }
            async let upcomingScheduleResponse = timedDashboardRequest("upcoming schedule") {
                try await APIClient.shared.fetchMobileUpcomingSchedule()
            }

            let dashboard = try await dashboardResponse
            let dispatchHistory = try await dispatchHistoryResponse

            let upcomingSchedule: APIClient.MobileUpcomingScheduleResponse?
            do {
                upcomingSchedule = try await upcomingScheduleResponse
                print("🗓️ Upcoming schedule:", upcomingSchedule as Any)
            } catch {
                upcomingSchedule = nil
                print("🧨 Upcoming schedule failed:", error.localizedDescription)
            }

            activeDispatches = dashboard.activeDispatches ?? dispatchHistory.activeDispatches

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
                pendingDocumentSignatures: dashboard.trainingSummary?.pendingDocumentSignatures ?? 0,
                stationCallTotal: stationYtd,
                departmentCallTotal: departmentYtd,
                dashboardDepartment: dashboard.department,
                dashboardStation: dashboard.station,
                lastUpdated: dashboard.lastUpdated,
                recentDepartmentCalls: mapRecentCalls(from: dispatchHistory.historicalDispatches),
                apparatusWorkOrders: mapApparatusWorkOrders(from: dashboard.apparatusWorkOrders ?? []),
                apparatusWorkOrdersMessage: dashboard.apparatusWorkOrdersMessage,
                upcomingSchedule: upcomingSchedule,
                isLoading: false,
                errorMessage: nil
            )

            hasLoaded = true
            lastLoadedAt = Date()

            Task {
                await loadDispatchStats()
            }
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
                pendingDocumentSignatures: 0,
                stationCallTotal: nil,
                departmentCallTotal: nil,
                dashboardDepartment: nil,
                dashboardStation: nil,
                lastUpdated: nil,
                recentDepartmentCalls: [],
                apparatusWorkOrders: [],
                apparatusWorkOrdersMessage: nil,
                upcomingSchedule: nil,
                isLoading: false,
                errorMessage: error.localizedDescription
            )

            print("Dashboard load failed: \(error.localizedDescription)")
        }
    }

    private func loadDispatchStats() async {
        let startedAt = Date()
        print("⏱️ Dashboard separate stats load started")

        do {
            let statsResponse = try await APIClient.shared.fetchDispatchStats()

            state = DashboardState(
                greeting: state.greeting,
                role: state.role,
                alerts: state.alerts,
                stationUpdates: state.stationUpdates,
                departmentUpdates: state.departmentUpdates,
                attentionItems: state.attentionItems,
                quickActions: state.quickActions,
                progressItems: state.progressItems,
                assignedTrainingPreview: state.assignedTrainingPreview,
                pendingDocumentSignatures: state.pendingDocumentSignatures,
                stationCallTotal: statsResponse.stats?.stationYtd,
                departmentCallTotal: statsResponse.stats?.departmentYtd,
                dashboardDepartment: statsResponse.department,
                dashboardStation: statsResponse.station,
                lastUpdated: statsResponse.lastUpdated,
                recentDepartmentCalls: state.recentDepartmentCalls,
                apparatusWorkOrders: state.apparatusWorkOrders,
                apparatusWorkOrdersMessage: state.apparatusWorkOrdersMessage,
                upcomingSchedule: state.upcomingSchedule,
                isLoading: state.isLoading,
                errorMessage: state.errorMessage
            )

            print("✅ Dashboard separate stats load finished in \(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s")
        } catch {
            print("🧨 Dashboard separate stats load failed in \(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s: \(error.localizedDescription)")
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

    private func mapApparatusWorkOrders(
        from workOrders: [APIClient.ApparatusWorkOrder]
    ) -> [DashboardApparatusWorkOrder] {
        workOrders.prefix(3).map { workOrder in
            DashboardApparatusWorkOrder(
                id: workOrder.id,
                apparatusName: workOrder.apparatusName,
                title: workOrder.title,
                status: workOrder.status
            )
        }
    }

    private func mapRecentCalls(
        from dispatches: [APIClient.DispatchHistoryItem]
    ) -> [RecentDepartmentCall] {
        dispatches.prefix(3).map { dispatch in
            let location = [
                dispatch.placeName,
                dispatch.address,
                dispatch.city
            ]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed?.isEmpty == false ? trimmed : nil
            }
            .first ?? "Location unavailable"

            let timestamp: String
            if let dispatchedAt = dispatch.dispatchedAt {
                timestamp = dispatchedAt.formatted(date: .abbreviated, time: .shortened)
            } else if let lastActivityAt = dispatch.lastActivityAt {
                timestamp = lastActivityAt.formatted(date: .abbreviated, time: .shortened)
            } else {
                timestamp = "Time unavailable"
            }

            return RecentDepartmentCall(
                id: dispatch.id,
                incidentNumber: dispatch.stableId,
                title: dispatch.callType,
                address: location,
                timestamp: timestamp
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
