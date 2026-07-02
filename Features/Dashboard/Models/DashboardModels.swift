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

enum DashboardMessageTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case unread = "Unread"
    case announcements = "Announcements"
    case training = "Training"
    case staffing = "Staffing"
    case officer = "Officer"
    case documents = "Documents"
    case other = "Other"

    var id: String { rawValue }

    func includes(_ message: MobileMessage) -> Bool {
        let type = message.type.uppercased()

        if type == "DISPATCH" || type == "DISPATCH_UPDATE" || message.dispatchId != nil {
            return false
        }

        return includes(type: type, isRead: message.isRead)
    }

    func includes(_ preview: DashboardMessagePreview) -> Bool {
        includes(type: preview.type, isRead: preview.isRead)
    }

    private func includes(type rawType: String, isRead: Bool) -> Bool {
        let type = rawType.uppercased()

        switch self {
        case .all:
            return true
        case .unread:
            return !isRead
        case .announcements:
            return ["ANNOUNCEMENT", "EVENT", "GENERAL", "POLICY_LINK"].contains(type)
        case .training:
            return ["TRAINING", "TRAINING_REMINDER", "TRAINING_ASSIGNMENT"].contains(type)
        case .staffing:
            return type == "STAFFING"
        case .officer:
            return ["OFFICER_NOTE", "ADMIN_MESSAGE", "SYSTEM"].contains(type)
        case .documents:
            return ["POLICY_LINK", "DOCUMENT", "DOCUMENT_SIGNATURE"].contains(type)
        case .other:
            return !DashboardMessageTypeFilter.allPrimaryTypes.contains(type)
        }
    }

    private static let allPrimaryTypes = Set([
        "ANNOUNCEMENT",
        "EVENT",
        "GENERAL",
        "TRAINING",
        "TRAINING_REMINDER",
        "TRAINING_ASSIGNMENT",
        "STAFFING",
        "OFFICER_NOTE",
        "ADMIN_MESSAGE",
        "SYSTEM",
        "POLICY_LINK",
        "DOCUMENT",
        "DOCUMENT_SIGNATURE"
    ])
}

struct DashboardMessagePreview: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String?
    let type: String
    let priority: String
    let audienceLabel: String
    let typeLabel: String
    let icon: String
    let isRead: Bool
    let isPinned: Bool
    let createdAt: Date

    init(message: MobileMessage) {
        id = message.id
        title = message.title
        body = message.body
        type = message.type
        priority = message.priority
        audienceLabel = message.audienceDisplayLabel
        typeLabel = message.typeDisplayLabel
        icon = message.displayIcon
        isRead = message.isRead
        isPinned = message.isPinned == true
        createdAt = message.createdAt
    }
}

struct RecentDepartmentCall: Identifiable, Hashable {
    let id: String
    let incidentNumber: String?
    let title: String
    let address: String
    let timestamp: String
    let units: [String]
    let rawUnits: [String]
}

extension AppNotificationPayload {
    init(recentDepartmentCall call: RecentDepartmentCall) {
        self.init(
            type: .dispatch,
            id: call.id,
            title: call.title,
            body: call.address,
            callType: call.title,
            address: call.address,
            units: call.units,
            isWorkingFire: call.title.localizedCaseInsensitiveContains("fire"),
            activeCallCount: 1,
            stationId: nil,
            messageId: nil,
            trainingId: nil,
            documentId: nil
        )
    }
}

struct DashboardApparatusWorkOrder: Identifiable, Hashable {
    let id: String
    let apparatusApiId: String?
    let apparatusName: String
    let title: String
    let status: String?
}

struct DashboardPendingPolicy: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let folderName: String?
}

struct DashboardState {
    let greeting: String
    let role: UserRole
    let alerts: [AppAlert]

    let stationUpdates: [DashboardBulletin]
    let departmentUpdates: [DashboardBulletin]
    var messagePreviews: [DashboardMessagePreview] = []

    let attentionItems: [DashboardAttentionItem]
    let quickActions: [DashboardQuickAction]
    let progressItems: [DashboardProgressItem]
    let assignedTrainingPreview: [DashboardTrainingPreviewItem]
    let pendingDocumentSignatures: Int
    var pendingPolicyDocuments: [DashboardPendingPolicy] = []

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
            pendingPolicyDocuments: [],
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
