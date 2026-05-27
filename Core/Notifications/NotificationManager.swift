import Foundation
import UserNotifications
import UIKit
import Combine

final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound, .criticalAlert]
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
