import Foundation

enum AlertPriority {
    case info
    case important
    case urgent
    case critical
}

enum AlertCategory {
    case dispatch
    case training
    case uniform
    case admin
}

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let priority: AlertPriority
    let category: AlertCategory
    let date: Date
}
