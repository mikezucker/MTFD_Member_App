
import Foundation

import ActivityKit

struct DispatchLiveActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {

        var callType: String

        var address: String

        var units: [String]

        var statusText: String

        var isCritical: Bool

        var isWorkingFire: Bool

        var activeCallCount: Int

        var lastUpdated: Date

    }

    var dispatchId: String

    var startedAt: Date

}

