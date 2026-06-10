import SwiftUI

struct VolunteerMemberDashboardView: View {
    let volunteerContext: APIClient.VolunteerContext?
    let stationDisplayName: String?
    let stationStats: APIClient.DispatchBucket?
    let workOrders: [DashboardApparatusWorkOrder]
    let workOrdersMessage: String?
    let assignedTrainingPreview: [DashboardTrainingPreviewItem]
    let stationUpdates: [DashboardBulletin]
    let departmentUpdates: [DashboardBulletin]
    let isLoading: Bool
    let onRefresh: () async -> Void

    @State private var selectedAnnouncementScope: AnnouncementScope = .all
    @State private var selectedApparatusName: String = "All"

    private enum AnnouncementScope: String, CaseIterable {
        case all = "All"
        case station = "Station"
        case department = "Department"
    }

    var body: some View {
        NonBouncingVerticalScrollView(showsIndicators: false, onRefresh: onRefresh) {
            VStack(alignment: .leading, spacing: 22) {
                belongingCard
                nextStepCard
                announcementsCard
                apparatusStatusCard
                contributionCard

                if volunteerContext?.officer != nil {
                    officerCard
                } else {
                    quietOfficerCard
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var belongingCard: some View {
        volunteerCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.gold.opacity(0.18))
                        .frame(width: 46, height: 46)

                    AppIcon(.station)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.gold)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("You’re part of \(stationTitle)")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("\(apparatusTitle)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))

                    Text("Training, announcements, apparatus status, and station activity are pulled together here.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
        }
    }

    private var nextStepCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Training", systemImage: "graduationcap.fill")

            volunteerCard {
                VStack(alignment: .leading, spacing: 12) {
                if assignedTrainingPreview.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("No assigned training right now.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text("When a drill, refresher, or assignment is posted, it will show up here.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.64))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    ForEach(assignedTrainingPreview.prefix(4)) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top, spacing: 8) {
                                AppIcon(systemImage: item.isOverdue ? "exclamationmark.triangle.fill" : "play.circle.fill")
                                    .foregroundStyle(item.isOverdue ? .orange : AppTheme.gold)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)

                                    Text(trainingSubtitle(for: item))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.64))
                                }

                                Spacer()

