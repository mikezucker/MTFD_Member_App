import SwiftUI

struct ChiefDashboardView: View {

    let activeDispatches: [APIClient.ActiveDispatch]
    let workOrders: [DashboardApparatusWorkOrder]
    let departmentStats: APIClient.DispatchBucket?
    let recentCalls: [RecentDepartmentCall]
    let outlookDays: [ScheduleOutlookDay]
    let isLoading: Bool
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

            scheduleOutlookSection

            commandMessagesSection

            recentDispatchesSection

            apparatusWorkOrdersSection
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 120)
    }

    @ViewBuilder
    private var activeDispatchSection: some View {
        if let primaryActiveDispatch {
            sectionTitle("Current Dispatch", systemImage: "bell.and.waves.left.and.right.fill")

            DashboardDispatchPreviewCard(
                dispatch: makeDispatchPayload(from: primaryActiveDispatch),
                isHighlighted: false
            ) {
                onOpenDispatch(makeDispatchPayload(from: primaryActiveDispatch))
            }

            if !secondaryActiveDispatches.isEmpty {
                sectionTitle("Additional Active Dispatches", systemImage: "bell.and.waves.left.and.right.fill")

                ActiveDispatchStackView(
                    dispatches: secondaryActiveDispatches
                ) { activeDispatch in
                    onOpenDispatch(makeDispatchPayload(from: activeDispatch))
                }
            }
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

            if isLoading && departmentStats == nil {
                loadingCard("Loading call totals...")
            } else {
                HStack(spacing: 0) {
                    chiefInlineTotal(value: callTotal(.department), label: "Department")

                    Divider()
                        .frame(height: 48)
                        .background(Color.white.opacity(0.18))

                    chiefInlineTotal(value: callTotal(.fire), label: "🔥 Fire")

                    Divider()
                        .frame(height: 48)
                        .background(Color.white.opacity(0.18))

                    chiefInlineTotal(value: callTotal(.ems), label: "🚑 EMS")
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
                .gesture(totalsSwipeGesture)
            }
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
        switch (selectedTotalsWindow, kind) {
        case (.last24h, .department): return departmentStats?.total24h ?? 0
        case (.last24h, .fire): return departmentStats?.fire24h ?? 0
        case (.last24h, .ems): return departmentStats?.ems24h ?? 0

        case (.last7d, .department): return departmentStats?.total7d ?? 0
        case (.last7d, .fire): return departmentStats?.fire7d ?? 0
        case (.last7d, .ems): return departmentStats?.ems7d ?? 0

        case (.last30d, .department): return departmentStats?.total30d ?? 0
        case (.last30d, .fire): return departmentStats?.fire30d ?? 0
        case (.last30d, .ems): return departmentStats?.ems30d ?? 0

        case (.ytd, .department): return departmentStats?.totalYtd ?? 0
        case (.ytd, .fire): return departmentStats?.fireYtd ?? 0
        case (.ytd, .ems): return departmentStats?.emsYtd ?? 0
        }
    }

    private enum ChiefCallTotalKind {
        case department
        case fire
        case ems
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
                if isLoading && outlookDays.isEmpty {
                    loadingRow("Loading schedule outlook...")
                } else if outlookDays.isEmpty {
                    emptyRow("Schedule outlook unavailable.")
                } else if displayEntries.isEmpty {
                    Text("\(DashboardEmoji.schedule) No staffing returned for \(selectedScheduleDay?.label ?? "this day").")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Full details remain available in Schedule.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(displayEntries) { entry in
                                scheduleEntryRow(entry)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 126)

                    Text("Swipe left/right for days. Scroll for more staffing.")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.52))
                }

                if totalVacancies > 0 {
                    Text("\(DashboardEmoji.warning) \(totalVacancies) vacanc\(totalVacancies == 1 ? "y" : "ies"). View full Schedule for open positions.")
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
            .gesture(scheduleSwipeGesture)
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

    private var scheduleSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard abs(horizontal) > abs(vertical), abs(horizontal) > 40 else {
                    return
                }

                if horizontal < 0 {
                    selectNextScheduleDay()
                } else {
                    selectPreviousScheduleDay()
                }
            }
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
