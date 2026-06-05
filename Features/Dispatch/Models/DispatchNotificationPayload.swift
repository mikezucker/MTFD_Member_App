import Foundation
import Combine

enum AppNotificationType: String {
    case dispatch = "dispatch"
    case dispatchCritical = "dispatch_critical"

    case departmentMessage = "department_message"
    case stationMessage = "station_message"
    case trainingAssignment = "training_assignment"
    case documentAssignment = "document_assignment"
    case messageCenter = "message_center"
    case unknown = "unknown"

    init(rawValueSafe value: String?) {
        let normalized = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self = AppNotificationType(rawValue: normalized) ?? .unknown
    }
}

struct AppNotificationPayload: Identifiable {
    let type: AppNotificationType
    let id: String
    let title: String
    let body: String?

    // Dispatch-only fields
    let callType: String?
    let address: String?
    let units: [String]
    let isWorkingFire: Bool
    let activeCallCount: Int

    // Optional routing/context fields
    let stationId: String?
    let messageId: String?
    let trainingId: String?
    let documentId: String?

    static func from(userInfo: [AnyHashable: Any]) -> AppNotificationPayload? {
        let type = AppNotificationType(rawValueSafe: userInfo["type"] as? String)

        guard type != .unknown else {
            return nil
        }

        let id =
            userInfo["id"] as? String ??
            userInfo["dispatchId"] as? String ??
            userInfo["messageId"] as? String ??
            userInfo["trainingId"] as? String ??
            userInfo["documentId"] as? String ??
            UUID().uuidString

        let title =
            userInfo["title"] as? String ??
            defaultTitle(for: type)

        let body = userInfo["body"] as? String

        let callType = userInfo["callType"] as? String
        let address = userInfo["address"] as? String

        let units: [String]
        if let stringUnits = userInfo["units"] as? [String] {
            units = stringUnits
        } else if let nsArrayUnits = userInfo["units"] as? NSArray {
            units = nsArrayUnits.compactMap { $0 as? String }
        } else if let singleUnit = userInfo["unit"] as? String {
            units = [singleUnit]
        } else {
            units = []
        }

        let isWorkingFire: Bool = {
            if let b = userInfo["isWorkingFire"] as? Bool { return b }
            if let s = userInfo["isWorkingFire"] as? String {
                let normalized = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return normalized == "true" || normalized == "1" || normalized == "yes"
            }
            if let n = userInfo["isWorkingFire"] as? NSNumber { return n.boolValue }
            return false
        }()

        let activeCallCount: Int = {
            if let n = userInfo["activeCallCount"] as? Int {
                return max(1, n)
            }
            if let n = userInfo["activeCallCount"] as? NSNumber {
                return max(1, n.intValue)
            }
            if let s = userInfo["activeCallCount"] as? String,
               let n = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return max(1, n)
            }
            return 1
        }()

        return AppNotificationPayload(
            type: type,
            id: id,
            title: title,
            body: body,
            callType: callType,
            address: address,
            units: units,
            isWorkingFire: isWorkingFire,
            activeCallCount: activeCallCount,
            stationId: userInfo["stationId"] as? String,
            messageId: userInfo["messageId"] as? String,
            trainingId: userInfo["trainingId"] as? String,
            documentId: userInfo["documentId"] as? String
        )
    }

    private static func defaultTitle(for type: AppNotificationType) -> String {
        switch type {
        case .dispatch, .dispatchCritical:
            return "Dispatch Alert"
        case .departmentMessage:
            return "Department Message"
        case .stationMessage:
            return "Station Message"
        case .trainingAssignment:
            return "Training Assignment"
        case .documentAssignment:
            return "Document Assignment"
        case .messageCenter:
            return "Message Center"
        case .unknown:
            return "Notification"
        }
    }
}

// Backward-compatible alias so older files that reference DispatchNotificationPayload
// do not immediately explode while we migrate the app.
typealias DispatchNotificationPayload = AppNotificationPayload
