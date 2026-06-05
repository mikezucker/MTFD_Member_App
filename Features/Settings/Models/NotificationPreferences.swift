import Foundation

enum NotificationScheduleMode: String, Codable, CaseIterable, Identifiable {
    case always = "ALWAYS"
    case onlyWhenWorking = "ONLY_WHEN_WORKING"
    case never = "NEVER"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .always:
            return "Always"
        case .onlyWhenWorking:
            return "Only while working"
        case .never:
            return "Off"
        }
    }

    var description: String {
        switch self {
        case .always:
            return "Send these alerts whether you are working or not, as long as your other filters match."
        case .onlyWhenWorking:
            return "Send these alerts only when you are listed as working on the department schedule."
        case .never:
            return "Do not send this type of dispatch alert."
        }
    }
}


enum CriticalDispatchAlertMode: String, Codable, CaseIterable, Identifiable {
    case seriousOnly = "SERIOUS_ONLY"
    case allDispatches = "ALL_DISPATCHES"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seriousOnly:
            return "Serious incidents only"
        case .allDispatches:
            return "All dispatches"
        }
    }

    var subtitle: String {
        switch self {
        case .seriousOnly:
            return "Uses the department’s current critical dispatch rules."
        case .allDispatches:
            return "Every dispatch you receive may be sent as a Critical Alert."
        }
    }
}


enum DispatchAlertTone: String, Codable, CaseIterable, Identifiable {
    case systemDefault = "SYSTEM_DEFAULT"
    case silent = "SILENT"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemDefault:
            return "Default System Sound"
        case .silent:
            return "Silent"
        }
    }

    var subtitle: String {
        switch self {
        case .systemDefault:
            return "Uses the normal iOS notification sound for dispatch alerts."
        case .silent:
            return "Dispatch alerts appear visually without a notification sound."
        }
    }
}

struct NotificationPreferencesResponse: Codable {
    var hapticsEnabled: Bool?
    let success: Bool
    let preferences: NotificationPreferences?
    let error: String?
}

struct NotificationPreferences: Codable, Equatable {
    var isEnabled: Bool = true

    var dispatchAlertsEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var criticalDispatchAlerts: Bool = false
    var criticalDispatchAlertMode: CriticalDispatchAlertMode = .seriousOnly
    var dispatchAlertTone: DispatchAlertTone = .systemDefault
    var callTypes: Set<String> = ["FIRE", "EMS", "MVA"]
    var workingOnly: Bool = false

    var normalAlertScheduleMode: NotificationScheduleMode = .always
    var criticalAlertScheduleMode: NotificationScheduleMode = .always

    var allUnits: Bool = true
    var units: Set<String> = []
    var stations: Set<String> = []

    var departmentMessagesEnabled: Bool = true
    var stationMessagesEnabled: Bool = true
    var messageCenterEnabled: Bool = true

    var trainingAssignmentsEnabled: Bool = true
    var documentAssignmentsEnabled: Bool = true

    var quietHoursEnabled: Bool = false
    var quietStart: Date = NotificationPreferences.defaultQuietStart()
    var quietEnd: Date = NotificationPreferences.defaultQuietEnd()

    var respectDoNotDisturb: Bool = true

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case dispatchAlertsEnabled
        case hapticsEnabled
        case criticalDispatchAlerts
        case criticalDispatchAlertMode
        case dispatchAlertTone
        case callTypes
        case workingOnly
        case normalAlertScheduleMode
        case criticalAlertScheduleMode
        case allUnits
        case units
        case stations
        case departmentMessagesEnabled
        case stationMessagesEnabled
        case messageCenterEnabled
        case trainingAssignmentsEnabled
        case documentAssignmentsEnabled
        case quietHoursEnabled
        case quietStart
        case quietEnd
        case respectDoNotDisturb
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        dispatchAlertsEnabled = try container.decodeIfPresent(Bool.self, forKey: .dispatchAlertsEnabled) ?? true
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        criticalDispatchAlerts = try container.decodeIfPresent(Bool.self, forKey: .criticalDispatchAlerts) ?? false
        criticalDispatchAlertMode = try container.decodeIfPresent(CriticalDispatchAlertMode.self, forKey: .criticalDispatchAlertMode) ?? .seriousOnly
        dispatchAlertTone = try container.decodeIfPresent(DispatchAlertTone.self, forKey: .dispatchAlertTone) ?? .systemDefault
        callTypes = try container.decodeIfPresent(Set<String>.self, forKey: .callTypes) ?? ["FIRE", "EMS", "MVA"]
        workingOnly = try container.decodeIfPresent(Bool.self, forKey: .workingOnly) ?? false

