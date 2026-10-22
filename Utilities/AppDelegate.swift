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
            await NotificationManager.shared.requestPermission(includeCriticalAlert: true)
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in DispatchAttentionPresenter.shared.resume() }
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

        let session = WCSession.default
        session.delegate = self

        if session.activationState == .notActivated {
            session.activate()
        }
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
        Task { @MainActor in WatchSettingsController.shared.sync() }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in WatchSettingsController.shared.refreshConnection() }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in WatchSettingsController.shared.sync() }
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

    // MARK: - Foreground Notifications

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        if userInfo["type"] as? String == "password_recovery_admin" {
            // Security alerts never enter dispatch filtering, receipts, badges, haptics or Live Activities.
            completionHandler([.banner, .sound])
            return
        }

        if userInfo["type"] as? String == "test_push" {
            // Exercise the real foreground feedback path without creating a call,
            // receipt, Live Activity, or dispatch navigation target.
            Task { @MainActor in
                let preferences = NotificationPreferencesViewModel().preferences
                let style = (userInfo["hapticAlertStyle"] as? String).flatMap(HapticAlertStyle.init(rawValue:))
                    ?? preferences.hapticAlertStyle
                self.playForegroundDispatchHaptics(
                    id: userInfo["id"] as? String ?? notification.request.identifier,
                    style: style, isCritical: userInfo["critical"] as? Bool ?? false
                )
                completionHandler([.banner, .sound])
            }
            return
        }

        print("🔍 FULL PAYLOAD:", userInfo)
        print("🔔 Notification received foreground:", userInfo)

        guard let payload = AppNotificationPayload.from(userInfo: userInfo) else {
            print("📲 Unknown/non-app notification received foreground")

            completionHandler([.banner, .sound, .badge])
            return
        }

        recordDispatchPushReceipt(payload: payload, event: "foreground_received")

        Task {
            // A closure clears an existing popup even when closure alerts are disabled.
            if payload.type == .dispatchClosed {
                await MainActor.run { DispatchAttentionPresenter.shared.receive(payload) }
            }
            let preferences = NotificationPreferencesViewModel().preferences
            let needsSchedule = preferences.normalAlertScheduleMode == .onlyWhenWorking
                || preferences.criticalAlertScheduleMode == .onlyWhenWorking
            let scheduleContext = needsSchedule
                ? await makeScheduleNotificationContext()
                : (canUseScheduleBasedNotifications: false, isCurrentlyWorking: false)

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

            let isNewDispatch = payload.type == .dispatch || payload.type == .dispatchCritical
            let isDispatch = isNewDispatch || payload.type == .dispatchClosed
            let isCritical = NotificationEngine.usesCriticalAlert(payload: payload, preferences: preferences)
            DispatchQueue.main.async {
                if isNewDispatch {
                    DispatchAttentionPresenter.shared.receive(payload)
                    self.playForegroundDispatchHaptics(
                        id: payload.id, style: preferences.hapticAlertStyle, isCritical: isCritical
                    )
                }
                // iOS owns incoming alert audio so hardware buttons can silence it.
                // AVAudioPlayer is reserved for tone previews in Settings.
                NotificationCenter.default.post(
                    name: .didReceiveDispatchNotification,
                    object: payload
                )
            }

            var presentation: UNNotificationPresentationOptions = [.banner, .badge]
            let tone = isCritical ? preferences.criticalDispatchAlertTone : preferences.dispatchAlertTone
            if !isDispatch || tone != .silent {
                presentation.insert(.sound)
            }
            completionHandler(presentation)
        }
    }

    @MainActor
    private func playForegroundDispatchHaptics(id: String, style: HapticAlertStyle, isCritical: Bool) {
        guard UIApplication.shared.applicationState == .active else { return }
        HapticAlertManager.shared.playDispatchAlert(dispatchId: id, style: style, isCritical: isCritical)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState == .activated, session.isPaired,
           session.isWatchAppInstalled, session.isReachable {
            session.sendMessage([
                "action": "dispatch_haptic", "dispatchId": id,
                "hapticAlertStyle": style.rawValue, "critical": isCritical,
                "sentAt": Date().timeIntervalSince1970
            ], replyHandler: nil, errorHandler: { _ in })
        }
    }

    // MARK: - Notification Tap Handling

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if userInfo["type"] as? String == "test_push" {
            completionHandler()
            return
        }
        if userInfo["type"] as? String == "password_recovery_admin" {
            DispatchQueue.main.async {
                NavigationRouter.shared.selectedTab = .more
                NavigationRouter.shared.showPasswordRecoveryRequests = true
            }
            completionHandler()
            return
        }

        print("📲 Notification tapped:", userInfo)

        guard let payload = AppNotificationPayload.from(userInfo: userInfo) else {
            print("📲 Unknown/non-app notification tapped")

            completionHandler()
            return
        }

        recordDispatchPushReceipt(payload: payload, event: "opened")

        Task {
            // Opening a delivered alert must work after cold launch or a settings change.
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .didReceiveDispatchNotification,
                    object: payload
                )

                DispatchAttentionPresenter.shared.opened(dispatchId: payload.id)
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
        guard payload.type == .dispatch || payload.type == .dispatchCritical || payload.type == .dispatchClosed else {
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
