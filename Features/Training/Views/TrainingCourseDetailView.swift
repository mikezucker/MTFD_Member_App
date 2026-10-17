import AVKit
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
                TrainingPlayerContentCard(item: current)

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
                        videoURL: APIClient.shared.absoluteURL(from: lesson.videoUrl),
                        videoFileURL: nil,
                        contentURL: APIClient.shared.absoluteURL(from: lesson.filePath),
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
                    let requiresSignoff = (objective.objectiveType.uppercased() == "PRACTICAL" || objective.jprEnabled) &&
                        detail.allowMemberObjectiveSelfCheckoff != true
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
                        videoFileURL: APIClient.shared.absoluteURL(from: objective.videoFilePath),
                        contentURL: APIClient.shared.absoluteURL(from: objective.contentFilePath),
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

        return items
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

            if let videoURL = item.videoURL ?? item.videoFileURL {
                mediaPreview(url: videoURL, kind: .video)
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
            VideoPlayer(player: AVPlayer(url: url))
                .frame(minHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .document:
            openButton(url: url, title: item.contentFileName ?? "Open Document", systemImage: "doc.text.fill")
        case .link:
            openButton(url: url, title: "Open Content", systemImage: "link")
        }
    }

    private func openButton(url: URL, title: String, systemImage: String) -> some View {
        Button {
            openURL(url)
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
        !isComplete && !requiresInstructorSignoff
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
