import Foundation

struct MemberDashboardResponse: Codable {
    let attentionItems: [DashboardAttentionItemResponse]
    let dashboardUpdates: [DashboardUpdateItemResponse]
    let latestUpdates: [DashboardUpdateItemResponse]
    let trainingSummary: TrainingSummaryResponse?
}

// MARK: - Attention Items

struct DashboardAttentionItemResponse: Codable {
    let id: String
    let title: String
    let subtitle: String?
    let actionLabel: String?
    let destination: String?
}

// MARK: - Updates

struct DashboardUpdateItemResponse: Codable {
    let id: String
    let title: String
    let message: String
    let priority: String
    let postedBy: String
    let createdAt: String
}

// MARK: - Training Summary

struct TrainingSummaryResponse: Codable {
    let assignedCount: Int
    let completedCount: Int
    let percentComplete: Double
    let activeCourseTitle: String?
    let pendingJprReviews: Int?
}
