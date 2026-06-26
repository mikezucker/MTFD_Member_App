import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var viewModel = ScheduleViewModel()

    @State private var selectedDayId: String?
    @State private var selectedStation = ScheduleStationFilter.all
    @State private var selectedStatus = ScheduleStatusFilter.all
    @State private var expandedEntryIDs: Set<String> = []

    private let outlookDayCount = 7

    var body: some View {
        AppScreen(
            title: "Schedule",
            subtitle: "Department staffing and upcoming assignments.",
            systemImage: "calendar.badge.clock"
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    scheduleToolbar

                    if viewModel.isLoading && selectedEntries.isEmpty {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let errorMessage = viewModel.errorMessage,
                              selectedEntries.isEmpty,
                              viewModel.outlookDays.isEmpty {
                        errorCard(errorMessage)
                    } else if selectedEntries.isEmpty {
                        emptyCard(title: "No schedule entries", message: "No staffing assignments were returned for this date.")
                    } else {
                        coverageSummary
                        needsCoverageSection
                        scheduleListSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            if viewModel.outlookDays.isEmpty && viewModel.entries.isEmpty {
                await viewModel.loadOutlookDays(count: outlookDayCount)
            }
        }
        .onChange(of: viewModel.outlookDays.count) { _, _ in
            if selectedDayId == nil {
                selectedDayId = viewModel.outlookDays.first?.id
            }
        }
    }

    private var scheduleToolbar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedDay?.label == "Today" ? "Today’s Staffing" : "Staffing Board")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    Text(selectedDay?.date ?? viewModel.date ?? "Current FirstDue schedule")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppTheme.gold)
                }
            }

            dayPicker
            filterControls

            if let message = viewModel.errorMessage,
               !message.isEmpty,
               (!selectedEntries.isEmpty || !viewModel.outlookDays.isEmpty) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow.opacity(0.92))
                    .lineLimit(3)
            }
        }
    }

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(displayDays) { day in
                    let isSelected = day.id == activeDayId
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedDayId = day.id
                            selectedStation = .all
                            selectedStatus = .all
                            expandedEntryIDs.removeAll()
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Text(day.label)
                                .font(.caption.weight(.bold))

                            Text(shortDateLabel(for: day.id))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isSelected ? .black.opacity(0.68) : .white.opacity(0.58))

                            HStack(spacing: 4) {
                                Image(systemName: dayVacancyCount(day) > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("\(day.entries.count)")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(isSelected ? .black.opacity(0.76) : dayVacancyCount(day) > 0 ? .orange : AppTheme.gold)
                        }
                        .foregroundStyle(isSelected ? .black : .white)
                        .frame(width: 72, height: 66)
                        .background(isSelected ? AppTheme.gold : Color.white.opacity(0.09))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? Color.clear : Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ScheduleStatusFilter.allCases) { status in
                        filterChip(
                            title: status.title,
                            systemImage: status.systemImage,
                            isSelected: selectedStatus == status
                        ) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedStatus = status
                                expandedEntryIDs.removeAll()
                            }
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(stationFilters) { station in
                        filterChip(
                            title: station.title,
                            systemImage: station.systemImage,
                            isSelected: selectedStation == station
                        ) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedStation = station
                                expandedEntryIDs.removeAll()
                            }
                        }
                    }
                }
            }
        }
    }

    private var coverageSummary: some View {
        HStack(spacing: 10) {
            summaryMetric(title: "Assignments", value: "\(selectedEntries.count)", systemImage: "calendar")
            summaryMetric(title: "Staffed", value: "\(filledStaffingCount)", systemImage: "person.2.fill")
            summaryMetric(title: "Vacant", value: "\(vacancyCount)", systemImage: "exclamationmark.triangle.fill", isWarning: vacancyCount > 0)
        }
    }

    @ViewBuilder
    private var needsCoverageSection: some View {
        if selectedStatus != .needsCoverage && !needsCoverageEntries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Needs Coverage", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(needsCoverageEntries.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.orange)
                        .clipShape(Capsule())
                }

                VStack(spacing: 10) {
                    ForEach(needsCoverageEntries.prefix(3)) { entry in
                        compactCoverageRow(entry)
                    }
                }
            }
            .padding(14)
            .background(Color.orange.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var scheduleListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(listTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(visibleEntries.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.76))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.10))
                    .clipShape(Capsule())
            }

            if visibleEntries.isEmpty {
                emptyCard(title: "No matching assignments", message: "Adjust the filters to see more staffing entries for this date.")
            } else {
                ForEach(visibleEntries) { entry in
                    scheduleCard(entry)
                }
            }
        }
    }

    private func scheduleCard(_ entry: APIClient.MobileScheduleEntry) -> some View {
        let isExpanded = expandedEntryIDs.contains(entry.id)
        let vacantCount = entryVacancyCount(entry)
        let staffedCount = entryStaffedCount(entry)

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                if isExpanded {
                    expandedEntryIDs.remove(entry.id)
                } else {
                    expandedEntryIDs.insert(entry.id)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text(entry.timeRange)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.gold)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 7) {
                        if let station = cleanStation(entry), !station.isEmpty {
                            Text(station)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.82))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Image(systemName: "chevron.down")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.44))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }

                HStack(spacing: 8) {
                    staffingPill(title: "\(staffedCount) staffed", systemImage: "person.crop.circle.fill", color: AppTheme.gold)

                    if vacantCount > 0 {
                        staffingPill(title: "\(vacantCount) vacant", systemImage: "exclamationmark.triangle.fill", color: .orange)
                    } else {
                        staffingPill(title: "Covered", systemImage: "checkmark.circle.fill", color: .green)
                    }
                }

                if isExpanded {
                    Divider()
                        .background(Color.white.opacity(0.16))

                    staffingDetails(for: entry)
                } else if let preview = staffingPreview(for: entry) {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.09))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(vacantCount > 0 ? Color.orange.opacity(0.26) : Color.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func staffingDetails(for entry: APIClient.MobileScheduleEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.staffingDetails.isEmpty && entry.staffing.isEmpty {
                Text("No staffing listed")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.58))
            } else if !entry.staffingDetails.isEmpty {
                ForEach(Array(entry.staffingDetails.enumerated()), id: \.offset) { _, detail in
                    staffingDetailRow(detail)
                }
            } else {
                ForEach(Array(entry.staffing.enumerated()), id: \.offset) { _, staff in
                    legacyStaffingRow(staff)
                }
            }
        }
    }

    private func staffingDetailRow(_ detail: APIClient.MobileScheduleStaffingDetail) -> some View {
        let name = detail.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let qualifier = detail.qualifier?.trimmingCharacters(in: .whitespacesAndNewlines)

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: detail.isVacant ? "person.crop.circle.badge.exclamationmark" : "person.crop.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(detail.isVacant ? .orange : AppTheme.gold)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(name?.isEmpty == false ? name! : "Vacant position")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))

                if let qualifier, !qualifier.isEmpty {
                    Text(qualifier)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func legacyStaffingRow(_ staff: String) -> some View {
        let isVacant = staff.localizedCaseInsensitiveContains("vacant")

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: isVacant ? "person.crop.circle.badge.exclamationmark" : "person.crop.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isVacant ? .orange : AppTheme.gold)
                .frame(width: 24)

            Text(staff)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func compactCoverageRow(_ entry: APIClient.MobileScheduleEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.orange)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(entry.timeRange) • \(entryVacancyCount(entry)) vacant")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }

            Spacer()

            if let station = cleanStation(entry) {
                Text(station)
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.74))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.10))
                    .clipShape(Capsule())
            }
        }
    }

    private func summaryMetric(title: String, value: String, systemImage: String, isWarning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isWarning ? .orange : AppTheme.gold)

                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.58))
                    .textCase(.uppercase)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isWarning ? Color.orange.opacity(0.24) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func filterChip(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.82))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.gold : Color.white.opacity(0.09))
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func staffingPill(title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schedule unavailable")
                .font(.headline)
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func emptyCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var displayDays: [ScheduleOutlookDay] {
        if !viewModel.outlookDays.isEmpty {
            return viewModel.outlookDays
        }

        return [
            ScheduleOutlookDay(
                id: "today",
                label: "Today",
                date: viewModel.date ?? "Today",
                entries: viewModel.entries
            )
        ]
    }

    private var activeDayId: String {
        selectedDayId ?? displayDays.first?.id ?? "today"
    }

    private var selectedDay: ScheduleOutlookDay? {
        displayDays.first { $0.id == activeDayId } ?? displayDays.first
    }

    private var selectedEntries: [APIClient.MobileScheduleEntry] {
        selectedDay?.entries ?? viewModel.entries
    }

    private var stationFilters: [ScheduleStationFilter] {
        let stations = selectedEntries
            .compactMap(cleanStation)
            .uniqued()
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        return [.all] + stations.map { ScheduleStationFilter.station($0) }
    }

    private var visibleEntries: [APIClient.MobileScheduleEntry] {
        selectedEntries.filter { entry in
            let stationMatches: Bool
            switch selectedStation {
            case .all:
                stationMatches = true
            case .station(let station):
                stationMatches = cleanStation(entry) == station
            }

            let statusMatches: Bool
            switch selectedStatus {
            case .all:
                statusMatches = true
            case .needsCoverage:
                statusMatches = entryVacancyCount(entry) > 0
            case .mySchedule:
                statusMatches = isCurrentUserAssigned(to: entry)
            }

            return stationMatches && statusMatches
        }
    }

    private var needsCoverageEntries: [APIClient.MobileScheduleEntry] {
        selectedEntries.filter { entryVacancyCount($0) > 0 }
    }

    private var filledStaffingCount: Int {
        selectedEntries.reduce(0) { $0 + entryStaffedCount($1) }
    }

    private var vacancyCount: Int {
        selectedEntries.reduce(0) { $0 + entryVacancyCount($1) }
    }

    private var listTitle: String {
        if selectedStatus == .mySchedule {
            return "My Schedule"
        }

        if selectedStatus == .needsCoverage {
            return "Needs Coverage"
        }

        if case .station(let station) = selectedStation {
            return station
        }

        return "Assignments"
    }

    private func cleanStation(_ entry: APIClient.MobileScheduleEntry) -> String? {
        let station = entry.station?.trimmingCharacters(in: .whitespacesAndNewlines)
        return station?.isEmpty == false ? station : nil
    }

    private func entryStaffedCount(_ entry: APIClient.MobileScheduleEntry) -> Int {
        if !entry.staffingDetails.isEmpty {
            return entry.staffingDetails.filter { !$0.isVacant }.count
        }

        return entry.staffing.filter { !$0.localizedCaseInsensitiveContains("vacant") }.count
    }

    private func entryVacancyCount(_ entry: APIClient.MobileScheduleEntry) -> Int {
        if !entry.staffingDetails.isEmpty {
            return entry.staffingDetails.filter { $0.isVacant }.count
        }

        return entry.staffing.filter { $0.localizedCaseInsensitiveContains("vacant") }.count
    }

    private func dayVacancyCount(_ day: ScheduleOutlookDay) -> Int {
        day.entries.reduce(0) { $0 + entryVacancyCount($1) }
    }

    private func staffingPreview(for entry: APIClient.MobileScheduleEntry) -> String? {
        if !entry.staffingDetails.isEmpty {
            let names = entry.staffingDetails
                .filter { !$0.isVacant }
                .compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if !names.isEmpty {
                return names.prefix(3).joined(separator: " • ")
            }
        }

        let nonVacantStaffing = entry.staffing.filter { !$0.localizedCaseInsensitiveContains("vacant") }
        return nonVacantStaffing.isEmpty ? nil : nonVacantStaffing.prefix(2).joined(separator: " • ")
    }

    private func isCurrentUserAssigned(to entry: APIClient.MobileScheduleEntry) -> Bool {
        let userName = session.currentUser?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !userName.isEmpty else {
            return false
        }

        let normalizedUser = userName.normalizedScheduleSearchText
        let nameParts = normalizedUser
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 1 }

        func matches(_ candidate: String?) -> Bool {
            guard let candidate else {
                return false
            }

            let normalizedCandidate = candidate.normalizedScheduleSearchText

            if normalizedCandidate.contains(normalizedUser) || normalizedUser.contains(normalizedCandidate) {
                return true
            }

            return nameParts.allSatisfy { normalizedCandidate.contains($0) }
        }

        if entry.staffingDetails.contains(where: { matches($0.name) }) {
            return true
        }

        return entry.staffing.contains(where: matches)
    }

    private func shortDateLabel(for id: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: id) else {
            return ""
        }

        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

private enum ScheduleStatusFilter: String, CaseIterable, Identifiable {
    case all
    case needsCoverage
    case mySchedule

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .needsCoverage:
            return "Needs Coverage"
        case .mySchedule:
            return "My Schedule"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease.circle"
        case .needsCoverage:
            return "exclamationmark.triangle.fill"
        case .mySchedule:
            return "person.crop.circle.fill"
        }
    }
}

private enum ScheduleStationFilter: Identifiable, Equatable {
    case all
    case station(String)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .station(let station):
            return station
        }
    }

    var title: String {
        switch self {
        case .all:
            return "All Stations"
        case .station(let station):
            return station
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "building.2.fill"
        case .station:
            return "mappin.and.ellipse"
        }
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

private extension String {
    var normalizedScheduleSearchText: String {
        lowercased()
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }
}

#Preview {
    NavigationStack {
        ScheduleView()
            .environmentObject(SessionManager.shared)
    }
}
