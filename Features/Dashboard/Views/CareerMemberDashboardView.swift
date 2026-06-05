import SwiftUI

struct CareerMemberDashboardView: View {

    let activeDispatches: [APIClient.ActiveDispatch]
    let departmentStats: APIClient.DispatchBucket?
    let stationStats: APIClient.DispatchBucket?
    let upcomingSchedule: APIClient.MobileUpcomingScheduleResponse?
    let workOrders: [DashboardApparatusWorkOrder]
    let recentCalls: [RecentDepartmentCall]
    let assignedTraining: [DashboardTrainingPreviewItem]
    let pendingDocuments: Int
    let isLoading: Bool

    let onOpenDispatch: (DispatchNotificationPayload) -> Void
    let onOpenMessages: () -> Void
    let onOpenWorkOrders: () -> Void
    let onOpenSchedule: () -> Void
    let onOpenTraining: () -> Void
    let onOpenDocuments: () -> Void
    let onOpenPastDispatches: () -> Void

    @AppStorage("careerDashboardTotalsWindow") private var selectedWindowRawValue = DashboardTotalsWindow.ytd.rawValue
    @State private var selectedTotalsScope: TotalsScope = .station

    private var selectedTotalsWindow: DashboardTotalsWindow {
        DashboardTotalsWindow(rawValue: selectedWindowRawValue) ?? .ytd
    }

    private var primaryActiveDispatch: APIClient.ActiveDispatch? {
        activeDispatches.first
    }

