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
    let dashboardCards: [DashboardCardID]
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

    private var topContentPadding: CGFloat {
        activeDispatches.isEmpty ? 64 : 22
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
            .padding(.top, topContentPadding)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .id("chief-dashboard-scroll")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            if scheduleViewModel.outlookDays.isEmpty {
                await scheduleViewModel.loadOutlookDays(count: 4)
            }
        }
    }

    
    private var supportedDashboardCards: [DashboardCardID] {
        dashboardCards.filter(isSupportedDashboardCard)
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

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 10) {
                    Text(chiefBriefDateLabel)
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.navy)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.gold)
                        .clipShape(Capsule())

                    Text("MTFD Command Desk")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .textCase(.uppercase)

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(chiefBriefHeadline)
                        .font(.system(size: 23, weight: .black, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(chiefBriefSubheadline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.gold)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()
                    .background(Color.white.opacity(0.18))

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(chiefBriefLeadParagraph)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)

                        Text(chiefBriefOperationsParagraph)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.76))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)

                        Text(chiefBriefReadinessParagraph)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.76))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)

                        VStack(alignment: .leading, spacing: 9) {
                            chiefBriefArticleNote(
                                title: "Incident Watch",
                                detail: chiefBriefIncidentNote,
                                tint: activeDispatches.isEmpty ? AppTheme.gold : .orange
                            )

                            chiefBriefArticleNote(
                                title: "Apparatus Readiness",
                                detail: chiefBriefWorkOrderNote,
                                tint: workOrders.isEmpty ? .green : .orange
                            )

                            chiefBriefArticleNote(
                                title: "Coverage Picture",
                                detail: chiefBriefStaffingNote,
                                tint: todayVacancyCount > 0 ? .orange : AppTheme.gold
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 250)

                HStack(spacing: 8) {
                    chiefBriefStatusPill(
                        title: activeDispatches.isEmpty ? "Calls" : "Active",
                        value: activeDispatches.isEmpty ? "\(recentCalls.count)" : "\(activeDispatches.count)",
                        tint: activeDispatches.isEmpty ? AppTheme.gold : .orange
                    )

                    chiefBriefStatusPill(
                        title: "Work Orders",
                        value: "\(workOrders.count)",
                        tint: workOrders.isEmpty ? .green : .orange
                    )

                    chiefBriefStatusPill(
                        title: "Staffing",
                        value: todayVacancyCount > 0 ? "\(todayScheduledMemberCount) / \(todayVacancyCount) vac" : "\(todayScheduledMemberCount)",
                        tint: todayVacancyCount > 0 ? .orange : AppTheme.gold
                    )
                }
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

    private func chiefBriefArticleNote(
        title: String,
        detail: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(tint)
                .frame(width: 3)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.88))
                    .textCase(.uppercase)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private func chiefBriefStatusPill(
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.13))
        .clipShape(Capsule())
    }

    private var todayScheduleEntries: [APIClient.MobileScheduleEntry] {
        outlookDays.first?.entries ?? []
    }

    private var todayScheduledMemberCount: Int {
        todayScheduleEntries
            .flatMap(\.staffingDetails)
            .filter { !$0.isVacant }
            .compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
    }

    private var todayVacancyCount: Int {
        todayScheduleEntries.reduce(0) { total, entry in
            total + entry.staffingDetails.filter { $0.isVacant }.count
        }
    }

    private var todayAssignmentCount: Int {
        todayScheduleEntries.count
    }

    private var chiefBriefHeadline: String {
        if !activeDispatches.isEmpty {
            return dailyHeadline(from: [
                "Active Operations Require Command Awareness",
                "Live Incidents Lead Today’s Operational Picture",
                "Command Focus: Active Dispatch Activity"
            ])
        }

        if !notableRecentCallTypes.isEmpty {
            return dailyHeadline(from: [
                "Recent Call Activity Sets Today’s Tempo",
                "Department Activity Trending Beyond Routine",
                "Notable Calls Deserve Follow-Up"
            ])
        }

        if !workOrders.isEmpty {
            return dailyHeadline(from: [
                "Apparatus Readiness Needs Attention",
                "Open Work Orders Shape Today’s Readiness",
                "Fleet Status Is the Watch Item"
            ])
        }

        return dailyHeadline(from: [
            "Department Posture Looks Steady",
            "Today’s Operations Are in Good Shape",
            "Coverage and Readiness Are Holding"
        ])
    }

    private var chiefBriefDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: Date()).uppercased()
    }

    private var chiefBriefSubheadline: String {
        if !activeDispatches.isEmpty {
            return "\(activeDispatches.count) active dispatch\(activeDispatches.count == 1 ? "" : "es") on the board"
        }

        if !workOrders.isEmpty {
            return "\(workOrders.count) apparatus work order\(workOrders.count == 1 ? "" : "s") open"
        }

        if todayVacancyCount > 0 {
            return "\(todayVacancyCount) staffing vacanc\(todayVacancyCount == 1 ? "y" : "ies") showing for today"
        }

        return "Calls, readiness, and coverage in one command snapshot"
    }

    private var chiefBriefLeadParagraph: String {
        if let active = activeDispatches.first {
            let callType = trimmedOrFallback(active.callType, fallback: "Active dispatch")
            let location = trimmedOptional(active.address)
            let unitText = active.units.isEmpty
                ? "assigned units"
                : active.units.prefix(4).joined(separator: ", ")

            if let location {
                return "\(callType) is setting the tone for the current operational period, with \(unitText) committed at \(location). Command should keep the incident visible while monitoring any backfill, move-up, or apparatus availability impacts."
            }

            return "\(callType) is setting the tone for the current operational period, with \(unitText) committed. Command should keep the incident visible while monitoring any backfill, move-up, or apparatus availability impacts."
        }

        if let notable = notableRecentCallTypes.first {
            return "\(notable) stands out in the recent call picture, giving today’s brief a more incident-focused posture than a routine staffing snapshot. The dashboard is showing \(recentCalls.count) recent dispatch\(recentCalls.count == 1 ? "" : "es") available for review."
        }

        if recentCalls.isEmpty {
            return "The incident board is quiet in the current feed, which gives command room to stay ahead of readiness items before the next dispatch changes the tempo."
        }

        return "The current feed shows \(recentCalls.count) recent dispatch\(recentCalls.count == 1 ? "" : "es"), giving command a quick read on department activity without pulling attention away from readiness and coverage."
    }

    private var chiefBriefOperationsParagraph: String {
        let callSentence: String
        if activeDispatches.count > 1 {
            callSentence = "\(activeDispatches.count - 1) additional active dispatch\(activeDispatches.count - 1 == 1 ? "" : "es") should remain on the command radar."
        } else if recentCalls.count > 1 {
            callSentence = "Recent dispatches include \(chiefBriefRecentCallSummary), which gives context beyond the latest incident alone."
        } else {
            callSentence = chiefBriefCallsSentence
        }

        let workOrderSentence: String
        if workOrders.isEmpty {
            workOrderSentence = "Apparatus readiness is clean from the work-order feed, with no open items currently listed."
        } else {
            workOrderSentence = "\(workOrders.count) work order\(workOrders.count == 1 ? "" : "s") remain open, led by \(chiefBriefDetailedWorkOrderSummary)."
        }

        return "\(callSentence) \(workOrderSentence)"
    }

    private var chiefBriefReadinessParagraph: String {
        let staffing = chiefBriefStaffingSentence

        if todayVacancyCount > 0 {
            return "\(staffing) That does not need to crowd out the rest of the brief, but it should stay visible while command weighs call volume, apparatus status, and any expected coverage changes."
        }

        if !workOrders.isEmpty || !activeDispatches.isEmpty {
            return "\(staffing) With staffing summarized, the higher-value watch items are incident movement and whether the open apparatus items affect response posture."
        }

        return "\(staffing) With no active dispatch pressure and no open work-order load, today’s command posture reads steady while the schedule and recent call feed continue to refresh."
    }

    private var chiefBriefIncidentNote: String {
        if let active = activeDispatches.first {
            let callType = trimmedOrFallback(active.callType, fallback: "Active dispatch")
            let location = trimmedOptional(active.address)
            let unitText = active.units.isEmpty ? "units not listed" : active.units.prefix(5).joined(separator: ", ")

            if let location {
                return "\(callType) at \(location). Units: \(unitText)."
            }

            return "\(callType). Units: \(unitText)."
        }

        if recentCalls.isEmpty {
            return "No recent dispatches are highlighted in the current feed."
        }

        return "Recent feed: \(chiefBriefRecentCallSummary)."
    }

    private var chiefBriefWorkOrderNote: String {
        if workOrders.isEmpty {
            return "No apparatus work orders are currently open."
        }

        return chiefBriefDetailedWorkOrderSummary
    }

    private var chiefBriefStaffingNote: String {
        if todayScheduledMemberCount == 0 && todayAssignmentCount == 0 {
            return "Schedule outlook has not loaded yet."
        }

        if todayVacancyCount > 0 {
            return "\(todayScheduledMemberCount) scheduled, \(todayVacancyCount) vacant across \(todayAssignmentCount) assignment\(todayAssignmentCount == 1 ? "" : "s")."
        }

        return "\(todayScheduledMemberCount) scheduled across \(todayAssignmentCount) assignment\(todayAssignmentCount == 1 ? "" : "s"); no vacancies shown."
    }

    private var chiefBriefRecentCallSummary: String {
        let titles = recentCalls
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !titles.isEmpty else {
            return "no recent dispatch titles listed"
        }

        let preview = titles.prefix(2)
        let joined = preview.joined(separator: ", ")
        let remaining = titles.count - preview.count

        return remaining > 0 ? "\(joined), and \(remaining) more" : joined
    }

    private var chiefBriefDetailedWorkOrderSummary: String {
        let summaries = workOrders.prefix(2).map { order in
            let apparatus = order.apparatusName.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = shortenedChiefBriefText(
                order.title.trimmingCharacters(in: .whitespacesAndNewlines),
                limit: 48
            )

            if apparatus.isEmpty {
                return title.isEmpty ? "untitled work order" : title
            }

            if title.isEmpty {
                return apparatus
            }

            return "\(apparatus): \(title)"
        }

        guard !summaries.isEmpty else {
            return "no open work orders"
        }

        let remaining = workOrders.count - summaries.count
        let joined = summaries.joined(separator: "; ")

        return remaining > 0 ? "\(joined); +\(remaining) more" : joined
    }

    private func shortenedChiefBriefText(_ value: String, limit: Int) -> String {
        guard value.count > limit else {
            return value
        }

        let index = value.index(value.startIndex, offsetBy: limit)
        return "\(value[..<index])..."
    }

    private var chiefBriefCallsSentence: String {
        if let active = activeDispatches.first {
            let title = active.callType.trimmingCharacters(in: .whitespacesAndNewlines)
            let address = active.address?.trimmingCharacters(in: .whitespacesAndNewlines)

            if let address, !address.isEmpty {
                return "\(title.isEmpty ? "Active dispatch" : title) is active at \(address)."
            }

            return "\(title.isEmpty ? "Active dispatch" : title) is currently active."
        }

        if let notable = notableRecentCallTypes.first {
            return "Recent call activity includes \(notable), with \(recentCalls.count) dispatch\(recentCalls.count == 1 ? "" : "es") in the current feed."
        }

        if recentCalls.isEmpty {
            return "No recent dispatches are highlighted in the current feed."
        }

        return "\(recentCalls.count) recent dispatch\(recentCalls.count == 1 ? " is" : "es are") listed for review."
    }

    private var chiefBriefWorkOrdersSentence: String {
        if !workOrders.isEmpty {
            return workOrders.count == 1
                ? "One apparatus work order remains open for \(chiefBriefWorkOrderSubtitle)."
                : "\(workOrders.count) apparatus work orders remain open, led by \(chiefBriefWorkOrderSubtitle)."
        }

        return "No apparatus work orders are open."
    }

    private var chiefBriefStaffingSentence: String {
        if todayScheduledMemberCount == 0 && todayAssignmentCount == 0 {
            return "Staffing has not loaded yet."
        }

        if todayVacancyCount > 0 {
            return "Today’s staffing shows \(todayScheduledMemberCount) scheduled and \(todayVacancyCount) vacanc\(todayVacancyCount == 1 ? "y" : "ies")."
        }

        return "Today’s staffing shows \(todayScheduledMemberCount) scheduled across \(todayAssignmentCount) assignment\(todayAssignmentCount == 1 ? "" : "s")."
    }

    private func trimmedOptional(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func trimmedOrFallback(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private var todayStaffingShortText: String {
        if todayScheduledMemberCount == 0 && todayAssignmentCount == 0 {
            return "not loaded yet"
        }

        if todayVacancyCount > 0 {
            return "\(todayScheduledMemberCount) scheduled with \(todayVacancyCount) vacant"
        }

        return "\(todayScheduledMemberCount) scheduled"
    }

    private var chiefBriefWorkOrderSubtitle: String {
        guard !workOrders.isEmpty else {
            return "none open"
        }

        var seenApparatus = Set<String>()
        let apparatus = workOrders.compactMap { order -> String? in
            let name = order.apparatusName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seenApparatus.insert(name).inserted else {
                return nil
            }

            return name
        }

        guard let first = apparatus.first else {
            return workOrders.count == 1 ? "1 open item" : "\(workOrders.count) open items"
        }

        if apparatus.count == 1 {
            return first
        }

        return "\(first) +\(apparatus.count - 1)"
    }

    private func dailyHeadline(from options: [String]) -> String {
        guard !options.isEmpty else {
            return "Chief Brief"
        }

        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return options[day % options.count]
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
                    DashboardScrollableList(itemCount: displayEntries.count, maxHeight: 360) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(displayEntries) { entry in
                                scheduleEntryRow(entry)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
            sectionTitle("Apparatus Status", systemImage: "wrench.and.screwdriver.fill")

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
                    workOrders: workOrders,
                    title: "Apparatus Status",
                    subtitle: "Department-wide apparatus overview.",
                    emptyMessage: "No open apparatus issues."
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