        normalAlertScheduleMode = try container.decodeIfPresent(NotificationScheduleMode.self, forKey: .normalAlertScheduleMode) ?? .always
        criticalAlertScheduleMode = try container.decodeIfPresent(NotificationScheduleMode.self, forKey: .criticalAlertScheduleMode) ?? .always

        allUnits = try container.decodeIfPresent(Bool.self, forKey: .allUnits) ?? true
        units = try container.decodeIfPresent(Set<String>.self, forKey: .units) ?? []
        stations = try container.decodeIfPresent(Set<String>.self, forKey: .stations) ?? []

        departmentMessagesEnabled = try container.decodeIfPresent(Bool.self, forKey: .departmentMessagesEnabled) ?? true
        stationMessagesEnabled = try container.decodeIfPresent(Bool.self, forKey: .stationMessagesEnabled) ?? true
        messageCenterEnabled = try container.decodeIfPresent(Bool.self, forKey: .messageCenterEnabled) ?? true

        trainingAssignmentsEnabled = try container.decodeIfPresent(Bool.self, forKey: .trainingAssignmentsEnabled) ?? true
        documentAssignmentsEnabled = try container.decodeIfPresent(Bool.self, forKey: .documentAssignmentsEnabled) ?? true

        quietHoursEnabled = try container.decodeIfPresent(Bool.self, forKey: .quietHoursEnabled) ?? false

        let quietStartString = try container.decodeIfPresent(String.self, forKey: .quietStart)
        let quietEndString = try container.decodeIfPresent(String.self, forKey: .quietEnd)

        quietStart = Self.dateFromHHMM(quietStartString) ?? Self.defaultQuietStart()
        quietEnd = Self.dateFromHHMM(quietEndString) ?? Self.defaultQuietEnd()

        respectDoNotDisturb = try container.decodeIfPresent(Bool.self, forKey: .respectDoNotDisturb) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(dispatchAlertsEnabled, forKey: .dispatchAlertsEnabled)
        try container.encode(hapticsEnabled, forKey: .hapticsEnabled)
        try container.encode(criticalDispatchAlerts, forKey: .criticalDispatchAlerts)
        try container.encode(criticalDispatchAlertMode, forKey: .criticalDispatchAlertMode)
        try container.encode(dispatchAlertTone, forKey: .dispatchAlertTone)
        try container.encode(callTypes, forKey: .callTypes)
        try container.encode(workingOnly, forKey: .workingOnly)

        try container.encode(normalAlertScheduleMode, forKey: .normalAlertScheduleMode)
        try container.encode(criticalAlertScheduleMode, forKey: .criticalAlertScheduleMode)

        try container.encode(allUnits, forKey: .allUnits)
        try container.encode(units, forKey: .units)
        try container.encode(stations, forKey: .stations)

        try container.encode(departmentMessagesEnabled, forKey: .departmentMessagesEnabled)
        try container.encode(stationMessagesEnabled, forKey: .stationMessagesEnabled)
        try container.encode(messageCenterEnabled, forKey: .messageCenterEnabled)

        try container.encode(trainingAssignmentsEnabled, forKey: .trainingAssignmentsEnabled)
        try container.encode(documentAssignmentsEnabled, forKey: .documentAssignmentsEnabled)

        try container.encode(quietHoursEnabled, forKey: .quietHoursEnabled)
        try container.encode(Self.hhmmFromDate(quietStart), forKey: .quietStart)
        try container.encode(Self.hhmmFromDate(quietEnd), forKey: .quietEnd)

        try container.encode(respectDoNotDisturb, forKey: .respectDoNotDisturb)
    }

    private static func dateFromHHMM(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let parts = value.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0

        return Calendar.current.date(from: components)
    }

    private static func hhmmFromDate(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }

    private static func defaultQuietStart() -> Date {
        dateFromHHMM("22:00") ?? Date()
    }

    private static func defaultQuietEnd() -> Date {
        dateFromHHMM("06:00") ?? Date()
    }
}
