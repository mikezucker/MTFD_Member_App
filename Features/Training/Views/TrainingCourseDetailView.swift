import AVKit
import WebKit
import SwiftUI

struct TrainingCourseDetailView: View {
    let item: MobileTrainingItem

    @State private var detail: MobileTrainingCourseDetail?
    @State private var selectedItemID: String?
    @State private var isLoading = true
    @State private var isCompleting = false
    @State private var errorMessage: String?
    @State private var completionMessage: String?

    var body: some View {
        AppScreen(title: "") {
            VStack(spacing: 0) {
                headerCard

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if isLoading {
                            loadingCard
                        } else if let errorMessage {
                            errorCard(errorMessage)
                        } else if let detail {
                            playerBody(detail)
                        } else {
                            emptyCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .padding(.bottom, detail == nil ? 0 : 12)
                }
                .refreshable {
                    await loadDetail(preserveSelection: true)
                }

                if let detail, !playerItems(for: detail).isEmpty {
                    playerControls(detail)
                }
            }
        }
        .task {
            await loadDetail(preserveSelection: false)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                iconBox(systemName: item.progressStatus == "COMPLETED" ? "checkmark.seal.fill" : "play.circle.fill")

                VStack(alignment: .leading, spacing: 6) {
                    Text(displayedTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .allowsTightening(true)

                    HStack(spacing: 8) {
                        statusPill(displayedProgressText)

                        if item.isOverdue {
                            Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        } else if let dueAt = item.dueAt {
                            Label("Due \(dueAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.68))
                        }
                    }
                }

                Spacer()
            }

            if let displayedDescription, !displayedDescription.isEmpty {
                Text(displayedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Course Progress")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.72))

                    Spacer()

                    Text("\(displayedProgressPercent)%")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(AppTheme.gold)
                }

                ProgressView(value: Double(displayedProgressPercent), total: 100)
                    .tint(AppTheme.gold)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                DetailMetric(value: "\(detail?.moduleCount ?? item.moduleCount)", label: "Modules", systemImage: "square.stack.3d.up.fill")
                DetailMetric(value: "\(detail?.lessonCount ?? item.lessonCount)", label: "Lessons", systemImage: "play.rectangle.fill")
                DetailMetric(value: "\(detail?.objectiveCount ?? item.objectiveCount)", label: "Objectives", systemImage: "checklist")
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

    private func playerBody(_ detail: MobileTrainingCourseDetail) -> some View {
        let items = playerItems(for: detail)

        return VStack(alignment: .leading, spacing: 16) {
            if items.isEmpty {
                emptyCard
            } else if let current = currentItem(in: detail) {
                moduleProgressStrip(detail: detail, items: items, current: current)
                TrainingPlayerContentCard(item: current, courseId: item.courseId,
                    selfPaced: !["PRACTICAL_HANDS_ON", "PRACTICAL", "JPR_SKILL", "DRILL", "EMS_COMPETENCY", "CLASSROOM"].contains(detail.trainingType ?? ""),
                    onLessonComplete: { await loadDetail(preserveSelection: true) })

                if let completionMessage {
                    Label(completionMessage, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.gold)
                        .padding(.horizontal, 2)
                }

                upcomingSection(items: items, current: current)
            }
        }
    }

    private func moduleProgressStrip(
        detail: MobileTrainingCourseDetail,
        items: [TrainingPlayerItem],
        current: TrainingPlayerItem
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Module \(current.moduleOrder)")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold)

                    Text(current.moduleTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }

                Spacer()

                Text("\((items.firstIndex { $0.id == current.id } ?? 0) + 1) of \(items.count)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.white.opacity(0.68))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { playerItem in
                        Button {
                            selectedItemID = playerItem.id
                            completionMessage = nil
                        } label: {
                            VStack(spacing: 7) {
                                Image(systemName: playerItem.statusIcon)
                                    .font(.caption.bold())

                                Text("\(playerItem.sequenceNumber)")
                                    .font(.caption2.monospacedDigit().bold())
                            }
                            .foregroundStyle(playerItem.id == current.id ? AppTheme.navy : playerItem.statusColor)
                            .frame(width: 42, height: 46)
                            .background(playerItem.id == current.id ? AppTheme.gold : Color.white.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(15)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func upcomingSection(items: [TrainingPlayerItem], current: TrainingPlayerItem) -> some View {
        let nextItems = items
            .drop { $0.id != current.id }
            .dropFirst()
            .prefix(3)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Next Up")
                .font(.headline)
                .foregroundStyle(.white)

            if nextItems.isEmpty {
                Text("This is the final item in the course.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(Array(nextItems)) { playerItem in
                    Button {
                        selectedItemID = playerItem.id
                        completionMessage = nil
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: playerItem.kindIcon)
                                .foregroundStyle(AppTheme.gold)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(playerItem.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)

                                Text(playerItem.shortTypeLabel)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.42))
                        }
                        .padding(13)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func playerControls(_ detail: MobileTrainingCourseDetail) -> some View {
        let items = playerItems(for: detail)
        let current = currentItem(in: detail)
        let currentIndex = current.flatMap { current in
            items.firstIndex { $0.id == current.id }
        }
        let canGoBack = (currentIndex ?? 0) > 0
        let canGoNext = currentIndex.map { $0 < items.count - 1 } ?? false
        let canComplete = current?.canMarkComplete == true && !isCompleting

        return VStack(spacing: 10) {
            Divider()
                .overlay(.white.opacity(0.1))

            HStack(spacing: 10) {
                Button {
                    moveSelection(by: -1, in: detail)
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .disabled(!canGoBack)
                .foregroundStyle(canGoBack ? .white : .white.opacity(0.35))
                .background(Color.white.opacity(canGoBack ? 0.12 : 0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    Task {
                        await markCurrentComplete(in: detail)
                    }
                } label: {
                    if isCompleting {
                        ProgressView()
                            .tint(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        Label(current?.completeButtonTitle ?? "Mark Complete", systemImage: current?.completeButtonIcon ?? "checkmark.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .disabled(!canComplete)
                .foregroundStyle(canComplete ? .black : .white.opacity(0.45))
                .background(canComplete ? AppTheme.gold : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    moveSelection(by: 1, in: detail)
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .font(.subheadline.bold())
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .disabled(!canGoNext)
                .foregroundStyle(canGoNext ? .white : .white.opacity(0.35))
                .background(Color.white.opacity(canGoNext ? 0.12 : 0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(AppTheme.navy)
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.gold)

            Text("Loading course...")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))

            Spacer()
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                Task { await loadDetail(preserveSelection: true) }
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
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var emptyCard: some View {
        Text("No course content is available yet.")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func iconBox(systemName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.gold.opacity(0.18))
                .frame(width: 52, height: 52)

            Image(systemName: systemName)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(AppTheme.gold)
        }
    }

    private func statusPill(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.gold)
            .clipShape(Capsule())
    }

    private var cardBackground: Color {
        Color.white.opacity(0.08)
    }

    private func playerItems(for detail: MobileTrainingCourseDetail) -> [TrainingPlayerItem] {
        var sequence = 1
        var items: [TrainingPlayerItem] = []

        for module in detail.modules.sorted(by: { $0.order < $1.order }) {
            let lessons = module.lessons
                .sorted(by: { $0.order < $1.order })
                .map { lesson in
                    let item = TrainingPlayerItem(
                        id: "lesson-\(lesson.id)",
                        sourceID: lesson.id,
                        itemType: .lesson,
                        sequenceNumber: sequence,
                        moduleOrder: module.order,
                        moduleTitle: module.title,
                        title: lesson.title,
                        subtitle: lesson.typeDisplayTitle,
                        progressStatus: lesson.progressStatus,
                        completedAt: lesson.completedAt,
                        contentMd: lesson.contentMd,
                        videoURL: lesson.videoUrl != nil && lesson.videoUrl?.lowercased().hasPrefix("http") != true ? APIClient.shared.absoluteURL(from: "/api/training/media?source=lesson&sourceId=\(lesson.id)&kind=video") : APIClient.shared.absoluteURL(from: lesson.videoUrl),
                        videoFileURL: lesson.type?.uppercased() == "VIDEO" && lesson.filePath != nil ? APIClient.shared.absoluteURL(from: "/api/training/media?source=lesson&sourceId=\(lesson.id)") : nil,
                        contentURL: lesson.type?.uppercased() != "VIDEO" && lesson.filePath != nil ? APIClient.shared.absoluteURL(from: "/api/training/media?source=lesson&sourceId=\(lesson.id)") : nil,
                        contentFileName: lesson.fileName,
                        skills: lesson.skills,
                        quizPrompt: lesson.quiz?.firstQuestionPrompt,
                        jprs: [],
                        requiresInstructorSignoff: false
                    )
                    sequence += 1
                    return item
                }

            let objectives = module.objectives
                .sorted(by: { $0.order < $1.order })
                .map { objective in
                    let requiresSignoff = (objective.objectiveType.uppercased() == "PRACTICAL" || objective.jprEnabled) ||
                        detail.allowMemberObjectiveSelfCheckoff != true || ["PRACTICAL_HANDS_ON", "PRACTICAL", "JPR_SKILL", "DRILL", "EMS_COMPETENCY", "CLASSROOM"].contains(detail.trainingType ?? "")
                    let item = TrainingPlayerItem(
                        id: "objective-\(objective.id)",
                        sourceID: objective.id,
                        itemType: .objective,
                        sequenceNumber: sequence,
                        moduleOrder: module.order,
                        moduleTitle: module.title,
                        title: objective.title,
                        subtitle: objective.objectiveType.replacingOccurrences(of: "_", with: " ").capitalized,
                        progressStatus: objective.progressStatus,
                        completedAt: objective.completedAt,
                        contentMd: objective.contentMd ?? objective.instructions,
                        videoURL: APIClient.shared.absoluteURL(from: objective.videoUrl),
                        videoFileURL: objective.videoFilePath != nil ? APIClient.shared.absoluteURL(from: "/api/training/media?source=objective&sourceId=\(objective.id)&kind=video") : nil,
                        contentURL: objective.contentFilePath != nil ? APIClient.shared.absoluteURL(from: "/api/training/media?source=objective&sourceId=\(objective.id)&kind=content") : nil,
                        contentFileName: objective.contentFileName,
                        skills: [],
                        quizPrompt: nil,
                        jprs: objective.jprs,
                        requiresInstructorSignoff: requiresSignoff
                    )
                    sequence += 1
                    return item
                }

            items.append(contentsOf: lessons)
            items.append(contentsOf: objectives)
        }

        return items.filter { $0.subtitle != "Knowledge Check" } + items.filter { $0.subtitle == "Knowledge Check" }
    }

    private func currentItem(in detail: MobileTrainingCourseDetail) -> TrainingPlayerItem? {
        let items = playerItems(for: detail)

        if let selectedItemID,
           let selected = items.first(where: { $0.id == selectedItemID }) {
            return selected
        }

        return items.first { !$0.isComplete } ?? items.first
    }

    private func moveSelection(by offset: Int, in detail: MobileTrainingCourseDetail) {
        let items = playerItems(for: detail)
        guard let current = currentItem(in: detail),
              let index = items.firstIndex(where: { $0.id == current.id }) else {
            return
        }

        let nextIndex = index + offset
        guard items.indices.contains(nextIndex) else {
            return
        }

        selectedItemID = items[nextIndex].id
        completionMessage = nil
    }

    @MainActor
    private func markCurrentComplete(in detail: MobileTrainingCourseDetail) async {
        guard let current = currentItem(in: detail), current.canMarkComplete else {
            return
        }

        isCompleting = true
        errorMessage = nil
        completionMessage = nil

        let request: TrainingProgressUpdateRequest
        switch current.itemType {
        case .lesson:
            request = .completeLesson(id: current.sourceID)
        case .objective:
            request = .completeObjective(id: current.sourceID)
        }

        do {
            let response = try await APIClient.shared.updateTrainingProgress(
                courseId: item.courseId,
                request: request
            )

            guard response.success else {
                throw APIClient.APIError.serverError(
                    statusCode: 500,
                    message: response.error ?? "Training progress was not updated."
                )
            }

            completionMessage = "Saved completion."
            await loadDetail(preserveSelection: true)
        } catch {
            errorMessage = error.localizedDescription
        }

        isCompleting = false
    }

    @MainActor
    private func loadDetail(preserveSelection: Bool) async {
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
            let items = playerItems(for: course)

            if !preserveSelection ||
                selectedItemID == nil ||
                !items.contains(where: { $0.id == selectedItemID }) {
                selectedItemID = items.first { !$0.isComplete }?.id ?? items.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct TrainingPlayerContentCard: View {
    let item: TrainingPlayerItem
    let courseId: String
    let selfPaced: Bool
    let onLessonComplete: () async -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.gold.opacity(0.18))
                        .frame(width: 44, height: 44)

                    Image(systemName: item.kindIcon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(AppTheme.gold)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.shortTypeLabel)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.gold)

                Text(item.title)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

                Spacer()

                itemStatusPill
            }

            if let contentMd = item.contentMd, !contentMd.isEmpty {
                Text(.init(contentMd))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if item.itemType == .lesson && selfPaced {
                TrainingLessonActivityView(courseId: courseId, lessonId: item.sourceID, videoURL: item.videoURL ?? item.videoFileURL, onComplete: onLessonComplete)
                    .id(item.id)
            } else if let videoURL = item.videoURL ?? item.videoFileURL {
                TrainingLessonVideoView(url: videoURL, resumeSeconds: 0, onPosition: { _ in })
                    .id(item.id)
            }

            if let contentURL = item.contentURL {
                mediaPreview(url: contentURL, kind: item.mediaKind)
            }

            if !item.skills.isEmpty {
                skillsSection
            }

            if let quizPrompt = item.quizPrompt, !quizPrompt.isEmpty {
                Label(quizPrompt, systemImage: "questionmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if !item.jprs.isEmpty {
                jprSection
            } else if item.requiresInstructorSignoff {
                signoffNotice
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

    private var itemStatusPill: some View {
        Text(item.statusTitle)
            .font(.caption2.bold())
            .foregroundStyle(item.isComplete ? .black : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(item.isComplete ? AppTheme.gold : Color.white.opacity(0.14))
            .clipShape(Capsule())
    }

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Skills")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(item.skills) { skill in
                VStack(alignment: .leading, spacing: 5) {
                    Label(skill.title, systemImage: skill.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(skill.isCompleted ? AppTheme.gold : .white.opacity(0.78))

                    if let instructions = skill.instructions, !instructions.isEmpty {
                        Text(instructions)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var jprSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Practical Checkoff")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text(item.requiresInstructorSignoff ? "Instructor Sign-Off" : "Self Check")
                    .font(.caption2.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppTheme.gold)
                    .clipShape(Capsule())
            }

            ForEach(item.jprs) { jpr in
                VStack(alignment: .leading, spacing: 8) {
                    Text(jpr.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)

                    if let description = jpr.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.64))
                    }

                    ForEach(jpr.steps) { step in
                        Label(step.text, systemImage: step.safetyCritical == true ? "exclamationmark.triangle.fill" : "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(step.safetyCritical == true ? .orange : .white.opacity(0.68))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if item.requiresInstructorSignoff {
                signoffNotice
            }
        }
    }

    private var signoffNotice: some View {
        Label("This item requires an evaluator to sign off before it can be completed.", systemImage: "person.badge.shield.checkmark.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func mediaPreview(url: URL, kind: TrainingMediaKind) -> some View {
        switch kind {
        case .image:
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(AppTheme.gold)
                        .frame(maxWidth: .infinity, minHeight: 190)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                case .failure:
                    openButton(url: url, title: "Open Image", systemImage: "photo.fill")
                @unknown default:
                    EmptyView()
                }
            }
        case .video:
            TrainingLessonVideoView(url: url, resumeSeconds: 0, onPosition: { _ in })
        case .document:
            openButton(url: url, title: item.contentFileName ?? "Open Document", systemImage: "doc.text.fill")
        case .link:
            openButton(url: url, title: "Open Content", systemImage: "link")
        }
    }

    private func openButton(url: URL, title: String, systemImage: String) -> some View {
        Button {
            Task {
                if let resolved = try? await APIClient.shared.trainingMediaURL(url) { openURL(resolved) }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(AppTheme.gold)

                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.54))
            }
            .padding(13)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct TrainingPlayerItem: Identifiable {
    enum ItemType {
        case lesson
        case objective
    }

    let id: String
    let sourceID: String
    let itemType: ItemType
    let sequenceNumber: Int
    let moduleOrder: Int
    let moduleTitle: String
    let title: String
    let subtitle: String
    let progressStatus: String
    let completedAt: Date?
    let contentMd: String?
    let videoURL: URL?
    let videoFileURL: URL?
    let contentURL: URL?
    let contentFileName: String?
    let skills: [TrainingSkillDetail]
    let quizPrompt: String?
    let jprs: [TrainingJPRDetail]
    let requiresInstructorSignoff: Bool

    var isComplete: Bool {
        progressStatus == "COMPLETED" || completedAt != nil
    }

    var canMarkComplete: Bool {
        !isComplete && !requiresInstructorSignoff && itemType == .objective
    }

    var shortTypeLabel: String {
        switch itemType {
        case .lesson:
            return subtitle.isEmpty ? "Lesson" : subtitle
        case .objective:
            return requiresInstructorSignoff ? "Evaluator Checkoff" : subtitle
        }
    }

    var kindIcon: String {
        switch itemType {
        case .lesson:
            if quizPrompt != nil { return "questionmark.circle.fill" }
            if videoURL != nil || videoFileURL != nil { return "play.rectangle.fill" }
            if contentURL != nil { return "doc.text.fill" }
            return "book.closed.fill"
        case .objective:
            return requiresInstructorSignoff ? "person.badge.shield.checkmark.fill" : "checklist.checked"
        }
    }

    var statusIcon: String {
        if isComplete { return "checkmark" }
        if requiresInstructorSignoff { return "signature" }
        return kindIcon
    }

    var statusColor: Color {
        if isComplete { return AppTheme.gold }
        if requiresInstructorSignoff { return .orange }
        return .white.opacity(0.72)
    }

    var statusTitle: String {
        if isComplete { return "DONE" }
        if requiresInstructorSignoff { return "SIGN-OFF" }
        if progressStatus == "IN_PROGRESS" { return "ACTIVE" }
        return "OPEN"
    }

    var completeButtonTitle: String {
        if isComplete { return "Completed" }
        if itemType == .lesson { return subtitle == "Knowledge Check" ? "Take Test Above" : "Complete Above" }
        if requiresInstructorSignoff { return "Needs Sign-Off" }
        return "Mark Complete"
    }

    var completeButtonIcon: String {
        if requiresInstructorSignoff { return "person.badge.shield.checkmark.fill" }
        return "checkmark.circle.fill"
    }

    var mediaKind: TrainingMediaKind {
        guard let value = (contentFileName ?? contentURL?.lastPathComponent)?.lowercased() else {
            return .link
        }

        if value.hasSuffix(".png") ||
            value.hasSuffix(".jpg") ||
            value.hasSuffix(".jpeg") ||
            value.hasSuffix(".gif") ||
            value.hasSuffix(".webp") {
            return .image
        }

        if value.hasSuffix(".mp4") ||
            value.hasSuffix(".mov") ||
            value.hasSuffix(".m4v") {
            return .video
        }

        if value.hasSuffix(".pdf") ||
            value.hasSuffix(".doc") ||
            value.hasSuffix(".docx") ||
            value.hasSuffix(".ppt") ||
            value.hasSuffix(".pptx") {
            return .document
        }

        return .link
    }
}

private enum TrainingMediaKind {
    case image
    case video
    case document
    case link
}

private extension TrainingLessonDetail {
    var typeDisplayTitle: String {
        switch type?.uppercased() {
        case "VIDEO":
            return "Video Lesson"
        case "FILE":
            return "Document / Media"
        case "QUIZ":
            return "Knowledge Check"
        default:
            return "Lesson"
        }
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// One persistent player per lesson; bookmarks use the same server record as the website.
private struct TrainingLessonVideoView: View {
    let url: URL
    let resumeSeconds: Int
    let onPosition: (Int) -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var player: AVPlayer?
    @State private var observer: Any?
    @State private var error: String?

    private var isHostedPage: Bool {
        !["mp4", "mov", "m4v", "webm", "m3u8"].contains(url.pathExtension.lowercased()) && !url.path.hasPrefix("/api/")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let videoID = TrainingYouTubeVideoView.videoID(url) {
                TrainingYouTubeVideoView(videoID: videoID, resumeSeconds: resumeSeconds, onPosition: onPosition)
                    .frame(minHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text("Video supplied by its YouTube publisher. Use the player controls for captions and full screen.").font(.caption).foregroundStyle(.secondary)
            } else if isHostedPage {
                Link("Watch on video provider website", destination: url)
            } else if let player {
                VideoPlayer(player: player)
                    .frame(minHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text("Playback position saves while you watch. Use the player controls for available captions.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let error {
                Text(error).font(.caption).foregroundStyle(.orange)
            } else {
                ProgressView("Opening video…")
            }
        }
        .task(id: url) {
            guard TrainingYouTubeVideoView.videoID(url) == nil, !isHostedPage else { return }
            do {
                let mediaURL = try await APIClient.shared.trainingMediaURL(url)
                guard !Task.isCancelled else { return }
                let newPlayer = AVPlayer(url: mediaURL)
                await newPlayer.seek(to: CMTime(seconds: Double(resumeSeconds), preferredTimescale: 600))
                player = newPlayer
                observer = newPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 10, preferredTimescale: 600), queue: .main) { time in
                    if time.seconds.isFinite { onPosition(max(0, Int(time.seconds))) }
                }
            } catch { self.error = error.localizedDescription }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { savePosition(); player?.pause() }
        }
        .onDisappear {
            savePosition()
            player?.pause()
            if let observer { player?.removeTimeObserver(observer) }
            observer = nil
            player = nil
        }
    }
    private func savePosition() {
        if let seconds = player?.currentTime().seconds, seconds.isFinite { onPosition(max(0, Int(seconds))) }
    }
}

private struct TrainingLessonActivityView: View {
    let courseId: String
    let lessonId: String
    let videoURL: URL?
    let onComplete: () async -> Void
    @State private var snapshot: TrainingLessonSnapshot?
    @State private var attemptID: String?
    @State private var expiresAt: Date?
    @State private var answers: [String: Set<String>] = [:]
    @State private var result: TrainingLessonActionResponse?
    @State private var error: String?
    @State private var busy = false
    @State private var savingPosition = false
    @State private var position = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let error { Text(error).font(.subheadline).foregroundStyle(.orange) }
            if let snapshot {
                if let videoURL {
                    TrainingLessonVideoView(url: videoURL, resumeSeconds: snapshot.lastPositionSeconds) { seconds in
                        position = seconds
                        Task { await savePosition(seconds) }
                    }
                }
                if let quiz = snapshot.quiz {
                    Text("Course Test").font(.title3.bold())
                    Text("Pass mark: \(quiz.passingScorePercent)%" + (quiz.timeLimitSeconds.map { " · \(($0 + 59) / 60) minute limit" } ?? ""))
                        .font(.subheadline)
                    if let limit = quiz.attemptLimit { Text("Attempts used: \(quiz.attemptsUsed ?? 0) of \(limit). Contact your instructor if all attempts are used.").font(.caption) }
                    if quiz.passed { Label("Test passed · \(quiz.scorePercent ?? 0)%", systemImage: "checkmark.seal.fill").foregroundStyle(AppTheme.gold) }
                    if let result {
                        Text("\(result.expired == true ? "Time expired" : result.passed == true ? "Passed" : "Not passed") · \(result.scorePercent ?? 0)%\(result.passed == true ? " — result saved" : " — review the lessons and try again")")
                            .font(.subheadline.bold()).foregroundStyle(result.passed == true ? AppTheme.gold : .orange)
                    }
                    if attemptID == nil {
                        Button(quiz.passed ? "Retake Test" : "Start Test") { Task { await startTest() } }
                            .buttonStyle(.borderedProminent).tint(AppTheme.gold).disabled(busy)
                        Text("Complete the learning material before starting.").font(.caption)
                    } else {
                        if let expiresAt { Text("Submit by \(expiresAt.formatted(date: .omitted, time: .shortened)). Leaving does not stop the timer.").font(.caption) }
                        ForEach(Array(quiz.questions.enumerated()), id: \.element.id) { index, question in
                            VStack(alignment: .leading, spacing: 10) {
                                Text("\(index + 1). \(question.prompt)").font(.headline)
                                if question.type == "MULTI_CHOICE" { Text("Select all that apply.").font(.caption) }
                                ForEach(question.options) { option in
                                    Button {
                                        if question.type == "MULTI_CHOICE" {
                                            var selected = answers[question.id] ?? []
                                            if selected.contains(option.id) { selected.remove(option.id) } else { selected.insert(option.id) }
                                            answers[question.id] = selected
                                        } else { answers[question.id] = [option.id] }
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: answers[question.id]?.contains(option.id) == true ? "checkmark.circle.fill" : "circle")
                                            Text(option.text).multilineTextAlignment(.leading)
                                            Spacer(minLength: 0)
                                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                    }.buttonStyle(.bordered).tint(AppTheme.gold)
                                }
                            }
                        }
                        Button(busy ? "Submitting…" : "Submit Test") { Task { await submitTest(quiz) } }
                            .buttonStyle(.borderedProminent).tint(AppTheme.gold)
                            .disabled(busy || quiz.questions.contains { answers[$0.id]?.isEmpty != false })
                    }
                } else if snapshot.status == "COMPLETED" {
                    Label("Lesson complete", systemImage: "checkmark.circle.fill").foregroundStyle(AppTheme.gold)
                } else {
                    Button(busy ? "Saving…" : "Mark Lesson Complete") { Task { await completeLesson() } }
                        .buttonStyle(.borderedProminent).tint(AppTheme.gold).disabled(busy)
                }
            } else {
                Button("Load Lesson") { Task { await load() } }.disabled(busy)
            }
        }
        .task { await load() }
    }
    @MainActor private func load() async {
        do {
            let response = try await APIClient.shared.fetchTrainingLesson(courseId: courseId, lessonId: lessonId)
            guard response.success, let lesson = response.lesson else { throw APIClient.APIError.serverError(statusCode: 400, message: response.error ?? "Unable to load lesson.") }
            snapshot = lesson; position = lesson.lastPositionSeconds; error = nil
        } catch { self.error = error.localizedDescription }
    }
    @MainActor private func savePosition(_ seconds: Int) async {
        guard !savingPosition else { return }
        savingPosition = true
        defer { savingPosition = false }
        do {
            _ = try await APIClient.shared.trainingLessonAction(courseId: courseId, lessonId: lessonId, action: TrainingLessonAction(action: "progress", positionSeconds: seconds))
        } catch { self.error = "Playback position was not saved. \(error.localizedDescription)" }
    }
    @MainActor private func completeLesson() async {
        busy = true; defer { busy = false }
        do {
            let response = try await APIClient.shared.trainingLessonAction(courseId: courseId, lessonId: lessonId, action: TrainingLessonAction(action: "progress", positionSeconds: position, complete: true))
            guard response.success else { throw APIClient.APIError.serverError(statusCode: 400, message: response.error ?? "Unable to save lesson.") }
            await load(); await onComplete()
        } catch { self.error = error.localizedDescription }
    }
    @MainActor private func startTest() async {
        busy = true; defer { busy = false }
        do {
            let response = try await APIClient.shared.trainingLessonAction(courseId: courseId, lessonId: lessonId, action: TrainingLessonAction(action: "startQuiz"))
            guard response.success, let id = response.attemptId else { throw APIClient.APIError.serverError(statusCode: 400, message: response.error ?? "Unable to start test.") }
            attemptID = id; expiresAt = response.expiresAt; answers = [:]; result = nil; error = nil
            await load()
        } catch { self.error = error.localizedDescription }
    }
    @MainActor private func submitTest(_ quiz: TrainingLearnerQuiz) async {
        guard let attemptID else { return }
        busy = true; defer { busy = false }
        do {
            let response = try await APIClient.shared.trainingLessonAction(courseId: courseId, lessonId: lessonId, action: TrainingLessonAction(action: "submitQuiz", attemptId: attemptID, answers: quiz.questions.map { TrainingLessonAnswer(questionId: $0.id, selectedOptionIds: Array(answers[$0.id] ?? [])) }))
            guard response.success else { throw APIClient.APIError.serverError(statusCode: 400, message: response.error ?? "Unable to submit test.") }
            self.attemptID = nil; result = response; error = nil
            await load()
            if response.passed == true { await onComplete() }
        } catch { self.error = error.localizedDescription }
    }
}

private struct TrainingYouTubeVideoView: UIViewRepresentable {
    let videoID: String
    let resumeSeconds: Int
    let onPosition: (Int) -> Void

    static func videoID(_ url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        let value: String?
        if host == "youtu.be" { value = url.pathComponents.dropFirst().first }
        else if ["youtube.com", "www.youtube.com", "m.youtube.com", "youtube-nocookie.com", "www.youtube-nocookie.com"].contains(host) {
            value = url.path == "/watch" ? URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value : ["embed", "shorts"].contains(url.pathComponents.dropFirst().first ?? "") ? url.pathComponents.dropFirst(2).first : nil
        } else { value = nil }
        guard let value, value.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil else { return nil }
        return value
    }
    func makeCoordinator() -> Coordinator { Coordinator(onPosition: onPosition) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        configuration.userContentController.add(context.coordinator, name: "trainingPosition")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.scrollView.isScrollEnabled = false
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="strict-origin-when-cross-origin"><style>html,body,#player{margin:0;width:100%;height:100%;background:#000;color:#fff;font:16px sans-serif}a{color:#ffc107}</style></head><body><div id="player"></div><script>
        var player;function save(){if(player&&[0,1,2].includes(player.getPlayerState())){var t=player.getCurrentTime();if(Number.isFinite(t))window.webkit.messageHandlers.trainingPosition.postMessage(Math.floor(t));}}
        function onYouTubeIframeAPIReady(){player=new YT.Player('player',{host:'https://www.youtube-nocookie.com',videoId:'\(videoID)',playerVars:{playsinline:1,start:\(max(0,resumeSeconds)),cc_load_policy:1,rel:0},events:{onStateChange:save,onReady:function(){setInterval(function(){if(player.getPlayerState()===1)save();},10000)},onError:function(){document.getElementById('player').innerHTML='<p>Embedded playback unavailable.</p><a href="https://www.youtube.com/watch?v=\(videoID)">Open publisher video</a>';}}});}document.addEventListener('visibilitychange',save);
        </script><script src="https://www.youtube.com/iframe_api"></script></body></html>
        """
        // YouTube requires client identification for WebView embeds. No member tokens enter this document.
        let bundleID = (Bundle.main.bundleIdentifier ?? "org.mtfd.members").lowercased()
        view.loadHTMLString(html, baseURL: URL(string: "https://\(bundleID)"))
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "trainingPosition")
        uiView.loadHTMLString("", baseURL: nil)
    }
    final class Coordinator: NSObject, WKScriptMessageHandler {
        let onPosition: (Int) -> Void
        init(onPosition: @escaping (Int) -> Void) { self.onPosition = onPosition }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let number = message.body as? NSNumber, number.doubleValue.isFinite, number.doubleValue >= 0, number.doubleValue <= 86400 else { return }
            onPosition(number.intValue)
        }
    }
}
