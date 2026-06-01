import Foundation
import ActivityKit

@MainActor
final class DispatchLiveActivityManager {
    static let shared = DispatchLiveActivityManager()

    private init() {}

    private var activeActivity: Activity<DispatchLiveActivityAttributes>? {
        Activity<DispatchLiveActivityAttributes>.activities.first
    }

    var liveActivitiesAvailable: Bool {
        if #available(iOS 16.2, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }

        return false
    }

    func startOrUpdate(from dispatch: DispatchNotificationPayload) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let contentState = DispatchLiveActivityAttributes.ContentState(
            callType: dispatch.callType ?? dispatch.title,
            address: dispatch.address ?? dispatch.body ?? "Address unavailable",
            units: dispatch.units,
            statusText: dispatch.type == .dispatchCritical ? "Critical Dispatch" : "Active Dispatch",
            isCritical: dispatch.type == .dispatchCritical,
            isWorkingFire: dispatch.isWorkingFire,
            lastUpdated: Date()
        )

        if let activeActivity,
           activeActivity.attributes.dispatchId == dispatch.id {
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
                let attributes = DispatchLiveActivityAttributes(
                    dispatchId: dispatch.id,
                    startedAt: Date()
                )

                _ = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(
                        state: contentState,
                        staleDate: Date().addingTimeInterval(15 * 60)
                    ),
                    pushType: .token
                )
            } catch {
                print("Live Activity start failed: \(error.localizedDescription)")
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
        guard #available(iOS 16.2, *) else { return }

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
