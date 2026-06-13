import SwiftUI
import UIKit

struct ChiefDashboardView: View {

    let activeDispatches: [APIClient.ActiveDispatch]
    let workOrders: [DashboardApparatusWorkOrder]
    let departmentStats: APIClient.DispatchBucket?
    let stationStats: APIClient.DispatchBucket?
    let chiefStationStats: APIClient.ChiefStationStats?
    let recentCalls: [RecentDepartmentCall]
    let isLoading: Bool
    let onRefresh: () async -> Void

    @StateObject private var scheduleViewModel = ScheduleViewModel()

    private var outlookDays: [ScheduleOutlookDay] {
        scheduleViewModel.outlookDays
    }
    let onOpenWorkOrders: () -> Void
    let onOpenMessages: () -> Void
    let onOpenDispatch: (DispatchNotificationPayload) -> Void
    let onOpenPastDispatches: () -> Void

    

    @State private var selectedScheduleDayId: String?

    private var selectedScheduleDay: ScheduleOutlookDay? {
        if let selectedScheduleDayId,
           let day = outlookDays.first(where: { $0.id == selectedScheduleDayId }) {
            return day
        }

        return outlookDays.first
    }

    private var scheduleEntriesForSelectedDay: [APIClient.MobileScheduleEntry] {
        selectedScheduleDay?.entries ?? []
    }

    @AppStorage("chiefDashboardTotalsWindow") private var selectedWindowRawValue = DashboardTotalsWindow.ytd.rawValue
    @AppStorage("chiefDashboardTotalsScope") private var selectedTotalsScopeRawValue = ChiefTotalsScope.all.rawValue

    private var selectedTotalsWindow: DashboardTotalsWindow {
        DashboardTotalsWindow(rawValue: selectedWindowRawValue) ?? .ytd
    }

    private var selectedTotalsScope: ChiefTotalsScope {
        ChiefTotalsScope(rawValue: selectedTotalsScopeRawValue) ?? .all
    }

    private var selectedTotalsBucket: APIClient.DispatchBucket? {
        switch selectedTotalsScope {
        case .all:
            return chiefStationStats?.all ?? departmentStats
        case .station1:
            return chiefStationStats?.station1
        case .station2:
            return chiefStationStats?.station2
        case .station3:
            return chiefStationStats?.station3
        case .station4:
            return chiefStationStats?.station4
        case .station5:
            return chiefStationStats?.station5
        }
    }

    private var primaryActiveDispatch: APIClient.ActiveDispatch? {
        activeDispatches.first
    }

    private var secondaryActiveDispatches: [APIClient.ActiveDispatch] {
        Array(activeDispatches.dropFirst())
    }

