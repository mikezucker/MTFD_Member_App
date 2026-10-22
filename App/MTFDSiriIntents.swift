import AppIntents
import Foundation
import UIKit

private enum MTFDIntentTimeoutError: Error {
    case timedOut
}

private func withMTFDIntentTimeout<T>(seconds: UInt64 = 8, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            throw MTFDIntentTimeoutError.timedOut
        }

        guard let result = try await group.next() else {
            throw MTFDIntentTimeoutError.timedOut
        }

        group.cancelAll()
        return result
    }
}

private enum MTFDIntentSupport {
    static func activeDispatch() async -> APIClient.ActiveDispatch? {
        do {
            let response = try await withMTFDIntentTimeout {
                try await APIClient.shared.fetchDispatchHistory(window: "24h")
            }
            return response.activeDispatches.first
        } catch {
            return nil
        }
    }

    static func payload(from dispatch: APIClient.ActiveDispatch) -> AppNotificationPayload {
        AppNotificationPayload(
            type: .dispatch,
            id: dispatch.id,
            title: dispatch.callType,
            body: dispatch.address,
            callType: dispatch.callType,
            address: dispatch.address,
            units: dispatch.units,
            isWorkingFire: dispatch.isWorkingFire ?? false,
            activeCallCount: 1,
            stationId: nil,
            messageId: nil,
            trainingId: nil,
            documentId: nil
        )
    }

    @MainActor
    static func openDispatch(_ dispatch: APIClient.ActiveDispatch) {
        NavigationRouter.shared.route(from: payload(from: dispatch))
    }

    @MainActor
    static func selectTab(_ tab: NavigationRouter.AppTab) {
        NavigationRouter.shared.selectedTab = tab
    }

    @MainActor
    static func openMaps(for dispatch: APIClient.ActiveDispatch) {
        let destination = [dispatch.placeName, dispatch.address, dispatch.address2, dispatch.city, dispatch.state]
            .compactMap { value in
                value?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        guard !destination.isEmpty,
              let encodedDestination = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://maps.apple.com/?daddr=\(encodedDestination)&dirflg=d") else {
            return
        }

        UIApplication.shared.open(url)
    }

    nonisolated static func callBucket(
        from stats: APIClient.DispatchStatsResponse,
        scope: MTFDCallTotalsScope,
        station: MTFDStationSelection
    ) -> APIClient.DispatchBucket? {
        switch scope {
        case .department:
            return stats.department ?? stats.stations?.all
        case .station:
            if station == .myStation {
                return stats.station
            }

            switch station {
            case .myStation:
                return stats.station
            case .station1:
                return stats.stations?.station1
            case .station2:
                return stats.stations?.station2
            case .station3:
                return stats.stations?.station3
            case .station4:
                return stats.stations?.station4
            case .station5:
                return stats.stations?.station5
            }
        }
    }

    nonisolated static func callValue(
        from bucket: APIClient.DispatchBucket,
        window: MTFDCallTotalsWindow,
        category: MTFDCallCategory
    ) -> Int? {
        switch (window, category) {
        case (.last24Hours, .total): return bucket.total24h
        case (.last7Days, .total): return bucket.total7d
        case (.last30Days, .total): return bucket.total30d
        case (.yearToDate, .total): return bucket.totalYtd
        case (.last24Hours, .fire): return bucket.fire24h
        case (.last7Days, .fire): return bucket.fire7d
        case (.last30Days, .fire): return bucket.fire30d
        case (.yearToDate, .fire): return bucket.fireYtd
        case (.last24Hours, .ems): return bucket.ems24h
        case (.last7Days, .ems): return bucket.ems7d
        case (.last30Days, .ems): return bucket.ems30d
        case (.yearToDate, .ems): return bucket.emsYtd
        case (.last24Hours, .other): return bucket.other24h
        case (.last7Days, .other): return bucket.other7d
        case (.last30Days, .other): return bucket.other30d
        case (.yearToDate, .other): return bucket.otherYtd
        }
    }

    nonisolated static func countLabel(_ count: Int) -> String {
        count == 1 ? "1 call" : "\(count) calls"
    }
}

