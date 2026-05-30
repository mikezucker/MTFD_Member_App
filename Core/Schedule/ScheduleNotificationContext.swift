import Foundation

struct ScheduleNotificationContext {
    let canUseScheduleBasedNotifications: Bool
    let isCurrentlyWorking: Bool
}

enum ScheduleNotificationContextProvider {
    static func makeContext(currentUser: APIClient.Member?) async -> ScheduleNotificationContext {
        guard let currentUser else {
            return ScheduleNotificationContext(
                canUseScheduleBasedNotifications: false,
                isCurrentlyWorking: false
            )
        }

        let role = currentUser.role.uppercased()

        let canUseScheduleBasedNotifications =
            role == "CHIEF" ||
            role == "OFFICER_CAREER" ||
            role == "MEMBER_CAREER" ||
            currentUser.isReliefDriver

        guard canUseScheduleBasedNotifications else {
            return ScheduleNotificationContext(
                canUseScheduleBasedNotifications: false,
                isCurrentlyWorking: false
            )
        }

        do {
            let response = try await APIClient.shared.fetchMobileSchedule()
            let isWorking = isUserListedOnSchedule(
                currentUser: currentUser,
                entries: response.entries
            )

            return ScheduleNotificationContext(
                canUseScheduleBasedNotifications: true,
                isCurrentlyWorking: isWorking
            )
        } catch {
            print("⚠️ Failed to fetch schedule context:", error.localizedDescription)

            return ScheduleNotificationContext(
                canUseScheduleBasedNotifications: canUseScheduleBasedNotifications,
                isCurrentlyWorking: false
            )
        }
    }

    private static func isUserListedOnSchedule(
        currentUser: APIClient.Member,
        entries: [APIClient.MobileScheduleEntry]
    ) -> Bool {
        let userName = normalize(currentUser.name)

        guard !userName.isEmpty else {
            return false
        }

        for entry in entries {
            for detail in entry.staffingDetails {
                guard !detail.isVacant,
                      let name = detail.name else {
                    continue
                }

                let scheduleName = normalize(name)

                if scheduleName == userName ||
                    scheduleName.contains(userName) ||
                    userName.contains(scheduleName) {
                    return true
                }
            }
        }

        return false
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "  ", with: " ")
    }
}
