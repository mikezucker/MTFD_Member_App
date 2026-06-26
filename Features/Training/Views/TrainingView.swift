import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct TrainingView: View {
    @StateObject private var viewModel = TrainingViewModel()
    @State private var selectedTool: TrainingToolDestination?

    var body: some View {
        NavigationStack {
            AppScreen(title: "") {
                VStack(spacing: 0) {
                    headerSection

                    if viewModel.isLoading && !viewModel.hasCachedData {
                        loadingState
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                if let errorMessage = viewModel.errorMessage {
                                    trainingDataWarning(errorMessage)
                                }

                                trainingMainMenuSection
                                footerSection
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
            .navigationDestination(for: TrainingHomeSection.self) { section in
                trainingSectionDestination(section)
            }
        }
        .sheet(item: $selectedTool) { destination in
            NavigationStack {
                TrainingToolDestinationView(
                    destination: destination,
                    viewer: viewModel.response?.viewer,
                    scope: viewModel.response?.scope,
                    summary: viewModel.summary,
                    pendingEvaluations: viewModel.pendingEvaluations,
                    managedMembers: viewModel.managedMembers
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func trainingSectionDestination(_ section: TrainingHomeSection) -> some View {
        AppScreen(title: "") {
            VStack(spacing: 0) {
                trainingSectionHeader(section)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch section {
                        case .myTraining:
                            if activeTrainingItems.isEmpty {
                                emptyTrainingSection
                            } else {
                                assignedTrainingSection
                            }

                        case .completed:
                            completedTrainingSection

                        case .create:
                            CreateTrainingToolView(
                                viewer: viewModel.response?.viewer,
                                scope: viewModel.response?.scope,
                                managedMembers: viewModel.managedMembers
                            )

                        case .manage:
                            if let response = viewModel.response {
                                manageTrainingSection(response: response)
                            }

                        case .progress:
                            progressDashboardSection
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

    private func trainingSectionHeader(_ section: TrainingHomeSection) -> some View {
        TrainingScreenHeader(
            title: section.screenTitle,
            subtitle: section.subtitle,
            systemImage: section.systemImage,
            isRefreshing: viewModel.isRefreshing,
            stats: headerStats(for: section)
        )
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
        TrainingScreenHeader(
            title: "Training",
            subtitle: headerSubtitle,
            systemImage: "graduationcap.fill",
            isRefreshing: viewModel.isRefreshing,
            stats: [
                TrainingHeaderStat(label: "Active", value: "\(activeTrainingItems.count)"),
                TrainingHeaderStat(label: "Done", value: "\(completedTrainingItems.count)"),
                TrainingHeaderStat(label: "Overdue", value: "\(viewModel.summary?.overdueCount ?? 0)", isWarning: (viewModel.summary?.overdueCount ?? 0) > 0)
            ]
        )
    }

    private var trainingHomeActions: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible())
            ],
            spacing: 10
        ) {
            ForEach(TrainingHomeSection.allCases) { section in
                NavigationLink(value: section) {
                    TrainingHomeActionButton(section: section)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trainingMainMenuSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Menu")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(
                columns: [
                    GridItem(.flexible())
                ],
                spacing: 10
            ) {
                ForEach(visibleTrainingMenuSections) { section in
                    NavigationLink(value: section) {
                        TrainingHomeActionButton(
                            section: section,
                            badgeText: badgeText(for: section)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var visibleTrainingMenuSections: [TrainingHomeSection] {
        var sections: [TrainingHomeSection] = [.myTraining, .completed]

        guard let response = viewModel.response else {
            return sections
        }

        let capabilities = response.capabilities

        if capabilities.canEvaluateTraining ||
            capabilities.canCreateTraining ||
            capabilities.canAssignTraining {
            sections.append(.manage)
        }

        if capabilities.canViewManagedProgress ||
            capabilities.canViewDepartmentProgress ||
            capabilities.canManageReporting {
            sections.append(.progress)
        }

        return sections
    }

    private func badgeText(for section: TrainingHomeSection) -> String? {
        switch section {
        case .myTraining:
            return "\(activeTrainingItems.count)"
        case .completed:
            return "\(completedTrainingItems.count)"
        case .manage:
            let count = viewModel.pendingEvaluations.count
            return count > 0 ? "\(count)" : nil
        case .progress:
            let count = viewModel.managedMembers.count
            return count > 0 ? "\(count)" : nil
        case .create:
            return nil
        }
    }

    private func headerStats(for section: TrainingHomeSection) -> [TrainingHeaderStat] {
        switch section {
        case .myTraining:
            return [
                TrainingHeaderStat(label: "Active", value: "\(activeTrainingItems.count)"),
                TrainingHeaderStat(label: "In Progress", value: "\(viewModel.summary?.inProgressCount ?? 0)"),
                TrainingHeaderStat(label: "Overdue", value: "\(viewModel.summary?.overdueCount ?? 0)", isWarning: (viewModel.summary?.overdueCount ?? 0) > 0)
            ]
        case .completed:
            return [
                TrainingHeaderStat(label: "Completed", value: "\(completedTrainingItems.count)")
            ]
        case .manage:
            return [
                TrainingHeaderStat(label: "Evaluations", value: "\(viewModel.pendingEvaluations.count)"),
                TrainingHeaderStat(label: "Tools", value: viewModel.capabilities?.hasTrainingManagementAccess(viewer: viewModel.response?.viewer) == true ? "On" : "Off")
            ]
        case .progress:
            return [
                TrainingHeaderStat(label: "Roster", value: "\(viewModel.managedMembers.count)"),
                TrainingHeaderStat(label: "Pending", value: "\(viewModel.pendingEvaluations.count)")
            ]
        case .create:
            return []
        }
    }

    private var activeTrainingItems: [MobileTrainingItem] {
        viewModel.myTraining.filter { item in
            item.progressStatus != "COMPLETED" && item.completedAt == nil
        }
    }

    private var completedTrainingItems: [MobileTrainingItem] {
        viewModel.myTraining.filter { item in
            item.progressStatus == "COMPLETED" || item.completedAt != nil
        }
    }

    private func accessExplanationSection(
        capabilities: TrainingCapabilities,
        scope: TrainingScope
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(accessModeEmoji(capabilities: capabilities, scope: scope))
                    .font(.system(size: 30))
                    .frame(width: 38)

                VStack(alignment: .leading, spacing: 5) {
                    Text(accessModeTitle(capabilities: capabilities, scope: scope))
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(accessModeMessage(capabilities: capabilities, scope: scope))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            if capabilities.hasTrainingManagementAccess(viewer: viewModel.response?.viewer) {
                Divider()
                    .overlay(.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 7) {
                    Text("Available actions")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.68))

                    FlowLikePermissionRows(capabilities: capabilities)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func accessModeTitle(
        capabilities: TrainingCapabilities,
        scope: TrainingScope
    ) -> String {
        if capabilities.canViewDepartmentProgress {
            return "Department Training Access"
        }

        if scope.type == "DIRECT_REPORTS" || capabilities.canViewManagedProgress {
            return "Officer / Instructor Training Access"
        }

        return "Member Training Access"
    }

    private func accessModeMessage(
        capabilities: TrainingCapabilities,
        scope: TrainingScope
    ) -> String {
        if capabilities.canViewDepartmentProgress {
            return "You can review department training progress. Additional tools appear here only when your website permissions allow them."
        }

        if scope.type == "DIRECT_REPORTS" || capabilities.canViewManagedProgress {
            let count = scope.managedMemberCount
            let memberText = count == 1 ? "1 member" : "\(count) members"
            return "You can complete your own training and review training progress for \(memberText) assigned to your supervision."
        }

        return "You can view and complete training assigned to you. Management tools are hidden unless your website permissions allow them."
    }

    private func accessModeEmoji(
        capabilities: TrainingCapabilities,
        scope: TrainingScope
    ) -> String {
        if capabilities.canViewDepartmentProgress {
            return "🏢"
        }

        if scope.type == "DIRECT_REPORTS" || capabilities.canViewManagedProgress {
            return "👥"
        }

        return "🎓"
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
                    Text("⚠️")

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
                Text("Assigned Training")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(activeTrainingItems.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }

            ForEach(activeTrainingItems) { item in
                NavigationLink {
                    TrainingCourseDetailView(item: item)
                } label: {
                    TrainingAssignmentCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var completedTrainingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Completed Training")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(completedTrainingItems.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }

            if completedTrainingItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No completed training yet.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Completed courses will appear here with dates and course details.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ForEach(completedTrainingItems) { item in
                    NavigationLink {
                        TrainingCourseDetailView(item: item)
                    } label: {
                        TrainingCompletedCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var managementGatewaySection: some View {
        if let response = viewModel.response {
            let capabilities = response.capabilities
            let showManagedProgress = capabilities.canViewManagedProgress ||
                capabilities.canViewDepartmentProgress ||
                capabilities.canManageReporting
            let showManagement = capabilities.hasTrainingManagementAccess(viewer: response.viewer)

            if showManagement {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Evaluator Tools")
                        .font(.headline)
                        .foregroundStyle(.white)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 10
                    ) {
                        if capabilities.canEvaluateTraining || capabilities.canCreateTraining || capabilities.canAssignTraining {
                            NavigationLink(value: TrainingHomeSection.manage) {
                                TrainingHomeActionButton(section: .manage)
                            }
                            .buttonStyle(.plain)
                        }

                        if showManagedProgress {
                            NavigationLink(value: TrainingHomeSection.progress) {
                                TrainingHomeActionButton(section: .progress)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
            }
        }
    }

    private var emptyTrainingSection: some View {
        VStack(spacing: 12) {
            Text("✅")
                .font(.system(size: 38))

            Text("No active training right now.")
                .font(.headline)
                .foregroundStyle(.white)

            Text("New assignments will show here automatically. Completed courses stay in your history below.")
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
    private func officerTrainingConsoleSection(response: MobileTrainingResponse) -> some View {
        let capabilities = response.capabilities

        let showConsole = capabilities.hasTrainingManagementAccess(viewer: response.viewer)

        if showConsole {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Officer Training Console")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Edit, assign, delete, evaluate, and track training based on your website permissions.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 10
                ) {
                    if capabilities.canEvaluateTraining {
                        TrainingToolTile(
                            title: "Evaluate Skills",
                            subtitle: "Review JPR checkoffs",
                            emoji: "✅"
                        ) {
                            selectedTool = .evaluate
                        }
                    }

                    if capabilities.canViewManagedProgress {
                        TrainingToolTile(
                            title: "Training Roster",
                            subtitle: "Track completion and needs",
                            emoji: "📈"
                        ) {
                            selectedTool = .progress
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private func manageTrainingSection(response: MobileTrainingResponse) -> some View {
        let capabilities = response.capabilities
        let canManageTraining = capabilities.hasTrainingManagementAccess(viewer: response.viewer)
        let canEditTraining = capabilities.canCreateTraining

        VStack(alignment: .leading, spacing: 14) {
            if canManageTraining {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Manage Training")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(canEditTraining
                        ? "Review existing courses, edit course details and modules, manage assignments, or delete training that is no longer needed."
                        : "Review existing courses and evaluate assigned training. Editing and assignment tools follow your website permissions.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                ManageTrainingLibraryView(
                    capabilities: capabilities,
                    viewer: response.viewer,
                    scope: response.scope,
                    managedMembers: viewModel.managedMembers
                )
            } else {
                lockedManagementCard
            }

            if capabilities.canEvaluateTraining && !viewModel.pendingEvaluations.isEmpty {
                pendingEvaluationsSection
            }
        }
    }

    private var lockedManagementCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Training management unavailable")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Course management and reporting tools appear here when your website permissions allow training management.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
        .trainingConsoleCard()
    }

    private var progressDashboardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Progress")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Review training completion by person, status, role, and station.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            summarySection
            TrainingProgressFiltersView()

            if !viewModel.managedMembers.isEmpty {
                managedMembersSection
            } else {
                lockedManagementCard
            }

            if !viewModel.pendingEvaluations.isEmpty {
                pendingEvaluationsSection
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
                Text("Training Roster")
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
                    Text("👤")
                        .font(.system(size: 28))
                        .frame(width: 36, height: 36)

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
            Text("⚠️")
                .font(.system(size: 38))

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

    private func trainingDataWarning(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Training data could not refresh", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.orange.opacity(0.24), lineWidth: 1)
        }
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

private enum TrainingHomeSection: String, CaseIterable, Identifiable {
    case myTraining
    case completed
    case create
    case manage
    case progress

    var id: String { rawValue }

    static var allCases: [TrainingHomeSection] {
        [.myTraining, .completed, .manage, .progress]
    }

    var title: String {
        switch self {
        case .myTraining:
            return "My Training"
        case .completed:
            return "Completed"
        case .create:
            return "Create"
        case .manage:
            return "Evaluator Tools"
        case .progress:
            return "Training Roster"
        }
    }

    var screenTitle: String {
        switch self {
        case .myTraining:
            return "My Training"
        case .completed:
            return "Completed Training"
        case .create:
            return "Create Training"
        case .manage:
            return "Evaluator Tools"
        case .progress:
            return "Training Roster"
        }
    }

    var emoji: String {
        switch self {
        case .myTraining:
            return "📚"
        case .completed:
            return "✅"
        case .create:
            return "🧱"
        case .manage:
            return "🛠️"
        case .progress:
            return "📈"
        }
    }

    var systemImage: String {
        switch self {
        case .myTraining:
            return "play.circle.fill"
        case .completed:
            return "checkmark.seal.fill"
        case .create:
            return "plus.rectangle.on.folder.fill"
        case .manage:
            return "wrench.and.screwdriver.fill"
        case .progress:
            return "chart.bar.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .myTraining:
            return "Start or continue assigned courses, lessons, and checkoffs."
        case .completed:
            return "Review completed courses and completion dates."
        case .create:
            return "Build a new course with modules, media, testing, and assignments."
        case .manage:
            return "Review evaluations and course tools based on your permissions."
        case .progress:
            return "See completion, overdue work, checkoffs, and roster status."
        }
    }
}

private struct TrainingHomeActionButton: View {
    let section: TrainingHomeSection
    var badgeText: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Text(section.emoji)
                .font(.system(size: 32))
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(section.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if let badgeText {
                Text(badgeText)
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct TrainingHeaderStat: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var isWarning = false
}

private struct TrainingScreenHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var isRefreshing = false
    var stats: [TrainingHeaderStat] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                AppDashboardIcon(systemImage: systemImage, size: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)

                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                if isRefreshing {
                    ProgressView()
                        .tint(AppTheme.gold)
                }
            }

            if !stats.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(stats) { stat in
                            HStack(spacing: 6) {
                                Text(stat.value)
                                    .font(.caption.monospacedDigit().bold())
                                    .foregroundStyle(stat.isWarning ? .orange : AppTheme.gold)

                                Text(stat.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.09))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(AppTheme.navy)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

private struct TrainingProgressFiltersView: View {
    private enum StatusFilter: String, CaseIterable, Identifiable {
        case all
        case overdue
        case inProgress
        case complete

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .overdue: return "Overdue"
            case .inProgress: return "In Progress"
            case .complete: return "Complete"
            }
        }
    }

    @State private var status: StatusFilter = .all
    @State private var station = TrainingTargetStation.station1
    @State private var role: AssignTrainingTargetRole = .memberVolunteer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.headline)
                .foregroundStyle(.white)

            Picker("Status", selection: $status) {
                ForEach(StatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Picker("Station", selection: $station) {
                    ForEach(TrainingTargetStation.allCases) { station in
                        Text(station.displayName).tag(station)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)

                Picker("Role", selection: $role) {
                    ForEach(AssignTrainingTargetRole.allCases) { role in
                        Text(role.displayName).tag(role)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
            }
        }
        .trainingConsoleCard()
    }
}

private enum TrainingTargetStation: String, CaseIterable, Identifiable {
    case station1 = "Station 1"
    case station2 = "Station 2"
    case station3 = "Station 3"
    case station4 = "Station 4"
    case station5 = "Station 5"

    var id: String { rawValue }
    var displayName: String { rawValue }

    static func allowedStations(for viewer: TrainingViewer?) -> [TrainingTargetStation] {
        guard let viewer else {
            return TrainingTargetStation.allCases
        }

        if viewer.canAssignDepartmentWide {
            return TrainingTargetStation.allCases
        }

        let display = StationMapper.displayName(from: viewer.company)
        return TrainingTargetStation.allCases.filter { $0.displayName == display }
    }
}

private enum TrainingAssignmentAudience: String, CaseIterable, Identifiable {
    case allUsers
    case role
    case station
    case individuals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allUsers: return "All"
        case .role: return "Role"
        case .station: return "Station"
        case .individuals: return "People"
        }
    }
}

private enum TrainingToolDestination: String, Identifiable {
    case create
    case assign
    case evaluate
    case progress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .create:
            return "Create Training"
        case .assign:
            return "Assign Training"
        case .evaluate:
            return "Evaluate JPRs"
        case .progress:
            return "Training Roster"
        }
    }

    var emoji: String {
        switch self {
        case .create:
            return "🧱"
        case .assign:
            return "📨"
        case .evaluate:
            return "✅"
        case .progress:
            return "📈"
        }
    }
}

private struct TrainingDraftModule: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var contentTypes: Set<TrainingDraftContentType>
    var practicalSkillCount: Int
    var videoTitle = ""
    var videoUrl = ""
    var imageTitle = ""
    var imageUrl = ""
    var documentTitle = ""
    var documentUrl = ""
    var quizPrompt = ""
    var practicalTitle = ""
    var practicalInstructions = ""
    var practicalScenarios: [TrainingDraftPracticalScenario] = []
}

private extension TrainingDraftModule {
    func trimmedOrNil(_ keyPath: KeyPath<TrainingDraftModule, String>) -> String? {
        let value = self[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private struct TrainingStandardVideo: Identifiable, Equatable {
    let id: String
    let title: String
    let url: String
    let category: String
}

private enum TrainingVideoSource: String, CaseIterable, Identifiable {
    case library
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: return "Library"
        case .custom: return "New Video"
        }
    }
}

private let trainingStandardVideos: [TrainingStandardVideo] = [
    TrainingStandardVideo(
        id: "nfpa-fire-extinguisher",
        title: "Portable Fire Extinguishers",
        url: "https://www.youtube.com/results?search_query=portable+fire+extinguisher+training",
        category: "Fireground"
    ),
    TrainingStandardVideo(
        id: "scba-basics",
        title: "SCBA Basics",
        url: "https://www.youtube.com/results?search_query=firefighter+SCBA+basics+training",
        category: "Operations"
    ),
    TrainingStandardVideo(
        id: "mayday-radio",
        title: "Mayday Radio Procedure",
        url: "https://www.youtube.com/results?search_query=firefighter+mayday+radio+procedure+training",
        category: "Safety"
    )
]

private enum TrainingDraftContentType: String, CaseIterable, Identifiable, Hashable {
    case video
    case image
    case document
    case quiz
    case practical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .video: return "Video"
        case .image: return "Image"
        case .document: return "Document"
        case .quiz: return "Quiz"
        case .practical: return "Practical Evaluation"
        }
    }

    var systemImage: String {
        switch self {
        case .video: return "play.rectangle.fill"
        case .image: return "photo.fill"
        case .document: return "doc.text.fill"
        case .quiz: return "checklist.checked"
        case .practical: return "figure.strengthtraining.traditional"
        }
    }

    var addTitle: String {
        switch self {
        case .video: return "Add Video"
        case .image: return "Add Image"
        case .document: return "Add Document"
        case .quiz: return "Add Quiz"
        case .practical: return "Add Practical Evaluation"
        }
    }

    var removeTitle: String {
        switch self {
        case .video: return "Remove Video"
        case .image: return "Remove Image"
        case .document: return "Remove Document"
        case .quiz: return "Remove Quiz"
        case .practical: return "Remove Practical Evaluation"
        }
    }

    var detail: String {
        switch self {
        case .video:
            return "Add a video title and URL."
        case .image:
            return "Add an image title and URL."
        case .document:
            return "Add a document title and URL."
        case .quiz:
            return "Add a quiz prompt with true/false answers."
        case .practical:
            return "Add evaluator checkoff title and instructions."
        }
    }
}

private struct TrainingDraftModuleCard: View {
    @Binding var module: TrainingDraftModule
    @State private var videoSource: TrainingVideoSource = .library
    @State private var selectedLibraryVideoId = trainingStandardVideos.first?.id ?? ""
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var isDocumentImporterPresented = false
    @State private var isUploading = false
    @State private var uploadMessage: String?
    @State private var uploadError: String?
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.gold)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Module title", text: $module.title)
                        .textInputAutocapitalization(.words)
                        .font(.headline)
                        .foregroundStyle(.white)

                    contentTypeSummary
                }

                Spacer()

                contentTypeMenu
            }

            Divider()
                .overlay(Color.white.opacity(0.12))

            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    contentFields

                    if isUploading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("Uploading…")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }

                    if let uploadMessage {
                        Text(uploadMessage)
                            .font(.caption)
                            .foregroundStyle(AppTheme.gold)
                    }

                    if let uploadError {
                        Text(uploadError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("Details")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
            }
            .tint(AppTheme.gold)
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .fileImporter(
            isPresented: $isDocumentImporterPresented,
            allowedContentTypes: Self.documentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleDocumentSelection(result)
        }
        .onChange(of: selectedVideoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await uploadPickerItem(
                    newItem,
                    fallbackFileName: "training-video-\(UUID().uuidString).mov",
                    mimeType: "video/quicktime"
                ) { file in
                    module.videoTitle = module.videoTitle.isEmpty ? file.fileName : module.videoTitle
                    module.videoUrl = file.filePath
                    videoSource = .custom
                }
                selectedVideoItem = nil
            }
        }
        .onChange(of: selectedImageItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await uploadPickerItem(
                    newItem,
                    fallbackFileName: "training-image-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg"
                ) { file in
                    module.imageTitle = module.imageTitle.isEmpty ? file.fileName : module.imageTitle
                    module.imageUrl = file.filePath
                }
                selectedImageItem = nil
            }
        }
    }

    private var contentTypeMenu: some View {
        Menu {
            ForEach(TrainingDraftContentType.allCases) { type in
                Button {
                    toggle(type)
                } label: {
                    Label(
                        module.contentTypes.contains(type) ? type.removeTitle : type.addTitle,
                        systemImage: module.contentTypes.contains(type) ? "minus.circle" : type.systemImage
                    )
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(AppTheme.gold)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .menuOrder(.fixed)
    }

    @ViewBuilder
    private var contentTypeSummary: some View {
        if module.contentTypes.isEmpty {
            Text("No content selected")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(module.contentTypes.sorted { $0.title < $1.title }) { type in
                        Label(type.title, systemImage: type.systemImage)
                            .font(.caption2.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(AppTheme.gold)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contentFields: some View {
        if module.contentTypes.contains(.video) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Video Source", selection: $videoSource) {
                    ForEach(TrainingVideoSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: videoSource) { _, newValue in
                    if newValue == .library {
                        applySelectedLibraryVideo()
                    }
                }

                if videoSource == .library {
                    Picker("Standard Video", selection: $selectedLibraryVideoId) {
                        ForEach(trainingStandardVideos) { video in
                            Text("\(video.category): \(video.title)").tag(video.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .onChange(of: selectedLibraryVideoId) { _, _ in
                        applySelectedLibraryVideo()
                    }

                    if let selectedVideo {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedVideo.title)
                                .font(.caption.bold())
                                .foregroundStyle(.white)

                            Text(selectedVideo.url)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(2)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                } else {
                    contentTextField("Video title", text: $module.videoTitle)
                    contentTextField("Video URL", text: $module.videoUrl, keyboard: .URL)
                }

                PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                    Label("Upload Video From Device", systemImage: "video.badge.plus")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold)
                }
                .buttonStyle(.plain)
                .disabled(isUploading)
            }
            .onAppear {
                if module.videoTitle.isEmpty, module.videoUrl.isEmpty {
                    applySelectedLibraryVideo()
                } else if !trainingStandardVideos.contains(where: { $0.url == module.videoUrl }) {
                    videoSource = .custom
                }
            }
        }

        if module.contentTypes.contains(.image) {
            contentTextField("Image title", text: $module.imageTitle)
            contentTextField("Image URL", text: $module.imageUrl, keyboard: .URL)

            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                Label("Upload Photo From Device", systemImage: "photo.badge.plus")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.gold)
            }
            .buttonStyle(.plain)
            .disabled(isUploading)
        }

        if module.contentTypes.contains(.document) {
            contentTextField("Document title", text: $module.documentTitle)
            contentTextField("Document URL", text: $module.documentUrl, keyboard: .URL)

            Button {
                isDocumentImporterPresented = true
            } label: {
                Label("Upload PowerPoint / File", systemImage: "doc.badge.plus")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.gold)
            }
            .buttonStyle(.plain)
            .disabled(isUploading)
        }

        if module.contentTypes.contains(.quiz) {
            contentTextField("Quiz prompt", text: $module.quizPrompt)
        }

        if module.contentTypes.contains(.practical) {
            contentTextField("Practical evaluation title", text: $module.practicalTitle)
            TextField("Evaluator instructions", text: $module.practicalInstructions, axis: .vertical)
                .lineLimit(3...6)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.white)

            Stepper(
                value: $module.practicalSkillCount,
                in: 1...20
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Practical evaluations")
                        .font(.caption.bold())
                        .foregroundStyle(.white)

                    Text("\(module.practicalSkillCount) hands-on checkoff\(module.practicalSkillCount == 1 ? "" : "s") for an instructor/evaluator to pass or fail")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(AppTheme.gold)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Testing Scenarios / JPRs")
                        .font(.caption.bold())
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        module.practicalScenarios.append(
                            TrainingDraftPracticalScenario(
                                title: "Scenario \(module.practicalScenarios.count + 1)",
                                instructions: ""
                            )
                        )
                        module.practicalSkillCount = max(1, module.practicalScenarios.count)
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.gold)
                    }
                    .buttonStyle(.plain)
                }

                if module.practicalScenarios.isEmpty {
                    Text("Add scenarios for instructor pass/fail checkoffs.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                }

                ForEach($module.practicalScenarios) { $scenario in
                    VStack(alignment: .leading, spacing: 8) {
                        contentTextField("Scenario / JPR title", text: $scenario.title)

                        TextField("Scenario instructions", text: $scenario.instructions, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)

                        Button(role: .destructive) {
                            module.practicalScenarios.removeAll { $0.id == scenario.id }
                            module.practicalSkillCount = module.practicalScenarios.count
                        } label: {
                            Label("Delete Scenario", systemImage: "trash.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func contentTextField(
        _ placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(keyboard == .URL ? .never : .sentences)
            .autocorrectionDisabled(keyboard == .URL)
            .padding(10)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(.white)
    }

    private var selectedVideo: TrainingStandardVideo? {
        trainingStandardVideos.first { $0.id == selectedLibraryVideoId }
    }

    private func applySelectedLibraryVideo() {
        guard let selectedVideo else { return }
        module.videoTitle = selectedVideo.title
        module.videoUrl = selectedVideo.url
    }

    private func toggle(_ type: TrainingDraftContentType) {
        if module.contentTypes.contains(type) {
            module.contentTypes.remove(type)
            if type == .practical {
                module.practicalSkillCount = 0
                module.practicalScenarios.removeAll()
            }
        } else {
            module.contentTypes.insert(type)
            if type == .practical && module.practicalSkillCount == 0 {
                module.practicalSkillCount = 1
                module.practicalScenarios = [
                    TrainingDraftPracticalScenario(title: "Scenario 1", instructions: "")
                ]
            }
        }
    }

    private static var documentTypes: [UTType] {
        [
            .pdf,
            .movie,
            .image,
            UTType(filenameExtension: "ppt"),
            UTType(filenameExtension: "pptx"),
            UTType(filenameExtension: "doc"),
            UTType(filenameExtension: "docx")
        ].compactMap { $0 }
    }

    private func uploadPickerItem(
        _ item: PhotosPickerItem,
        fallbackFileName: String,
        mimeType: String,
        apply: @escaping (TrainingUploadedFile) -> Void
    ) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                uploadError = "Unable to read selected file."
                return
            }

            await uploadFile(data: data, fileName: fallbackFileName, mimeType: mimeType, apply: apply)
        } catch {
            uploadError = error.localizedDescription
        }
    }

    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            Task {
                let canAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if canAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let data = try Data(contentsOf: url)
                    let fileName = url.lastPathComponent
                    let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"

                    await uploadFile(data: data, fileName: fileName, mimeType: mimeType) { file in
                        module.documentTitle = module.documentTitle.isEmpty ? file.fileName : module.documentTitle
                        module.documentUrl = file.filePath
                    }
                } catch {
                    uploadError = error.localizedDescription
                }
            }
        case .failure(let error):
            uploadError = error.localizedDescription
        }
    }

    private func uploadFile(
        data: Data,
        fileName: String,
        mimeType: String,
        apply: @escaping (TrainingUploadedFile) -> Void
    ) async {
        isUploading = true
        uploadMessage = nil
        uploadError = nil

        defer {
            isUploading = false
        }

        do {
            let response = try await APIClient.shared.uploadTrainingContent(
                data: data,
                fileName: fileName,
                mimeType: mimeType
            )

            guard response.success, let file = response.file else {
                uploadError = response.error ?? "Upload failed."
                return
            }

            apply(file)
            uploadMessage = "Uploaded \(file.fileName)"
        } catch {
            uploadError = error.localizedDescription
        }
    }
}

private struct TrainingToolDestinationView: View {
    let destination: TrainingToolDestination
    let viewer: TrainingViewer?
    let scope: TrainingScope?
    let summary: TrainingSummary?
    let pendingEvaluations: [PendingTrainingEvaluation]
    let managedMembers: [ManagedTrainingMember]

    var body: some View {
        AppScreen(title: destination.title) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    switch destination {
                    case .create:
                        CreateTrainingToolView(
                            viewer: viewer,
                            scope: scope,
                            managedMembers: managedMembers
                        )

                    case .assign:
                        AssignTrainingToolView(
                            viewer: viewer,
                            scope: scope,
                            managedMembers: managedMembers
                        )

                    case .evaluate:
                        evaluationsContent

                    case .progress:
                        managedMembersContent

                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(destination.emoji)
                .font(.system(size: 38))
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                Text(destination.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Training tools use the shared backend and will expand as the training/JPR system grows.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var createTrainingContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Create Training")

            TrainingWorkflowCard(
                emoji: "📝",
                title: "Course Setup",
                message: "Start with the course title, description, category, and whether it is a draft or ready to publish.",
                status: "Step 1"
            )

            TrainingWorkflowCard(
                emoji: "📚",
                title: "Curriculum",
                message: "Build modules, lessons, videos, documents, objectives, quizzes, and practical skills.",
                status: "Step 2"
            )

            TrainingWorkflowCard(
                emoji: "✅",
                title: "JPR / Skills",
                message: "Add skill steps, safety-critical items, evaluator notes, and pass/fail requirements.",
                status: "Step 3"
            )

            TrainingWorkflowCard(
                emoji: "📨",
                title: "Publish & Assign",
                message: "Release the training and send it to members, roles, groups, stations, or direct reports.",
                status: "Step 4"
            )

            emptyStatusCard(
                title: "Write actions need API endpoints",
                message: "The app can show the officer workflow now. The next backend step is adding mobile create/update endpoints that mirror the website training builder."
            )
        }
    }

    private var evaluationsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Pending Evaluations")

            if pendingEvaluations.isEmpty {
                emptyStatusCard(
                    title: "No pending evaluations",
                    message: "JPR reviews and skill checkoffs waiting for evaluation will appear here."
                )
            } else {
                ForEach(pendingEvaluations) { evaluation in
                    PendingEvaluationReviewCard(evaluation: evaluation)
                }
            }
        }
    }

    private var managedMembersContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Training Roster")

            if managedMembers.isEmpty {
                emptyStatusCard(
                    title: "No roster members",
                    message: "Members assigned to your supervision or training scope will appear here."
                )
            } else {
                ForEach(managedMembers) { member in
                    ManagedMemberProgressCard(member: member)
                }
            }
        }
    }

    private var departmentContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Training Summary")

            HStack(spacing: 10) {
                SummaryMetricCard(
                    value: "\(summary?.assignedCount ?? 0)",
                    label: "Assigned",
                    systemImage: "tray.full.fill"
                )

                SummaryMetricCard(
                    value: "\(summary?.completedCount ?? 0)",
                    label: "Done",
                    systemImage: "checkmark.seal.fill"
                )

                SummaryMetricCard(
                    value: "\(summary?.overdueCount ?? 0)",
                    label: "Overdue",
                    systemImage: "exclamationmark.triangle.fill"
                )
            }

            emptyStatusCard(
                title: "Compliance detail coming soon",
                message: "Department and station-level training compliance breakdowns will appear here as the training command tools are expanded."
            )
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
    }

    private func comingSoonCard(title: String, message: String) -> some View {
        emptyStatusCard(title: title, message: message)
    }

    private func emptyStatusCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ManagedMemberProgressCard: View {
    let member: ManagedTrainingMember

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Text("👤")
                .font(.system(size: 32))
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(member.name ?? member.email)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(member.role.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))

                if let company = member.company, !company.isEmpty {
                    Text(company.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.52))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("View")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())

                Text("Progress")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct CreateTrainingToolView: View {
    var viewer: TrainingViewer?
    var scope: TrainingScope?
    var managedMembers: [ManagedTrainingMember] = []

    private enum CreateTrainingField {
        case title
        case description
    }

    @FocusState private var focusedField: CreateTrainingField?
    @State private var title = ""
    @State private var description = ""
    @State private var publish = false
    @State private var trainingType: TrainingCourseType = .selfPaced
    @State private var allowMemberObjectiveSelfCheckoff = false
    @State private var objectiveFeedbackToMessages = false
    @State private var enableInstructorDashboard = false
    @State private var assignOnCreate = false
    @State private var audience: TrainingAssignmentAudience = .allUsers
    @State private var selectedRole: AssignTrainingTargetRole = .memberVolunteer
    @State private var selectedStation: TrainingTargetStation = .station1
    @State private var selectedMemberIds = Set<String>()
    @State private var includeFutureUsers = true
    @State private var includeDueDate = false
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var modules: [TrainingDraftModule] = [
        TrainingDraftModule(title: "Module 1", contentTypes: [.video, .image, .quiz], practicalSkillCount: 1)
    ]

    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        cleanTitle.count >= 3 && !isSubmitting && (!assignOnCreate || canSubmitInitialAssignment)
    }

    private var canAssignDepartmentWide: Bool {
        scope?.type == "DEPARTMENT"
    }

    private var allowedStations: [TrainingTargetStation] {
        TrainingTargetStation.allowedStations(for: viewer)
    }

    private var availableAudiences: [TrainingAssignmentAudience] {
        canAssignDepartmentWide ? TrainingAssignmentAudience.allCases : [.individuals]
    }

    private var visibleMembers: [ManagedTrainingMember] {
        guard let viewer, !viewer.canAssignDepartmentWide else {
            return managedMembers
        }

        let station = StationMapper.displayName(from: viewer.company)
        return managedMembers.filter { StationMapper.displayName(from: $0.company) == station }
    }

    private var canSubmitInitialAssignment: Bool {
        if audience == .individuals {
            return !selectedMemberIds.isEmpty
        }

        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create Training")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Create the course, outline modules, add content types, and plan quizzes or hands-on skill checkoffs.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            courseInfoCard
            trainingTypeCard
            moduleBuilderCard
            optionsCard
            initialAssignmentCard
            submitButton

            if let successMessage {
                resultCard(emoji: "✅", title: "Training Created", message: successMessage)
            }

            if let errorMessage {
                resultCard(emoji: "⚠️", title: "Create Failed", message: errorMessage)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .onAppear {
            normalizeAudience()
        }
        .onChange(of: viewer?.company) { _, _ in
            normalizeAudience()
        }
    }

    private var courseInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            labelRow(emoji: "📝", title: "Course Info", subtitle: "Matches the website create course form")

            TextField("Training title", text: $title)
                .focused($focusedField, equals: .title)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)

            TextField("Description", text: $description, axis: .vertical)
                .focused($focusedField, equals: .description)
                .lineLimit(4...7)
                .padding(12)
                .background(Color.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
        }
        .trainingConsoleCard()
    }


    private var trainingTypeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            labelRow(
                emoji: trainingType.emoji,
                title: "Training Type",
                subtitle: "Matches the website course type"
            )

            Picker("Training Type", selection: $trainingType) {
                ForEach(TrainingCourseType.allCases) { type in
                    Text("\(type.emoji) \(type.displayName)").tag(type)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
        .trainingConsoleCard()
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            labelRow(emoji: "⚙️", title: "Options", subtitle: "Same switches as the website")

            Toggle("Publish immediately", isOn: $publish)
                .tint(AppTheme.gold)
                .foregroundStyle(.white)

            Toggle("Allow student self-checkoff", isOn: $allowMemberObjectiveSelfCheckoff)
                .tint(AppTheme.gold)
                .foregroundStyle(.white)

            Toggle("Objective feedback to messages", isOn: $objectiveFeedbackToMessages)
                .tint(AppTheme.gold)
                .foregroundStyle(.white)

            Toggle("Enable instructor dashboard", isOn: $enableInstructorDashboard)
                .tint(AppTheme.gold)
                .foregroundStyle(.white)
        }
        .trainingConsoleCard()
    }

    private var moduleBuilderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            labelRow(
                emoji: "🧩",
                title: "Modules & Content",
                subtitle: "Videos, images, quizzes, and practical skill checkoffs"
            )

            ForEach($modules) { $module in
                VStack(alignment: .leading, spacing: 8) {
                    TrainingDraftModuleCard(module: $module)

                    Button(role: .destructive) {
                        modules.removeAll { $0.id == module.id }
                    } label: {
                        Label("Delete Module", systemImage: "trash.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(modules.count <= 1)
                    .opacity(modules.count <= 1 ? 0.4 : 1)
                }
            }

            Button {
                modules.append(
                    TrainingDraftModule(
                        title: "Module \(modules.count + 1)",
                        contentTypes: [.video],
                        practicalSkillCount: 0
                    )
                )
            } label: {
                Label("Add Module", systemImage: "plus.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.gold)
            }
            .buttonStyle(.plain)
        }
        .trainingConsoleCard()
    }

    private var initialAssignmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $assignOnCreate) {
                labelRow(
                    emoji: "🎯",
                    title: "Initial Assignment",
                    subtitle: assignOnCreate ? audienceSummary : "Optional"
                )
            }
            .tint(AppTheme.gold)

            if assignOnCreate {
                audiencePicker
                dueDatePicker
            } else if !visibleMembers.isEmpty {
                Text("\(visibleMembers.count) eligible users loaded. Turn on Initial Assignment and choose People to select individual members.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .trainingConsoleCard()
    }

    private var audiencePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Audience", selection: $audience) {
                ForEach(availableAudiences) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .tint(.white)

            switch audience {
            case .allUsers:
                Toggle("Include future users", isOn: $includeFutureUsers)
                    .tint(AppTheme.gold)
                    .foregroundStyle(.white)

            case .role:
                Picker("Role", selection: $selectedRole) {
                    ForEach(AssignTrainingTargetRole.allCases) { role in
                        Text("\(role.emoji) \(role.displayName)").tag(role)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)

            case .station:
                Picker("Station", selection: $selectedStation) {
                    ForEach(allowedStations) { station in
                        Text(station.displayName).tag(station)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)

                if !canAssignDepartmentWide {
                    Text("Volunteer officers are limited to their assigned company/station.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }

            case .individuals:
                if visibleMembers.isEmpty {
                    Text("No eligible members are available yet. Pull to refresh training or check the website user table permissions.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                } else {
                    ForEach(visibleMembers) { member in
                        Button {
                            toggleMember(member.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selectedMemberIds.contains(member.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedMemberIds.contains(member.id) ? AppTheme.gold : .white.opacity(0.55))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.name ?? member.email)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)

                                    Text("\(member.roleDisplay) • \(StationMapper.displayName(from: member.company))")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.62))
                                }

                                Spacer()
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var dueDatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Add due date", isOn: $includeDueDate)
                .tint(AppTheme.gold)
                .foregroundStyle(.white)

            if includeDueDate {
                DatePicker("Due", selection: $dueDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .tint(AppTheme.gold)
                    .foregroundStyle(.white)
            }
        }
    }

    private var submitButton: some View {
        Button {
            Task {
                await submit()
            }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text(publish ? "📣" : "🧱")
                }

                Text(isSubmitting ? "Creating…" : buttonTitle)
                    .font(.headline)

                Spacer()

                Text(publish ? "Publish" : "Draft")
                    .font(.caption.bold())
                    .opacity(0.72)
            }
            .foregroundStyle(.black)
            .padding(15)
            .frame(maxWidth: .infinity)
            .background(AppTheme.gold)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.55)
        .buttonStyle(.plain)
    }

    private var buttonTitle: String {
        publish ? "Create & Publish" : "Save Draft"
    }

    private func submit() async {
        guard canSubmit else { return }

        isSubmitting = true
        errorMessage = nil
        successMessage = nil

        let request = CreateTrainingCourseRequest(
            title: cleanTitle,
            description: cleanDescription.isEmpty ? nil : cleanDescription,
            publish: publish,
            trainingType: trainingType.rawValue,
            allowMemberObjectiveSelfCheckoff: allowMemberObjectiveSelfCheckoff,
            objectiveFeedbackToMessages: objectiveFeedbackToMessages,
            enableInstructorDashboard: enableInstructorDashboard,
            targetType: assignOnCreate ? assignmentRequest.targetType : nil,
            targetRole: assignOnCreate ? assignmentRequest.targetRole : nil,
            targetStation: assignOnCreate ? assignmentRequest.targetStation : nil,
            targetUserId: assignOnCreate ? assignmentRequest.targetUserId : nil,
            targetUserIds: assignOnCreate ? assignmentRequest.targetUserIds : nil,
            dueAt: assignOnCreate ? assignmentRequest.dueAt : nil,
            includeFutureUsers: assignOnCreate ? assignmentRequest.includeFutureUsers : nil,
            modules: modules.map { module in
                CreateTrainingCourseModule(
                    title: module.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    contentTypes: module.contentTypes.map(\.rawValue).sorted(),
                    practicalSkillCount: module.practicalSkillCount,
                    videoTitle: module.trimmedOrNil(\.videoTitle),
                    videoUrl: module.trimmedOrNil(\.videoUrl),
                    imageTitle: module.trimmedOrNil(\.imageTitle),
                    imageUrl: module.trimmedOrNil(\.imageUrl),
                    documentTitle: module.trimmedOrNil(\.documentTitle),
                    documentUrl: module.trimmedOrNil(\.documentUrl),
                    quizPrompt: module.trimmedOrNil(\.quizPrompt),
                    practicalTitle: module.trimmedOrNil(\.practicalTitle),
                    practicalInstructions: module.trimmedOrNil(\.practicalInstructions),
                    practicalScenarios: module.practicalScenarios.map { scenario in
                        TrainingDraftPracticalScenario(
                            title: scenario.title.trimmingCharacters(in: .whitespacesAndNewlines),
                            instructions: scenario.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }.filter { !$0.title.isEmpty }
                )
            }
        )

        do {
            let response = try await APIClient.shared.createTrainingCourse(request: request)

            if response.success {
                successMessage = response.message ?? "Training course created."
                title = ""
                description = ""
                publish = false
                objectiveFeedbackToMessages = false
                enableInstructorDashboard = false
                assignOnCreate = false
                audience = .allUsers
                selectedRole = .memberVolunteer
                selectedMemberIds.removeAll()
                includeFutureUsers = true
                includeDueDate = false
                modules = [
                    TrainingDraftModule(title: "Module 1", contentTypes: [.video, .image, .quiz], practicalSkillCount: 1)
                ]
            } else {
                errorMessage = response.error ?? "Unable to create training."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    private var assignmentRequest: AssignTrainingCourseRequest {
        switch audience {
        case .allUsers:
            return .allUsers(dueAt: includeDueDate ? dueDate : nil, includeFutureUsers: includeFutureUsers)
        case .role:
            return .role(targetRole: selectedRole.rawValue, dueAt: includeDueDate ? dueDate : nil)
        case .station:
            return .station(station: selectedStation.displayName, dueAt: includeDueDate ? dueDate : nil)
        case .individuals:
            return .users(userIds: Array(selectedMemberIds), dueAt: includeDueDate ? dueDate : nil)
        }
    }

    private var audienceSummary: String {
        switch audience {
        case .allUsers:
            return includeFutureUsers ? "All + Future" : "All Users"
        case .role:
            return selectedRole.displayName
        case .station:
            return selectedStation.displayName
        case .individuals:
            return selectedMemberIds.isEmpty ? "People" : "\(selectedMemberIds.count) selected"
        }
    }

    private func toggleMember(_ id: String) {
        if selectedMemberIds.contains(id) {
            selectedMemberIds.remove(id)
        } else {
            selectedMemberIds.insert(id)
        }
    }

    private func normalizeAudience() {
        if !availableAudiences.contains(audience) {
            audience = availableAudiences.first ?? .station
        }

        let stations = allowedStations
        if !stations.contains(selectedStation) {
            selectedStation = stations.first ?? .station1
        }
    }

    private func labelRow(emoji: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(emoji)
                .font(.system(size: 28))
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }

            Spacer()
        }
    }

    private func resultCard(emoji: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.system(size: 30))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct ManageTrainingLibraryView: View {
    let capabilities: TrainingCapabilities
    var viewer: TrainingViewer?
    var scope: TrainingScope?
    var managedMembers: [ManagedTrainingMember]

    @State private var courses: [MobileTrainingManageCourse] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Existing Training")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Edit drafts, published training, archived courses, assignments, and reports.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                }

                Spacer()

                Button {
                    Task {
                        await loadCourses()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline)
                        .foregroundStyle(AppTheme.gold)
                }
                .buttonStyle(.plain)
            }

            if isLoading && courses.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)

                    Text("Loading training…")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(.vertical, 8)
            } else if courses.isEmpty {
                Text(errorMessage ?? "No manageable training found yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.vertical, 4)
            } else {
                ForEach(courses) { course in
                    ManageTrainingCourseRow(
                        course: course,
                        capabilities: capabilities,
                        viewer: viewer,
                        scope: scope,
                        managedMembers: managedMembers
                    ) {
                        Task {
                            await loadCourses()
                        }
                    }
                }
            }
        }
        .trainingConsoleCard()
        .task {
            await loadCourses()
        }
    }

    private func loadCourses() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.fetchTrainingManageCourses()

            if response.success {
                courses = response.courses
            } else {
                errorMessage = response.error ?? "Unable to load training."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct ManageTrainingCourseRow: View {
    let course: MobileTrainingManageCourse
    let capabilities: TrainingCapabilities
    var viewer: TrainingViewer?
    var scope: TrainingScope?
    var managedMembers: [ManagedTrainingMember]
    var onDeleted: () -> Void

    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)

                    Text(course.detailLine)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))

                    if let description = course.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(2)
                    }
                }

                Spacer()

                Text(course.status.capitalized)
                    .font(.caption2.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(statusColor)
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                let canEditTraining = capabilities.canCreateTraining

                if canEditTraining || capabilities.canEvaluateTraining {
                    NavigationLink {
                        TrainingCourseManageEditView(
                            course: course,
                            capabilities: capabilities,
                            viewer: viewer,
                            scope: scope,
                            managedMembers: managedMembers
                        )
                    } label: {
                        TrainingInlineAction(
                            title: canEditTraining ? "Edit" : "View",
                            systemImage: canEditTraining ? "pencil" : "eye.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if canEditTraining {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        if isDeleting {
                            ProgressView()
                                .tint(.red)
                        } else {
                            TrainingInlineAction(title: "Delete", systemImage: "trash.fill", foregroundColor: .red)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .alert("Delete Training?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteCourse()
                }
            }
        } message: {
            Text("This permanently deletes \(course.title), including its modules and assignments. This cannot be undone.")
        }
    }

    private var statusIcon: String {
        switch course.status.uppercased() {
        case "PUBLISHED":
            return "checkmark.seal.fill"
        case "ARCHIVED":
            return "archivebox.fill"
        default:
            return "pencil.and.outline"
        }
    }

    private var statusColor: Color {
        switch course.status.uppercased() {
        case "PUBLISHED":
            return .green
        case "ARCHIVED":
            return .gray
        default:
            return AppTheme.gold
        }
    }

    private func deleteCourse() async {
        guard !isDeleting else { return }

        isDeleting = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.deleteTrainingCourse(courseId: course.id)

            if response.success {
                onDeleted()
            } else {
                errorMessage = response.error ?? "Unable to delete training."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isDeleting = false
    }
}

private struct TrainingInlineAction: View {
    let title: String
    let systemImage: String
    var foregroundColor: Color = .white.opacity(0.78)

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.bold())
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }
}

private struct TrainingCourseManageEditView: View {
    let course: MobileTrainingManageCourse
    let capabilities: TrainingCapabilities
    var viewer: TrainingViewer?
    var scope: TrainingScope?
    var managedMembers: [ManagedTrainingMember]

    @Environment(\.dismiss) private var dismiss

    @State private var detail: MobileTrainingCourseDetail?
    @State private var title = ""
    @State private var description = ""
    @State private var status = "DRAFT"
    @State private var trainingType: TrainingCourseType = .selfPaced
    @State private var allowMemberObjectiveSelfCheckoff = false
    @State private var objectiveFeedbackToMessages = false
    @State private var enableInstructorDashboard = false
    @State private var modules: [TrainingDraftModule] = []
    @State private var modulePendingDeletion: UUID?

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let statusOptions = ["DRAFT", "PUBLISHED", "ARCHIVED"]
    private var canEditTraining: Bool {
        capabilities.canCreateTraining
    }

    var body: some View {
        AppScreen(title: "") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    editHeader

                    if isLoading {
                        loadingCard
                    } else {
                        if canEditTraining {
                            courseFieldsCard
                            moduleEditorCard
                        } else {
                            readOnlyCourseSummaryCard
                        }
                        assignedUsersCard
                        if capabilities.canAssignTraining {
                            AssignTrainingToolView(
                                viewer: viewer,
                                scope: scope,
                                managedMembers: managedMembers,
                                lockedCourseId: course.id,
                                lockedCourseTitle: title.isEmpty ? course.title : title
                            )
                        }
                        if canEditTraining {
                            saveButton
                        }
                    }

                    if let successMessage {
                        statusCard(emoji: "✅", title: "Saved", message: successMessage)
                    }

                    if let errorMessage {
                        statusCard(emoji: "⚠️", title: "Manage Training", message: errorMessage)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .refreshable {
                await loadDetail()
            }
        }
        .task {
            await loadDetail()
        }
    }

    private var editHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("🛠️")
                .font(.system(size: 44))
                .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text("Edit Training")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("Course details, modules, assignments, and enrolled users.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()
        }
        .trainingConsoleCard()
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)

            Text("Loading course…")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
        .trainingConsoleCard()
    }

    private var readOnlyCourseSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Course Details")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text(title.isEmpty ? course.title : title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                if !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }

            Text("Editing, assignment, and deletion tools appear here only when your website permissions allow those actions.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .trainingConsoleCard()
    }

    private var courseFieldsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Course Details")
                .font(.headline)
                .foregroundStyle(.white)

            TextField("Title", text: $title)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)

            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(4...8)
                .padding(12)
                .background(Color.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)

            Picker("Status", selection: $status) {
                ForEach(statusOptions, id: \.self) { status in
                    Text(status.replacingOccurrences(of: "_", with: " ").capitalized).tag(status)
                }
            }
            .pickerStyle(.segmented)

            Picker("Training Type", selection: $trainingType) {
                ForEach(TrainingCourseType.allCases) { type in
                    Text("\(type.emoji) \(type.displayName)").tag(type)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            Toggle("Allow student self-checkoff", isOn: $allowMemberObjectiveSelfCheckoff)
                .tint(AppTheme.gold)
                .foregroundStyle(.white)

            Toggle("Objective feedback to messages", isOn: $objectiveFeedbackToMessages)
                .tint(AppTheme.gold)
                .foregroundStyle(.white)

            Toggle("Enable instructor dashboard", isOn: $enableInstructorDashboard)
                .tint(AppTheme.gold)
                .foregroundStyle(.white)
        }
        .trainingConsoleCard()
    }

    private var moduleEditorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Modules")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Add, edit, or delete module outlines.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                }

                Spacer()

                Button {
                    modules.append(
                        TrainingDraftModule(
                            title: "Module \(modules.count + 1)",
                            contentTypes: [.video],
                            practicalSkillCount: 0
                        )
                    )
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold)
                }
                .buttonStyle(.plain)
            }

            ForEach($modules) { $module in
                VStack(alignment: .leading, spacing: 8) {
                    TrainingDraftModuleCard(module: $module)

                    Button(role: .destructive) {
                        modulePendingDeletion = module.id
                    } label: {
                        Label("Delete Module", systemImage: "trash.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(modules.count <= 1)
                    .opacity(modules.count <= 1 ? 0.4 : 1)
                }
            }
        }
        .trainingConsoleCard()
        .confirmationDialog(
            "Delete this module?",
            isPresented: Binding(
                get: { modulePendingDeletion != nil },
                set: { if !$0 { modulePendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Module", role: .destructive) {
                if let modulePendingDeletion {
                    modules.removeAll { $0.id == modulePendingDeletion }
                }
                modulePendingDeletion = nil
            }

            Button("Cancel", role: .cancel) {
                modulePendingDeletion = nil
            }
        } message: {
            Text("This removes the module and its content from the draft. Changes are applied when you save.")
        }
    }

    private var assignedUsersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Assignments")
                .font(.headline)
                .foregroundStyle(.white)

            let assignments = detail?.assignments ?? []

            if assignments.isEmpty {
                Text("No users, roles, or stations are assigned yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                ForEach(assignments) { assignment in
                    HStack(alignment: .top, spacing: 10) {
                        Text(assignmentEmoji(assignment))
                            .font(.title3)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(assignmentTitle(assignment))
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)

                            if let dueAt = assignment.dueAt {
                                Text("Due \(dueAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                        }

                        Spacer()
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .trainingConsoleCard()
    }

    private var saveButton: some View {
        Button {
            Task {
                await saveCourse()
            }
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text("💾")
                }

                Text(isSaving ? "Saving…" : "Save Changes")
                    .font(.headline)

                Spacer()
            }
            .foregroundStyle(.black)
            .padding(15)
            .frame(maxWidth: .infinity)
            .background(AppTheme.gold)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || modules.isEmpty)
        .opacity(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || modules.isEmpty ? 0.55 : 1)
    }

    private func statusCard(emoji: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.system(size: 30))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .trainingConsoleCard()
    }

    private func assignmentEmoji(_ assignment: TrainingCourseAssignmentDetail) -> String {
        switch assignment.targetType.uppercased() {
        case "ROLE":
            return "👥"
        case "USER":
            return "👤"
        default:
            return "🎯"
        }
    }

    private func assignmentTitle(_ assignment: TrainingCourseAssignmentDetail) -> String {
        if let user = assignment.targetUser {
            return user.name ?? user.email ?? "Assigned member"
        }

        if let role = assignment.targetRole {
            return role.replacingOccurrences(of: "_", with: " ").capitalized
        }

        return assignment.targetType.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func loadDetail() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.fetchTrainingCourseDetail(courseId: course.id)

            guard response.success, let courseDetail = response.course else {
                throw APIClient.APIError.serverError(
                    statusCode: 500,
                    message: response.error ?? "Course detail was not returned."
                )
            }

            detail = courseDetail
            title = courseDetail.title
            description = courseDetail.description ?? ""
            status = courseDetail.status
            trainingType = TrainingCourseType(rawValue: courseDetail.trainingType ?? "") ?? .selfPaced
            allowMemberObjectiveSelfCheckoff = courseDetail.allowMemberObjectiveSelfCheckoff ?? false
            objectiveFeedbackToMessages = courseDetail.objectiveFeedbackToMessages ?? false
            enableInstructorDashboard = courseDetail.enableInstructorDashboard ?? false
            modules = courseDetail.modules.map(Self.draftModule(from:))

            if modules.isEmpty {
                modules = [
                    TrainingDraftModule(title: "Module 1", contentTypes: [.video], practicalSkillCount: 0)
                ]
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func saveCourse() async {
        guard !isSaving else { return }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        let request = UpdateTrainingCourseRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            trainingType: trainingType.rawValue,
            allowMemberObjectiveSelfCheckoff: allowMemberObjectiveSelfCheckoff,
            objectiveFeedbackToMessages: objectiveFeedbackToMessages,
            enableInstructorDashboard: enableInstructorDashboard,
            modules: modules.map { module in
                CreateTrainingCourseModule(
                    title: module.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    contentTypes: module.contentTypes.map(\.rawValue).sorted(),
                    practicalSkillCount: module.practicalSkillCount,
                    videoTitle: module.trimmedOrNil(\.videoTitle),
                    videoUrl: module.trimmedOrNil(\.videoUrl),
                    imageTitle: module.trimmedOrNil(\.imageTitle),
                    imageUrl: module.trimmedOrNil(\.imageUrl),
                    documentTitle: module.trimmedOrNil(\.documentTitle),
                    documentUrl: module.trimmedOrNil(\.documentUrl),
                    quizPrompt: module.trimmedOrNil(\.quizPrompt),
                    practicalTitle: module.trimmedOrNil(\.practicalTitle),
                    practicalInstructions: module.trimmedOrNil(\.practicalInstructions),
                    practicalScenarios: module.practicalScenarios.map { scenario in
                        TrainingDraftPracticalScenario(
                            title: scenario.title.trimmingCharacters(in: .whitespacesAndNewlines),
                            instructions: scenario.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }.filter { !$0.title.isEmpty }
                )
            }
        )

        do {
            let response = try await APIClient.shared.updateTrainingCourse(
                courseId: course.id,
                request: request
            )

            if response.success {
                successMessage = response.message ?? "Training course updated."
                await loadDetail()
            } else {
                errorMessage = response.error ?? "Unable to update training."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private static func draftModule(from module: TrainingModuleDetail) -> TrainingDraftModule {
        var contentTypes = Set<TrainingDraftContentType>()

        for lesson in module.lessons {
            switch lesson.type?.uppercased() {
            case "VIDEO":
                contentTypes.insert(.video)
            case "QUIZ":
                contentTypes.insert(.quiz)
            case "FILE":
                if lesson.fileName?.localizedCaseInsensitiveContains("image") == true {
                    contentTypes.insert(.image)
                } else {
                    contentTypes.insert(.document)
                }
            default:
                break
            }
        }

        let practicalCount = module.objectives.filter {
            $0.objectiveType.uppercased() == "PRACTICAL" || $0.jprEnabled
        }.count

        if practicalCount > 0 {
            contentTypes.insert(.practical)
        }

        var draft = TrainingDraftModule(
            title: module.title,
            contentTypes: contentTypes.isEmpty ? [.video] : contentTypes,
            practicalSkillCount: practicalCount
        )

        if let videoLesson = module.lessons.first(where: { $0.type?.uppercased() == "VIDEO" }) {
            draft.videoTitle = videoLesson.title
            draft.videoUrl = videoLesson.videoUrl ?? ""
        }

        if let imageLesson = module.lessons.first(where: {
            $0.type?.uppercased() == "FILE" &&
                ($0.fileName?.localizedCaseInsensitiveContains("image") == true ||
                 $0.title.localizedCaseInsensitiveContains("image"))
        }) {
            draft.imageTitle = imageLesson.title
            draft.imageUrl = imageLesson.filePath ?? ""
        }

        if let documentLesson = module.lessons.first(where: {
            $0.type?.uppercased() == "FILE" &&
                $0.id != module.lessons.first(where: {
                    $0.type?.uppercased() == "FILE" &&
                        ($0.fileName?.localizedCaseInsensitiveContains("image") == true ||
                         $0.title.localizedCaseInsensitiveContains("image"))
                })?.id
        }) {
            draft.documentTitle = documentLesson.title
            draft.documentUrl = documentLesson.filePath ?? ""
        }

        if let quizLesson = module.lessons.first(where: { $0.type?.uppercased() == "QUIZ" }) {
            draft.quizPrompt = quizLesson.quiz?.firstQuestionPrompt ?? ""
        }

        let practicalObjectives = module.objectives.filter {
            $0.objectiveType.uppercased() == "PRACTICAL" || $0.jprEnabled
        }

        if let practicalObjective = practicalObjectives.first {
            draft.practicalTitle = practicalObjective.title
            draft.practicalInstructions = practicalObjective.instructions ?? ""
        }

        draft.practicalScenarios = practicalObjectives.map { objective in
            TrainingDraftPracticalScenario(
                title: objective.title,
                instructions: objective.instructions ?? objective.jprs.first?.description ?? ""
            )
        }

        return draft
    }
}

private struct AssignTrainingToolView: View {
    var viewer: TrainingViewer?
    var scope: TrainingScope?
    var managedMembers: [ManagedTrainingMember] = []
    var lockedCourseId: String?
    var lockedCourseTitle: String?

    @State private var courses: [MobileTrainingManageCourse] = []
    @State private var selectedCourseId = ""
    @State private var audience: TrainingAssignmentAudience = .allUsers
    @State private var selectedRole: AssignTrainingTargetRole = .memberVolunteer
    @State private var selectedStation: TrainingTargetStation = .station1
    @State private var selectedMemberIds = Set<String>()
    @State private var includeFutureUsers = true
    @State private var includeDueDate = false
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var selectedCourse: MobileTrainingManageCourse? {
        courses.first { $0.id == selectedCourseId }
    }

    private var canAssignDepartmentWide: Bool {
        scope?.type == "DEPARTMENT"
    }

    private var allowedStations: [TrainingTargetStation] {
        TrainingTargetStation.allowedStations(for: viewer)
    }

    private var availableAudiences: [TrainingAssignmentAudience] {
        canAssignDepartmentWide ? TrainingAssignmentAudience.allCases : [.individuals]
    }

    private var visibleMembers: [ManagedTrainingMember] {
        guard let viewer, !viewer.canAssignDepartmentWide else {
            return managedMembers
        }

        let station = StationMapper.displayName(from: viewer.company)
        return managedMembers.filter { StationMapper.displayName(from: $0.company) == station }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Assignments")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Assign published training by role, station, or individual members. Department-wide assignment is available to HQ and instructors.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            if isLoading {
                loadingCard
            } else if courses.isEmpty && lockedCourseId == nil {
                emptyCard
            } else {
                coursePickerCard
                audiencePickerCard
                dueDateCard
                submitButton
            }

            if let successMessage {
                statusCard(emoji: "✅", title: "Assignment Sent", message: successMessage)
            }

            if let errorMessage {
                statusCard(emoji: "⚠️", title: "Assignment Failed", message: errorMessage)
            }
        }
        .task {
            normalizeAudience()
            await loadCourses()
        }
        .onChange(of: viewer?.company) { _, _ in
            normalizeAudience()
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)

            Text("Loading published courses…")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyCard: some View {
        statusCard(
            emoji: "📭",
            title: "No Published Courses",
            message: "Only published courses can be assigned from the app. Publish a course first."
        )
    }

    private var coursePickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            labelHeader(emoji: "📚", title: "Course", subtitle: "Choose the training to assign")

            if let lockedCourseTitle {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lockedCourseTitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)

                    Text("Adding assignments to this course")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Picker("Course", selection: $selectedCourseId) {
                    ForEach(courses) { course in
                        Text(course.title).tag(course.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
            }

            if lockedCourseTitle == nil, let selectedCourse {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedCourse.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)

                    Text(selectedCourse.detailLine)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))

                    if let description = selectedCourse.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(3)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .trainingConsoleCard()
    }

    private var audiencePickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            labelHeader(emoji: "🎯", title: "Audience", subtitle: audienceSubtitle)

            Picker("Audience", selection: $audience) {
                ForEach(availableAudiences) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .tint(.white)

            audienceDetail
        }
        .trainingConsoleCard()
    }

    @ViewBuilder
    private var audienceDetail: some View {
        switch audience {
        case .allUsers:
            Toggle("Include future users", isOn: $includeFutureUsers)
                .tint(AppTheme.gold)
                .foregroundStyle(.white)

        case .role:
            Picker("Role", selection: $selectedRole) {
                ForEach(AssignTrainingTargetRole.allCases) { role in
                    Text("\(role.emoji) \(role.displayName)").tag(role)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

        case .station:
            Picker("Station", selection: $selectedStation) {
                ForEach(allowedStations) { station in
                    Text(station.displayName).tag(station)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            if !canAssignDepartmentWide {
                Text("Volunteer officers are limited to their assigned company/station.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

        case .individuals:
            if visibleMembers.isEmpty {
                Text("No eligible members are available from the current mobile training response.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            } else {
                ForEach(visibleMembers) { member in
                    Button {
                        toggleMember(member.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedMemberIds.contains(member.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedMemberIds.contains(member.id) ? AppTheme.gold : .white.opacity(0.55))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name ?? member.email)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)

                                Text("\(member.roleDisplay) • \(StationMapper.displayName(from: member.company))")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.62))
                            }

                            Spacer()
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dueDateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $includeDueDate) {
                labelHeader(
                    emoji: "📅",
                    title: "Due Date",
                    subtitle: includeDueDate ? "Assignment will show a deadline" : "No due date"
                )
            }
            .tint(AppTheme.gold)

            if includeDueDate {
                DatePicker("Due", selection: $dueDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .tint(AppTheme.gold)
                    .foregroundStyle(.white)
            }
        }
        .trainingConsoleCard()
    }

    private var submitButton: some View {
        Button {
            Task {
                await submitAssignment()
            }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text("📨")
                }

                Text(isSubmitting ? "Assigning…" : "Assign Training")
                    .font(.headline)

                Spacer()

                Text(audienceSummary)
                    .font(.caption.bold())
                    .opacity(0.72)
            }
            .foregroundStyle(.black)
            .padding(15)
            .frame(maxWidth: .infinity)
            .background(AppTheme.gold)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .disabled(!canSubmitAssignment)
        .opacity(canSubmitAssignment ? 1 : 0.55)
        .buttonStyle(.plain)
    }

    private var audienceSubtitle: String {
        switch audience {
        case .allUsers:
            return "Every current user"
        case .role:
            return "By department role"
        case .station:
            return "Station 1, Station 2, etc."
        case .individuals:
            return "Selected members"
        }
    }

    private var audienceSummary: String {
        switch audience {
        case .allUsers:
            return includeFutureUsers ? "All + Future" : "All Users"
        case .role:
            return selectedRole.displayName
        case .station:
            return selectedStation.displayName
        case .individuals:
            return selectedMemberIds.isEmpty ? "People" : "\(selectedMemberIds.count) selected"
        }
    }

    private var canSubmitAssignment: Bool {
        guard !isSubmitting, !selectedCourseId.isEmpty else {
            return false
        }

        if audience == .individuals {
            return !selectedMemberIds.isEmpty
        }

        return true
    }

    private func loadCourses() async {
        guard !isLoading else { return }

        if let lockedCourseId {
            selectedCourseId = lockedCourseId
        }

        normalizeAudience()
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await APIClient.shared.fetchTrainingManageCourses()

            if response.success {
                courses = response.courses

                if let lockedCourseId {
                    selectedCourseId = lockedCourseId
                } else {
                    selectedCourseId = response.courses.first?.id ?? ""
                }

                selectedStation = allowedStations.first ?? .station1
            } else {
                errorMessage = response.error ?? "Unable to load courses."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func submitAssignment() async {
        guard canSubmitAssignment else { return }

        isSubmitting = true
        errorMessage = nil
        successMessage = nil

        do {
            let request: AssignTrainingCourseRequest

            switch audience {
            case .allUsers:
                request = .allUsers(
                    dueAt: includeDueDate ? dueDate : nil,
                    includeFutureUsers: includeFutureUsers
                )
            case .role:
                request = .role(
                    targetRole: selectedRole.rawValue,
                    dueAt: includeDueDate ? dueDate : nil
                )
            case .station:
                request = .station(
                    station: selectedStation.displayName,
                    dueAt: includeDueDate ? dueDate : nil
                )
            case .individuals:
                request = .users(
                    userIds: Array(selectedMemberIds),
                    dueAt: includeDueDate ? dueDate : nil
                )
            }

            let response = try await APIClient.shared.assignTrainingCourse(
                courseId: selectedCourseId,
                request: request
            )

            if response.success {
                successMessage = response.message ?? "Training assigned."
            } else {
                errorMessage = response.error ?? "Unable to assign training."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    private func toggleMember(_ id: String) {
        if selectedMemberIds.contains(id) {
            selectedMemberIds.remove(id)
        } else {
            selectedMemberIds.insert(id)
        }
    }

    private func normalizeAudience() {
        if !availableAudiences.contains(audience) {
            audience = availableAudiences.first ?? .station
        }

        let stations = allowedStations
        if !stations.contains(selectedStation) {
            selectedStation = stations.first ?? .station1
        }
    }

    private func labelHeader(emoji: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }

            Spacer()
        }
    }

    private func statusCard(emoji: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.system(size: 30))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private extension View {
    func trainingConsoleCard() -> some View {
        self
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
    }
}

private struct PendingEvaluationReviewCard: View {
    let evaluation: PendingTrainingEvaluation

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                Text("✅")
                    .font(.system(size: 32))
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 5) {
                    Text(evaluation.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(evaluation.courseTitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer()

                Text(evaluation.outcome.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                if let updatedAt = evaluation.updatedAt {
                    Text("Updated \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                } else {
                    Text("Awaiting review")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                Text("Open Review")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct TrainingWorkflowCard: View {
    let emoji: String
    let title: String
    let message: String
    let status: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Text(emoji)
                .font(.system(size: 30))
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    Text(status)
                        .font(.caption2.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppTheme.gold)
                        .clipShape(Capsule())
                }

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct TrainingAssignmentCard: View {
    let item: MobileTrainingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(iconEmoji)
                    .font(.system(size: 34))
                    .frame(width: 46, height: 46)

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

    private var iconEmoji: String {
        if item.isOverdue {
            return "⚠️"
        }

        switch item.progressStatus {
        case "COMPLETED":
            return "✅"
        case "IN_PROGRESS":
            return "▶️"
        default:
            return "📚"
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

private struct TrainingCompletedCard: View {
    let item: MobileTrainingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("✅")
                    .font(.system(size: 30))
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(item.detailLine)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.42))
                    .padding(.top, 5)
            }

            HStack(spacing: 10) {
                Label(completionText, systemImage: "calendar.badge.checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.gold)

                Spacer()

                if item.practicalObjectiveCount > 0 {
                    Label("\(item.practicalObjectiveCount) practical", systemImage: "signature")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
        }
        .padding(15)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var completionText: String {
        if let completedAt = item.completedAt {
            return "Completed \(completedAt.formatted(date: .abbreviated, time: .omitted))"
        }

        return "Completed"
    }
}

private struct SummaryMetricCard: View {
    let value: String
    let label: String
    let systemImage: String

    private var emoji: String {
        switch systemImage {
        case "tray.full.fill":
            return "📥"
        case "clock.fill":
            return "⏱️"
        case "checkmark.seal.fill":
            return "✅"
        case "exclamationmark.triangle.fill":
            return "⚠️"
        default:
            return "📊"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(emoji)
                .font(.system(size: 22))

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

private struct FlowLikePermissionRows: View {
    let capabilities: TrainingCapabilities

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if capabilities.canCreateTraining {
                permissionRow("Edit / delete training")
            }

            if capabilities.canAssignTraining {
                permissionRow("Assign training")
            }

            if capabilities.canEvaluateTraining {
                permissionRow("Evaluate JPRs / skills")
            }

            if capabilities.canManageReporting {
                permissionRow("View training reports")
            }

            if capabilities.canViewManagedProgress && !capabilities.canViewDepartmentProgress {
                permissionRow("Review assigned members")
            }

            if capabilities.canViewDepartmentProgress {
                permissionRow("Review department progress")
            }
        }
    }

    private func permissionRow(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text("✅")
                .font(.caption)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
        }
    }
}

private struct TrainingToolTile: View {
    let title: String
    let subtitle: String
    let emoji: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(emoji)
                        .font(.system(size: 30))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.top, 6)
                }

                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct TrainingPill: View {
    let title: String
    let systemImage: String

    private var emoji: String {
        switch systemImage {
        case "person.crop.circle.badge.checkmark":
            return "🎓"
        case "wrench.and.screwdriver.fill":
            return "🛠️"
        default:
            return "•"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(emoji)
            Text(title)
                .font(.caption.bold())
        }
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

    var isTrainingOfficerLike: Bool {
        let normalizedRole = role.uppercased()
        return normalizedRole == "OFFICER_CAREER" ||
            normalizedRole == "OFFICER_VOLUNTEER" ||
            normalizedRole == "ADMIN" ||
            normalizedRole == "CHIEF" ||
            canAssignDepartmentWide
    }

    var hasTrainingManagerRoleOrAttribute: Bool {
        let normalizedRole = role.uppercased()
        return normalizedRole == "ADMIN" ||
            normalizedRole == "CHIEF" ||
            normalizedRole == "BATTALION_CHIEF" ||
            normalizedRole == "OFFICER_CAREER" ||
            normalizedRole == "OFFICER_VOLUNTEER" ||
            canAssignDepartmentWide
    }

    var canAssignDepartmentWide: Bool {
        let normalizedRole = role.uppercased()
        if normalizedRole == "ADMIN" ||
            normalizedRole == "CHIEF" ||
            normalizedRole == "BATTALION_CHIEF" ||
            normalizedRole == "OFFICER_CAREER" {
            return true
        }

        let normalizedCompany = (company ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")

        let station = StationMapper.displayName(from: company).uppercased()
        if normalizedCompany == "FIRE_HQ" ||
            normalizedCompany == "HQ" ||
            normalizedCompany == "FIRE_HEADQUARTERS" ||
            station == "FIRE HQ" ||
            station == "FIRE HEADQUARTERS" ||
            station == "DEPARTMENT" {
            return true
        }

        return attributes?.contains { attribute in
            let normalized = attribute
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "-", with: "_")

            return normalized == "INSTRUCTOR" ||
                normalized == "LEAD_INSTRUCTOR" ||
                normalized == "TRAINING_INSTRUCTOR" ||
                normalized == "TRAINING_OFFICER" ||
                normalized.contains("INSTRUCTOR")
        } == true
    }
}

private extension TrainingCapabilities {
    func hasTrainingManagementAccess(viewer: TrainingViewer?) -> Bool {
        canCreateTraining ||
            canAssignTraining ||
            canEvaluateTraining ||
            canManageReporting ||
            canViewManagedProgress
    }
}

private extension ManagedTrainingMember {
    var roleDisplay: String {
        role
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