enum MTFDCallTotalsScope: String, AppEnum {
    case station
    case department

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Call Totals Scope"
    static var caseDisplayRepresentations: [MTFDCallTotalsScope: DisplayRepresentation] = [
        .station: "Station",
        .department: "Department"
    ]

    var spokenLabel: String {
        switch self {
        case .station: return "station"
        case .department: return "department"
        }
    }
}

enum MTFDStationSelection: String, AppEnum {
    case myStation
    case station1
    case station2
    case station3
    case station4
    case station5

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Station"
    static var caseDisplayRepresentations: [MTFDStationSelection: DisplayRepresentation] = [
        .myStation: "My Station",
        .station1: "Station 1",
        .station2: "Station 2",
        .station3: "Station 3",
        .station4: "Station 4",
        .station5: "Station 5"
    ]

    var spokenLabel: String {
        switch self {
        case .myStation: return "your station"
        case .station1: return "Station 1"
        case .station2: return "Station 2"
        case .station3: return "Station 3"
        case .station4: return "Station 4"
        case .station5: return "Station 5"
        }
    }
}

enum MTFDCallTotalsWindow: String, AppEnum {
    case last24Hours
    case last7Days
    case last30Days
    case yearToDate

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Call Totals Window"
    static var caseDisplayRepresentations: [MTFDCallTotalsWindow: DisplayRepresentation] = [
        .last24Hours: "Last 24 Hours",
        .last7Days: "Last 7 Days",
        .last30Days: "Last 30 Days",
        .yearToDate: "Year To Date"
    ]

    var spokenLabel: String {
        switch self {
        case .last24Hours: return "in the last 24 hours"
        case .last7Days: return "in the last 7 days"
        case .last30Days: return "in the last 30 days"
        case .yearToDate: return "year to date"
        }
    }
}

enum MTFDCallCategory: String, AppEnum {
    case total
    case fire
    case ems
    case other

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Call Category"
    static var caseDisplayRepresentations: [MTFDCallCategory: DisplayRepresentation] = [
        .total: "Total Calls",
        .fire: "Fire Calls",
        .ems: "EMS Calls",
        .other: "Other Calls"
    ]

    var spokenLabel: String {
        switch self {
        case .total: return "total"
        case .fire: return "fire"
        case .ems: return "EMS"
        case .other: return "other"
        }
    }
}

private enum MTFDCallTotalsDialog {
    static func make(
        scope: MTFDCallTotalsScope,
        station: MTFDStationSelection,
        window: MTFDCallTotalsWindow,
        category: MTFDCallCategory
    ) async -> String {
        let response: APIClient.DispatchStatsResponse

        do {
            response = try await withMTFDIntentTimeout {
                try await APIClient.shared.fetchDispatchStats()
            }
        } catch MTFDIntentTimeoutError.timedOut {
            return "I couldn't reach MTFD quickly enough to get the call totals. Please try again."
        } catch APIClient.APIError.missingAuthToken, APIClient.APIError.sessionExpired {
            return "Please open MTFD and sign in before asking for call totals."
        } catch {
            return "I couldn't get the MTFD call totals right now. Please try again."
        }

        guard let bucket = MTFDIntentSupport.callBucket(from: response, scope: scope, station: station) else {
            return "I couldn't find call totals for that selection."
        }

        guard let count = MTFDIntentSupport.callValue(from: bucket, window: window, category: category) else {
            return "I couldn't find a \(category.spokenLabel) call total for \(window.spokenLabel)."
        }

        let subject = scope == .department ? "The department" : station.spokenLabel

        if category == .total {
            let fire = MTFDIntentSupport.callValue(from: bucket, window: window, category: .fire)
            let ems = MTFDIntentSupport.callValue(from: bucket, window: window, category: .ems)

            if let fire, let ems {
                return "\(subject) has had \(MTFDIntentSupport.countLabel(count)) \(window.spokenLabel): \(fire) fire and \(ems) EMS."
            }
        }

        return "\(subject) has had \(MTFDIntentSupport.countLabel(count)) for \(category.spokenLabel) \(window.spokenLabel)."
    }
}

struct DepartmentCallsTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Department Calls Today"
    static var description = IntentDescription("Checks today's department call total.")
    static var openAppWhenRun = false

    func perform() async -> some IntentResult & ProvidesDialog {
        let dialog = await MTFDCallTotalsDialog.make(
            scope: .department,
            station: .myStation,
            window: .last24Hours,
            category: .total
        )
        return .result(dialog: "\(dialog)")
    }
}

