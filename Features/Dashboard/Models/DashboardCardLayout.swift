import Foundation

enum DashboardCardID: String, CaseIterable, Identifiable, Codable {
    case messages
    case assignedTraining
    case stationWorkOrders
    case documents
    case scheduleEvents
    case recentCalls
    case departmentUpdates
    case stationUpdates
    case needsAttention

    var id: String { rawValue }

    var title: String {
        switch self {
        case .messages: return "Messages"
        case .assignedTraining: return "Assigned Training"
        case .stationWorkOrders: return "Station Work Orders"
        case .documents: return "Documents / SOPs"
        case .scheduleEvents: return "Schedule / Events"
        case .recentCalls: return "Recent Calls"
        case .departmentUpdates: return "Department Updates"
        case .stationUpdates: return "Station Updates"
        case .needsAttention: return "Needs Attention"
        }
    }

    var systemImage: String {
        switch self {
        case .messages: return "text.bubble.fill"
        case .assignedTraining: return "graduationcap.fill"
        case .stationWorkOrders: return "wrench.and.screwdriver.fill"
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
            return [.messages, .needsAttention, .assignedTraining, .departmentUpdates, .stationWorkOrders, .scheduleEvents, .documents, .recentCalls, .stationUpdates]
        case "OFFICER_CAREER":
            return [.messages, .scheduleEvents, .stationWorkOrders, .assignedTraining, .needsAttention, .stationUpdates, .documents, .recentCalls, .departmentUpdates]
        case "OFFICER_VOLUNTEER":
            return [.messages, .assignedTraining, .stationWorkOrders, .scheduleEvents, .needsAttention, .stationUpdates, .documents, .recentCalls, .departmentUpdates]
        case "MEMBER_CAREER":
            return [.messages, .scheduleEvents, .stationWorkOrders, .assignedTraining, .documents, .departmentUpdates, .recentCalls, .stationUpdates, .needsAttention]
        case "MEMBER_VOLUNTEER":
            return [.messages, .assignedTraining, .scheduleEvents, .stationWorkOrders, .documents, .departmentUpdates, .recentCalls, .stationUpdates, .needsAttention]
        default:
            return [.messages, .assignedTraining, .documents, .scheduleEvents, .departmentUpdates, .stationUpdates, .needsAttention, .recentCalls, .stationWorkOrders]
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
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: orderKey)
        UserDefaults.standard.removeObject(forKey: hiddenCardsKey)
    }
}
