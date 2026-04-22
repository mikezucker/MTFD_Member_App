import Foundation

enum DashboardTotalsWindow: String, CaseIterable {
    case last24h = "24H"
    case last7d = "7D"
    case last30d = "30D"
    case ytd = "YTD"
}

struct DashboardQuickAction: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let systemImage: String
    let destination: AppDestination
}

struct DashboardProgressItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let progress: Double
    let subtitle: String
    let destination: AppDestination
}

struct DashboardAttentionItem: Identifiable, Hashable {
    let id = UUID()
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

struct DashboardState {
    let greeting: String
    let role: UserRole
    let alerts: [AppAlert]

    let stationUpdates: [DashboardBulletin]
    let departmentUpdates: [DashboardBulletin]

    let attentionItems: [DashboardAttentionItem]
    let quickActions: [DashboardQuickAction]
    let progressItems: [DashboardProgressItem]

    // Legacy headline values, keep for compatibility
    var stationCallTotal: Int? = nil
    var departmentCallTotal: Int? = nil

    // Raw stats payload for the selector-based totals display
    var dashboardDepartment: APIClient.DispatchBucket? = nil
    var dashboardStation: APIClient.DispatchBucket? = nil
    var lastUpdated: String? = nil

    var recentDepartmentCalls: [RecentDepartmentCall] = []
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
            stationCallTotal: nil,
            departmentCallTotal: nil,
            dashboardDepartment: nil,
            dashboardStation: nil,
            lastUpdated: nil,
            recentDepartmentCalls: [],
            isLoading: false,
            errorMessage: nil
        )
    }
}