struct DepartmentCallsThisYearIntent: AppIntent {
    static var title: LocalizedStringResource = "Department Calls This Year"
    static var description = IntentDescription("Checks year-to-date department call totals.")
    static var openAppWhenRun = false

    func perform() async -> some IntentResult & ProvidesDialog {
        let dialog = await MTFDCallTotalsDialog.make(
            scope: .department,
            station: .myStation,
            window: .yearToDate,
            category: .total
        )
        return .result(dialog: "\(dialog)")
    }
}

struct StationCallsThisYearIntent: AppIntent {
    static var title: LocalizedStringResource = "Station Calls This Year"
    static var description = IntentDescription("Checks year-to-date call totals for your station.")
    static var openAppWhenRun = false

    func perform() async -> some IntentResult & ProvidesDialog {
        let dialog = await MTFDCallTotalsDialog.make(
            scope: .station,
            station: .myStation,
            window: .yearToDate,
            category: .total
        )
        return .result(dialog: "\(dialog)")
    }
}

struct EMSCallsThisYearIntent: AppIntent {
    static var title: LocalizedStringResource = "EMS Calls This Year"
    static var description = IntentDescription("Checks year-to-date EMS call totals.")
    static var openAppWhenRun = false

    func perform() async -> some IntentResult & ProvidesDialog {
        let dialog = await MTFDCallTotalsDialog.make(
            scope: .department,
            station: .myStation,
            window: .yearToDate,
            category: .ems
        )
        return .result(dialog: "\(dialog)")
    }
}

struct FireCallsThisYearIntent: AppIntent {
    static var title: LocalizedStringResource = "Fire Calls This Year"
    static var description = IntentDescription("Checks year-to-date fire call totals.")
    static var openAppWhenRun = false

    func perform() async -> some IntentResult & ProvidesDialog {
        let dialog = await MTFDCallTotalsDialog.make(
            scope: .department,
            station: .myStation,
            window: .yearToDate,
            category: .fire
        )
        return .result(dialog: "\(dialog)")
    }
}

struct OpenActiveDispatchIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Active Dispatch"
    static var description = IntentDescription("Opens the current active dispatch in MTFD Member App.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let dispatch = await MTFDIntentSupport.activeDispatch() else {
            NavigationRouter.shared.selectedTab = .home
            return .result(dialog: "There are no active dispatches right now.")
        }

        MTFDIntentSupport.openDispatch(dispatch)
        return .result(dialog: "Opening \(dispatch.callType).")
    }
}

struct NavigateToActiveDispatchIntent: AppIntent {
    static var title: LocalizedStringResource = "Navigate to Active Dispatch"
    static var description = IntentDescription("Starts navigation to the current active dispatch.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let dispatch = await MTFDIntentSupport.activeDispatch() else {
            NavigationRouter.shared.selectedTab = .home
            return .result(dialog: "There are no active dispatches right now.")
        }

        MTFDIntentSupport.openDispatch(dispatch)
        MTFDIntentSupport.openMaps(for: dispatch)
        return .result(dialog: "Starting navigation to \(dispatch.callType).")
    }
}

struct CheckNextShiftIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Next Shift"
    static var description = IntentDescription("Checks your next scheduled MTFD shift.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let response = try await APIClient.shared.fetchMobileUpcomingSchedule()

        guard response.isScheduleTrackedUser else {
            return .result(dialog: "Your role is not currently tracked on the department schedule.")
        }

        guard let shift = response.nextShift else {
            return .result(dialog: "I don't see an upcoming shift for you.")
        }

        let station = shift.station.map { " at \($0)" } ?? ""
        let assignment = shift.assignment.map { " as \($0)" } ?? ""
        return .result(dialog: "Your next shift is \(shift.title)\(station), \(shift.timeRange)\(assignment).")
    }
}

struct ShowDashboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Show MTFD Dashboard"
    static var description = IntentDescription("Opens the MTFD dashboard.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        MTFDIntentSupport.selectTab(.home)
        return .result(dialog: "Opening the MTFD dashboard.")
    }
}

