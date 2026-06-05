import Foundation

extension Notification.Name {
    static let dashboardLayoutDidChange = Notification.Name("dashboardLayoutDidChange")
}


enum DashboardCardID: String, CaseIterable, Identifiable, Codable {
    case commandOverview
    case messages
    case assignedTraining
    case apparatusWorkOrders
    case documents
    case scheduleEvents
    case recentCalls
    case departmentUpdates
    case stationUpdates
    case needsAttention

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commandOverview: return "Command Overview"
        case .messages: return "Messages"
        case .assignedTraining: return "Assigned Training"
        case .apparatusWorkOrders: return "Apparatus Work Orders"
        case .documents: return "Documents / SOPs"
        case .scheduleEvents: return "Schedule / Events"
        case .recentCalls: return "Latest Dispatches"
        case .departmentUpdates: return "Department Updates"
        case .stationUpdates: return "Station Updates"
        case .needsAttention: return "Needs Attention"
        }
    }

    var systemImage: String {
        switch self {
        case .commandOverview: return "shield.lefthalf.filled"
        case .messages: return "text.bubble.fill"
        case .assignedTraining: return "graduationcap.fill"
        case .apparatusWorkOrders: return "wrench.and.screwdriver.fill"
        case .documents: return "doc.text.fill"
        case .scheduleEvents: return "calendar.badge.clock"
        case .recentCalls: return "clock.arrow.circlepath"
        case .departmentUpdates: return "megaphone.fill"
        case .stationUpdates: return "building.2.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        }
    }
}

enum DashboardCardLayoutDefaults {
    static let hiddenCardsKey = "dashboard_hidden_cards"
    static let orderKey = "dashboard_card_order"

    static func defaultOrder(for rawRole: String?) -> [DashboardCardID] {
        let role = rawRole?.uppercased() ?? ""

        switch role {
        case "ADMIN", "CHIEF":
            return [.commandOverview, .needsAttention, .scheduleEvents, .apparatusWorkOrders, .assignedTraining, .departmentUpdates, .messages, .documents, .recentCalls, .stationUpdates]
        case "OFFICER_CAREER":
            return [.commandOverview, .scheduleEvents, .apparatusWorkOrders, .stationUpdates, .assignedTraining, .needsAttention, .messages, .documents, .recentCalls, .departmentUpdates]
        case "OFFICER_VOLUNTEER":
            return [.commandOverview, .apparatusWorkOrders, .stationUpdates, .assignedTraining, .scheduleEvents, .needsAttention, .messages, .documents, .recentCalls, .departmentUpdates]
        case "MEMBER_CAREER":
            return [.messages, .scheduleEvents, .apparatusWorkOrders, .assignedTraining, .documents, .departmentUpdates, .recentCalls, .stationUpdates, .needsAttention]
        case "MEMBER_VOLUNTEER":
            return [.messages, .assignedTraining, .scheduleEvents, .apparatusWorkOrders, .documents, .departmentUpdates, .recentCalls, .stationUpdates, .needsAttention]
        default:
            return [.messages, .assignedTraining, .documents, .scheduleEvents, .departmentUpdates, .stationUpdates, .needsAttention, .recentCalls, .apparatusWorkOrders]
        }
    }

    static func savedOrder(for rawRole: String?) -> [DashboardCardID] {
        guard let data = UserDefaults.standard.data(forKey: orderKey),
              let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
            return defaultOrder(for: rawRole)
        }

        let decoded = rawValues.compactMap(DashboardCardID.init(rawValue:))
        let missing = DashboardCardID.allCases.filter { !decoded.contains($0) }
        return decoded + missing
    }

    static func saveOrder(_ cards: [DashboardCardID]) {
        let rawValues = cards.map(\.rawValue)
        if let data = try? JSONEncoder().encode(rawValues) {
            UserDefaults.standard.set(data, forKey: orderKey)
            NotificationCenter.default.post(name: .dashboardLayoutDidChange, object: nil)
        }
    }

    static func hiddenCards() -> Set<DashboardCardID> {
        guard let rawValues = UserDefaults.standard.stringArray(forKey: hiddenCardsKey) else {
            return []
        }
        return Set(rawValues.compactMap(DashboardCardID.init(rawValue:)))
    }

    static func saveHiddenCards(_ cards: Set<DashboardCardID>) {
        UserDefaults.standard.set(cards.map(\.rawValue), forKey: hiddenCardsKey)
        NotificationCenter.default.post(name: .dashboardLayoutDidChange, object: nil)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: orderKey)
        UserDefaults.standard.removeObject(forKey: hiddenCardsKey)
        NotificationCenter.default.post(name: .dashboardLayoutDidChange, object: nil)
    }
}
