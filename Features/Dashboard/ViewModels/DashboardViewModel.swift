import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var state: DashboardState = .empty(for: .member)
    @Published var activeDispatches: [APIClient.ActiveDispatch] = []

    private var hasLoaded = false
    private var cachedVolunteerContext: APIClient.VolunteerContext?
    private var isLoadingDashboard = false
    private var isRefreshingDispatchFeed = false
    private var pendingForceRefresh = false
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

    func refreshAsync(role: UserRole) async {
        await loadDashboard(role: role, force: true)
    }

    func refreshIfStale(role: UserRole) {
        if let lastLoadedAt, Date().timeIntervalSince(lastLoadedAt) < minimumRefreshInterval {
            return
        }

        Task {
            await loadDashboard(role: role, force: true)
        }
    }

    func refreshAfterDispatchNotification(role: UserRole) {
        Task {
            await refreshActiveDispatchesAfterNotification(role: role)
        }
    }

    func refreshDispatchFeed() async {
        guard !isRefreshingDispatchFeed else { return }

        isRefreshingDispatchFeed = true
        defer {
            isRefreshingDispatchFeed = false
        }

        do {
            let dispatchHistory = try await APIClient.shared.fetchDispatchHistory(window: "24h")
            activeDispatches = dispatchHistory.activeDispatches

            logActiveDispatches(
                sourceLabel: dispatchHistory.sourceLabel,
                activeDispatches: dispatchHistory.activeDispatches
            )
        } catch {
            print("Dispatch feed refresh failed: \(error.localizedDescription)")
        }
    }

    private func refreshActiveDispatchesAfterNotification(role: UserRole) async {
        await loadDashboard(role: role, force: true)

        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await loadDashboard(role: role, force: true)

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await loadDashboard(role: role, force: true)
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
        if isLoadingDashboard {
            if force {
                pendingForceRefresh = true
            }
            return
        }

        let dashboardLoadStartedAt = Date()
        print("⏱️ Dashboard load started. force=\(force), role=\(role.rawValue)")

        if !force, hasLoaded {
            return
        }

        isLoadingDashboard = true
        defer {
            isLoadingDashboard = false
            print("⏱️ Dashboard load finished in \(String(format: "%.2f", Date().timeIntervalSince(dashboardLoadStartedAt)))s")

            if pendingForceRefresh {
                pendingForceRefresh = false

                Task {
                    await loadDashboard(role: role, force: true)
                }
            }
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
            pendingPolicyDocuments: state.pendingPolicyDocuments,
            stationCallTotal: state.stationCallTotal,
            departmentCallTotal: state.departmentCallTotal,
            dashboardDepartment: state.dashboardDepartment,
            dashboardStation: state.dashboardStation,
            dashboardStations: state.dashboardStations,
            volunteerContext: cachedVolunteerContext ?? state.volunteerContext,
            lastUpdated: state.lastUpdated,
            recentDepartmentCalls: state.recentDepartmentCalls,
            apparatusWorkOrders: state.apparatusWorkOrders,
            apparatusWorkOrdersMessage: state.apparatusWorkOrdersMessage,
            upcomingSchedule: state.upcomingSchedule,
            departmentScheduleEntries: state.departmentScheduleEntries,
            tomorrowScheduleEntries: state.tomorrowScheduleEntries,
            unreadNonDispatchMessageCount: state.unreadNonDispatchMessageCount,
            isLoadingStats: true,
            isLoading: true,
            errorMessage: nil
        )

        do {
            async let dashboardResponse = timedDashboardRequest("mobile dashboard") {
                try await APIClient.shared.fetchDashboard()
            }
            async let upcomingScheduleResponse = timedDashboardRequest("upcoming schedule") {
                try await APIClient.shared.fetchMobileUpcomingSchedule()
            }
            async let departmentScheduleEntriesResponse = fetchDepartmentScheduleOutlook()
            async let pendingPolicyDocumentsResponse = fetchPendingPolicyDocuments()

            let dashboard = try await dashboardResponse

            let dispatchHistory: APIClient.DispatchHistoryResponse?
            do {
                dispatchHistory = try await timedDashboardRequest("dispatch history 24h") {
                    try await APIClient.shared.fetchDispatchHistory(window: "24h")
                }
            } catch {
                dispatchHistory = nil
                print("🧨 Dispatch history failed:", error.localizedDescription)
            }

            let upcomingSchedule: APIClient.MobileUpcomingScheduleResponse?
            do {
                upcomingSchedule = try await upcomingScheduleResponse
                print("🗓️ Upcoming schedule:", upcomingSchedule as Any)
            } catch {
                upcomingSchedule = nil
                print("🧨 Upcoming schedule failed:", error.localizedDescription)
            }

            let departmentScheduleEntries = await departmentScheduleEntriesResponse
            let pendingPolicyDocuments = await pendingPolicyDocumentsResponse

            let resolvedActiveDispatches =
                dispatchHistory?.activeDispatches ??
                dashboard.activeDispatches?.filter(\.isVisibleActiveDispatch) ??
                []
            let resolvedHistoricalDispatches =
                dispatchHistory?.historicalDispatches ??
                dashboard.historicalDispatches ??
                []

            activeDispatches = resolvedActiveDispatches
            logActiveDispatches(
                sourceLabel: dispatchHistory?.sourceLabel ?? dashboard.sourceLabel,
                activeDispatches: resolvedActiveDispatches
            )

            let resolvedVolunteerContext = mergedVolunteerContext(
                incoming: dashboard.volunteerContext,
                existing: cachedVolunteerContext ?? state.volunteerContext
            )
            cachedVolunteerContext = resolvedVolunteerContext

            let departmentYtd: Int? = nil
            let stationYtd: Int? = nil

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
                pendingDocumentSignatures: pendingPolicyDocuments.isEmpty
                    ? (dashboard.trainingSummary?.pendingDocumentSignatures ?? 0)
                    : pendingPolicyDocuments.count,
                pendingPolicyDocuments: pendingPolicyDocuments,
                stationCallTotal: stationYtd,
                departmentCallTotal: departmentYtd,
                dashboardDepartment: nil,
                dashboardStation: nil,
                dashboardStations: nil,
                volunteerContext: resolvedVolunteerContext,
                lastUpdated: nil,
                recentDepartmentCalls: mapRecentCalls(from: resolvedHistoricalDispatches),
                apparatusWorkOrders: mapApparatusWorkOrders(from: dashboard.apparatusWorkOrders ?? []),
                apparatusWorkOrdersMessage: dashboard.apparatusWorkOrdersMessage,
                upcomingSchedule: upcomingSchedule,
                departmentScheduleEntries: departmentScheduleEntries,
                tomorrowScheduleEntries: [],
                unreadNonDispatchMessageCount: state.unreadNonDispatchMessageCount,
                isLoadingStats: true,
                isLoading: false,
                errorMessage: nil
            )

            hasLoaded = true
            lastLoadedAt = Date()

            Task {
                await loadDispatchStats()
            }

            Task {
                await loadUnreadNonDispatchMessageCount()
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
                pendingPolicyDocuments: [],
                stationCallTotal: nil,
                departmentCallTotal: nil,
                dashboardDepartment: nil,
                dashboardStation: nil,
                dashboardStations: nil,
                volunteerContext: cachedVolunteerContext ?? state.volunteerContext,
                lastUpdated: state.lastUpdated,
                recentDepartmentCalls: [],
                apparatusWorkOrders: [],
                apparatusWorkOrdersMessage: nil,
                upcomingSchedule: nil,
                unreadNonDispatchMessageCount: state.unreadNonDispatchMessageCount,
                isLoadingStats: false,
                isLoading: false,
                errorMessage: error.localizedDescription
            )

            print("Dashboard load failed: \(error.localizedDescription)")
        }
    }


    private func mergedVolunteerContext(
        incoming: APIClient.VolunteerContext?,
        existing: APIClient.VolunteerContext?
    ) -> APIClient.VolunteerContext? {
        guard let incoming else {
            return existing
        }

        guard incoming.officer == nil, let existingOfficer = existing?.officer else {
            return incoming
        }

        return APIClient.VolunteerContext(
            company: incoming.company ?? existing?.company,
            station: incoming.station ?? existing?.station,
            officer: existingOfficer,
            apparatus: incoming.apparatus ?? existing?.apparatus,
            stationApparatus: incoming.stationApparatus ?? existing?.stationApparatus
        )
    }

    private func logActiveDispatches(
        sourceLabel: String?,
        activeDispatches: [APIClient.ActiveDispatch]
    ) {
        #if DEBUG
        print("🚒 Active dispatch source: /api/mobile/dispatches source=\(sourceLabel ?? "unknown") count=\(activeDispatches.count)")

        for dispatch in activeDispatches {
            print(
                """
                🚒 Active dispatch normalized:
                  id=\(dispatch.id)
                  incidentType=\(dispatch.callType)
                  address=\(dispatch.address ?? "nil")
                  city=\(dispatch.city ?? "nil")
                  category=\(dispatch.priority ?? "nil")
                  assignedUnits=\(dispatch.units.joined(separator: ", "))
                  activeStatus=active
                  receivedAt=\(dispatch.dispatchedAt?.description ?? "nil")
                  updatedAt=not provided
                """
            )
        }
        #endif
    }

    private func loadUnreadNonDispatchMessageCount() async {
        do {
            let response = try await APIClient.shared.fetchMessages()
            let unreadCount = response.messages.filter { message in
                message.type != "DISPATCH" &&
                message.type != "DISPATCH_UPDATE" &&
                message.dispatchId == nil &&
                !message.isRead
            }.count

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
                pendingPolicyDocuments: state.pendingPolicyDocuments,
                stationCallTotal: state.stationCallTotal,
                departmentCallTotal: state.departmentCallTotal,
                dashboardDepartment: state.dashboardDepartment,
                dashboardStation: state.dashboardStation,
                dashboardStations: state.dashboardStations,
                volunteerContext: cachedVolunteerContext ?? state.volunteerContext,
                lastUpdated: state.lastUpdated,
                recentDepartmentCalls: state.recentDepartmentCalls,
                apparatusWorkOrders: state.apparatusWorkOrders,
                apparatusWorkOrdersMessage: state.apparatusWorkOrdersMessage,
                upcomingSchedule: state.upcomingSchedule,
                unreadNonDispatchMessageCount: unreadCount,
                isLoadingStats: state.isLoadingStats,
                isLoading: state.isLoading,
                errorMessage: state.errorMessage
            )
        } catch {
            print("Dashboard unread non-dispatch message count failed:", error.localizedDescription)
        }
    }

    private func fetchDepartmentScheduleOutlook() async -> [APIClient.MobileScheduleEntry] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var entries: [APIClient.MobileScheduleEntry] = []

        for offset in 0..<4 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else {
                continue
            }

            let dateString = formatter.string(from: date)

            do {
                let response = try await APIClient.shared.fetchMobileSchedule(date: dateString)
                print("🗓️ Department schedule \(dateString): \(response.entries.count) entries")
                entries.append(contentsOf: response.entries)
            } catch {
                print("🧨 Department schedule failed for \(dateString):", error.localizedDescription)
            }
        }

        print("🗓️ Department schedule outlook total entries:", entries.count)
        return entries
    }

    private func fetchPendingPolicyDocuments() async -> [DashboardPendingPolicy] {
        do {
            let response = try await APIClient.shared.fetchDocuments()
            let foldersById = Dictionary(uniqueKeysWithValues: response.folders.map { ($0.id, $0.name) })

            return response.documents
                .filter { $0.latestVersion?.requiresAcknowledgement == true }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                .prefix(6)
                .map { document in
                    DashboardPendingPolicy(
                        id: document.id,
                        title: document.title,
                        category: document.category,
                        folderName: document.folderId.flatMap { foldersById[$0] }
                    )
                }
        } catch {
            print("🧨 Pending policy preview failed:", error.localizedDescription)
            return []
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
                pendingPolicyDocuments: state.pendingPolicyDocuments,
                stationCallTotal: statsResponse.stats?.stationYtd,
                departmentCallTotal: statsResponse.stats?.departmentYtd,
                dashboardDepartment: statsResponse.department,
                dashboardStation: statsResponse.station,
                dashboardStations: statsResponse.stations,
                volunteerContext: cachedVolunteerContext ?? state.volunteerContext,
                lastUpdated: statsResponse.lastUpdated,
                recentDepartmentCalls: state.recentDepartmentCalls,
                apparatusWorkOrders: state.apparatusWorkOrders,
                apparatusWorkOrdersMessage: state.apparatusWorkOrdersMessage,
                upcomingSchedule: state.upcomingSchedule,
                departmentScheduleEntries: state.departmentScheduleEntries,
                tomorrowScheduleEntries: state.tomorrowScheduleEntries,
                unreadNonDispatchMessageCount: state.unreadNonDispatchMessageCount,
                isLoadingStats: false,
                isLoading: state.isLoading,
                errorMessage: state.errorMessage
            )

            print("✅ Dashboard separate stats load finished in \(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s")
        } catch {
            print("🧨 Dashboard separate stats load failed in \(String(format: "%.2f", Date().timeIntervalSince(startedAt)))s: \(error.localizedDescription)")
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

    private func mapAttentionItems(from items: [APIClient.AttentionItem]) -> [DashboardAttentionItem] {
        items.map { item in
            let normalized = item.destination?.lowercased() ?? ""

            return DashboardAttentionItem(
                title: item.title,
                subtitle: item.subtitle,
                actionLabel: item.actionLabel ?? "Open",
                destination: normalized.contains("document")
                    ? .documents
                    : normalized.contains("training")
                        ? .trainingAssigned
                        : .messageCenter
            )
        }
    }

    private func mapApparatusWorkOrders(
        from workOrders: [APIClient.ApparatusWorkOrder]
    ) -> [DashboardApparatusWorkOrder] {
        print("🛠️ Dashboard work orders received:", workOrders.count)
        workOrders.forEach { workOrder in
            print("🛠️ Work order:", workOrder.apparatusName, workOrder.title)
        }

        return workOrders.map { workOrder in
            DashboardApparatusWorkOrder(
                id: workOrder.id,
                apparatusApiId: workOrder.apparatusApiId,
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
