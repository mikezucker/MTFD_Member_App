import Foundation
@main struct PolicyTests {
    @MainActor static func main() throws {
        func payload(_ type: String = "dispatch", _ call: String = "EMS") -> AppNotificationPayload {
            AppNotificationPayload.from(userInfo: ["type": type, "id": "test", "callType": call])!
        }
        func allowed(_ p: NotificationPreferences, _ value: AppNotificationPayload, working: Bool = false) -> Bool {
            NotificationEngine.shouldNotify(payload: value, preferences: p, canUseScheduleBasedNotifications: true, isCurrentlyWorking: working)
        }
        var p = NotificationPreferences()
        p.callTypes = []
        precondition(allowed(p, payload("dispatch", "CARDIAC ARREST")))
        precondition(allowed(p, payload("dispatch_critical", "STRUCTURE FIRE")))
        p.normalAlertScheduleMode = .never
        precondition(!allowed(p, payload()))
        p.criticalDispatchAlerts = true
        precondition(allowed(p, payload("dispatch_critical", "STRUCTURE FIRE")))
        p.criticalAlertScheduleMode = .never
        precondition(!allowed(p, payload("dispatch_critical", "STRUCTURE FIRE")))
        p.criticalAlertScheduleMode = .onlyWhenWorking
        precondition(!allowed(p, payload("dispatch_critical", "STRUCTURE FIRE")))
        precondition(allowed(p, payload("dispatch_critical", "STRUCTURE FIRE"), working: true))
        p.normalAlertScheduleMode = .always
        p.criticalAlertScheduleMode = .always
        p.criticalDispatchAlertMode = .allDispatches
        precondition(NotificationEngine.usesCriticalAlert(payload: payload(), preferences: p))
        p.dispatchAlertTone = .silent
        p.criticalDispatchAlertTone = .silent
        let copy = try JSONDecoder().decode(NotificationPreferences.self, from: JSONEncoder().encode(p))
        precondition(copy.dispatchAlertTone == .silent && copy.criticalDispatchAlertTone == .silent)
        p.isEnabled = false
        precondition(!allowed(p, payload()))
        let messageSwitches: [(String, WritableKeyPath<NotificationPreferences, Bool>)] = [
            ("department_message", \.departmentMessagesEnabled),
            ("station_message", \.stationMessagesEnabled),
            ("message_center", \.messageCenterEnabled),
            ("training_assignment", \.trainingAssignmentsEnabled),
            ("document_assignment", \.documentAssignmentsEnabled)
        ]
        for (type, key) in messageSwitches {
            var preferences = NotificationPreferences()
            precondition(allowed(preferences, payload(type)))
            preferences[keyPath: key] = false
            precondition(!allowed(preferences, payload(type)))
            preferences[keyPath: key] = true
            preferences.isEnabled = false
            precondition(!allowed(preferences, payload(type)))
        }
        var filtered = NotificationPreferences()
        filtered.allUnits = false
        filtered.units = []
        precondition(!allowed(filtered, payload()))
        filtered.allUnits = true
        filtered.callTypes = ["HAZMAT"]
        precondition(!allowed(filtered, payload()))
        precondition(allowed(filtered, payload("dispatch", "HAZMAT")))
        let closed = payload("dispatch_closed", "STRUCTURE FIRE")
        var closurePreferences = NotificationPreferences()
        precondition(!closurePreferences.dispatchClosedAlertsEnabled)
        precondition(!allowed(closurePreferences, closed))
        closurePreferences.dispatchClosedAlertsEnabled = true
        closurePreferences.criticalDispatchAlerts = true
        closurePreferences.criticalDispatchAlertMode = .allDispatches
        closurePreferences.criticalAlertScheduleMode = .never
        precondition(!NotificationEngine.usesCriticalAlert(payload: closed, preferences: closurePreferences))
        precondition(allowed(closurePreferences, closed))
        closurePreferences.workingOnly = true
        precondition(allowed(closurePreferences, payload("dispatch_closed", "CONFIRMED FIRE")))
        precondition(!allowed(closurePreferences, payload("dispatch_closed", "EMS")))
        closurePreferences.workingOnly = false
        closurePreferences.normalAlertScheduleMode = .never
        precondition(!allowed(closurePreferences, closed))
        closurePreferences.normalAlertScheduleMode = .always
        closurePreferences.quietHoursEnabled = true
        closurePreferences.quietStart = Date()
        closurePreferences.quietEnd = Date()
        precondition(!allowed(closurePreferences, closed))
        let roundTrip = try JSONDecoder().decode(NotificationPreferences.self, from: JSONEncoder().encode(closurePreferences))
        precondition(roundTrip.dispatchClosedAlertsEnabled)
        let legacy = try JSONDecoder().decode(NotificationPreferences.self, from: Data("{}".utf8))
        precondition(!legacy.dispatchClosedAlertsEnabled)
        let router = NavigationRouter()
        router.route(from: closed)
        precondition(router.closedDispatchToOpen?.id == closed.id && router.dispatchToOpen == nil)
        router.resetToHome()
        precondition(router.closedDispatchToOpen == nil)
        print("PASS: normal/critical fallback, independent schedules, duty filter, all-dispatch promotion, Silent round-trip, master Off")
    }
}
