import Foundation

struct NotificationEngine {

    static func shouldNotify(
        payload: AppNotificationPayload,
        preferences: NotificationPreferences,
        canUseScheduleBasedNotifications: Bool = false,
        isCurrentlyWorking: Bool = false
    ) -> Bool {

        print("🧠 Evaluating notification")
        print("   type:", payload.type.rawValue)
        print("   id:", payload.id)
        print("   title:", payload.title)
        print("   callType:", payload.callType ?? "nil")
        print("   units:", payload.units)

        guard preferences.isEnabled else {
            print("🔕 Suppressed: master notifications disabled")
            return false
        }

        switch payload.type {
        case .dispatch, .dispatchCritical:
            return shouldNotifyDispatch(
                payload: payload,
                preferences: preferences,
                canUseScheduleBasedNotifications: canUseScheduleBasedNotifications,
                isCurrentlyWorking: isCurrentlyWorking
            )

        case .departmentMessage:
            guard preferences.departmentMessagesEnabled else {
                print("🔕 Suppressed: department messages disabled")
                return false
            }
            return quietHoursAllowed(payload: payload, preferences: preferences)

        case .stationMessage:
            guard preferences.stationMessagesEnabled else {
                print("🔕 Suppressed: station messages disabled")
                return false
            }
            return quietHoursAllowed(payload: payload, preferences: preferences)

        case .trainingAssignment:
            guard preferences.trainingAssignmentsEnabled else {
                print("🔕 Suppressed: training assignments disabled")
                return false
            }
            return quietHoursAllowed(payload: payload, preferences: preferences)

        case .documentAssignment:
            guard preferences.documentAssignmentsEnabled else {
                print("🔕 Suppressed: document assignments disabled")
                return false
            }
            return quietHoursAllowed(payload: payload, preferences: preferences)

        case .messageCenter:
            guard preferences.messageCenterEnabled else {
                print("🔕 Suppressed: message center disabled")
                return false
            }
            return quietHoursAllowed(payload: payload, preferences: preferences)

        case .unknown:
            print("🔕 Suppressed: unknown notification type")
            return false
        }
    }

    private static func shouldNotifyDispatch(
        payload: AppNotificationPayload,
        preferences: NotificationPreferences,
        canUseScheduleBasedNotifications: Bool,
        isCurrentlyWorking: Bool
    ) -> Bool {

        let isCriticalDispatch =
            payload.type == .dispatchCritical ||
            (
                payload.type == .dispatch &&
                preferences.criticalDispatchAlerts &&
                preferences.criticalDispatchAlertMode == .allDispatches
            )

        guard preferences.dispatchAlertsEnabled else {
            print("🔕 Suppressed: dispatch alerts disabled")
            return false
        }

        if isCriticalDispatch && !preferences.criticalDispatchAlerts {
            print("🔕 Suppressed: critical dispatch alerts disabled")
            return false
        }

        let incomingType = (payload.callType ?? "Dispatch").uppercased()

        if !preferences.callTypes.isEmpty {
            let allowed = preferences.callTypes.contains { allowedType in
                incomingType.contains(allowedType.uppercased())
            }

            if !allowed {
                print("🔕 Suppressed: dispatch call type mismatch")
                print("   incoming:", incomingType)
                print("   allowed:", preferences.callTypes)
                return false
            }
        }

        let scheduleMode = isCriticalDispatch
            ? preferences.criticalAlertScheduleMode
            : preferences.normalAlertScheduleMode

        switch scheduleMode {
        case .always:
            break

        case .never:
            print("🔕 Suppressed: dispatch schedule mode is off")
            return false

        case .onlyWhenWorking:
            guard canUseScheduleBasedNotifications else {
                print("⚠️ Only while working selected, but this user is not eligible for schedule-based notifications. Falling back to always.")
                break
            }

            guard isCurrentlyWorking else {
                print("🔕 Suppressed: user is not currently listed on schedule")
                return false
            }
        }

        if preferences.workingOnly {
            let isWorkingFire =
                payload.isWorkingFire ||
                incomingType.contains("WORKING") ||
                incomingType.contains("STRUCTURE FIRE") ||
                incomingType.contains("BUILDING FIRE")

            if !isWorkingFire {
                print("🔕 Suppressed: working fires only enabled")
                print("   incoming:", incomingType)
                return false
            }
        }

        if !preferences.allUnits {
            let incomingUnits = Set(payload.units.map { $0.uppercased() })
            let selectedUnits = Set(preferences.units.map { $0.uppercased() })

            if selectedUnits.isEmpty {
                print("🔕 Suppressed: all units off and no specific units selected")
                return false
            }

            if incomingUnits.isDisjoint(with: selectedUnits) {
                print("🔕 Suppressed: dispatch unit mismatch")
                print("   incoming:", incomingUnits)
                print("   selected:", selectedUnits)
                return false
            }
        }

        if isCriticalDispatch && preferences.criticalDispatchAlerts {
            print("✅ Critical dispatch allowed")
            return true
        }

        return quietHoursAllowed(payload: payload, preferences: preferences)
    }

    private static func quietHoursAllowed(
        payload: AppNotificationPayload,
        preferences: NotificationPreferences
    ) -> Bool {

        guard preferences.quietHoursEnabled else {
            print("✅ Notification allowed")
            return true
        }

        let now = Date()

        let nowMin = minutes(from: now)
        let startMin = minutes(from: preferences.quietStart)
        let endMin = minutes(from: preferences.quietEnd)

        let isQuiet: Bool

        if startMin < endMin {
            isQuiet = nowMin >= startMin && nowMin <= endMin
        } else {
            isQuiet = nowMin >= startMin || nowMin <= endMin
        }

        if isQuiet {
            print("🔕 Suppressed: quiet hours active")
            print("   type:", payload.type.rawValue)
            print("   nowMin:", nowMin)
            print("   startMin:", startMin)
            print("   endMin:", endMin)
            return false
        }

        print("✅ Notification allowed")
        return true
    }

    private static func minutes(from date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
    }



//  NotificationEngine.swift
//  MTFD Member App
//
//  Created by Michael Zucker on 4/27/26.
//