    var body: some View {
        NonBouncingVerticalScrollView(
            showsIndicators: false,
            onRefresh: {
                await onRefresh()
                await scheduleViewModel.loadOutlookDays(count: 4)
            }
        ) {
            VStack(alignment: .leading, spacing: 22) {
                activeDispatchSection

                callTotalsSection

                chiefBriefSection

                ForEach(supportedDashboardCards, id: \.rawValue) { card in
                    dashboardSection(for: card)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            if scheduleViewModel.outlookDays.isEmpty {
                await scheduleViewModel.loadOutlookDays(count: 4)
            }
        }
    }

    
    private var supportedDashboardCards: [DashboardCardID] {
        DashboardCardID.allCases.filter(isSupportedDashboardCard)
    }

private func isSupportedDashboardCard(_ card: DashboardCardID) -> Bool {
        switch card {
        case .messages, .scheduleEvents, .apparatusWorkOrders, .recentCalls:
            return true
        case .commandOverview, .assignedTraining, .documents, .departmentUpdates, .stationUpdates, .needsAttention:
            return false
        }
    }

    @ViewBuilder
    private func dashboardSection(for card: DashboardCardID) -> some View {
        switch card {
        case .messages:
            commandMessagesSection
        case .scheduleEvents:
            scheduleOutlookSection
        case .apparatusWorkOrders:
            apparatusWorkOrdersSection
        case .recentCalls:
            recentDispatchesSection
        case .commandOverview, .assignedTraining, .documents, .departmentUpdates, .stationUpdates, .needsAttention:
            EmptyView()
        }
    }

    @ViewBuilder
    private var activeDispatchSection: some View {
        if let primaryActiveDispatch {
            sectionTitle("Current Dispatch", systemImage: "firetruck.fill")

            DashboardDispatchPreviewCard(
                dispatch: makeDispatchPayload(from: primaryActiveDispatch),
                isHighlighted: false
            ) {
                onOpenDispatch(makeDispatchPayload(from: primaryActiveDispatch))
            }

            if !secondaryActiveDispatches.isEmpty {
                sectionTitle("Additional Active Dispatches", systemImage: "firetruck.fill")

                ActiveDispatchStackView(
                    dispatches: secondaryActiveDispatches
                ) { activeDispatch in
                    onOpenDispatch(makeDispatchPayload(from: activeDispatch))
                }
            }
        }
    }


    private var chiefBriefSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Chief Brief", systemImage: "shield.lefthalf.filled")

            VStack(alignment: .leading, spacing: 10) {
                Text(chiefBriefHeadline)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(chiefBriefSummary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    chiefBriefDetailRow(label: "Today", value: todayStaffingCountText)
                    chiefBriefDetailRow(label: "Recent Calls", value: recentCalls.isEmpty ? "None listed" : "\(recentCalls.count)")
                    chiefBriefDetailRow(label: "Notable", value: notableRecentCallTypes.isEmpty ? "None listed" : notableRecentCallTypes.prefix(2).joined(separator: ", "))
                    chiefBriefDetailRow(label: "Work Orders", value: workOrders.isEmpty ? "None open" : "\(workOrders.count) open")
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
    }

    private func chiefBriefDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(AppTheme.gold)
                .tracking(0.5)
                .frame(width: 92, alignment: .leading)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
    }

    private var todayStaffingCountText: String {
        guard let today = outlookDays.first else {
            return "Unavailable"
        }

        let count = today.entries
            .flatMap(\.staffingDetails)
            .filter { !$0.isVacant }
            .compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count

        return count == 1 ? "1 working" : "\(count) working"
    }

    private var chiefBriefHeadline: String {
        if !activeDispatches.isEmpty {
            return "Active Operations Underway"
        }

        if !notableRecentCallTypes.isEmpty {
            return "Notable Activity Logged Across the Department"
        }

        if !workOrders.isEmpty {
            return "Apparatus Readiness Items Remain Open"
        }

        return "Steady Operations Continue Across the Department"
    }

    private var chiefBriefSummary: String {
        chiefBriefParts.joined(separator: " ")
    }

    private var chiefBriefParts: [String] {
        var parts: [String] = []

        parts.append(todayStaffingSummary)

        if !activeDispatches.isEmpty {
            let count = activeDispatches.count
            parts.append(count == 1
                ? "One active dispatch is currently visible for command review."
                : "\(count) active dispatches are currently visible for command review."
            )
        } else if !recentCalls.isEmpty {
            let count = recentCalls.count
            parts.append(count == 1
                ? "One recent department call is listed in the current feed."
                : "\(count) recent department calls are listed in the current feed."
            )
        }

        if !notableRecentCallTypes.isEmpty {
            parts.append("Notable recent call types include \(notableRecentCallTypes.joined(separator: ", ")).")
        }

        if !workOrders.isEmpty {
            let count = workOrders.count
            let apparatus = workOrders
                .map(\.apparatusName)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .prefix(3)
                .joined(separator: ", ")

            if apparatus.isEmpty {
                parts.append(count == 1
                    ? "One apparatus work order remains open."
                    : "\(count) apparatus work orders remain open."
                )
            } else {
                parts.append(count == 1
                    ? "One apparatus work order remains open for \(apparatus)."
                    : "\(count) apparatus work orders remain open, including \(apparatus)."
                )
            }
        }
        return parts
    }

    private var todayStaffingSummary: String {
        guard let today = outlookDays.first else {
            return "Today’s staffing outlook is available for review."
        }

        let staffedDetails = today.entries
            .flatMap(\.staffingDetails)
            .filter { !$0.isVacant }

        let names = staffedDetails
            .compactMap { detail -> String? in
                guard let name = detail.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty else {
                    return nil
                }

                if let qualifier = detail.qualifier?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !qualifier.isEmpty {
                    return "\(name) (\(qualifier))"
                }

                return name
            }

        if names.isEmpty {
            return "Today’s schedule is available for command review."
        }

        let preview = names.prefix(4).joined(separator: ", ")
        let remaining = max(0, names.count - 4)

        if remaining > 0 {
            return "Today’s staffing shows \(names.count) scheduled members, including \(preview), and \(remaining) more."
        }

        return "Today’s staffing shows \(names.count) scheduled members: \(preview)."
    }

    private var notableRecentCallTypes: [String] {
        let seriousKeywords = [
            "working fire",
            "structure fire",
            "building fire",
            "cardiac arrest",
            "choking",
            "mva",
            "motor vehicle",
            "extrication",
            "hazmat",
            "carbon monoxide",
            "co alarm",
            "gas leak",
            "overdose",
            "unconscious",
        ]

        var seen = Set<String>()

        return recentCalls.compactMap { call in
            let title = call.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }

            let normalized = title.lowercased()
            guard seriousKeywords.contains(where: { normalized.contains($0) }) else {
                return nil
            }

            guard !seen.contains(normalized) else {
                return nil
            }

            seen.insert(normalized)
            return title
        }
    }

    private var callTotalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Call Totals", systemImage: "chart.bar.fill")

                Spacer()

                HStack(spacing: 6) {
                    ForEach(DashboardTotalsWindow.allCases, id: \.rawValue) { window in
                        Button {
                            selectedWindowRawValue = window.rawValue
                        } label: {
                            Text(window.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(selectedTotalsWindow == window ? AppTheme.navy : .white.opacity(0.72))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selectedTotalsWindow == window ? AppTheme.gold : Color.white.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ChiefTotalsScope.allCases, id: \.rawValue) { scope in
                        Button {
                            selectedTotalsScopeRawValue = scope.rawValue
                        } label: {
                            Text(scope.title)
                                .font(.caption.bold())
                                .foregroundStyle(selectedTotalsScope == scope ? AppTheme.navy : .white.opacity(0.72))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selectedTotalsScope == scope ? AppTheme.gold : Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if isLoading && departmentStats == nil {
                loadingCard("Loading call totals...")
            } else {
                HStack(spacing: 0) {
                    chiefInlineTotal(value: callTotal(.total), label: selectedTotalsScope.title)

                    Divider()
                        .frame(height: 48)
                        .background(Color.white.opacity(0.18))

                    chiefInlineTotal(value: callTotal(.fire), label: "🔥 Fire")

                    Divider()
                        .frame(height: 48)
                        .background(Color.white.opacity(0.18))

                    chiefInlineTotal(value: callTotal(.ems), label: "🚑 EMS")

                    Divider()
                        .frame(height: 48)
                        .background(Color.white.opacity(0.18))

                    chiefInlineTotal(value: callTotal(.other), label: "Other")
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                .contentShape(Rectangle())
            }
        }
    }

private func selectNextTotalsWindow() {
        let windows = DashboardTotalsWindow.allCases
        guard let currentIndex = windows.firstIndex(of: selectedTotalsWindow) else { return }
        selectedWindowRawValue = windows[min(currentIndex + 1, windows.count - 1)].rawValue
    }

    private func selectPreviousTotalsWindow() {
        let windows = DashboardTotalsWindow.allCases
        guard let currentIndex = windows.firstIndex(of: selectedTotalsWindow) else { return }
        selectedWindowRawValue = windows[max(currentIndex - 1, 0)].rawValue
    }

    private func chiefInlineTotal(value: Int, label: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func callTotal(_ kind: ChiefCallTotalKind) -> Int {
        let bucket = selectedTotalsBucket

        switch (selectedTotalsWindow, kind) {
        case (.last24h, .total): return bucket?.total24h ?? 0
        case (.last24h, .fire): return bucket?.fire24h ?? 0
        case (.last24h, .ems): return bucket?.ems24h ?? 0
        case (.last24h, .other): return bucket?.other24h ?? 0

        case (.last7d, .total): return bucket?.total7d ?? 0
        case (.last7d, .fire): return bucket?.fire7d ?? 0
        case (.last7d, .ems): return bucket?.ems7d ?? 0
        case (.last7d, .other): return bucket?.other7d ?? 0

        case (.last30d, .total): return bucket?.total30d ?? 0
        case (.last30d, .fire): return bucket?.fire30d ?? 0
        case (.last30d, .ems): return bucket?.ems30d ?? 0
        case (.last30d, .other): return bucket?.other30d ?? 0

        case (.ytd, .total): return bucket?.totalYtd ?? 0
        case (.ytd, .fire): return bucket?.fireYtd ?? 0
        case (.ytd, .ems): return bucket?.emsYtd ?? 0
        case (.ytd, .other): return bucket?.otherYtd ?? 0
        }
    }


    private enum ChiefTotalsScope: String, CaseIterable {
        case all = "ALL"
        case station1 = "1"
        case station2 = "2"
        case station3 = "3"
        case station4 = "4"
        case station5 = "5"

        var title: String {
            switch self {
            case .all: return "ALL"
            case .station1: return "Sta 1"
            case .station2: return "Sta 2"
            case .station3: return "Sta 3"
            case .station4: return "Sta 4"
            case .station5: return "Sta 5"
            }
        }
    }

    private enum ChiefCallTotalKind {
        case total
        case fire
        case ems
        case other
    }



    private var scheduleOutlookSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Schedule Outlook", systemImage: "calendar.badge.clock")

                HStack(spacing: 6) {
                    ForEach(outlookDays) { day in
                        let isSelected = selectedScheduleDay?.id == day.id

                        Button {
                            selectedScheduleDayId = day.id
                        } label: {
                            Text(day.label)
                                .font(.caption.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(isSelected ? AppTheme.navy : .white.opacity(0.72))
                                .frame(minWidth: isSelected ? 66 : 46, minHeight: 34)
                                .padding(.horizontal, isSelected ? 10 : 8)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? AppTheme.gold : Color.white.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            let entries = scheduleEntriesForSelectedDay
            let displayEntries = entries.filter { entry in
                entry.staffingDetails.contains { !$0.isVacant }
            }
            let totalVacancies = entries.reduce(0) { total, entry in
                total + entry.staffingDetails.filter { $0.isVacant }.count
            }

            VStack(alignment: .leading, spacing: 10) {
                if scheduleViewModel.isLoading && outlookDays.isEmpty {
                    loadingRow("Loading schedule outlook...")
                } else if outlookDays.isEmpty {
                    emptyRow("Schedule outlook unavailable.")
                } else if displayEntries.isEmpty {
                    Text("📅 No staffing returned for \(selectedScheduleDay?.label ?? "this day").")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Full details remain available in Schedule.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(displayEntries.prefix(3)) { entry in
                            scheduleEntryRow(entry)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Showing first staffing items. View full Schedule for more.")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.52))
                }

                if totalVacancies > 0 {
                    Text("⚠️ \(totalVacancies) vacanc\(totalVacancies == 1 ? "y" : "ies"). View full Schedule for open positions.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
    }

    private func scheduleEntryRow(_ entry: APIClient.MobileScheduleEntry) -> some View {
        let filledNames = entry.staffingDetails
            .filter { !$0.isVacant }
            .compactMap { detail -> String? in
                let name = detail.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !name.isEmpty else { return nil }

                let qualifier = detail.qualifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return qualifier.isEmpty ? name : "\(name) (\(qualifier))"
            }

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let station = entry.station, !station.isEmpty {
                    Text(station)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.gold)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(entry.timeRange)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1)
            }

            Text(filledNames.joined(separator: " • "))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(3)
        }
        .padding(.vertical, 2)
    }

private func selectNextScheduleDay() {
        guard !outlookDays.isEmpty else { return }
        let currentId = selectedScheduleDay?.id ?? outlookDays.first?.id
        let currentIndex = outlookDays.firstIndex { $0.id == currentId } ?? 0
        selectedScheduleDayId = outlookDays[min(currentIndex + 1, outlookDays.count - 1)].id
    }

    private func selectPreviousScheduleDay() {
        guard !outlookDays.isEmpty else { return }
        let currentId = selectedScheduleDay?.id ?? outlookDays.first?.id
        let currentIndex = outlookDays.firstIndex { $0.id == currentId } ?? 0
        selectedScheduleDayId = outlookDays[max(currentIndex - 1, 0)].id
    }


    private var commandMessagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Command Messages", systemImage: "envelope.fill")

            DashboardMessageCenterCard {
                onOpenMessages()
            }
        }
    }


    private var recentDispatchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Past Dispatches", systemImage: "clock.arrow.circlepath")

            if isLoading && recentCalls.isEmpty {
                loadingCard("Loading past dispatches...")
            } else if recentCalls.isEmpty {
                emptyCard("No recent dispatches available.")
            } else {
                DashboardRecentCallsCard(
                    calls: recentCalls
                ) {
                    onOpenPastDispatches()
                }
            }
        }
    }

    private var apparatusWorkOrdersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Apparatus Work Orders", systemImage: "wrench.and.screwdriver.fill")

            if workOrders.isEmpty {
                Text("No open apparatus work orders.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    onOpenWorkOrders()
                }
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                DashboardApparatusWorkOrdersCard(
                    workOrders: workOrders
                ) {
                    onOpenWorkOrders()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 0)
            }
        }
    }


    private func loadingCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.white)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func emptyCard(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func loadingRow(_ message: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.white)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }

    private func emptyRow(_ message: String) -> some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.78))
    }

    private func sectionTitle(_ text: String, systemImage: String? = nil) -> some View {
        HStack(spacing: 8) {
            if let systemImage {
                DashboardColorIcon(systemImage: systemImage, size: 22, frameSize: 30)
            }

            Text(text)
                .font(.headline)
                .foregroundStyle(.white)
        }
    }

    private func makeDispatchPayload(from activeDispatch: APIClient.ActiveDispatch) -> DispatchNotificationPayload {
        DispatchNotificationPayload(
            type: activeDispatch.priority == "CRITICAL" ? .dispatchCritical : .dispatch,
            id: activeDispatch.id,
            title: activeDispatch.callType,
            body: activeDispatch.address ?? activeDispatch.message ?? "Dispatch details available",
            callType: activeDispatch.callType,
            address: activeDispatch.address,
            units: DispatchUnitFilter.visibleRespondingUnits(from: activeDispatch.units),
            isWorkingFire: activeDispatch.isWorkingFire ?? false,
            activeCallCount: activeDispatches.count,
            stationId: nil,
            messageId: nil,
            trainingId: nil,
            documentId: nil
        )
    }
}
