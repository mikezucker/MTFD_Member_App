import UIKit
import UserNotifications

@MainActor
final class AppBadgeManager {
    static let shared = AppBadgeManager()

    private init() {}

    func updateAppBadge(dispatchCount: Int, unreadMessageCount: Int) {
        let total = max(0, dispatchCount + unreadMessageCount)

        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(total) { error in
                if let error = error {
                    print("⚠️ Failed to set app badge:", error.localizedDescription)
                }
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = total
        }

        print("🔢 App badge updated:", total, [
            "dispatchCount": dispatchCount,
            "unreadMessageCount": unreadMessageCount
        ])
    }

    func clearAppBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    print("⚠️ Failed to clear app badge:", error.localizedDescription)
                }
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }

        print("🔢 App badge cleared")
    }
}//
//  AppBadgeManager.swift
//  MTFD Member App
//
//  Created by Michael Zucker on 5/11/26.
//


