import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    static var latestAPNsToken: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("🔥 AppDelegate didFinishLaunching fired")

        UNUserNotificationCenter.current().delegate = self

        Task {
            await NotificationManager.shared.requestPermission()
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Do not automatically clear badge count here.
        // Dispatch badges should reflect uncleared dispatches, not whether the app is open.
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        AppDelegate.latestAPNsToken = token

        print("📲 APNs Token captured: \(token)")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
    }

    // MARK: - Foreground Notifications

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        print("🔍 FULL PAYLOAD:", userInfo)
        print("🔔 Notification received foreground:", userInfo)

        guard let payload = AppNotificationPayload.from(userInfo: userInfo) else {
            print("📲 Unknown/non-app notification received foreground")

            completionHandler([.banner, .sound, .badge])
            return
        }

        Task {
            let preferences = NotificationPreferencesViewModel().preferences
            let scheduleContext = await makeScheduleNotificationContext()

            guard NotificationEngine.shouldNotify(
                payload: payload,
                preferences: preferences,
                canUseScheduleBasedNotifications: scheduleContext.canUseScheduleBasedNotifications,
                isCurrentlyWorking: scheduleContext.isCurrentlyWorking
            ) else {
                print("🔕 Notification suppressed by preferences:", payload.id)

                completionHandler([])
                return
            }

            print("✅ Notification allowed by preferences:", payload.id)

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .didReceiveDispatchNotification,
                    object: payload
                )
            }

            completionHandler([.banner, .sound, .badge])
        }
    }

    // MARK: - Notification Tap Handling

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        print("📲 Notification tapped:", userInfo)

        guard let payload = AppNotificationPayload.from(userInfo: userInfo) else {
            print("📲 Unknown/non-app notification tapped")

            completionHandler()
            return
        }

        Task {
            let preferences = NotificationPreferencesViewModel().preferences
            let scheduleContext = await makeScheduleNotificationContext()

            guard NotificationEngine.shouldNotify(
                payload: payload,
                preferences: preferences,
                canUseScheduleBasedNotifications: scheduleContext.canUseScheduleBasedNotifications,
                isCurrentlyWorking: scheduleContext.isCurrentlyWorking
            ) else {
                print("🔕 Tapped notification ignored by preferences:", payload.id)

                completionHandler()
                return
            }

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .didReceiveDispatchNotification,
                    object: payload
                )

                NavigationRouter.shared.route(from: payload)
            }

            completionHandler()
        }
    }

    private func makeScheduleNotificationContext() async -> (canUseScheduleBasedNotifications: Bool, isCurrentlyWorking: Bool) {
        guard let currentUser = await MainActor.run(body: { SessionManager.shared.currentUser }) else {
            return (false, false)
        }

        let role = currentUser.role.uppercased()

        let canUseScheduleBasedNotifications =
            role == "CHIEF" ||
            role == "OFFICER_CAREER" ||
            role == "MEMBER_CAREER" ||
            currentUser.isReliefDriver

        guard canUseScheduleBasedNotifications else {
            return (false, false)
        }

        do {
            let response = try await APIClient.shared.fetchMobileSchedule()
            let isWorking = isUserListedOnSchedule(
                currentUser: currentUser,
                entries: response.entries
            )

            print("🗓️ Schedule notification context:", "eligible=\(canUseScheduleBasedNotifications)", "working=\(isWorking)")

            return (canUseScheduleBasedNotifications, isWorking)
        } catch {
            print("⚠️ Failed to fetch schedule for notification context:", error.localizedDescription)
            return (canUseScheduleBasedNotifications, false)
        }
    }

    private func isUserListedOnSchedule(
        currentUser: APIClient.Member,
        entries: [APIClient.MobileScheduleEntry]
    ) -> Bool {
        let userName = normalizedScheduleName(currentUser.name)

        guard !userName.isEmpty else {
            return false
        }

        for entry in entries {
            for detail in entry.staffingDetails {
                guard !detail.isVacant,
                      let name = detail.name else {
                    continue
                }

                let scheduleName = normalizedScheduleName(name)

                if scheduleName == userName ||
                    scheduleName.contains(userName) ||
                    userName.contains(scheduleName) {
                    return true
                }
            }
        }

        return false
    }

    private func normalizedScheduleName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "  ", with: " ")
    }
}
