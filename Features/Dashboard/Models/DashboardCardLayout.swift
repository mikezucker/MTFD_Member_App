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

        let supportedRoles = ["admin", "chief", "battalion_chief", "officer_career", "officer_volunteer", "member_career", "member_volunteer"]
        return supportedRoles.contains(role) ? role : "member_volunteer"
    }

    private static func orderKey(for rawRole: String?) -> String {
        "\(baseOrderKey)_\(normalizedRoleKey(for: rawRole))"
    }

    private static func hiddenCardsKey(for rawRole: String?) -> String {
        "\(baseHiddenCardsKey)_\(normalizedRoleKey(for: rawRole))"
    }

    static func defaultOrder(for rawRole: String?) -> [DashboardCardID] {
        let role = normalizedRoleKey(for: rawRole).uppercased()

        switch role {
        case "ADMIN":
            return [.commandOverview, .scheduleEvents, .messages, .apparatusWorkOrders, .recentCalls]
        case "CHIEF", "BATTALION_CHIEF":
            return [.commandOverview, .scheduleEvents, .messages, .apparatusWorkOrders, .recentCalls]
        case "OFFICER_CAREER":
            return [.commandOverview, .scheduleEvents, .apparatusWorkOrders, .stationUpdates, .assignedTraining, .messages, .documents, .recentCalls, .departmentUpdates]
        case "OFFICER_VOLUNTEER":
            return [.commandOverview, .apparatusWorkOrders, .stationUpdates, .assignedTraining, .scheduleEvents, .messages, .documents, .recentCalls, .departmentUpdates]
        case "MEMBER_CAREER":
            return [.messages, .scheduleEvents, .apparatusWorkOrders, .assignedTraining, .documents, .departmentUpdates, .recentCalls, .stationUpdates]
        case "MEMBER_VOLUNTEER":
            return [.commandOverview, .assignedTraining, .departmentUpdates, .apparatusWorkOrders, .recentCalls, .stationUpdates]
        default:
            return [.messages, .assignedTraining, .documents, .scheduleEvents, .departmentUpdates, .stationUpdates, .recentCalls, .apparatusWorkOrders]
        }
    }

    static func savedOrder(for rawRole: String?, defaults: UserDefaults = .standard) -> [DashboardCardID] {
        let defaultCards = defaultOrder(for: rawRole)

        guard let data = defaults.data(forKey: orderKey(for: rawRole)),
              let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
            return defaultCards
        }

        var seen = Set<DashboardCardID>()
        let decoded = rawValues
            .compactMap(DashboardCardID.init(rawValue:))
            .filter { defaultCards.contains($0) && seen.insert($0).inserted }
        let missing = defaultCards.filter { !decoded.contains($0) }
        return decoded + missing
    }

    /// Shared by every dashboard so hiding never changes the saved order.
    static func visibleCards(for rawRole: String?, defaults: UserDefaults = .standard) -> [DashboardCardID] {
        let hidden = hiddenCards(for: rawRole, defaults: defaults)
        return savedOrder(for: rawRole, defaults: defaults).filter { !hidden.contains($0) }
    }

    static func saveOrder(_ cards: [DashboardCardID], for rawRole: String?, defaults: UserDefaults = .standard) {
        let supportedCards = Set(defaultOrder(for: rawRole))
        var seen = Set<DashboardCardID>()
        let rawValues = cards
            .filter { supportedCards.contains($0) && seen.insert($0).inserted }
            .map(\.rawValue)
        if let data = try? JSONEncoder().encode(rawValues) {
            defaults.set(data, forKey: orderKey(for: rawRole))
            NotificationCenter.default.post(name: .dashboardLayoutDidChange, object: nil)
        }
    }

    static func hiddenCards(for rawRole: String?, defaults: UserDefaults = .standard) -> Set<DashboardCardID> {
        guard let rawValues = defaults.stringArray(forKey: hiddenCardsKey(for: rawRole)) else {
            return []
        }

        let supportedCards = Set(defaultOrder(for: rawRole))
        return Set(rawValues.compactMap(DashboardCardID.init(rawValue:))).intersection(supportedCards)
    }

    static func saveHiddenCards(_ cards: Set<DashboardCardID>, for rawRole: String?, defaults: UserDefaults = .standard) {
        let supportedCards = Set(defaultOrder(for: rawRole))
        defaults.set(cards.intersection(supportedCards).map(\.rawValue), forKey: hiddenCardsKey(for: rawRole))
        NotificationCenter.default.post(name: .dashboardLayoutDidChange, object: nil)
    }

    static func reset(for rawRole: String?, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: orderKey(for: rawRole))
        defaults.removeObject(forKey: hiddenCardsKey(for: rawRole))
        NotificationCenter.default.post(name: .dashboardLayoutDidChange, object: nil)
    }
}
