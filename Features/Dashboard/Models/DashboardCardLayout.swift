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
        case .documents: return "Policy Center"
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
    private static let baseHiddenCardsKey = "dashboard_hidden_cards"
    private static let baseOrderKey = "dashboard_card_order"

    private static func normalizedRoleKey(for rawRole: String?) -> String {
        let role = rawRole?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_") ?? "default"

        return role.isEmpty ? "default" : role
    }

    private static func orderKey(for rawRole: String?) -> String {
        "\(baseOrderKey)_\(normalizedRoleKey(for: rawRole))"
    }

    private static func hiddenCardsKey(for rawRole: String?) -> String {
        "\(baseHiddenCardsKey)_\(normalizedRoleKey(for: rawRole))"
    }

    static func defaultOrder(for rawRole: String?) -> [DashboardCardID] {
        let role = rawRole?.uppercased() ?? ""

        switch role {
        case "ADMIN":
            return [.scheduleEvents, .apparatusWorkOrders, .messages, .recentCalls]
        case "CHIEF", "BATTALION_CHIEF":
            return [.scheduleEvents, .apparatusWorkOrders, .messages, .recentCalls]
        case "OFFICER_CAREER":
            return [.scheduleEvents, .apparatusWorkOrders, .stationUpdates, .assignedTraining, .messages, .documents, .recentCalls, .departmentUpdates]
        case "OFFICER_VOLUNTEER":
            return [.apparatusWorkOrders, .stationUpdates, .assignedTraining, .scheduleEvents, .messages, .documents, .recentCalls, .departmentUpdates]
        case "MEMBER_CAREER":
            return [.messages, .scheduleEvents, .apparatusWorkOrders, .assignedTraining, .documents, .departmentUpdates, .recentCalls, .stationUpdates]
        case "MEMBER_VOLUNTEER":
            return [.messages, .assignedTraining, .scheduleEvents, .apparatusWorkOrders, .documents, .departmentUpdates, .recentCalls, .stationUpdates]
        default:
            return [.messages, .assignedTraining, .documents, .scheduleEvents, .departmentUpdates, .stationUpdates, .recentCalls, .apparatusWorkOrders]
        }
    }

    static func savedOrder(for rawRole: String?) -> [DashboardCardID] {
        let defaultCards = defaultOrder(for: rawRole)

        guard let data = UserDefaults.standard.data(forKey: orderKey(for: rawRole)),
              let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
            return defaultCards
        }

        let decoded = rawValues
            .compactMap(DashboardCardID.init(rawValue:))
            .filter { defaultCards.contains($0) }
        let missing = defaultCards.filter { !decoded.contains($0) }
        return decoded + missing
    }

    static func saveOrder(_ cards: [DashboardCardID], for rawRole: String?) {
        let rawValues = cards.map(\.rawValue)
        if let data = try? JSONEncoder().encode(rawValues) {
            UserDefaults.standard.set(data, forKey: orderKey(for: rawRole))
            NotificationCenter.default.post(name: .dashboardLayoutDidChange, object: nil)
        }
    }

    static func hiddenCards(for rawRole: String?) -> Set<DashboardCardID> {
        guard let rawValues = UserDefaults.standard.stringArray(forKey: hiddenCardsKey(for: rawRole)) else {
            return []
        }

        let supportedCards = Set(defaultOrder(for: rawRole))
        return Set(rawValues.compactMap(DashboardCardID.init(rawValue:))).intersection(supportedCards)
    }

    static func saveHiddenCards(_ cards: Set<DashboardCardID>, for rawRole: String?) {
        let supportedCards = Set(defaultOrder(for: rawRole))
        UserDefaults.standard.set(cards.intersection(supportedCards).map(\.rawValue), forKey: hiddenCardsKey(for: rawRole))
        NotificationCenter.default.post(name: .dashboardLayoutDidChange, object: nil)
    }

    static func reset(for rawRole: String?) {
        UserDefaults.standard.removeObject(forKey: orderKey(for: rawRole))
        UserDefaults.standard.removeObject(forKey: hiddenCardsKey(for: rawRole))
        NotificationCenter.default.post(name: .dashboardLayoutDidChange, object: nil)
    }
}
