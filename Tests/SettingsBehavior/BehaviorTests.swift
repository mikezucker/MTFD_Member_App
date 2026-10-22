import Foundation
let behaviorTestDefaults = UserDefaults(suiteName: "mtfd-settings-behavior-\(UUID().uuidString)")!
@main struct BehaviorTests {
    static func main() throws {
        let defaults=behaviorTestDefaults
        precondition(DispatchLiveActivitySettings(defaults:defaults).enabled)
        precondition(DispatchLiveActivitySettings(defaults:defaults).endWhenDispatchClears)
        for enabled in [false,true] { for end in [false,true] {
            defaults.set(enabled,forKey:"liveActivitiesEnabled")
            defaults.set(end,forKey:"liveActivitiesEndWhenDispatchClears")
            let policy=DispatchLiveActivitySettings(defaults:defaults)
            precondition(policy.enabled == enabled && policy.endWhenDispatchClears == end)
            precondition(policy.shouldEndAfterClear == (!enabled || end))
        }}
        let member="MEMBER_CAREER"
        let initial=DashboardCardLayoutDefaults.defaultOrder(for:member)
        let reordered=Array(initial.reversed())
        DashboardCardLayoutDefaults.saveOrder(reordered,for:member)
        DashboardCardLayoutDefaults.saveHiddenCards([.documents],for:member)
        precondition(DashboardCardLayoutDefaults.savedOrder(for:member) == reordered)
        precondition(DashboardCardLayoutDefaults.hiddenCards(for:member) == [.documents])
        precondition(DashboardCardLayoutDefaults.hiddenCards(for:"CHIEF").isEmpty)
        DashboardCardLayoutDefaults.reset(for:member)
        precondition(DashboardCardLayoutDefaults.savedOrder(for:member) == initial)
        precondition(DashboardCardLayoutDefaults.hiddenCards(for:member).isEmpty)
        print("PASS: Live Activity toggle combinations; dashboard reorder, hide, role separation and reset")
    }
}
