import SwiftUI

struct TrainingView: View {
    @StateObject private var viewModel = TrainingViewModel()

    var body: some View {
        NavigationStack {
            AppScreen(title: "Training") {
                ZStack {
                    if viewModel.isLoading && !viewModel.hasCachedData {
                        loadingState
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                headerSection

                                if let errorMessage = viewModel.errorMessage, !viewModel.hasCachedData {
                                    errorState(errorMessage)
                                } else {
                                    summarySection

                                    if viewModel.myTraining.isEmpty {
                                        emptyTrainingSection
                                    } else {
                                        assignedTrainingSection
                                    }

                                    if let capabilities = viewModel.capabilities {
                                        roleAwareToolsSection(capabilities)
                                    }

                                    if !viewModel.pendingEvaluations.isEmpty {
                                        pendingEvaluationsSection
                                    }

                                    if !viewModel.managedMembers.isEmpty {
                                        managedMembersSection
                                    }

                                    footerSection
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .refreshable {
                            await viewModel.refresh()
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.1)

            Text("Loading training…")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.gold.opacity(0.18))
                        .frame(width: 58, height: 58)

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppTheme.gold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Training Hub")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                if viewModel.isRefreshing {
                    ProgressView()
                        .tint(AppTheme.gold)
                }
            }

            HStack(spacing: 8) {
                TrainingPill(
                    title: scopeTitle,
                    systemImage: "person.crop.circle.badge.checkmark"
                )

                if let capabilities = viewModel.capabilities,
                   capabilities.canCreateTraining ||
                    capabilities.canAssignTraining ||
                    capabilities.canEvaluateTraining {
                    TrainingPill(
                        title: "Tools Enabled",
                        systemImage: "wrench.and.screwdriver.fill"
                    )
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                SummaryMetricCard(
                    value: "\(viewModel.summary?.assignedCount ?? 0)",
                    label: "Assigned",
                    systemImage: "tray.full.fill"
                )

                SummaryMetricCard(
                    value: "\(viewModel.summary?.inProgressCount ?? 0)",
                    label: "In Progress",
                    systemImage: "clock.fill"
                )

                SummaryMetricCard(
                    value: "\(viewModel.summary?.completedCount ?? 0)",
                    label: "Done",
                    systemImage: "checkmark.seal.fill"
                )
            }

            if (viewModel.summary?.overdueCount ?? 0) > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    Text("\(viewModel.summary?.overdueCount ?? 0) overdue training item(s)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var assignedTrainingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Assignments")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(viewModel.myTraining.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }

            ForEach(viewModel.myTraining) { item in
                NavigationLink {
                    TrainingCourseDetailView(item: item)
                } label: {
                    TrainingAssignmentCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyTrainingSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppTheme.gold)

            Text("No assigned training right now.")
                .font(.headline)
                .foregroundStyle(.white)

            Text("You’re clear for the moment. New assignments will show here automatically.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private func roleAwareToolsSection(_ capabilities: TrainingCapabilities) -> some View {
        let showTools = capabilities.canCreateTraining ||
            capabilities.canAssignTraining ||
            capabilities.canEvaluateTraining ||
            capabilities.canViewManagedProgress ||
            capabilities.canViewDepartmentProgress

        if showTools {
            VStack(alignment: .leading, spacing: 12) {
                Text(capabilities.canViewDepartmentProgress ? "Training Command" : "Training Tools")
                    .font(.headline)
                    .foregroundStyle(.white)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 10
                ) {
                    if capabilities.canCreateTraining {
                        TrainingToolTile(
                            title: "Create",
                            subtitle: "Build courses",
                            systemImage: "plus.rectangle.on.folder.fill"
                        )
                    }

                    if capabilities.canAssignTraining {
                        TrainingToolTile(
                            title: "Assign",
                            subtitle: "Send training",
                            systemImage: "paperplane.fill"
                        )
                    }

                    if capabilities.canEvaluateTraining {
                        TrainingToolTile(
                            title: "Evaluate",
                            subtitle: "JPR reviews",
                            systemImage: "checklist.checked"
                        )
                    }

                    if capabilities.canViewManagedProgress {
                        TrainingToolTile(
                            title: "Progress",
                            subtitle: "Crew status",
                            systemImage: "chart.bar.fill"
                        )
                    }

                    if capabilities.canViewDepartmentProgress {
                        TrainingToolTile(
                            title: "Department",
                            subtitle: "Compliance",
                            systemImage: "building.2.crop.circle.fill"
                        )
                    }
                }
            }
        }
    }

    private var pendingEvaluationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pending Evaluations")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(viewModel.pendingEvaluations) { evaluation in
                VStack(alignment: .leading, spacing: 6) {
                    Text(evaluation.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)

                    Text(evaluation.courseTitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var managedMembersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Managed Members")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(viewModel.managedMembers.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }

            ForEach(Array(viewModel.managedMembers.prefix(6))) { member in
                HStack(spacing: 12) {
                    Circle()
                        .fill(AppTheme.gold.opacity(0.18))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(AppTheme.gold)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name ?? member.email)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)

                        Text(member.roleDisplay)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var footerSection: some View {
        VStack(spacing: 8) {
            if let lastUpdated = viewModel.response?.lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            if let errorMessage = viewModel.errorMessage, viewModel.hasCachedData {
                Text("Showing cached training. \(errorMessage)")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.orange.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.orange)

            Text("Training unavailable")
                .font(.headline)
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.72))

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var headerSubtitle: String {
        if let viewer = viewModel.response?.viewer {
            return "\(viewer.roleDisplay) · \(viewer.companyDisplay)"
        }

        return "Assignments, progress, and JPR readiness"
    }

    private var scopeTitle: String {
        switch viewModel.response?.scope.type {
        case "DEPARTMENT":
            return "Department"
        case "DIRECT_REPORTS":
            return "Crew"
        default:
            return "My Training"
        }
    }
}

private struct TrainingAssignmentCard: View {
    let item: MobileTrainingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.gold.opacity(0.16))
                        .frame(width: 46, height: 46)

                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.gold)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.96))
                        .lineLimit(2)

                    Text(item.detailLine)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }

                Spacer()

                statusBadge

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 6)
            }

            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(3)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(item.progressDisplayText)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.88))

                    Spacer()

                    Text("\(item.progressPercent)%")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(AppTheme.gold)
                }

                ProgressView(value: Double(item.progressPercent), total: 100)
                    .tint(AppTheme.gold)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                if item.isOverdue {
                    Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                } else if let dueAt = item.dueAt {
                    Label("Due \(dueAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Label("No due date", systemImage: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                Text(buttonTitle)
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        }
    }

    private var iconName: String {
        switch item.progressStatus {
        case "COMPLETED":
            return "checkmark.seal.fill"
        case "IN_PROGRESS":
            return "play.circle.fill"
        default:
            return "book.closed.fill"
        }
    }

    private var buttonTitle: String {
        switch item.progressStatus {
        case "COMPLETED":
            return "Review"
        case "IN_PROGRESS":
            return "Continue"
        default:
            return "Start"
        }
    }

    private var statusBadge: some View {
        Text(statusTitle)
            .font(.caption2.bold())
            .foregroundStyle(statusForeground)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(statusBackground)
            .clipShape(Capsule())
    }

    private var statusTitle: String {
        if item.isOverdue {
            return "OVERDUE"
        }

        switch item.progressStatus {
        case "COMPLETED":
            return "DONE"
        case "IN_PROGRESS":
            return "ACTIVE"
        default:
            return "NEW"
        }
    }

    private var statusForeground: Color {
        item.progressStatus == "COMPLETED" ? .black : .white
    }

    private var statusBackground: Color {
        if item.isOverdue {
            return .orange.opacity(0.85)
        }

        switch item.progressStatus {
        case "COMPLETED":
            return AppTheme.gold
        case "IN_PROGRESS":
            return .blue.opacity(0.72)
        default:
            return .white.opacity(0.16)
        }
    }
}

private struct SummaryMetricCard: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.gold)

            Text(value)
                .font(.title3.monospacedDigit().bold())
                .foregroundStyle(.white)

            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TrainingToolTile: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.gold)

            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TrainingPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.bold())
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
    }
}

private extension TrainingViewer {
    var roleDisplay: String {
        role
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    var companyDisplay: String {
        guard let company, !company.isEmpty else {
            return "Department"
        }

        return company
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

private extension ManagedTrainingMember {
    var roleDisplay: String {
        role
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
