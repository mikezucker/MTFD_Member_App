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
        center.delegate = self

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("Notification permission error:", error)
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

extension NotificationManager: UNUserNotificationCenterDelegate {}
