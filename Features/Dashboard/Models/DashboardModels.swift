import Foundation

enum DashboardTotalsWindow: String, CaseIterable {
    case last24h = "24H"
    case last7d = "7D"
    case last30d = "30D"
    case ytd = "YTD"
}

struct DashboardQuickAction: Identifiable, Hashable {
    var id: String { "\(title)-\(systemImage)-\(destination)" }
    let title: String
    let systemImage: String
    let destination: AppDestination
}

struct DashboardProgressItem: Identifiable, Hashable {
    var id: String { "\(title)-\(subtitle)-\(destination)" }
    let title: String
    let progress: Double
    let subtitle: String
    let destination: AppDestination
}

struct DashboardTrainingPreviewItem: Identifiable, Hashable {
    let id: String
    let courseId: String
    let title: String
    let progressText: String
    let progressPercent: Int
    let isOverdue: Bool
}

struct DashboardAttentionItem: Identifiable, Hashable {
    var id: String { "\(title)-\(subtitle)-\(actionLabel ?? "")-\(destination)" }
    let title: String
    let subtitle: String
    let actionLabel: String?
    let destination: AppDestination
}

struct DashboardBulletin: Identifiable, Hashable {
    let id: String
    let title: String
    let message: String
    let updatedAt: String?
}

struct RecentDepartmentCall: Identifiable, Hashable {
    let id: String
    let incidentNumber: String?
    let title: String
    let address: String
    let timestamp: String
}

struct DashboardApparatusWorkOrder: Identifiable, Hashable {
    let id: String
    let apparatusApiId: String?
    let apparatusName: String
    let title: String
    let status: String?
}

struct DashboardState {
    let greeting: String
    let role: UserRole
    let alerts: [AppAlert]

    let stationUpdates: [DashboardBulletin]
    let departmentUpdates: [DashboardBulletin]

    let attentionItems: [DashboardAttentionItem]
    let quickActions: [DashboardQuickAction]
    let progressItems: [DashboardProgressItem]
    let assignedTrainingPreview: [DashboardTrainingPreviewItem]
    let pendingDocumentSignatures: Int

    // Legacy headline values, keep for compatibility
    var stationCallTotal: Int? = nil
    var departmentCallTotal: Int? = nil

    // Raw stats payload for the selector-based totals display
    var dashboardDepartment: APIClient.DispatchBucket? = nil
    var dashboardStation: APIClient.DispatchBucket? = nil
    var dashboardStations: APIClient.ChiefStationStats? = nil
    var volunteerContext: APIClient.VolunteerContext? = nil
    var lastUpdated: String? = nil

    var recentDepartmentCalls: [RecentDepartmentCall] = []
    var apparatusWorkOrders: [DashboardApparatusWorkOrder] = []
    var apparatusWorkOrdersMessage: String? = nil
    var upcomingSchedule: APIClient.MobileUpcomingScheduleResponse? = nil
    var departmentScheduleEntries: [APIClient.MobileScheduleEntry] = []
    var tomorrowScheduleEntries: [APIClient.MobileScheduleEntry] = []
    var unreadNonDispatchMessageCount: Int = 0
    var isLoadingStats: Bool = false
    var isLoading: Bool = false
    var errorMessage: String? = nil

    static func empty(for role: UserRole) -> DashboardState {
        DashboardState(
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
            dashboardStations: nil,
            volunteerContext: nil,
            lastUpdated: nil,
            recentDepartmentCalls: [],
            apparatusWorkOrders: [],
            apparatusWorkOrdersMessage: nil,
            isLoadingStats: false,
            isLoading: false,
            errorMessage: nil
        )
    }
}