                                Text("\(item.progressPercent)%")
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.gold)
                            }
                        }

                        if item.id != assignedTrainingPreview.prefix(4).last?.id {
                            Divider().background(Color.white.opacity(0.14))
                        }
                    }
                }
            }
        }
    }

    }

    private var announcementsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Announcements", systemImage: "megaphone.fill")

            volunteerCard {
                VStack(alignment: .leading, spacing: 12) {
                filterChips(
                    items: AnnouncementScope.allCases.map(\.rawValue),
                    selected: selectedAnnouncementScope.rawValue
                ) { value in
                    selectedAnnouncementScope = AnnouncementScope(rawValue: value) ?? .all
                }

                let updates = filteredAnnouncements

                if updates.isEmpty {
                    emptyText("No station or department announcements right now.")
                } else {
                    ForEach(updates.prefix(4)) { update in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(update.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            Text(update.message)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.64))
                                .lineLimit(3)

                            if let updatedAt = update.updatedAt, !updatedAt.isEmpty {
                                Text(updatedAt)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(AppTheme.gold.opacity(0.9))
                            }
                        }

                        if update.id != updates.prefix(4).last?.id {
                            Divider().background(Color.white.opacity(0.14))
                        }
                    }
                }
            }
        }
    }

    }

    private var apparatusStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Apparatus Status", systemImage: "wrench.and.screwdriver.fill")

            volunteerCard {
                VStack(alignment: .leading, spacing: 12) {
                if apparatusFilterNames.count > 2 {
                    filterChips(
                        items: apparatusFilterNames,
                        selected: selectedApparatusName
                    ) { selectedApparatusName = $0 }
                }

                let orders = filteredWorkOrders

                if workOrders.isEmpty {
                    emptyText(workOrdersMessage ?? "No open trouble reports for your station apparatus.")
                } else if orders.isEmpty {
                    emptyText("No open trouble reports for \(selectedApparatusName).")
                } else {
                    ForEach(orders.prefix(5)) { order in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(order.apparatusName)
                                        .font(.caption.bold())
                                        .foregroundStyle(AppTheme.gold)

                                    Text(order.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(3)
                                }

                                Spacer()

                                if let status = order.status, !status.isEmpty {
                                    Text(status)
                                        .font(.caption2.bold())
                                        .foregroundStyle(AppTheme.navy)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(AppTheme.gold)
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        if order.id != orders.prefix(5).last?.id {
                            Divider().background(Color.white.opacity(0.14))
                        }
                    }
                }
            }
        }
    }
    }


    private var contributionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Station Contribution", systemImage: "chart.bar.fill")

            volunteerCard {
                VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 0) {
                    totalColumn("Total", stationStats?.totalYtd ?? 0)
                    Divider().frame(height: 44).background(Color.white.opacity(0.18))
                    totalColumn("Fire", stationStats?.fireYtd ?? 0)
                    Divider().frame(height: 44).background(Color.white.opacity(0.18))
                    totalColumn("EMS", stationStats?.emsYtd ?? 0)
                    Divider().frame(height: 44).background(Color.white.opacity(0.18))
                    totalColumn("Other", stationStats?.otherYtd ?? 0)
                }
            }
        }
    }
    }


    private var officerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Volunteer Officer", systemImage: "person.crop.circle.badge.checkmark")

            volunteerCard {
                VStack(alignment: .leading, spacing: 12) {
                if let officer = volunteerContext?.officer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(officer.name ?? "Assigned Officer")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("For drill questions, training help, station info, or apparatus concerns.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            if let phone = cleanValue(officer.phone), let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
                                Link(destination: url) {
                                    contactButtonLabel("Call", systemImage: "phone.fill")
                                }
                            }

                            if let email = cleanValue(officer.email), let url = URL(string: "mailto:\(email)") {
                                Link(destination: url) {
                                    contactButtonLabel("Email", systemImage: "envelope.fill")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    }


    private var quietOfficerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Volunteer Officer", systemImage: "person.crop.circle.badge.checkmark")

            volunteerCard {
                VStack(alignment: .leading, spacing: 8) {
                    emptyText("No volunteer officer is assigned yet.")
                }
            }
        }
    }



    private func volunteerCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            DashboardColorIcon(systemImage: systemImage, size: 22, frameSize: 30)

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()
        }
    }

    private func filterChips(items: [String], selected: String, onSelect: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        Text(item)
                            .font(.caption.bold())
                            .foregroundStyle(selected == item ? AppTheme.navy : .white.opacity(0.82))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selected == item ? AppTheme.gold : Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func contactButtonLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.bold())
            .foregroundStyle(AppTheme.navy)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(AppTheme.gold)
            .clipShape(Capsule())
    }

    private func totalColumn(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.64))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func cleanValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func trainingSubtitle(for item: DashboardTrainingPreviewItem) -> String {
        if item.isOverdue {
            return "Needs attention • Overdue"
        }

        return "Assigned training • \(item.progressText)"
    }

    private var filteredAnnouncements: [DashboardBulletin] {
        switch selectedAnnouncementScope {
        case .all:
            return stationUpdates + departmentUpdates
        case .station:
            return stationUpdates
        case .department:
            return departmentUpdates
        }
    }

    private var apparatusFilterNames: [String] {
        let names = workOrders
            .map(\.apparatusName)
            .filter { !$0.isEmpty }

        let uniqueNames = Array(Set(names)).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }

        return ["All"] + uniqueNames
    }

    private var filteredWorkOrders: [DashboardApparatusWorkOrder] {
        if selectedApparatusName == "All" {
            return workOrders
        }

        return workOrders.filter { $0.apparatusName == selectedApparatusName }
    }

    private var companyTitle: String {
        stationTitle
    }

    private var apparatusTitle: String {
        let apparatusList = volunteerContext?.stationApparatus ?? []

        if apparatusList.count > 1 {
            return "\(apparatusList.count) Station Apparatus"
        }

        if let first = apparatusList.first?.displayName, !first.isEmpty {
            return first
        }

        if let apparatus = volunteerContext?.apparatus?.displayName, !apparatus.isEmpty {
            return apparatus
        }

        return "Station Apparatus"
    }

    private var stationTitle: String {
        if let stationDisplayName, !stationDisplayName.isEmpty {
            return stationDisplayName
        }

        if let company = volunteerContext?.company, !company.isEmpty {
            return StationMapper.displayName(from: company)
        }

        if let station = volunteerContext?.station, !station.isEmpty {
            return station
        }

        if let apparatusStation = volunteerContext?.apparatus?.station, !apparatusStation.isEmpty {
            return apparatusStation
        }

        return "Station not assigned"
    }
}
