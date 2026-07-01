import UIKit
import UserNotifications
import MapKit
import WatchConnectivity

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, WCSessionDelegate {

    static var latestAPNsToken: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("🔥 AppDelegate didFinishLaunching fired")

        UNUserNotificationCenter.current().delegate = self
        configureWatchConnectivity()

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

        Task { @MainActor in
            await SessionManager.shared.registerPushTokenIfAvailable()
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
    }

    // MARK: - Watch Navigation Handoff

    private func configureWatchConnectivity() {
        guard WCSession.isSupported() else { return }

        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func handleWatchMessage(_ message: [String: Any]) {
        guard message["action"] as? String == "navigate_to_call",
              let address = message["address"] as? String else {
            return
        }

        openMapsForWatchNavigation(address: address)
    }

    private func openMapsForWatchNavigation(address: String) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAddress.isEmpty else { return }

        let searchAddress = trimmedAddress.localizedCaseInsensitiveContains("NJ")
            ? trimmedAddress
            : "\(trimmedAddress), Morris Township, NJ"

        if let encodedAddress = searchAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "http://maps.apple.com/?daddr=\(encodedAddress)&dirflg=d") {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("📱 WatchConnectivity activation failed: \(error.localizedDescription)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleWatchMessage(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleWatchMessage(applicationContext)
    }

    private static func currentHapticAlertStyle() -> HapticAlertStyle {
        if let rawValue = UserDefaults.standard.string(forKey: "notification_haptic_alert_style"),
           let style = HapticAlertStyle(rawValue: rawValue) {
            return style
        }

        if UserDefaults.standard.object(forKey: "notification_haptics_enabled") == nil {
            return .normal
        }

        return UserDefaults.standard.bool(forKey: "notification_haptics_enabled") ? .normal : .off
    }

    private static func currentDispatchAlertTone(isCritical: Bool) -> DispatchAlertTone {
        let key = isCritical
            ? "notification_critical_dispatch_alert_tone"
            : "notification_dispatch_alert_tone"

        if let rawValue = UserDefaults.standard.string(forKey: key),
           let tone = DispatchAlertTone(rawValue: rawValue) {
            return tone
        }

        guard let data = UserDefaults.standard.data(forKey: "notification_preferences"),
              let preferences = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else {
            return isCritical ? .airHornBlast : .systemDefault
        }

        return isCritical ? preferences.criticalDispatchAlertTone : preferences.dispatchAlertTone
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

        recordDispatchPushReceipt(payload: payload, event: "foreground_received")

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
                let isCritical = payload.type == .dispatchCritical

                DispatchAlertSoundManager.shared.playDispatchAlert(
                    dispatchId: payload.id,
                    tone: Self.currentDispatchAlertTone(isCritical: isCritical),
                    isCritical: isCritical
                )

                HapticAlertManager.shared.playDispatchAlert(
                    dispatchId: payload.id,
                    style: Self.currentHapticAlertStyle(),
                    isCritical: isCritical
                )

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

        recordDispatchPushReceipt(payload: payload, event: "opened")

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

    private func recordDispatchPushReceipt(payload: AppNotificationPayload, event: String) {
        guard payload.type == .dispatch || payload.type == .dispatchCritical else {
            return
        }

        Task {
            do {
                try await APIClient.shared.recordDispatchPushReceipt(
                    dispatchId: payload.id,
                    event: event,
                    notificationType: payload.type.rawValue,
                    deviceToken: Self.latestAPNsToken
                )
                print("📬 Dispatch push receipt recorded:", event, payload.id)
            } catch {
                print("⚠️ Dispatch push receipt failed:", event, payload.id, error.localizedDescription)
            }
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