    private var secondaryActiveDispatches: [APIClient.ActiveDispatch] {
        Array(activeDispatches.dropFirst())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            activeDispatchSection
            callTotalsSection
            scheduleSection
            messagesSection
            workOrdersSection
            trainingSection
            pastDispatchesSection
            documentsSection
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 120)
    }

    @ViewBuilder
    private var activeDispatchSection: some View {
        if let primaryActiveDispatch {
            sectionTitle("Current Dispatch")

            DashboardDispatchPreviewCard(
                dispatch: makeDispatchPayload(from: primaryActiveDispatch),
                isHighlighted: false
            ) {
                onOpenDispatch(makeDispatchPayload(from: primaryActiveDispatch))
            }

            if !secondaryActiveDispatches.isEmpty {
                sectionTitle("Additional Active Dispatches")

                ActiveDispatchStackView(dispatches: secondaryActiveDispatches) { activeDispatch in
                    onOpenDispatch(makeDispatchPayload(from: activeDispatch))
                }
            }
        }
    }

    private var callTotalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Call Totals")
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

            if isLoading && departmentStats == nil && stationStats == nil {
                loadingCard("Loading call totals...")
            } else {
                HStack(spacing: 6) {
                    totalsScopeButton(.station, title: "Station")
                    totalsScopeButton(.department, title: "Dept")
                }

                totalsRow(
                    title: selectedTotalsScope == .station ? "Station" : "Department",
                    stats: selectedTotalsScope == .station ? stationStats : departmentStats
                )
            }
        }
    }


    private enum TotalsScope {
        case station
        case department
    }

    private func totalsScopeButton(_ scope: TotalsScope, title: String) -> some View {
        let isSelected = selectedTotalsScope == scope

        return Button {
            selectedTotalsScope = scope
        } label: {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(isSelected ? AppTheme.navy : .white.opacity(0.72))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.gold : Color.white.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }

    private func totalsRow(title: String, stats: APIClient.DispatchBucket?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.gold)

            HStack(spacing: 0) {
                inlineTotal(value: callTotal(stats, .total), label: "Total")
                Divider().frame(height: 44).background(Color.white.opacity(0.18))
                inlineTotal(value: callTotal(stats, .fire), label: "🔥 Fire")
                Divider().frame(height: 44).background(Color.white.opacity(0.18))
                inlineTotal(value: callTotal(stats, .ems), label: "🚑 EMS")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .gesture(totalsSwipeGesture)
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(upcomingSchedule?.isWorkingNow == true ? "Working Now" : "Next Shift")

            if isLoading && upcomingSchedule == nil {
                loadingCard("Loading schedule...")
            } else if let upcomingSchedule,
                      upcomingSchedule.isWorkingNow == true,
                      upcomingSchedule.nextShift == nil {
                DashboardSmallStatusCard(
                    title: "Working Now",
                    subtitle: "You are currently scheduled as working.",
                    systemImage: "calendar.badge.clock"
                ) {
                    onOpenSchedule()
                }
            } else if let upcomingSchedule,
                      let nextShift = upcomingSchedule.nextShift {
                DashboardUpcomingScheduleCard(
                    schedule: upcomingSchedule,
                    shift: nextShift
                ) {
                    onOpenSchedule()
                }
            } else {
                emptyCard(upcomingSchedule?.error ?? "Schedule status unavailable.")
            }
        }
    }

    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Messages")
            DashboardMessageCenterCard {
                onOpenMessages()
            }
        }
    }

    private var workOrdersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Apparatus Work Orders")

            if isLoading && workOrders.isEmpty {
                loadingCard("Loading apparatus work orders...")
            } else if workOrders.isEmpty {
                emptyCard("No open apparatus work orders.")
            } else {
                DashboardApparatusWorkOrdersCard(workOrders: workOrders) {
                    onOpenWorkOrders()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    onOpenWorkOrders()
                }
            }
        }
    }

    private var trainingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Assigned Training")

            if isLoading && assignedTraining.isEmpty {
                loadingCard("Loading training...")
            } else if assignedTraining.isEmpty {
                DashboardSmallStatusCard(
                    title: "Assigned Training",
                    subtitle: "No assigned training right now.",
                    systemImage: "graduationcap.fill"
                ) {
                    onOpenTraining()
                }
            } else {
                DashboardAssignedTrainingPreviewCard(items: assignedTraining) {
                    onOpenTraining()
                }
            }
        }
    }

    private var pastDispatchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Past Dispatches")

            if isLoading && recentCalls.isEmpty {
                loadingCard("Loading past dispatches...")
            } else if recentCalls.isEmpty {
                emptyCard("No recent dispatches available.")
            } else {
                DashboardRecentCallsCard(calls: recentCalls) {
                    onOpenPastDispatches()
                }
            }
        }
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Documents / SOPs")

            DashboardSmallStatusCard(
                title: "Documents / SOPs",
                subtitle: pendingDocuments > 0
                    ? "\(pendingDocuments) item\(pendingDocuments == 1 ? "" : "s") need acknowledgement."
                    : "No documents need acknowledgement.",
                systemImage: "doc.text.fill"
            ) {
                onOpenDocuments()
            }
        }
    }

    private func inlineTotal(value: Int, label: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 26, weight: .bold))
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

    private enum TotalKind {
        case total
        case fire
        case ems
    }

    private func callTotal(_ stats: APIClient.DispatchBucket?, _ kind: TotalKind) -> Int {
        switch (selectedTotalsWindow, kind) {
        case (.last24h, .total): return stats?.total24h ?? 0
        case (.last24h, .fire): return stats?.fire24h ?? 0
        case (.last24h, .ems): return stats?.ems24h ?? 0

        case (.last7d, .total): return stats?.total7d ?? 0
        case (.last7d, .fire): return stats?.fire7d ?? 0
        case (.last7d, .ems): return stats?.ems7d ?? 0

        case (.last30d, .total): return stats?.total30d ?? 0
        case (.last30d, .fire): return stats?.fire30d ?? 0
        case (.last30d, .ems): return stats?.ems30d ?? 0

        case (.ytd, .total): return stats?.totalYtd ?? 0
        case (.ytd, .fire): return stats?.fireYtd ?? 0
        case (.ytd, .ems): return stats?.emsYtd ?? 0
        }
    }

    private var totalsSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard abs(horizontal) > abs(vertical), abs(horizontal) > 40 else {
                    return
                }

                if horizontal < 0 {
                    selectNextTotalsWindow()
                } else {
                    selectPreviousTotalsWindow()
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

    private func loadingCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            ProgressView().tint(.white)

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

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.white)
    }

    private func makeDispatchPayload(from activeDispatch: APIClient.ActiveDispatch) -> DispatchNotificationPayload {
        DispatchNotificationPayload(
            type: activeDispatch.priority == "CRITICAL" ? .dispatchCritical : .dispatch,
            id: activeDispatch.id,
            title: activeDispatch.callType,
            body: activeDispatch.address ?? activeDispatch.message ?? "Dispatch details available",
            callType: activeDispatch.callType,
            address: activeDispatch.address,
            units: activeDispatch.units,
            isWorkingFire: activeDispatch.isWorkingFire ?? false,
            activeCallCount: activeDispatches.count,
            stationId: nil,
            messageId: nil,
            trainingId: nil,
            documentId: nil
        )
    }
}
