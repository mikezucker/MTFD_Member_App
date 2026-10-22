import Foundation
import UserNotifications
import UIKit
import Combine

final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    func requestPermission(includeCriticalAlert: Bool = false) async {
        let center = UNUserNotificationCenter.current()

        do {
            // Merge rather than replacing categories registered by other features.
            var categories = await center.notificationCategories()
            categories = Set(categories.filter { $0.identifier != "MTFD_DISPATCH" })
            categories.insert(UNNotificationCategory(
                identifier: "MTFD_DISPATCH",
                actions: [],
                intentIdentifiers: [],
                options: [.allowInCarPlay]
            ))
            center.setNotificationCategories(categories)

            var options: UNAuthorizationOptions = [.alert, .badge, .sound, .carPlay]

            let currentSettings = await center.notificationSettings()
            if includeCriticalAlert && currentSettings.criticalAlertSetting != .notSupported {
                options.insert(.criticalAlert)
            }

            let granted = try await center.requestAuthorization(
                options: options
            )

            print("🔔 Notification permission granted:", granted)

            let settings = await center.notificationSettings()
            print("🔔 authorizationStatus:", settings.authorizationStatus.rawValue)
            print("🔊 soundSetting:", settings.soundSetting.rawValue)
            print("🚨 criticalAlertSetting:", settings.criticalAlertSetting.rawValue)

            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("❌ Notification permission error:", error)
        }
    }

    func requestCriticalAlertPermission() async {
        await requestPermission(includeCriticalAlert: true)
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("APNs token:", token)
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("APNs registration failed:", error)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
}

// An optional, device-local presentation preference. This never acknowledges a call.
@MainActor
final class DispatchAttentionPresenter {
    static let shared = DispatchAttentionPresenter()
    static let preferenceKey = "persistent_dispatch_popup_enabled"

    private var queue = DispatchAttentionQueue()
    private weak var alert: UIAlertController?
    private var isTransitioning = false
    private var previewDispatchID: String?

    func preview() {
        guard queue.current == nil else { resume(); return }
        let id = UUID().uuidString
        previewDispatchID = id
        if let payload = AppNotificationPayload.from(userInfo: [
            "type": "dispatch", "id": id, "title": "Popup Preview",
            "body": "This is a preview of the persistent dispatch popup. No notification was sent and no dispatch was created."
        ]) { receive(payload) }
    }

    func receive(_ payload: AppNotificationPayload) {
        if payload.type == .dispatchClosed {
            let wasVisible = queue.current?.id == payload.id
            queue.remove(dispatchId: payload.id)
            if wasVisible { dismissCurrent() }
            return
        }
        guard UserDefaults.standard.bool(forKey: Self.preferenceKey),
              SessionManager.shared.isLoggedIn else { return }
        queue.enqueue(payload)
        presentNext()
    }

    func clear() {
        queue = DispatchAttentionQueue()
        previewDispatchID = nil
        dismissCurrent()
    }

    func opened(dispatchId: String) {
        let wasVisible = queue.current?.id == dispatchId
        queue.remove(dispatchId: dispatchId)
        if wasVisible { dismissCurrent() }
    }

    private func dismissCurrent() {
        guard let alert else { presentNext(); return }
        isTransitioning = true
        alert.dismiss(animated: false) { [weak self] in
            self?.alert = nil
            self?.isTransitioning = false
            self?.presentNext()
        }
    }

    private func presentNext() {
        guard alert == nil, !isTransitioning, let payload = queue.current,
              SessionManager.shared.isLoggedIn,
              UIApplication.shared.applicationState == .active,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive && $0.session.role == .windowApplication }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        // Do not compete with a system alert or a controller being dismissed.
        guard !(top is UIAlertController), !top.isBeingDismissed, !top.isBeingPresented else {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000)
                self?.presentNext()
            }
            return
        }
        let isPreview = payload.id == previewDispatchID
        let details = [
            payload.address,
            payload.units.isEmpty ? nil : "Apparatus: " + payload.units.joined(separator: ", "),
            payload.body,
            "Dismiss Alert only clears this popup. It does not mark you responding."
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let controller = UIAlertController(
            title: isPreview ? "DISPATCH POPUP PREVIEW" : "NEW DISPATCH\n" + (payload.callType ?? payload.title),
            message: details.joined(separator: "\n\n"), preferredStyle: .alert
        )
        if !isPreview {
        controller.addAction(UIAlertAction(title: "View Dispatch", style: .default) { [weak self] _ in
            guard let self else { return }
            self.queue.remove(dispatchId: payload.id)
            self.alert = nil
            self.isTransitioning = true
            // Close a Settings/detail sheet before routing to the dashboard.
            let route = {
                NavigationRouter.shared.route(from: payload)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    self.isTransitioning = false
                    self.presentNext()
                }
            }
            if root.presentedViewController != nil { root.dismiss(animated: true, completion: route) }
            else { route() }
        })
        }
        controller.addAction(UIAlertAction(title: "Dismiss Alert", style: .cancel) { [weak self] _ in
            guard let self else { return }
            self.queue.remove(dispatchId: payload.id)
            self.alert = nil
            self.isTransitioning = true
            // UIKit calls the action before finishing its dismissal animation.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                self.isTransitioning = false
                self.presentNext()
            }
        })
        controller.preferredAction = controller.actions.first
        alert = controller
        top.present(controller, animated: true)
    }

    func resume() { presentNext() }
}
