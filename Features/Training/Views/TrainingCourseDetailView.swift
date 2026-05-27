import SwiftUI

struct TrainingCourseDetailView: View {
    let item: MobileTrainingItem

    @State private var detail: MobileTrainingCourseDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        AppScreen(title: "Course") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    progressCard

                    if isLoading {
                        loadingCard
                    } else if let errorMessage {
                        errorCard(errorMessage)
                    } else if let detail {
                        modulesSection(detail)
                    } else {
                        emptyCard
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

    private var displayedTitle: String {
        detail?.title ?? item.title
    }

    private var displayedDescription: String? {
        detail?.description ?? item.description
    }

    private var displayedProgressPercent: Int {
        detail?.progressPercent ?? item.progressPercent
    }

    private var displayedProgressText: String {
        detail?.progressDisplayText ?? item.progressDisplayText
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                iconBox(systemName: "book.closed.fill")

                VStack(alignment: .leading, spacing: 6) {
                    Text(displayedTitle)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .lineLimit(3)

                    Text(item.status.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.gold)
                        .clipShape(Capsule())
                }

                Spacer()
            }

            if let description = displayedDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
                .overlay(.white.opacity(0.12))

            HStack(spacing: 10) {
                if item.isOverdue {
                    Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else if let dueAt = item.dueAt {
                    Label("Due \(dueAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                        .foregroundStyle(.white.opacity(0.72))
                } else {
                    Label("No due date", systemImage: "calendar.badge.clock")
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()
            }
            .font(.caption.weight(.semibold))
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Progress")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(displayedProgressPercent)%")
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(AppTheme.gold)
            }

            ProgressView(value: Double(displayedProgressPercent), total: 100)
                .tint(AppTheme.gold)
                .background(.white.opacity(0.12))
                .clipShape(Capsule())

            Text(displayedProgressText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            if let detail {
                HStack(spacing: 10) {
                    DetailMetric(value: "\(detail.moduleCount)", label: "Modules", systemImage: "square.stack.3d.up.fill")
                    DetailMetric(value: "\(detail.lessonCount)", label: "Lessons", systemImage: "play.rectangle.fill")
                    DetailMetric(value: "\(detail.objectiveCount)", label: "Objectives", systemImage: "checklist")
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.gold)

            Text("Loading course outline...")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))

            Spacer()
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Could not load course", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            Button {
                Task { await loadDetail() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var emptyCard: some View {
        Text("No course detail available.")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func modulesSection(_ detail: MobileTrainingCourseDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Modules")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 2)

            ForEach(detail.modules) { module in
                NavigationLink {
                    TrainingModuleDetailView(module: module)
                } label: {
                    TrainingModuleRow(module: module)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func iconBox(systemName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.gold.opacity(0.18))
                .frame(width: 52, height: 52)

            Image(systemName: systemName)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(AppTheme.gold)
        }
    }

    private var cardBackground: Color {
        Color.white.opacity(0.08)
    }

    @MainActor
    private func loadDetail() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.fetchTrainingCourseDetail(courseId: item.courseId)

            guard response.success, let course = response.course else {
                throw APIClient.APIError.serverError(
                    statusCode: 500,
                    message: response.error ?? "Course detail was not returned."
                )
            }

            detail = course
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct TrainingModuleRow: View {
    let module: TrainingModuleDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.gold.opacity(0.18))
                        .frame(width: 42, height: 42)

                    Text("\(module.order)")
                        .font(.headline.monospacedDigit().bold())
                        .foregroundStyle(AppTheme.gold)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(module.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(module.progressDisplayText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 5)
            }

            ProgressView(value: Double(module.progressPercent), total: 100)
                .tint(AppTheme.gold)
                .background(.white.opacity(0.12))
                .clipShape(Capsule())

            HStack(spacing: 10) {
                Label("\(module.lessonCount)", systemImage: "play.rectangle.fill")
                Label("\(module.objectiveCount)", systemImage: "checklist")
                Spacer()
                Text("\(module.progressPercent)%")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.6))
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

private struct TrainingModuleDetailView: View {
    let module: TrainingModuleDetail

    var body: some View {
        AppScreen(title: "Module \(module.order)") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    moduleHeader

                    if !module.lessons.isEmpty {
                        sectionTitle("Lessons")
                        ForEach(module.lessons) { lesson in
                            lessonCard(lesson)
                        }
                    }

                    if !module.objectives.isEmpty {
                        sectionTitle("Objectives")
                        ForEach(module.objectives) { objective in
                            objectiveCard(objective)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var moduleHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(module.title)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(module.progressDisplayText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            ProgressView(value: Double(module.progressPercent), total: 100)
                .tint(AppTheme.gold)
                .background(.white.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(.white)
            .padding(.top, 4)
    }

    private func lessonCard(_ lesson: TrainingLessonDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(lesson.title, systemImage: "play.rectangle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                statusPill(lesson.progressStatus)
            }

            if let content = lesson.contentMd, !content.isEmpty {
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
            }

            if !lesson.skills.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(lesson.skills.prefix(6)) { skill in
                        Label(skill.title, systemImage: skill.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(skill.isCompleted ? AppTheme.gold : .white.opacity(0.66))
                    }

                    if lesson.skills.count > 6 {
                        Text("+ \(lesson.skills.count - 6) more skill(s)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func objectiveCard(_ objective: TrainingObjectiveDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Label(objective.title, systemImage: objectiveIcon(objective))
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                statusPill(objective.progressStatus)
            }

            if let instructions = objective.instructions, !instructions.isEmpty {
                Text(instructions)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
            }

            if objective.jprEnabled || !objective.jprs.isEmpty {
                Label("\(objective.jprs.count) JPR item(s)", systemImage: "signature")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.gold)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statusPill(_ status: String) -> some View {
        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption2.bold())
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(AppTheme.gold)
            .clipShape(Capsule())
    }

    private func objectiveIcon(_ objective: TrainingObjectiveDetail) -> String {
        if objective.jprEnabled || !objective.jprs.isEmpty {
            return "figure.strengthtraining.traditional"
        }

        return "checklist"
    }
}

private struct DetailMetric: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.gold)

            Text(value)
                .font(.title3.monospacedDigit().bold())
                .foregroundStyle(.white)

            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
