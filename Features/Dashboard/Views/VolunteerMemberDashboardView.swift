import SwiftUI

struct VolunteerMemberDashboardView: View {
    let volunteerContext: APIClient.VolunteerContext?
    let stationStats: APIClient.DispatchBucket?
    let workOrders: [DashboardApparatusWorkOrder]
    let workOrdersMessage: String?
    let assignedTrainingPreview: [DashboardTrainingPreviewItem]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            companyApparatusCard
            officerCard
            trainingCard
            apparatusTotalsCard
            troubleReportsCard
        }
    }

    private var companyApparatusCard: some View {
        volunteerCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("My Company", systemImage: "house.and.flag.fill")

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "firetruck.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.gold)
                        .frame(width: 34)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(companyTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        Text(apparatusTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))

                        Text(stationTitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Spacer()
                }
            }
        }
    }

    private var officerCard: some View {
        volunteerCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("My Volunteer Officer", systemImage: "person.crop.circle.badge.checkmark")

                if let officer = volunteerContext?.officer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(officer.name ?? "Assigned Officer")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)

                        Text("For drill questions, training help, company info, or apparatus concerns.")
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
                } else {
                    emptyText("No volunteer officer is assigned yet.")
                }
            }
        }
    }

    private var trainingCard: some View {
        volunteerCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("My Training Path", systemImage: "checkmark.seal.fill")

                if assignedTrainingPreview.isEmpty {
                    emptyText("No assigned training right now.")
                } else {
                    ForEach(assignedTrainingPreview.prefix(3)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(trainingSubtitle(for: item))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.64))
                        }

                        if item.id != assignedTrainingPreview.prefix(3).last?.id {
                            Divider().background(Color.white.opacity(0.14))
                        }
                    }
                }
            }
        }
    }

    private var apparatusTotalsCard: some View {
        volunteerCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("My Apparatus Calls", systemImage: "chart.bar.fill")

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

    private var troubleReportsCard: some View {
        volunteerCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("My Apparatus Trouble Reports", systemImage: "wrench.and.screwdriver.fill")

                if workOrders.isEmpty {
                    emptyText(workOrdersMessage ?? "No open trouble reports for your apparatus.")
                } else {
                    ForEach(workOrders.prefix(4)) { order in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(order.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(3)

                            if let status = order.status, !status.isEmpty {
                                Text(status)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.gold.opacity(0.92))
                            }
                        }

                        if order.id != workOrders.prefix(4).last?.id {
                            Divider().background(Color.white.opacity(0.14))
                        }
                    }
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

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.gold)

            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.gold)
                .textCase(.uppercase)
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
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    private func trainingSubtitle(for item: DashboardTrainingPreviewItem) -> String {
        if item.isOverdue {
            return "Ready to complete • Overdue"
        }

        return "Next step • \(item.progressText)"
    }

    private var companyTitle: String {
        volunteerContext?.company?
            .replacingOccurrences(of: "_", with: " ")
            .capitalized ?? "My Company"
    }

    private var apparatusTitle: String {
        volunteerContext?.apparatus?.displayName ?? "My Apparatus"
    }

    private var stationTitle: String {
        volunteerContext?.station ?? volunteerContext?.apparatus?.station ?? "Station not assigned"
    }
}
