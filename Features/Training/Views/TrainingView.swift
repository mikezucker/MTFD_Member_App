import SwiftUI

struct TrainingView: View {
    @StateObject private var viewModel = TrainingViewModel()
    @State private var selectedTool: TrainingToolDestination?

    var body: some View {
        NavigationStack {
            AppScreen(title: "") {
                ZStack {
                    if viewModel.isLoading && !viewModel.hasCachedData {
                        loadingState
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                headerSection

                                if let capabilities = viewModel.capabilities,
                                   let scope = viewModel.response?.scope {
                                    accessExplanationSection(capabilities: capabilities, scope: scope)
                                }

                                if let errorMessage = viewModel.errorMessage, !viewModel.hasCachedData {
                                    errorState(errorMessage)
                                } else {
                                    summarySection

                                    if viewModel.myTraining.isEmpty {
                                        emptyTrainingSection
                                    } else {
                                        assignedTrainingSection
                                    }

                                    if let response = viewModel.response {
                                        officerTrainingConsoleSection(response: response)
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
        .sheet(item: $selectedTool) { destination in
            NavigationStack {
                TrainingToolDestinationView(
                    destination: destination,
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
                Text("🎓")
                    .font(.system(size: 44))
                    .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Training")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Assigned courses, JPRs, evaluations, and member progress.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(headerSubtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
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

            if capabilities.canCreateTraining ||
                capabilities.canAssignTraining ||
                capabilities.canEvaluateTraining ||
                capabilities.canManageReporting {
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
            Text("✅")
                .font(.system(size: 38))

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
    private func officerTrainingConsoleSection(response: MobileTrainingResponse) -> some View {
        let capabilities = response.capabilities

        let role = response.viewer.role.uppercased()
        let isOfficer = role == "OFFICER_CAREER" || role == "OFFICER_VOLUNTEER"

        let hasInstructorAccess =
            capabilities.canCreateTraining ||
            capabilities.canAssignTraining ||
            capabilities.canEvaluateTraining ||
            capabilities.canViewManagedProgress

        let showConsole = isOfficer || hasInstructorAccess

        if showConsole {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Officer Training Console")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Create, assign, evaluate, and track training based on your website permissions.")
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
                    if capabilities.canCreateTraining || isOfficer {
                        TrainingToolTile(
                            title: "Create Training",
                            subtitle: "Build lessons, objectives, and JPRs",
                            emoji: "🧱"
                        ) {
                            selectedTool = .create
                        }
                    }

                    if capabilities.canAssignTraining || isOfficer {
                        TrainingToolTile(
                            title: "Assign Training",
                            subtitle: "Send training to your members",
                            emoji: "📨"
                        ) {
                            print("TRAINING TOOL DEBUG: Assign Training tapped")
                            selectedTool = .assign
                        }
                    }

                    if capabilities.canEvaluateTraining || isOfficer {
                        TrainingToolTile(
                            title: "Evaluate Skills",
                            subtitle: "Review JPR checkoffs",
                            emoji: "✅"
                        ) {
                            selectedTool = .evaluate
                        }
                    }

                    if capabilities.canViewManagedProgress || isOfficer {
                        TrainingToolTile(
                            title: "Member Progress",
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
            return "Crew Progress"
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

private struct TrainingToolDestinationView: View {
    let destination: TrainingToolDestination
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
                        CreateTrainingToolView()

                    case .assign:
                        AssignTrainingToolView()

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
            sectionTitle("Managed Members")

            if managedMembers.isEmpty {
                emptyStatusCard(
                    title: "No managed members",
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
    @State private var selectedRole: AssignTrainingTargetRole = .memberVolunteer

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
        cleanTitle.count >= 3 && !isSubmitting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create Training")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Create a course shell using the same backend as the website. The course starts with Module 1. Modules, lessons, quizzes, and JPR details can still be expanded from the website.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            courseInfoCard
            trainingTypeCard
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

    private var initialAssignmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $assignOnCreate) {
                labelRow(
                    emoji: "🎯",
                    title: "Initial Assignment",
                    subtitle: assignOnCreate ? selectedRole.displayName : "Optional"
                )
            }
            .tint(AppTheme.gold)

            if assignOnCreate {
                Picker("Role", selection: $selectedRole) {
                    ForEach(AssignTrainingTargetRole.allCases) { role in
                        Text("\(role.emoji) \(role.displayName)").tag(role)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
            }
        }
        .trainingConsoleCard()
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
            targetRole: assignOnCreate ? selectedRole.rawValue : nil
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
                selectedRole = .memberVolunteer
            } else {
                errorMessage = response.error ?? "Unable to create training."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
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

private struct AssignTrainingToolView: View {
    @State private var courses: [MobileTrainingManageCourse] = []
    @State private var selectedCourseId: String = ""
    @State private var selectedRole: AssignTrainingTargetRole = .memberVolunteer
    @State private var includeDueDate = false
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var selectedCourse: MobileTrainingManageCourse? {
        courses.first { $0.id == selectedCourseId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Assign Training")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Pick a published course, choose the role audience, then send the assignment through the shared training backend.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            if isLoading {
                loadingCard
            } else if courses.isEmpty {
                emptyCard
            } else {
                coursePickerCard
                rolePickerCard
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
            await loadCourses()
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
            message: "Only published courses can be assigned from the app. Create or publish a course from the website first."
        )
    }

    private var coursePickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("📚")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Course")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Choose the training to assign")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                }

                Spacer()
            }

            Picker("Course", selection: $selectedCourseId) {
                ForEach(courses) { course in
                    Text(course.title).tag(course.id)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)

            if let selectedCourse {
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

    private var rolePickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🎯")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Audience")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("First pass supports role assignment")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                }

                Spacer()
            }

            Picker("Audience", selection: $selectedRole) {
                ForEach(AssignTrainingTargetRole.allCases) { role in
                    Text("\(role.emoji) \(role.displayName)").tag(role)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
        .trainingConsoleCard()
    }

    private var dueDateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $includeDueDate) {
                HStack(spacing: 10) {
                    Text("📅")
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Due Date")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(includeDueDate ? "Assignment will show a deadline" : "No due date")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.64))
                    }
                }
            }
            .tint(AppTheme.gold)

            if includeDueDate {
                DatePicker(
                    "Due",
                    selection: $dueDate,
                    displayedComponents: [.date]
                )
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

                Text(selectedRole.displayName)
                    .font(.caption.bold())
                    .opacity(0.72)
            }
            .foregroundStyle(.black)
            .padding(15)
            .frame(maxWidth: .infinity)
            .background(AppTheme.gold)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .disabled(isSubmitting || selectedCourseId.isEmpty)
        .opacity(isSubmitting || selectedCourseId.isEmpty ? 0.55 : 1)
        .buttonStyle(.plain)
    }

    private func loadCourses() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await APIClient.shared.fetchTrainingManageCourses()

            if response.success {
                courses = response.courses
                selectedCourseId = response.courses.first?.id ?? ""
            } else {
                errorMessage = response.error ?? "Unable to load courses."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func submitAssignment() async {
        guard !selectedCourseId.isEmpty else { return }
        guard !isSubmitting else { return }

        isSubmitting = true
        errorMessage = nil
        successMessage = nil

        do {
            let request = AssignTrainingCourseRequest.role(
                targetRole: selectedRole.rawValue,
                dueAt: includeDueDate ? dueDate : nil
            )

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
                permissionRow("Create courses")
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
}

private extension ManagedTrainingMember {
    var roleDisplay: String {
        role
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