struct OpenMessageCenterIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Message Center"
    static var description = IntentDescription("Opens dispatches, department messages, and announcements.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        MTFDIntentSupport.selectTab(.more)
        return .result(dialog: "Opening the message center.")
    }
}

struct OpenTrainingIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Training"
    static var description = IntentDescription("Opens assigned training.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        MTFDIntentSupport.selectTab(.training)
        return .result(dialog: "Opening training.")
    }
}

struct OpenDocumentsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Documents"
    static var description = IntentDescription("Opens department documents.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        MTFDIntentSupport.selectTab(.documents)
        return .result(dialog: "Opening documents.")
    }
}

struct OpenScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Schedule"
    static var description = IntentDescription("Opens the MTFD schedule.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        MTFDIntentSupport.selectTab(.schedule)
        return .result(dialog: "Opening the schedule.")
    }
}

struct ShowApparatusWorkOrdersIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Apparatus Work Orders"
    static var description = IntentDescription("Opens apparatus work orders on the dashboard.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        MTFDIntentSupport.selectTab(.home)
        return .result(dialog: "Opening apparatus work orders on the dashboard.")
    }
}

struct MTFDAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DepartmentCallsTodayIntent(),
            phrases: [
                "How many department calls at \(.applicationName) today",
                "How many calls at \(.applicationName) today"
            ],
            shortTitle: "Dept Calls Today",
            systemImageName: "chart.bar.xaxis"
        )

        AppShortcut(
            intent: DepartmentCallsThisYearIntent(),
            phrases: [
                "How many department calls at \(.applicationName) this year",
                "How many calls at \(.applicationName) this year"
            ],
            shortTitle: "Dept Calls YTD",
            systemImageName: "chart.bar.xaxis"
        )

        AppShortcut(
            intent: StationCallsThisYearIntent(),
            phrases: [
                "How many calls for my station at \(.applicationName) this year"
            ],
            shortTitle: "Station Calls YTD",
            systemImageName: "building.2.fill"
        )

        AppShortcut(
            intent: EMSCallsThisYearIntent(),
            phrases: [
                "How many EMS calls at \(.applicationName) this year"
            ],
            shortTitle: "EMS Calls YTD",
            systemImageName: "cross.case.fill"
        )

        AppShortcut(
            intent: FireCallsThisYearIntent(),
            phrases: [
                "How many fire calls at \(.applicationName) this year"
            ],
            shortTitle: "Fire Calls YTD",
            systemImageName: "flame.fill"
        )

        AppShortcut(
            intent: OpenActiveDispatchIntent(),
            phrases: [
                "Open the active dispatch in \(.applicationName)",
                "Show the current call in \(.applicationName)"
            ],
            shortTitle: "Active Dispatch",
            systemImageName: "bell.badge.fill"
        )

        AppShortcut(
            intent: NavigateToActiveDispatchIntent(),
            phrases: [
                "Navigate to the \(.applicationName) call",
                "Navigate to the current \(.applicationName) call",
                "Take me to the \(.applicationName) call",
                "Get me to the \(.applicationName) call",
                "Directions to the \(.applicationName) call",
                "Navigate to the active dispatch at \(.applicationName)"
            ],
            shortTitle: "Navigate to Call",
            systemImageName: "map.fill"
        )

        AppShortcut(
            intent: CheckNextShiftIntent(),
            phrases: [
                "When is my next shift in \(.applicationName)",
                "Check my next MTFD shift in \(.applicationName)"
            ],
            shortTitle: "Next Shift",
            systemImageName: "calendar.badge.clock"
        )

        AppShortcut(
            intent: ShowDashboardIntent(),
            phrases: [
                "Show my \(.applicationName) dashboard",
                "Open \(.applicationName)"
            ],
            shortTitle: "Dashboard",
            systemImageName: "rectangle.grid.2x2.fill"
        )

        AppShortcut(
            intent: ShowApparatusWorkOrdersIntent(),
            phrases: [
                "Show apparatus work orders in \(.applicationName)",
                "Show truck issues in \(.applicationName)"
            ],
            shortTitle: "Work Orders",
            systemImageName: "wrench.and.screwdriver.fill"
        )

    }
}
