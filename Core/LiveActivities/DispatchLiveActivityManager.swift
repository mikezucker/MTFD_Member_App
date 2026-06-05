import Foundation
import ActivityKit

@MainActor
final class DispatchLiveActivityManager {
    static let shared = DispatchLiveActivityManager()

    private init() {}

    private var pushToStartTokenTask: Task<Void, Never>?

    private var activeActivity: Activity<DispatchLiveActivityAttributes>? {
        Activity<DispatchLiveActivityAttributes>.activities.first
    }


    func startObservingPushToStartToken() {
        guard #available(iOS 17.2, *) else {
            print("🟣 LiveActivity push-to-start unavailable: iOS below 17.2")
            return
        }

        guard pushToStartTokenTask == nil else { return }

        if let token = Activity<DispatchLiveActivityAttributes>.pushToStartToken {
            let tokenString = token.map { String(format: "%02x", $0) }.joined()
            print("🟣 LiveActivity existing push-to-start token:", tokenString.prefix(12), "...")
            Task {
                await registerPushToStartToken(tokenString)
            }
        }

        pushToStartTokenTask = Task {
            for await token in Activity<DispatchLiveActivityAttributes>.pushToStartTokenUpdates {
                let tokenString = token.map { String(format: "%02x", $0) }.joined()
                print("🟣 LiveActivity push-to-start token updated:", tokenString.prefix(12), "...")
                await registerPushToStartToken(tokenString)
            }
        }
    }

    private func registerPushToStartToken(_ token: String) async {
        do {
            try await APIClient.shared.registerLiveActivityPushToStartToken(token)
            print("✅ LiveActivity push-to-start token registered")
        } catch {
            print("🧨 LiveActivity push-to-start token register failed:", error.localizedDescription)
        }
    }

    var liveActivitiesAvailable: Bool {
        if #available(iOS 16.2, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }

        return false
    }

    func startOrUpdate(from dispatch: DispatchNotificationPayload) {
        print("🟣 LiveActivity startOrUpdate called:", dispatch.id, dispatch.title)

        guard #available(iOS 16.2, *) else {
            print("🟣 LiveActivity unavailable: iOS version below 16.2")
            return
        }

        let authorizationInfo = ActivityAuthorizationInfo()
        print("🟣 LiveActivity system enabled:", authorizationInfo.areActivitiesEnabled)

        guard authorizationInfo.areActivitiesEnabled else {
            print("🟣 LiveActivity blocked: ActivityAuthorizationInfo says disabled")
            return
        }

        let contentState = DispatchLiveActivityAttributes.ContentState(
            callType: dispatch.callType ?? dispatch.title,
            address: dispatch.address ?? dispatch.body ?? "Address unavailable",
            units: dispatch.units,
            statusText: dispatch.type == .dispatchCritical ? "Critical Dispatch" : "Active Dispatch",
            isCritical: dispatch.type == .dispatchCritical,
            isWorkingFire: dispatch.isWorkingFire,
            activeCallCount: dispatch.activeCallCount,
            lastUpdated: Date()
        )

        if let activeActivity,
           activeActivity.attributes.dispatchId == dispatch.id {
            print("🟣 LiveActivity updating existing activity:", activeActivity.id)
            Task {
                await activeActivity.update(
                    ActivityContent(
                        state: contentState,
                        staleDate: Date().addingTimeInterval(15 * 60)
                    )
                )
            }
            return
        }

        Task {
            await endAllExcept(dispatchId: dispatch.id)

            do {
                print("🟣 LiveActivity requesting new activity for dispatch:", dispatch.id)

                let attributes = DispatchLiveActivityAttributes(
                    dispatchId: dispatch.id,
                    startedAt: Date()
                )

                let activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(
                        state: contentState,
                        staleDate: Date().addingTimeInterval(15 * 60)
                    ),
                    pushType: .token
                )

                print("🟣 LiveActivity request succeeded:", activity.id)
            } catch {
                print("🧨 LiveActivity start failed:", error.localizedDescription)
                print("🧨 LiveActivity error:", error)
            }
        }
    }

    func end(dispatchId: String? = nil) {
        guard #available(iOS 16.2, *) else { return }

        Task {
            for activity in Activity<DispatchLiveActivityAttributes>.activities {
                if let dispatchId, activity.attributes.dispatchId != dispatchId {
                    continue
                }

                await activity.end(
                    ActivityContent(
                        state: activity.content.state,
                        staleDate: nil
                    ),
                    dismissalPolicy: .immediate
                )
            }
        }
    }

    func endAll() {
        print("🟣 LiveActivity endAll called")

        guard #available(iOS 16.2, *) else {
            print("🟣 LiveActivity endAll ignored: iOS version below 16.2")
            return
        }

        Task {
            for activity in Activity<DispatchLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func endAllExcept(dispatchId: String) async {
        guard #available(iOS 16.2, *) else { return }

        for activity in Activity<DispatchLiveActivityAttributes>.activities {
            if activity.attributes.dispatchId == dispatchId {
                continue
            }

            await activity.end(
                ActivityContent(
                    state: activity.content.state,
                    staleDate: nil
                ),
                dismissalPolicy: .immediate
            )
        }
    }
}
