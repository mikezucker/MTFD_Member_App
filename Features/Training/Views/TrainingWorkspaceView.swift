import SwiftUI
import UniformTypeIdentifiers

struct TrainingView: View {
    @State private var home: TrainingWorkspaceHome?
    @State private var error: String?
    @State private var useLegacy = false
    @State private var tab = "To Do"
    @State private var search = ""
    @State private var creating = false
    @State private var refreshing = false
    @State private var showingMyTraining = false
    @State private var navigationID = UUID()

    var body: some View {
        Group {
            if useLegacy { LegacyTrainingView() }
            else {
                NavigationStack {
                    AppScreen(title: "") {
                        ScrollView {
                            VStack(spacing: 0) {
                                TrainingScreenHeader(title: home?.guidedEnabled == true && (home?.canManage != true || showingMyTraining) ? "My Training" : "Training Hub", subtitle: "Prepare. Practice. Perform.", systemImage: "graduationcap.fill", isRefreshing: refreshing, stats: headerStats)
                                VStack(alignment: .leading, spacing: 18) {
                                    if let error { WorkspaceNotice(message: error, warning: true); Button("Try again") { Task { await load() } }.buttonStyle(WorkspaceActionStyle()) }
                                    if let home {
                                        if home.guidedEnabled == true && home.canManage && !showingMyTraining {
                                            GuidedInstructorHome(workspace: home, onMyTraining: { showingMyTraining = true }, onCatalog: { showingMyTraining = true; tab = "Catalog" })
                                        } else {
                                        if home.guidedEnabled == true && home.canManage { Button { returnToTrainingHome() } label: { Label("Training Home", systemImage: "house.fill") }.buttonStyle(WorkspaceActionStyle()) }
                                        trainingTabs
                                        if tab == "My JPR Results" { GuidedMemberResults() } else {
                                        if home.guidedEnabled == true { NavigationLink("My Skills Progress & Upcoming Training") { GuidedSkillsView() }.buttonStyle(WorkspaceActionStyle()) }
                                        HStack(spacing: 10) {
                                            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.55))
                                            TextField("Search courses", text: $search).foregroundStyle(.white).autocorrectionDisabled()
                                            if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search") }
                                        }.workspaceCard()
                                        sectionHeading(trainingSectionTitle, subtitle: tab == "Catalog" ? "Available for your member type. Enroll to get started." : tab == "Completed" ? "Completion dates, results, and credited hours." : "Assigned courses and your next steps.")
                                        if shownCourses.isEmpty {
                                            WorkspacePanel {
                                                Label(search.isEmpty ? (tab == "Catalog" ? "No courses available" : tab == "Completed" ? "Your training record starts here" : "You're up to date") : "No matching courses", systemImage: tab == "Completed" ? "checkmark.seal" : "graduationcap")
                                                    .font(.headline).foregroundStyle(TrainingVisualStyle.cyan)
                                                Text(search.isEmpty ? (tab == "Catalog" ? "Your instructors will publish eligible courses here." : tab == "Completed" ? "Completed courses and earned hours will appear here." : "You have no outstanding course assignments. Browse the catalog to find available training.") : "Try a different course name.").font(.subheadline).foregroundStyle(.white.opacity(0.72))
                                                if search.isEmpty && isRequiredTab { Button("Browse course catalog") { tab = "Catalog" }.buttonStyle(WorkspaceActionStyle()) }
                                            }
                                        }
                                        ForEach(shownCourses) { course in
                                            NavigationLink {
                                                if course.delivery == "LEGACY" && course.archived != true { TrainingCourseDetailView(item: course.legacyItem).trainingDestinationNavigation() }
                                                else { WorkspaceCourseView(course: course, members: home.members, manage: false) }
                                            } label: { WorkspaceCourseCard(course: course) }.buttonStyle(.plain)
                                        }
                                        if isRequiredTab && home.courses.contains(where: { $0.pendingForm }) {
                                            sectionHeading("Outstanding Forms", subtitle: "Follow-up items are separate from earned credit.")
                                            ForEach(home.courses.filter { $0.pendingForm }) { course in
                                                NavigationLink { WorkspaceCourseView(course: course, members: home.members, manage: false) } label: {
                                                    HStack(spacing: 12) {
                                                        Image(systemName: "doc.text.badge.ellipsis").font(.title2).foregroundStyle(TrainingVisualStyle.cyan)
                                                        VStack(alignment: .leading, spacing: 5) { Text(course.title).font(.headline); Text("Complete your evaluation or acknowledgment").font(.caption).foregroundStyle(.white.opacity(0.7)) }
                                                        Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.white.opacity(0.5))
                                                    }.workspaceCard()
                                                }.buttonStyle(.plain)
                                            }
                                        }
                                        }
                                        if home.canManage && home.guidedEnabled != true { instructorTools(home) }
                                        }
                                    } else if error == nil { ProgressView("Loading training…").tint(TrainingVisualStyle.cyan).frame(maxWidth: .infinity).padding(32) }
                                }.padding(.horizontal, 16).padding(.vertical, 16).padding(.bottom, 20)
                            }
                        }.refreshable { await load() }
                    }
                    // This tab has its own header; an empty navigation bar shifts it down.
                    .toolbar(.hidden, for: .navigationBar)
                    .tint(TrainingVisualStyle.cyan).environment(\.colorScheme, .dark)
                    .task { await load() }
                    .sheet(isPresented: $creating, onDismiss: { Task { await load() } }) { NavigationStack { WorkspaceCourseBuilder(members: home?.members ?? []) } }
                }
                .id(navigationID)
                .environment(\.trainingHomeAction, { returnToTrainingHome() })
            }
        }
    }
    private func returnToTrainingHome() {
        showingMyTraining = false
        tab = home?.guidedEnabled == true ? "Required Training" : "To Do"
        search = ""
        navigationID = UUID()
    }
    private var headerStats: [TrainingHeaderStat] {
        guard let home else { return [] }
        if home.guidedEnabled == true && home.canManage && !showingMyTraining { return [] }
        return [TrainingHeaderStat(label: "To Do", value: "\(home.courses.filter { $0.assigned && $0.progressStatus != "COMPLETED" }.count)"), TrainingHeaderStat(label: "Completed", value: "\(home.courses.filter { $0.progressStatus == "COMPLETED" }.count)", accent: TrainingVisualStyle.mint), TrainingHeaderStat(label: "Hours", value: workspaceHours(home.courses.reduce(0) { $0 + $1.creditedMinutes }), accent: TrainingVisualStyle.lavender)]
    }
    private var shownCourses: [TrainingWorkspaceCourse] {
        (home?.courses ?? []).filter { course in
            (search.isEmpty || course.title.localizedCaseInsensitiveContains(search)) && (tab == "Catalog" ? !course.assigned : course.assigned && (tab == "Completed" ? course.progressStatus == "COMPLETED" : course.progressStatus != "COMPLETED" && (tab != "In Progress" || course.progressStatus == "IN_PROGRESS")))
        }.sorted { left, right in
            if tab == "Completed" { return (left.completedAt ?? .distantPast) > (right.completedAt ?? .distantPast) }
            return (left.dueAt ?? .distantFuture) < (right.dueAt ?? .distantFuture)
        }
    }
    private var trainingTabs: some View {
        WorkspaceTrainingNavigation(selection: $tab, guided: home?.guidedEnabled == true)
    }
    private var isRequiredTab: Bool { tab == "To Do" || tab == "Required Training" }
    private var trainingSectionTitle: String {
        switch tab {
        case "Catalog": return "Course Catalog"
        case "Completed": return "Completed Training"
        case "In Progress": return "In Progress"
        case "Required Training": return "Required Training"
        default: return "My Training"
        }
    }
    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.title3.bold()).foregroundStyle(.white); Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.65)) }
    }
    private func instructorTools(_ home: TrainingWorkspaceHome) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Instructor Tools", subtitle: "Build courses, assign members, and record training.")
            if home.canCreate {
                Button { creating = true } label: { WorkspaceToolRow(title: "Create a Course", subtitle: "Online CBT or practical training · 3 steps", icon: "plus.rectangle.on.folder.fill") }.buttonStyle(.plain)
            }
            NavigationLink { WorkspaceInstructorCourses(home: home) } label: {
                WorkspaceToolRow(title: "Manage Courses", subtitle: "\(home.manageCourses.filter { $0.delivery != "LEGACY" }.count) courses · assignments, attendance, and records", icon: "person.2.fill")
            }.buttonStyle(.plain)
        }.padding(.top, 4)
    }
    @MainActor private func load() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        do { let result: TrainingWorkspaceHome = try await APIClient.shared.trainingWorkspace(); home = result; if result.guidedEnabled == true && tab == "To Do" { tab = "Required Training" }; error = nil }
        catch is CancellationError { }
        catch let failure where APIClient.isRequestCancellation(failure) { }
        catch APIClient.APIError.serverError(let code, _) where code == 404 { useLegacy = true }
        catch { self.error = error.localizedDescription }
    }
}


// Pushed training screens opt back into navigation; only the tab root hides its bar.
private struct TrainingHomeActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}
private extension EnvironmentValues {
    var trainingHomeAction: (() -> Void)? {
        get { self[TrainingHomeActionKey.self] }
        set { self[TrainingHomeActionKey.self] = newValue }
    }
}
private struct TrainingDestinationNavigation: ViewModifier {
    @Environment(\.trainingHomeAction) private var goHome
    let blocked: Bool
    func body(content: Content) -> some View {
        content
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                if let goHome {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: goHome) { Label("Training Home", systemImage: "house.fill") }
                            .disabled(blocked)
                            .accessibilityIdentifier("training-home")
                    }
                }
            }
    }
}
private extension View {
    func trainingDestinationNavigation(blocked: Bool = false) -> some View {
        modifier(TrainingDestinationNavigation(blocked: blocked))
    }
}

// Status filters and destinations stay visible without horizontal scrolling.
private struct WorkspaceTrainingNavigation: View {
    @Binding var selection: String
    let guided: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns(count: 3), spacing: 6) {
                if guided {
                    navigationButton("Required", value: "Required Training")
                    navigationButton("In Progress", value: "In Progress")
                    navigationButton("Completed", value: "Completed")
                } else {
                    navigationButton("To Do", value: "To Do")
                    navigationButton("Completed", value: "Completed")
                    navigationButton("Catalog", value: "Catalog")
                }
            }
            .padding(4)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))

            if guided {
                LazyVGrid(columns: columns(count: 2), spacing: 10) {
                    navigationButton("JPR Results", value: "My JPR Results", icon: "checklist")
                    navigationButton("Course Catalog", value: "Catalog", icon: "magnifyingglass")
                }
            }
        }
    }
    private func columns(count: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: dynamicTypeSize.isAccessibilitySize ? 1 : count)
    }
    private func navigationButton(_ title: String, value: String, icon: String? = nil) -> some View {
        Button { selection = value } label: {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).accessibilityHidden(true) }
                Text(title).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: icon == nil ? 48 : 52)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .foregroundStyle(selection == value ? AppTheme.navy : .white.opacity(0.85))
            .background(selection == value ? TrainingVisualStyle.cyan : icon == nil ? Color.clear : .white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == value ? .isSelected : [])
        .accessibilityIdentifier("training-filter-" + value)
    }
}

private struct WorkspaceInstructorCourses: View {
    let home: TrainingWorkspaceHome
    var body: some View {
        AppScreen(title: "Manage Courses", subtitle: "Assignments, attendance, and completion records.", systemImage: "person.2.fill") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if home.manageCourses.filter({ $0.delivery != "LEGACY" }).isEmpty { WorkspacePanel { Text("No courses yet").font(.headline); Text("Use Create a Course in Training to build your first CBT or practical course.").foregroundStyle(.white.opacity(0.7)) } }
                    ForEach(home.manageCourses.filter { $0.delivery != "LEGACY" }) { course in
                        NavigationLink { WorkspaceCourseView(course: workspaceSummary(course), members: home.members, manage: true) } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack { WorkspaceBadge(text: course.delivery == "CBT" ? "ONLINE CBT" : "PRACTICAL"); Spacer(); Text(course.status == "DRAFT" ? "Draft" : "Published").font(.caption.bold()).foregroundStyle(course.status == "DRAFT" ? TrainingVisualStyle.cyan : .green) }
                                Text(course.title).font(.title3.bold()).foregroundStyle(.white)
                                Label(course.delivery == "PRACTICAL" ? "Assignments & attendance" : "Assignments & quiz results", systemImage: "chevron.right").font(.subheadline).foregroundStyle(.white.opacity(0.7))
                            }.workspaceCard()
                        }.buttonStyle(.plain)
                    }
                }.padding(16)
            }
        }
        .trainingDestinationNavigation()
    }
    private func workspaceSummary(_ c: TrainingWorkspaceManagedCourse) -> TrainingWorkspaceCourse {
        TrainingWorkspaceCourse(id: c.id, title: c.title, description: nil, delivery: c.delivery, archived: false, assigned: false, progressStatus: "NOT_STARTED", completedAt: nil, dueAt: nil, durationMinutes: nil, creditedMinutes: 0, pendingForm: false)
    }
}

private struct WorkspaceCourseView: View {
    let course: TrainingWorkspaceCourse
    let members: [TrainingWorkspaceMember]
    let manage: Bool
    var allowJprReview = false
    @State private var detail: TrainingWorkspaceDetail?
    @State private var error: String?
    @State private var saved: String?
    @State private var response = ""
    @State private var selected = Set<String>()
    @State private var attending = Set<String>()
    @State private var date = Date()
    @State private var minutes = 60
    @State private var sessionKey = "DAILY"
    @State private var busy = false
    @State private var editing = false
    @State private var confirmingArchive = false
    var body: some View {
        AppScreen(title: "Training", subtitle: manage ? "Instructor course workspace" : "Course details and next steps", systemImage: "graduationcap.fill") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let error { WorkspaceNotice(message: error, warning: true); Button("Try again") { Task { await load() } }.buttonStyle(WorkspaceActionStyle()) }
                    if let saved { WorkspaceNotice(message: saved) }
                    if let detail {
                        let c = detail.course
                        WorkspacePanel {
                            HStack { WorkspaceBadge(text: c.delivery == "CBT" ? "ONLINE CBT" : "PRACTICAL TRAINING"); Spacer(); WorkspaceBadge(text: manage ? (c.status ?? "DRAFT") : c.progressStatus == "COMPLETED" ? "COMPLETED" : c.status == "DRAFT" ? "DRAFT" : c.enrolled == true ? "ASSIGNED" : "AVAILABLE") }
                            Text(c.title).font(.title2.bold())
                            if let description = c.description, !description.isEmpty { Text(description).font(.subheadline).foregroundStyle(.white.opacity(0.75)) }
                            Label("\(workspaceHours(c.durationMinutes ?? 0)) training hours", systemImage: "clock")
                            Label(c.instructor ?? "Training staff", systemImage: "person.crop.circle")
                            if let limit = c.quizAttemptLimit, c.delivery == "CBT" { Label("80% to pass · up to \(limit) attempts", systemImage: "checkmark.shield") }
                            if let dueAt = course.dueAt { Label("Due \(dueAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar").foregroundStyle(dueAt < Date() && c.progressStatus != "COMPLETED" ? .orange : .white.opacity(0.8)) }
                        }.font(.subheadline)
                        if manage && detail.canManage == true { instructorContent(detail) }
                        else { learnerContent(detail) }
                    } else if error == nil { ProgressView("Loading course…").tint(TrainingVisualStyle.cyan).frame(maxWidth: .infinity).padding(30) }
                }.padding(16).padding(.bottom, 20)
            }.refreshable { await load() }
        }
        .trainingDestinationNavigation(blocked: busy)
        .tint(TrainingVisualStyle.cyan).environment(\.colorScheme, .dark)
        .sheet(isPresented: $editing, onDismiss: { Task { await load() } }) { NavigationStack { WorkspaceCourseBuilder(members: members, courseId: course.id) } }
        .disabled(busy)
        .overlay { if busy { ProgressView("Saving…").padding(24).background(AppTheme.navy, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.white) } }
        .task { await load() }
        .alert("Archive this course?", isPresented: $confirmingArchive) { Button("Cancel", role: .cancel) { }; Button("Archive", role: .destructive) { perform(["action": "archive"]) } } message: { Text("The course leaves active training. Completion records and hours are preserved.") }
    }
    @ViewBuilder private func instructorContent(_ detail: TrainingWorkspaceDetail) -> some View {
        let c = detail.course
        if c.status == "DRAFT" {
            WorkspacePanel("Prepare your course") {
                Text("Review material, quiz questions, and the audience before publishing.").foregroundStyle(.white.opacity(0.7))
                Button("Edit draft") { editing = true }.buttonStyle(WorkspaceActionStyle())

            }
        }
        if allowJprReview && c.delivery == "PRACTICAL" { NavigationLink("Content & JPRs") { GuidedLibraryView(initialCourseId: course.id, keepCourseDraft: c.status == "DRAFT") }.buttonStyle(WorkspaceActionStyle()) }
        WorkspacePanel("Assign course (optional)") {
            Text("You can leave this course unassigned and return here later. This grants course access; it does not schedule a session or assign a skill requirement.").font(.caption)
            Text("\(detail.roster?.count ?? 0) \((detail.roster?.count ?? 0) == 1 ? "member" : "members") assigned").font(.subheadline).foregroundStyle(.white.opacity(0.7))
            DisclosureGroup("Assign members") {
                WorkspaceMemberSelection(members: members, selected: $selected)
                Button("Assign selected members") { perform(["action": "assign", "userIds": Array(selected)]) }.buttonStyle(WorkspaceActionStyle(primary: true)).disabled(selected.isEmpty)
            }
        }
        if c.delivery == "PRACTICAL" {
            WorkspacePanel("Record practical training") {
                Text("Select attendees, confirm the date and duration, then save their completion and hours together.").font(.subheadline).foregroundStyle(.white.opacity(0.7))
                WorkspaceMemberSelection(members: detail.roster ?? [], selected: $attending)
                DatePicker("Training date", selection: $date, in: ...Date(), displayedComponents: .date)
                Stepper("\(minutes) minutes · \(workspaceHours(minutes)) hours", value: $minutes, in: 1...1440, step: 15)
                Button("Record completion & hours") { perform(["action": "attendance", "userIds": Array(attending), "completedAt": ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: date)), "durationMinutes": minutes, "sessionKey": sessionKey]) }.buttonStyle(WorkspaceActionStyle(primary: true)).disabled(attending.isEmpty || c.status != "PUBLISHED")
                Button("Start an additional session") { sessionKey = UUID().uuidString; attending = []; saved = "Additional session ready. Select its attendees and date." }.buttonStyle(WorkspaceActionStyle())
                Text("Saving the same day's attendance again won't add hours twice. Use an additional session for separate repeat training.").font(.caption).foregroundStyle(.white.opacity(0.65))
            }
        }
        WorkspacePanel("Member progress & records") {
            if (detail.roster ?? []).isEmpty { Text("Assign members to see their progress and completion records.").foregroundStyle(.white.opacity(0.7)) }
            ForEach(detail.roster ?? []) { member in
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(member.name ?? "Member").font(.headline); Spacer(); Image(systemName: member.progressStatus == "COMPLETED" ? "checkmark.seal.fill" : "clock").foregroundStyle(member.progressStatus == "COMPLETED" ? .green : TrainingVisualStyle.cyan) }
                    Text("\(member.progressStatus == "COMPLETED" ? "Completed" : member.progressStatus == "IN_PROGRESS" ? "In progress" : "Not started") · \(workspaceHours(member.creditedMinutes ?? 0)) hours credited").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    if member.pendingForm == true { Text("Follow-up form outstanding · credit retained").font(.caption).foregroundStyle(TrainingVisualStyle.cyan) }
                    ForEach(member.completions ?? []) { credit in WorkspaceCreditRow(credit: credit) }
                }.padding(.vertical, 8)
                Divider().overlay(.white.opacity(0.1))
            }
        }
        if c.status != "ARCHIVED" {
            WorkspacePanel {
                DisclosureGroup("Course settings") { Text("Archiving preserves completion records and earned hours.").font(.caption).foregroundStyle(.white.opacity(0.7)); Button("Archive course", role: .destructive) { confirmingArchive = true }.padding(.top, 8) }
            }
        }
    }
    @ViewBuilder private func learnerContent(_ detail: TrainingWorkspaceDetail) -> some View {
        let c = detail.course
        if c.status == "ARCHIVED" { WorkspaceNotice(message: "This course is archived. Your completion records and hours remain available.") }
        if c.progressStatus == "COMPLETED" {
            WorkspacePanel("Training completed") {
                Label("Your training credit is recorded", systemImage: "checkmark.seal.fill").foregroundStyle(.green).font(.headline)
                ForEach(c.completions ?? []) { credit in WorkspaceCreditRow(credit: credit) }
            }
        }
        if c.status != "ARCHIVED" {
            if c.enrolled != true {
                WorkspacePanel("Ready to enroll?") { Text("Enroll to get immediate access to this course.").foregroundStyle(.white.opacity(0.75)); Button("Enroll & start") { perform(["action": "enroll"]) }.buttonStyle(WorkspaceActionStyle(primary: true)) }
            } else if c.delivery == "CBT" {
                WorkspacePanel(c.progressStatus == "COMPLETED" ? "Course material" : "Your next step") {
                    Text("Work through the course material, then take the required quiz. Your progress saves as you go.").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    NavigationLink { TrainingCourseDetailView(item: course.legacyItem).trainingDestinationNavigation() } label: { Label(c.progressStatus == "COMPLETED" ? "Review course" : "Start / resume course", systemImage: "play.circle.fill").frame(maxWidth: .infinity) }.buttonStyle(WorkspaceActionStyle(primary: true))
                }
            } else {
                WorkspacePanel("Practical training") {
                    Text(c.completionMethod == "MEMBER" ? "Complete the practical training, then record your completion below." : "Your instructor records your attendance, completion, and training hours after the session.").foregroundStyle(.white.opacity(0.75))
                    if c.completionMethod == "MEMBER" { Button(c.progressStatus == "COMPLETED" ? "Completion recorded" : "Record my completion") { perform(["action": "completeMember"]) }.buttonStyle(WorkspaceActionStyle(primary: true)).disabled(c.progressStatus == "COMPLETED") }
                }
            }
        }
        if let prompt = c.followUpPrompt {
            WorkspacePanel(c.followUpResponse == nil ? "Outstanding form" : "Submitted form") {
                Text(prompt).font(.subheadline)
                TextEditor(text: $response).frame(minHeight: 120).scrollContentBackground(.hidden).workspaceInput().accessibilityLabel("Evaluation or acknowledgment response")
                Button(c.followUpResponse == nil ? "Submit response" : "Update response") { perform(["action": "followUp", "response": response]) }.buttonStyle(WorkspaceActionStyle(primary: true)).disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("This follow-up is separate from your earned training credit.").font(.caption).foregroundStyle(.white.opacity(0.65))
            }
        }
    }
    private func perform(_ body: [String: Any]) {
        Task { @MainActor in
            busy = true; error = nil; saved = nil
            defer { busy = false }
            do {
                let result: TrainingWorkspaceMutation = try await APIClient.shared.trainingWorkspace("/courses/\(course.id)", body: try JSONSerialization.data(withJSONObject: body))
                guard result.success else { throw APIClient.APIError.serverError(statusCode: 400, message: result.error ?? "Unable to save training.") }
                await load(); saved = "Saved."
            } catch { self.error = error.localizedDescription }
        }
    }
    @MainActor private func load() async {
        do { let result: TrainingWorkspaceDetail = try await APIClient.shared.trainingWorkspace("/courses/\(course.id)"); if detail == nil { minutes = result.course.durationMinutes ?? 60 }; detail = result; response = result.course.followUpResponse ?? ""; error = nil }
        catch is CancellationError { }
        catch let failure where APIClient.isRequestCancellation(failure) { }
        catch { self.error = error.localizedDescription }
    }
}

private struct WorkspaceMemberSelection: View {
    let members: [TrainingWorkspaceMember]
    @Binding var selected: Set<String>
    @State private var search = ""
    var body: some View {
        TextField("Find members", text: $search).workspaceInput().autocorrectionDisabled()
        if members.isEmpty { Text("No assigned members yet.").font(.subheadline).foregroundStyle(.white.opacity(0.65)) }
        ForEach(members.filter { search.isEmpty || ($0.name ?? "").localizedCaseInsensitiveContains(search) }) { member in
            Toggle(isOn: Binding(get: { selected.contains(member.id) }, set: { if $0 { selected.insert(member.id) } else { selected.remove(member.id) } })) {
                VStack(alignment: .leading, spacing: 3) { Text(member.name ?? "Member").font(.subheadline.weight(.semibold)); Text(workspaceRoleNames[member.role] ?? member.role.replacingOccurrences(of: "_", with: " ").capitalized).font(.caption).foregroundStyle(.white.opacity(0.6)) }
            }.tint(TrainingVisualStyle.cyan).padding(.vertical, 4)
        }
        Text("\(selected.count) selected").font(.caption.weight(.semibold)).foregroundStyle(TrainingVisualStyle.cyan)
    }
}

private struct WorkspaceCourseBuilder: View {
    let members: [TrainingWorkspaceMember]
    var courseId: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var draft = WorkspaceCourseDraft()
    @State private var savedCourseId: String?
    @State private var assignNow = false
    init(members: [TrainingWorkspaceMember], courseId: String? = nil) { self.members = members; self.courseId = courseId; _savedCourseId = State(initialValue: courseId) }
    @State private var step = 0
    @State private var link = ""
    @State private var materialTitle = ""
    @State private var materialKind = "VIDEO"
    @State private var importing = false
    @State private var busy = false
    @State private var error: String?
    @State private var selected = Set<String>()
    var body: some View {
        AppScreen(title: "") {
            VStack(spacing: 0) {
                TrainingScreenHeader(title: courseId == nil ? "Create a Course" : "Edit Draft", subtitle: "Save a draft or publish. Assignments are optional.", systemImage: "graduationcap.fill")
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        WorkspaceBuilderSteps(step: step)
            if let error { WorkspaceNotice(message: error, warning: true) }
            if step == 0 {
                WorkspacePanel("Course Details") {
                    Text("Course name").font(.subheadline.weight(.semibold)); TextField("Give your course a clear name", text: $draft.title).workspaceInput()
                    Picker("Format", selection: $draft.delivery) { Text("Online CBT").tag("CBT"); Text("Practical / Instructor-led").tag("PRACTICAL") }
                    Text("What will members learn?").font(.subheadline.weight(.semibold)); TextField("Course description", text: $draft.description, axis: .vertical).lineLimit(3...6).workspaceInput()
                    Stepper("\(draft.durationMinutes) training minutes", value: $draft.durationMinutes, in: 1...1440, step: 15)
                    Text("You are recorded as the course instructor.").font(.caption)
                }
            } else if step == 1 {
                if draft.delivery == "CBT" {
                    WorkspacePanel("Course Material") {
                        TextField("Material title", text: $materialTitle).workspaceInput()
                        Picker("Format", selection: $materialKind) { Text("Video").tag("VIDEO"); Text("Presentation / PDF").tag("FILE") }
                        TextField("YouTube or hosted HTTPS link", text: $link).textInputAutocapitalization(.never).keyboardType(.URL).autocorrectionDisabled().workspaceInput()
                        Button("Add link") { addLink() }.buttonStyle(WorkspaceActionStyle())
                        Button("Upload video, PowerPoint, or PDF") { importing = true }.buttonStyle(WorkspaceActionStyle())
                        Text("Uploads up to 50 MB. You can also use a hosted video link.").font(.caption)
                        ForEach(draft.content) { material in
                            HStack { Text(material.title); Spacer(); Button("Remove", role: .destructive) { draft.content.removeAll { $0.url == material.url } }.buttonStyle(.borderless) }
                        }
                    }
                    WorkspacePanel("Quiz · 80% to Pass") {
                        Stepper("Maximum \(draft.quizAttemptLimit) attempts", value: $draft.quizAttemptLimit, in: 1...100)
                        ForEach($draft.questions) { $question in
                            VStack(alignment: .leading) {
                                WorkspaceQuizQuestionEditor(question: $question)
                                Button("Remove Question", role: .destructive) { draft.questions.removeAll { $0.id == question.id } }
                            }
                        }
                        Button("Add Question") { draft.questions.append(WorkspaceDraftQuestion()) }
                    }
                } else {
                    WorkspacePanel("Content & JPRs") {
                        if let savedCourseId { NavigationLink("Upload & review this course’s JPRs") { GuidedLibraryView(initialCourseId: savedCourseId, keepCourseDraft: true) }.buttonStyle(WorkspaceActionStyle()) }
                        Text("Review the approved teaching and evaluation checklist here. Approval does not publish this draft.").font(.caption)
                    }
                    WorkspacePanel("Who Records Completion?") {
                        Picker("Completion", selection: $draft.completionMethod) { Text("Instructor records attendance & completion").tag("INSTRUCTOR"); Text("Member records completion").tag("MEMBER") }
                    }
                }
                WorkspacePanel("Optional Evaluation / Acknowledgment") {
                    TextField("Form prompt (leave blank if none)", text: $draft.followUpPrompt, axis: .vertical).lineLimit(3...6).workspaceInput()
                    Text("This form is tracked separately. It does not hold up training credit.").font(.caption)
                }
            } else {
                WorkspacePanel("Catalog Access") {
                    Toggle("Allow Self-Enrollment", isOn: $draft.catalogEnabled)
                    if draft.catalogEnabled {
                        ForEach(Array(workspaceRoleNames.keys.sorted()), id: \.self) { role in
                            Toggle(workspaceRoleNames[role] ?? role, isOn: Binding(get: { draft.catalogRoles.contains(role) }, set: { if $0 { draft.catalogRoles.append(role) } else { draft.catalogRoles.removeAll { $0 == role } } }))
                        }
                    }
                    Text("Only selected member types see the course in the catalog. Named assignments grant access directly.").font(.caption)
                }
                WorkspacePanel("Assignments (optional)") { Toggle("Assign members now", isOn: $assignNow); if assignNow { WorkspaceMemberSelection(members: members, selected: $selected) } else { Text("No members will be assigned. You can assign them later from the saved course.").font(.subheadline) } }
                WorkspacePanel("Member Preview") {
                    Text(draft.title.isEmpty ? "Course name" : draft.title).font(.headline)
                    Text("\(draft.durationMinutes) training minutes")
                    Text(draft.delivery == "CBT" ? "View the material, then pass the quiz at 80%. Up to \(draft.quizAttemptLimit) attempts." : draft.completionMethod == "INSTRUCTOR" ? "Your instructor records attendance and completion." : "Record your completion after training.")
                    if !draft.followUpPrompt.isEmpty { Text("Separate follow-up form").font(.caption) }
                }
                WorkspacePanel { Button("Save draft") { save(publish: false) }.buttonStyle(WorkspaceActionStyle()); Button("Publish to library") { save(publish: true) }.buttonStyle(WorkspaceActionStyle(primary: !assignNow)); if assignNow { Button("Publish & assign") { save(publish: true, assign: true) }.buttonStyle(WorkspaceActionStyle(primary: true)).disabled(selected.isEmpty) } }
            }
            WorkspacePanel {
                HStack { if step > 0 { Button("Back") { step -= 1 }.buttonStyle(WorkspaceActionStyle()) }; if step < 2 { Button("Next step") { nextStep() }.buttonStyle(WorkspaceActionStyle(primary: true)).disabled(step == 0 && draft.title.trimmingCharacters(in: .whitespacesAndNewlines).count < 3) } }
            }
            if step < 2 { Button("Save draft") { save(publish: false) }.buttonStyle(WorkspaceActionStyle()) }
            if busy { ProgressView("Saving…").tint(TrainingVisualStyle.cyan) }
                    }.padding(16).padding(.bottom, 20)
                }
            }
        }
        .foregroundStyle(.white).tint(TrainingVisualStyle.cyan).environment(\.colorScheme, .dark)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(busy) } }
        .disabled(busy)
        .task {
            if let courseId {
                do {
                    let detail: TrainingWorkspaceDetail = try await APIClient.shared.trainingWorkspace("/courses/\(courseId)")
                    guard let existing = detail.draft else { error = "Only an unused draft can be edited."; return }
                    draft = existing; selected = Set(existing.assignedUserIds)
                } catch { self.error = error.localizedDescription }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.movie, .pdf, .presentation]) { result in
            Task { @MainActor in
                busy = true; error = nil; defer { busy = false }
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size > 0, size <= 50 * 1024 * 1024 else { error = "Choose a file up to 50 MB, or use a hosted video link."; return }
                    let type = UTType(filenameExtension: url.pathExtension)
                    let ticket: WorkspaceUploadResponse = try await APIClient.shared.trainingWorkspace("/uploads", body: JSONSerialization.data(withJSONObject: ["fileName": url.lastPathComponent, "sizeBytes": size]))
                    let file: WorkspaceUploadedFile
                    if let signedFile = ticket.file, let uploadURL = signedFile.uploadUrl {
                        guard uploadURL.scheme == "https" else { error = "Invalid upload address."; return }
                        var request = URLRequest(url: uploadURL)
                        request.httpMethod = "PUT"
                        request.setValue(signedFile.mimeType, forHTTPHeaderField: "Content-Type")
                        request.setValue("false", forHTTPHeaderField: "x-upsert")
                        let (_, response) = try await URLSession.shared.upload(for: request, fromFile: url)
                        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { error = "Upload failed. Please try again."; return }
                        file = signedFile
                    } else {
                        guard size <= 4 * 1024 * 1024 else { error = "Private media storage must be configured for large uploads."; return }
                        let uploaded = try await APIClient.shared.uploadWorkspaceTraining(data: Data(contentsOf: url), fileName: url.lastPathComponent, mimeType: type?.preferredMIMEType ?? "application/octet-stream")
                        guard let local = uploaded.file else { error = uploaded.error ?? "Upload failed."; return }
                        file = local
                    }
                    draft.content.append(WorkspaceCourseMaterial(title: materialTitle.isEmpty ? file.fileName : materialTitle, kind: file.mimeType.hasPrefix("video/") ? "VIDEO" : "FILE", url: file.filePath, fileName: file.fileName, assetToken: file.assetToken))
                    materialTitle = ""
                } catch { self.error = error.localizedDescription }
            }
        }
    }
    private func addLink() {
        guard let url = URL(string: link), url.scheme?.lowercased() == "https", url.host != nil, url.user == nil, url.password == nil else { error = "Enter a valid HTTPS video or presentation link."; return }
        draft.content.append(WorkspaceCourseMaterial(title: materialTitle.isEmpty ? "Course material" : materialTitle, kind: materialKind, url: url.absoluteString))
        materialTitle = ""; link = ""; error = nil
    }
    private func nextStep() {
        guard draft.delivery == "PRACTICAL" && step == 0 else { step += 1; return }
        Task { @MainActor in
            busy = true; error = nil; defer { busy = false }
            do {
                draft.publish = false; draft.assignedUserIds = []; draft.editCourseId = savedCourseId
                let result: TrainingWorkspaceMutation = try await APIClient.shared.trainingWorkspace("/courses", body: JSONEncoder().encode(draft))
                guard result.success, let id = result.courseId else { error = result.error ?? "Unable to save draft."; return }
                savedCourseId = id; step = 1
            } catch { self.error = error.localizedDescription }
        }
    }
    private func save(publish: Bool, assign: Bool = false) {
        Task { @MainActor in
            busy = true; error = nil; defer { busy = false }
            draft.publish = publish; draft.assignedUserIds = publish && assign ? Array(selected) : []; draft.editCourseId = savedCourseId
            do {
                let result: TrainingWorkspaceMutation = try await APIClient.shared.trainingWorkspace("/courses", body: JSONEncoder().encode(draft))
                if result.success { dismiss() } else { error = result.error ?? "Unable to save course." }
            } catch { self.error = error.localizedDescription }
        }
    }
}
private let workspaceRoleNames = ["OFFICER_CAREER": "Career Officers", "OFFICER_VOLUNTEER": "Volunteer Officers", "MEMBER_CAREER": "Career Members", "MEMBER_VOLUNTEER": "Volunteer Members"]
private struct WorkspaceQuizQuestionEditor: View {
    @Binding var question: WorkspaceDraftQuestion
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Question", text: $question.prompt, axis: .vertical).workspaceInput()
            ForEach(question.options.indices, id: \.self) { index in
                HStack {
                    Button { question.correctIndex = index } label: { Image(systemName: question.correctIndex == index ? "checkmark.circle.fill" : "circle") }.buttonStyle(.borderless).accessibilityLabel("Answer \(index+1) is correct")
                    TextField("Answer \(index+1)", text: $question.options[index]).workspaceInput()
                }
            }
            Text("Select the correct answer using the circle.").font(.caption)
        }.padding(.vertical, 8)
    }
}

private func workspaceHours(_ minutes: Int) -> String {
    (Double(minutes) / 60).formatted(.number.precision(.fractionLength(0...2)))
}

private struct WorkspacePanel<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content
    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title { Text(title).font(.headline).foregroundStyle(.white) }
            content()
        }.foregroundStyle(.white).workspaceCard()
    }
}

private struct WorkspaceBadge: View {
    let text: String
    var body: some View {
        Text(text).font(.caption2.weight(.bold)).foregroundStyle(TrainingVisualStyle.cyan)
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(TrainingVisualStyle.cyan.opacity(0.1), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct WorkspaceActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var primary = false
    var danger = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity).padding(.horizontal, 12).padding(.vertical, 14)
            .foregroundStyle(primary && !danger ? AppTheme.navy : .white)
            .background(LinearGradient(colors: danger ? [Color(red:185/255,green:28/255,blue:28/255), Color(red:153/255,green:27/255,blue:27/255)] : primary ? [TrainingVisualStyle.cyan, Color(red: 100/255, green: 184/255, blue: 242/255)] : [TrainingVisualStyle.raised, TrainingVisualStyle.surface], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(primary ? 0 : 0.1), lineWidth: 1) }
            .opacity(!enabled ? 0.4 : configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct WorkspaceNotice: View {
    let message: String
    var warning = false
    var body: some View {
        Label(message, systemImage: warning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .font(.subheadline).foregroundStyle(warning ? .orange : .green)
            .frame(maxWidth: .infinity, alignment: .leading).workspaceCard()
            .accessibilityAddTraits(warning ? .updatesFrequently : [])
    }
}

private struct WorkspaceToolRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var body: some View {
        HStack(spacing: 13) {
            TrainingEmblem(symbol: icon, compact: true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.68)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 2)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.white.opacity(0.45))
        }.workspaceCard()
    }
}

private struct TrainingEmblem: View {
    let symbol: String
    var compact = false
    var color: Color = TrainingVisualStyle.cyan
    var body: some View {
        TrainingColorIcon(symbol: symbol, size: compact ? 30 : 40)
            .frame(width: compact ? 46 : 62, height: compact ? 46 : 66)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: compact ? 14 : 19))
            .overlay { RoundedRectangle(cornerRadius: compact ? 14 : 19).stroke(color.opacity(0.25), lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

private struct TrainingQuickAction: View {
    let title: String
    let subtitle: String
    let symbol: String
    var accent: Color = TrainingVisualStyle.cyan
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TrainingColorIcon(symbol: symbol, size: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.bold()).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.68)).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).workspaceCard(accent: accent)
    }
}

private struct TrainingMetricStrip: View {
    let stats: [TrainingHeaderStat]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 1 : 3), spacing: 8) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 4) {
                    Text(stat.value).font(.system(.title2, design: .rounded, weight: .bold)).monospacedDigit().foregroundStyle(stat.accent ?? TrainingVisualStyle.cyan)
                    Text(stat.label).font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.75))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background((stat.accent ?? TrainingVisualStyle.cyan).opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                    .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct TrainingProgressDial: View {
    let percent: Int
    private var progress: Int { min(100, max(0, percent)) }
    private var accent: Color { progress >= 100 ? TrainingVisualStyle.mint : TrainingVisualStyle.cyan }
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.1), lineWidth: 6)
            Circle().trim(from: 0, to: Double(progress) / 100).stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
            Text("\(progress)%").font(.system(.subheadline, design: .rounded, weight: .bold)).monospacedDigit().foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.5).frame(width: 48)
        }.frame(width: 60, height: 60).padding(3)
            .accessibilityElement(children: .ignore).accessibilityLabel("\(progress) percent complete")
    }
}

private struct GuidedCatalogCourseCard: View {
    let course: GuidedTopic
    var members: [TrainingWorkspaceMember] = []
    var canManage = false
    var canReview = false
    let choose: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                TrainingEmblem(symbol: TrainingVisualStyle.symbol(for: course.title + " " + (course.category?.name ?? "")))
                VStack(alignment: .leading, spacing: 7) {
                    Text("PRACTICAL TRAINING").font(.caption2.bold()).tracking(1).foregroundStyle(TrainingVisualStyle.cyan)
                    Text(course.title).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                    if let category = course.category { Text(category.name).font(.caption).foregroundStyle(.white.opacity(0.68)) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { metadata }
                VStack(alignment: .leading, spacing: 8) { metadata }
            }.font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.8))
            Button(action: choose) { HStack { Text("Select course"); Spacer(); Image(systemName: "arrow.right") } }
                .buttonStyle(WorkspaceActionStyle(primary: true))
                .accessibilityLabel("Select course: " + course.title)
            if canManage { NavigationLink("Course details & assignments") { WorkspaceCourseView(course: TrainingWorkspaceCourse(id: course.id, title: course.title, description: course.description, delivery: "PRACTICAL", archived: false, assigned: false, progressStatus: "NOT_STARTED", completedAt: nil, dueAt: nil, durationMinutes: course.durationMinutes, creditedMinutes: 0, pendingForm: false), members: members, manage: true, allowJprReview: canReview) }.buttonStyle(WorkspaceActionStyle()) }
        }.workspaceCard()
            .overlay(alignment: .top) { Capsule().fill(TrainingVisualStyle.cyan.opacity(0.75)).frame(width: 44, height: 3).padding(.top, 1).accessibilityHidden(true) }
    }
    @ViewBuilder private var metadata: some View {
        Label("\(course.latestJprs.count) approved JPRs", systemImage: "checkmark.shield")
        Label("\(course.durationMinutes) min", systemImage: "clock")
    }
}

private struct WorkspaceCourseCard: View {
    let course: TrainingWorkspaceCourse
    private var completed: Bool { course.progressStatus == "COMPLETED" }
    private var overdue: Bool { !completed && (course.dueAt.map { $0 < Date() } ?? false) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                TrainingEmblem(symbol: completed ? "checkmark.seal.fill" : course.delivery == "CBT" ? "play.rectangle.fill" : TrainingVisualStyle.symbol(for: course.title), compact: true, color: completed ? TrainingVisualStyle.mint : TrainingVisualStyle.cyan)
                VStack(alignment: .leading, spacing: 5) {
                    Text(course.delivery == "CBT" ? "ONLINE CBT" : course.delivery == "PRACTICAL" ? "PRACTICAL TRAINING" : "TRAINING").font(.caption2.bold()).foregroundStyle(TrainingVisualStyle.cyan)
                    Text(course.title).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.white.opacity(0.45)).padding(.top, 6)
            }
            if let description = course.description, !description.isEmpty { Text(description).font(.subheadline).foregroundStyle(.white.opacity(0.72)).lineLimit(3) }
            HStack(spacing: 14) {
                if completed { Label("\(workspaceHours(course.creditedMinutes)) hr credited", systemImage: "checkmark.seal").foregroundStyle(.green) }
                else if let duration = course.durationMinutes { Label("\(workspaceHours(duration)) hr", systemImage: "clock").foregroundStyle(.white.opacity(0.7)) }
                Spacer(minLength: 0)
                Text(completed ? "Completed" : !course.assigned ? "Available" : course.progressStatus == "IN_PROGRESS" ? "In progress" : "Not started").fontWeight(.semibold).foregroundStyle(completed ? .green : TrainingVisualStyle.cyan)
            }.font(.caption)
            if completed, let date = course.completedAt { Label("Completed \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar").font(.caption).foregroundStyle(.white.opacity(0.65)) }
            else if let due = course.dueAt { Label("\(overdue ? "Overdue" : "Due") · \(due.formatted(date: .abbreviated, time: .omitted))", systemImage: overdue ? "exclamationmark.triangle.fill" : "calendar").font(.caption.weight(.semibold)).foregroundStyle(overdue ? .orange : .white.opacity(0.7)) }
            Divider().overlay(.white.opacity(0.08))
            Text(completed ? "View training record" : !course.assigned ? "View course & enroll" : course.delivery == "PRACTICAL" ? "View session & completion details" : "Start / resume course").font(.subheadline.weight(.semibold)).foregroundStyle(TrainingVisualStyle.cyan)
        }.workspaceCard()
    }
}

private struct WorkspaceCreditRow: View {
    let credit: TrainingWorkspaceCompletion
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("\(credit.completedAt.formatted(date: .abbreviated, time: .omitted)) · \(workspaceHours(credit.durationMinutes)) hours", systemImage: "calendar.badge.checkmark")
            Text("Recorded by \(credit.instructor ?? "Training staff")").foregroundStyle(.white.opacity(0.65))
            if let score = credit.scorePercent { Text("Quiz score: \(score)%\(credit.attemptCount.map { " · \($0) attempts" } ?? "")").foregroundStyle(TrainingVisualStyle.cyan) }
        }.font(.caption).padding(.vertical, 4)
    }
}

private struct WorkspaceBuilderSteps: View {
    let step: Int
    private let labels = ["Details", "Content & JPRs", "Review & save"]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STEP \(step + 1) OF 3").font(.caption.bold()).foregroundStyle(TrainingVisualStyle.cyan)
            HStack(alignment: .top, spacing: 8) {
                ForEach(labels.indices, id: \.self) { index in
                    VStack(spacing: 8) {
                        Text(index < step ? "✓" : "\(index + 1)").font(.subheadline.bold())
                            .frame(width: 32, height: 32).foregroundStyle(index <= step ? AppTheme.navy : .white.opacity(0.6))
                            .background(index <= step ? TrainingVisualStyle.cyan : .white.opacity(0.08), in: Circle())
                        Text(labels[index]).font(.caption.weight(.semibold)).foregroundStyle(index == step ? .white : .white.opacity(0.55))
                    }.frame(maxWidth: .infinity)
                }
            }
        }.workspaceCard()
    }
}

private extension View {
    func workspaceCard(accent: Color? = nil) -> some View {
        self.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [accent.map { $0.opacity(0.22) } ?? TrainingVisualStyle.raised, TrainingVisualStyle.surface], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1) }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }
    func workspaceInput() -> some View {
        self.textFieldStyle(.plain).foregroundStyle(.white).padding(12)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.12), lineWidth: 1) }
    }
}

// Guided training is online-only. Each observation is confirmed by the server
// before navigation is enabled; failed requests remain available for retry.
private struct GuidedInstructorHome: View {
    let workspace: TrainingWorkspaceHome
    var onMyTraining: () -> Void = {}
    var onCatalog: () -> Void = {}
    @State private var creating = false
    @State private var refreshedWorkspace: TrainingWorkspaceHome?
    private var libraryWorkspace: TrainingWorkspaceHome { refreshedWorkspace ?? workspace }
    @State private var evaluating = false
    @State private var home: GuidedHome?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var mode = "home"
    @State private var courseSearch = ""
    @State private var categoryId = ""
    @State private var assignmentOnly = false
    @State private var search = ""
    @State private var topicId = ""
    @State private var versions = Set<String>()
    @State private var selected = Set<String>()
    @State private var oneOff = false
    @State private var title = ""
    @State private var notes = ""
    @State private var scheduled = false
    @State private var date = Date()
    @State private var location = ""
    @State private var minutes = 60
    @State private var activeSession: String?
    @State private var requestId = UUID().uuidString
    @State private var error: String?
    @State private var status = ""
    @State private var busy = false
    private var topic: GuidedTopic? { home?.topics.first { $0.id == topicId } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let error { WorkspaceNotice(message: error, warning: true); if home == nil { Button("Try again") { Task { await load() } }.buttonStyle(WorkspaceActionStyle()) } }
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
            if let home {
                Menu {
                    Button("Overview") { mode = "home" }
                    Button("Training Library") { mode = "catalog" }
                    Button("Schedule & Sessions") { mode = "schedule" }
                    NavigationLink("Skills & Evaluations") { GuidedSkillsView(home: home, onEvaluate: prepareEvaluation) }
                    Button("My Training", action: onMyTraining)
                    Button("Course Catalog", action: onCatalog)
                    Button("Training Records") { mode = "history" }
                } label: { Label("Training sections", systemImage: "line.3.horizontal") }.buttonStyle(WorkspaceActionStyle())
                if mode == "catalog" { catalog(home) }
                else if mode == "home" {
                    Text("Overview").font(.title2.bold())
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                        Button { mode = "catalog" } label: { TrainingQuickAction(title: "Training Library", subtitle: "Find or create courses", symbol: "books.vertical.fill") }.buttonStyle(.plain)
                        Button { mode = "schedule" } label: { TrainingQuickAction(title: "Schedule & Sessions", subtitle: "Plan, run, or resume", symbol: "calendar", accent: TrainingVisualStyle.orange) }.buttonStyle(.plain)
                        NavigationLink { GuidedSkillsView(home: home, onEvaluate: prepareEvaluation) } label: { TrainingQuickAction(title: "Skills & Evaluations", subtitle: "Find skills and evaluate", symbol: "checkmark.seal.fill", accent: TrainingVisualStyle.mint) }.buttonStyle(.plain)
                        Button(action: onMyTraining) { TrainingQuickAction(title: "My Training", subtitle: "Personal assignments", symbol: "person.crop.circle.fill") }.buttonStyle(.plain)
                        Button(action: onCatalog) { TrainingQuickAction(title: "Course Catalog", subtitle: "Courses for your member type", symbol: "books.vertical.fill") }.buttonStyle(.plain)
                        Button { mode = "history" } label: { TrainingQuickAction(title: "Training Records", subtitle: "Results and hours", symbol: "doc.text.fill", accent: TrainingVisualStyle.lavender) }.buttonStyle(.plain)
                    }
                    Text("Pick up where you left off").font(.headline)
                    sessionRows(home.sessions.filter { $0.status == "IN_PROGRESS" })
                    Text("Upcoming sessions").font(.headline)
                    sessionRows(home.sessions.filter { $0.status == "SCHEDULED" })
                } else if mode == "start" {
                    Text(evaluating ? "Start a skills evaluation" : "Plan a training session").font(.title2.bold())
                    Picker("Training source", selection: $oneOff) { Text("Course catalog").tag(false); Text("One-off topic").tag(true) }.pickerStyle(.segmented).disabled(evaluating).onChange(of: oneOff) { _, value in if value { assignmentOnly = false } }
                    if oneOff {
                        TextField("Training topic", text: $title).workspaceInput()
                        TextField("Session notes", text: $notes, axis: .vertical).workspaceInput()
                        Text("Attendance and hours only. Practical competency requires an approved JPR.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Picker("Training course", selection: $topicId) { Text("Choose a course").tag(""); ForEach(home.topics) { Text($0.title).tag($0.id) } }.disabled(evaluating)
                            .onChange(of: topicId) { _, _ in if evaluating { return }; versions = Set(topic?.jprs.filter { v in topic?.jprs.first(where: { $0.jprId == v.jprId })?.id == v.id }.map(\.id) ?? []); minutes = topic?.durationMinutes ?? 60 }
                        if let topic {
                            DisclosureGroup("\(versions.count) JPRs selected · change selection") {
                            ForEach(topic.latestJprs) { version in
                                Toggle("\(version.content.number) · \(version.content.title) · Rev \(version.revision)", isOn: Binding(get: { versions.contains(version.id) }, set: { if $0 { versions.subtract(topic.jprs.filter { $0.jprId == version.jprId }.map(\.id)); versions.insert(version.id) } else { versions.remove(version.id) } }))
                            }
                            }.tint(TrainingVisualStyle.cyan)
                        }
                    }
                    Picker("Next step", selection: Binding(get: { assignmentOnly ? "assign" : scheduled ? "schedule" : "run" }, set: { assignmentOnly = $0 == "assign"; scheduled = $0 == "schedule" })) {

                        Text("Run now").tag("run"); Text("Schedule").tag("schedule")
                    }.pickerStyle(.segmented).disabled(evaluating)
                    Text(evaluating ? "Opens the selected skill for observed evaluation. No prior skill assignment is required." : oneOff ? "Records attendance and hours." : "Select session participants. Future course assignments and skill requirements are managed separately.").font(.caption).foregroundStyle(.white.opacity(0.65))
                    if scheduled { DatePicker("Session time", selection: $date)
                        .onChange(of: date) { _, _ in status = "Time changed. Reload the roster or check your selected participants." } }
                    if !assignmentOnly { DisclosureGroup("Session details · \(minutes) minutes") {
                        TextField("Location", text: $location).workspaceInput()
                        Stepper("\(minutes) minutes", value: $minutes, in: 5...1440, step: 5)
                    }.tint(TrainingVisualStyle.cyan) }
                    Divider()
                    Text("Participants · \(selected.count)").font(.headline)
                    Button("Load FirstDue roster at session time") { Task { await onDuty() } }.buttonStyle(WorkspaceActionStyle())
                    Menu("Add a department group") { ForEach(home.groups, id: \.name) { group in Button(group.name) { selected.formUnion(group.userIds) } } }.frame(minHeight: 44)
                    TextField("Find a firefighter", text: $search).workspaceInput()
                    if search.isEmpty {
                        if !selected.isEmpty { DisclosureGroup("Review \(selected.count) selected members") {
                            ForEach(home.members.filter { selected.contains($0.id) }) { member in memberRow(member) }
                        }.tint(TrainingVisualStyle.cyan) }
                    } else {
                        ForEach(home.members.filter { $0.name.localizedCaseInsensitiveContains(search) }) { member in memberRow(member) }
                    }
                    if selected.isEmpty && search.isEmpty { Text("Load the shift roster, choose a group, or search for members above.").font(.caption).foregroundStyle(.white.opacity(0.65)) }
                    Button(evaluating ? "Start evaluation" : scheduled ? "Schedule session" : "Start session") { Task { await start() } }.buttonStyle(WorkspaceActionStyle()).disabled(selected.isEmpty || busy || (oneOff ? title.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 : topic == nil || versions.isEmpty))
                } else {
                    Text(mode == "schedule" ? "Schedule & Sessions" : mode == "continue" ? "Continue Training" : "Training Records").font(.title2.bold())
                    let sessions = home.sessions.filter { mode == "history" ? $0.status == "FINALIZED" : mode == "schedule" ? ($0.status == "SCHEDULED" || $0.status == "IN_PROGRESS") : $0.status == "IN_PROGRESS" }
                    if sessions.isEmpty { Text("No sessions here yet.").foregroundStyle(.secondary) }
                    ForEach(sessions) { session in
                        Button { activeSession = session.id } label: { WorkspaceToolRow(title: session.title, subtitle: "\(session.participantCount) participants · \((session.startAt ?? session.updatedAt).formatted(date: .abbreviated,time: .shortened))", icon: "chevron.right") }.buttonStyle(.plain)
                    }
                    if mode == "schedule" { Button("Schedule session") { begin(); scheduled = true }.buttonStyle(WorkspaceActionStyle()); Button("Record one-off training") { begin(); oneOff = true }.buttonStyle(WorkspaceActionStyle()) }
                }
            } else if error == nil { ProgressView("Loading training…") }
            Text("Online connection required. Confirmed saved work can be resumed after an interruption.").font(.caption).foregroundStyle(.secondary)
        }.disabled(busy).task { await load() }
        .sheet(isPresented: $creating, onDismiss: { Task { await load() } }) { NavigationStack { WorkspaceCourseBuilder(members: libraryWorkspace.members) } }
        .navigationDestination(isPresented: Binding(get: { activeSession != nil }, set: { if !$0 { activeSession = nil; Task { await load() } } })) { if let activeSession { GuidedSessionView(id: activeSession) } }
    }
    private func prepareEvaluation(_ course: GuidedTopic, _ version: GuidedVersion, _ members: [String]) {
        choose(course); evaluating = true; versions = [version.id]; selected = Set(members)
    }
    private func sessionRows(_ sessions: [GuidedHistory]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if sessions.isEmpty { Text("No sessions here yet.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(sessions) { session in Button { activeSession = session.id } label: { WorkspaceToolRow(title: session.title, subtitle: "\(session.participantCount) participants · \(session.status == "SCHEDULED" ? "Scheduled" : "In progress")", icon: "calendar") }.buttonStyle(.plain) }
        }
    }
    private func memberRow(_ member: GuidedMember) -> some View {
        Toggle(member.name, isOn: Binding(get: { selected.contains(member.id) }, set: { if $0 { selected.insert(member.id) } else { selected.remove(member.id) } })).workspaceCard()
    }
    private func choose(_ course: GuidedTopic) {
        begin(); topicId = course.id; versions = Set(course.latestJprs.map(\.id)); minutes = course.durationMinutes
    }
    private func catalog(_ home: GuidedHome) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            TrainingMetricStrip(stats: [
                TrainingHeaderStat(label: "Ready courses", value: "\(home.topics.count)"),
                TrainingHeaderStat(label: "Scheduled", value: "\(home.sessions.filter { $0.status == "SCHEDULED" }.count)", accent: TrainingVisualStyle.orange),
                TrainingHeaderStat(label: "To resume", value: "\(home.sessions.filter { $0.status == "IN_PROGRESS" }.count)", accent: TrainingVisualStyle.lavender)
            ])
            if libraryWorkspace.canCreate {
                Button("Create training") { creating = true }.buttonStyle(WorkspaceActionStyle(primary: true))
                DisclosureGroup("Library tools") { NavigationLink("Bulk import Word JPRs") { GuidedLibraryView(workspace: libraryWorkspace) } }
            }
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(TrainingVisualStyle.cyan)
                TextField("Search courses or JPRs", text: $courseSearch).autocorrectionDisabled()
            }.workspaceCard()
            let categories = (home.topics.compactMap(\.category) + (home.pendingCourses ?? []).compactMap(\.category)).reduce(into: [String:String]()) { $0[$1.id] = $1.name }
            let courses = home.topics.filter { $0.matches(search: courseSearch, categoryId: categoryId) }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { catalogHeading; categoryPicker(categories) }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack { catalogHeading; Spacer(minLength: 8); categoryPicker(categories) }
                    VStack(alignment: .leading, spacing: 8) { catalogHeading; categoryPicker(categories) }
                }
            }
            if !courseSearch.isEmpty || !categoryId.isEmpty { Text("\(courses.count) matching courses").font(.caption).foregroundStyle(.white.opacity(0.7)) }
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 300), alignment: .top)], spacing: 16) {
                ForEach(courses) { course in GuidedCatalogCourseCard(course: course, members: libraryWorkspace.members, canManage: libraryWorkspace.manageCourses.contains(where: { $0.id == course.id }), canReview: libraryWorkspace.canCreate) { choose(course) } }
            }
            if courses.isEmpty { WorkspacePanel { Text(home.topics.isEmpty ? "No courses ready yet" : "No matching courses").font(.headline); Text(home.topics.isEmpty ? "Published courses with approved JPRs appear here." : "Try a course name, JPR number, or another category.").font(.subheadline).foregroundStyle(.white.opacity(0.65)) } }
            ForEach((home.pendingCourses ?? []).filter { (categoryId.isEmpty || $0.category?.id == categoryId) && (courseSearch.isEmpty || $0.title.localizedCaseInsensitiveContains(courseSearch)) }) { course in
                WorkspacePanel { Text(course.title).font(.headline); WorkspaceBadge(text: "JPR REVIEW PENDING"); Text("\(course.totalJprs) JPRs awaiting review. Guided training becomes available after approval.").font(.caption).foregroundStyle(.white.opacity(0.65)); if home.canCreate { NavigationLink("Review this course’s JPRs") { GuidedLibraryView(workspace: libraryWorkspace, initialCourseId: course.id) }.tint(TrainingVisualStyle.cyan) } }
            }
            ForEach(libraryWorkspace.manageCourses.filter { course in course.delivery != "LEGACY" && course.status != "ARCHIVED" && !home.topics.contains(where: { $0.id == course.id }) }) { course in
                NavigationLink { WorkspaceCourseView(course: TrainingWorkspaceCourse(id: course.id, title: course.title, description: nil, delivery: course.delivery, archived: false, assigned: false, progressStatus: "NOT_STARTED", completedAt: nil, dueAt: nil, durationMinutes: nil, creditedMinutes: 0, pendingForm: false), members: libraryWorkspace.members, manage: true, allowJprReview: libraryWorkspace.canCreate) } label: { WorkspaceToolRow(title: course.title, subtitle: course.status == "DRAFT" ? "Continue draft · content & JPRs" : "Course details · assignments & records", icon: "doc.text") }.buttonStyle(.plain)
            }
        }
    }
    private var catalogHeading: some View {
        Text("Training Library").font(.title3.bold()).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
    }
    private func categoryPicker(_ categories: [String: String]) -> some View {
        Picker("Category", selection: $categoryId) {
            Text("All categories").tag("")
            ForEach(categories.keys.sorted { (categories[$0] ?? "") < (categories[$1] ?? "") }, id: \.self) { id in Text(categories[id] ?? id).tag(id) }
        }.pickerStyle(.menu).tint(TrainingVisualStyle.cyan)
    }
    private func begin() { evaluating = false; assignmentOnly = false; mode = "start"; selected = []; versions = []; topicId = ""; search = ""; title = ""; notes = ""; oneOff = false; scheduled = false; date = Date(); status = ""; requestId = UUID().uuidString }
    @MainActor private func load() async { do { async let guided: GuidedHome = APIClient.shared.trainingWorkspace("/guided"); async let fresh: TrainingWorkspaceHome = APIClient.shared.trainingWorkspace(); let result = try await (guided, fresh); home = result.0; refreshedWorkspace = result.1; error = nil } catch { if !APIClient.isRequestCancellation(error) { self.error = error.localizedDescription } } }
    @MainActor private func onDuty() async {
        busy = true; defer { busy = false }
        let at = ISO8601DateFormatter().string(from: date).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        do { let result: GuidedDuty = try await APIClient.shared.trainingWorkspace("/guided?onDuty=1&at=\(at)"); selected = Set(result.userIds.filter { id in home?.members.contains { $0.id == id } == true }); if selected.isEmpty { error = "No eligible roster was returned for this time. Select participants by name." } else { error = nil; status = "Roster loaded. Adjust absences and covering members." } } catch { self.error = error.localizedDescription }
    }
    @MainActor private func start() async {
        busy = true; defer { busy = false }
        do {
            var values: [String: Any] = ["assignSkills": false, "requestId": requestId, "participantIds": Array(selected), "oneOff": oneOff, "scheduled": scheduled, "startAt": ISO8601DateFormatter().string(from: date), "location": location, "durationMinutes": minutes]
            if oneOff { values["title"] = title; values["notes"] = notes } else { values["courseId"] = topicId; values["versionIds"] = Array(versions) }
            let result: GuidedMutation = try await APIClient.shared.trainingWorkspace("/guided", body: JSONSerialization.data(withJSONObject: values))
            if scheduled { mode = "schedule"; status = "Scheduled. No credit awarded."; await load() }
            else if let id = result.sessionId {
                if evaluating {
                    let current: GuidedSessionResponse = try await APIClient.shared.trainingWorkspace("/guided/\(id)")
                    if current.session.stage != "EVALUATE" { let _: GuidedMutation = try await APIClient.shared.trainingWorkspace("/guided/\(id)", body: JSONSerialization.data(withJSONObject: ["revision": current.session.revision, "stage": "EVALUATE"])) }
                }
                activeSession = id
            }
            requestId = UUID().uuidString
        } catch { self.error = error.localizedDescription }
    }
}

private struct GuidedSessionView: View {
    let id: String
    @Environment(\.dismiss) private var dismiss
    @State private var editingSchedule = false
    @State private var deletingSchedule = false
    @State private var session: GuidedSession?
    @State private var error: String?
    @State private var saved = ""
    @State private var busy = false
    @State private var pending: Data?
    @State private var commentDraft: String?
    @State private var commenting: GuidedMember?
    @State private var individual = ""
    @State private var duration = ""
    @State private var confirmReload = false
    @State private var printHTML: String?
    var body: some View {
        AppScreen(title: session?.title ?? "Training", subtitle: "Approved JPR guidance", systemImage: "graduationcap.fill") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let error { WorkspaceNotice(message: error, warning: true) }
                    if pending != nil { Button("Retry saving") { Task { await retry() } }.buttonStyle(WorkspaceActionStyle()); Button("Reload last saved session") { confirmReload = true } }
                    Text(busy ? "Saving…" : saved).font(.caption).foregroundStyle(TrainingVisualStyle.cyan).accessibilityLabel(busy ? "Saving" : saved)
                    if let s = session {
                        if s.status == "SCHEDULED" {
                            Text("Scheduled training").font(.title2.bold())
                            if let date = s.startAt { Text(date.formatted(date: .abbreviated, time: .shortened)) }
                            if let location = s.location { Text(location) }
                            Text("\(s.participants.count) participants · No credit awarded until training is recorded.")
                            Button("Edit schedule") { editingSchedule = true }.buttonStyle(WorkspaceActionStyle()).disabled(blocked)
                            Button("Delete scheduled training", role: .destructive) { deletingSchedule = true }.frame(minHeight: 44).disabled(blocked)
                            Button("Begin scheduled training") { Task { await save(["begin": true]) } }.buttonStyle(WorkspaceActionStyle()).disabled(blocked)
                        } else if s.oneOff == true { summary(s) }
                        else if s.jprs.indices.contains(s.jprIndex), s.jprs[s.jprIndex].content.steps.indices.contains(s.stepIndex) {
                        if s.locked || s.stage == "SUMMARY" { summary(s) }
                        else { guide(s, version: s.jprs[s.jprIndex], step: s.jprs[s.jprIndex].content.steps[s.stepIndex]) }
                        }
                        Text("Online connection required. Changes are saved only after confirmation. Final evaluations are locked; use Start Training for reevaluation.").font(.caption).foregroundStyle(.secondary)
                    } else if error == nil { ProgressView("Loading saved session…") }
                }.padding(16)
            }
        }.trainingDestinationNavigation(blocked: busy || pending != nil || commentDraft != nil || durationDirty)
        .navigationBarBackButtonHidden(busy || pending != nil || commentDraft != nil || durationDirty)
        .interactiveDismissDisabled(busy || pending != nil || commentDraft != nil || durationDirty)
        .task { await load() }
        .sheet(isPresented: $editingSchedule) {
            if let session { NavigationStack { GuidedScheduleEditor(session: session) { Task { await load() } } } }
        }
        .confirmationDialog("Delete scheduled training?", isPresented: $deletingSchedule, titleVisibility: .visible) {
            Button("Delete scheduled training", role: .destructive) { Task { await deleteSchedule() } }
            Button("Keep scheduled training", role: .cancel) { }
        } message: { Text("Remove this scheduled session? This cannot be undone. Existing course and skill assignments remain.") }
        .alert("Reload last saved session?", isPresented: $confirmReload) { Button("Cancel",role:.cancel) {}; Button("Discard unconfirmed change",role:.destructive) { pending = nil; Task { await load() } } } message: { Text("Only confirmed saved work will be restored.") }
        .sheet(item: $commenting) { member in
            NavigationStack { Form {
                Text(member.name)
                if let error {Text(error).foregroundStyle(.red)}
                TextField("Comment or reason", text: Binding(get:{commentDraft ?? ""},set:{commentDraft=$0}),axis:.vertical).lineLimit(3...8)
                if let s=session { let v=s.jprs[s.jprIndex]; let step=v.content.steps[s.stepIndex]
                    ForEach(["PASS","NEEDS_WORK","NOT_EVALUATED"],id:\.self) { rating in
                        Button(rating == "PASS" ? "Pass" : rating == "NEEDS_WORK" ? "Needs work" : "Not evaluated") {
                            let text=commentDraft ?? ""
                            if step.critical && rating == "NEEDS_WORK" && text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { error="A reason is required for a critical safety failure."; return }
                            commenting=nil; commentDraft=nil
                            Task { await save(["observation":["versionId":v.id,"stepId":step.id,"userId":member.id,"rating":rating,"comment":text]]) }
                        }.frame(minHeight:44)
                    }
                }
            }.navigationTitle("Observed performance").toolbar { Button("Cancel") { commenting=nil;commentDraft=nil } }.interactiveDismissDisabled()
            }
        }
        .sheet(isPresented: Binding(get:{printHTML != nil},set:{if !$0 {printHTML=nil}})) { if let printHTML { NavigationStack { GuidedPrintSheet(html:printHTML).toolbar { Button("Done") { self.printHTML=nil } } } } }
    }
    private var durationDirty: Bool { guard let s=session else{return false}; return !duration.isEmpty && duration != String(s.durationMinutes) }
    private var blocked: Bool { busy || pending != nil || durationDirty }
    private func stages(_ s: GuidedSession) -> some View {
        ScrollView(.horizontal,showsIndicators:false) { HStack {
            ForEach(["TEACH","PRACTICE","EVALUATE","SUMMARY"],id:\.self) { stage in Button(stage == "SUMMARY" ? "Review & save" : stage) { Task { await save(["stage":stage]) } }.buttonStyle(WorkspaceActionStyle()).disabled(blocked || s.locked).opacity(s.stage == stage ? 1 : 0.65) }
        } }
    }
    private func guide(_ s: GuidedSession, version: GuidedVersion, step: GuidedStep) -> some View {
        VStack(alignment:.leading,spacing:18) {
            stages(s)
            DisclosureGroup("JPR objective, equipment & instructor guidance") {
                Text(version.content.objective)
                Text("Conditions: \(version.content.conditions)")
                Text("Equipment: \(version.content.equipment)")
                Text(version.content.guidance)
                Text("SOPs & standards: \(version.content.standards)")
            }
            Text("\(version.content.number) · Approved revision \(version.revision) · JPR \(s.jprIndex+1) of \(s.jprs.count)").font(.subheadline).foregroundStyle(TrainingVisualStyle.cyan)
            Text("STEP \(s.stepIndex+1) OF \(version.content.steps.count)").font(.headline)
            ProgressView(value:Double(s.stepIndex+1),total:Double(version.content.steps.count)).tint(TrainingVisualStyle.cyan)
            Text(step.title).font(.title2.bold())
            if s.stage == "PRACTICE" { Text("Supervised practice. Practice does not record a passing evaluation.") }
            guidance("TEACH",step.teach);guidance("SHOW",step.show);guidance("CHECK",step.check)
            if step.critical || !step.safety.isEmpty { TrainingSafetyNotice(text: step.safety, critical: step.critical) }
            if s.stage == "EVALUATE" {
                Picker("Evaluation view",selection:$individual) { Text("All participants").tag("");ForEach(s.participants) { Text($0.name).tag($0.id) } }
                ForEach(s.participants.filter { $0.attended != false && (individual.isEmpty || individual == $0.id) }) { member in
                    observation(s,version:version,step:step,member:member)
                }
            }
            HStack {
                Button("Back") { let ji=s.stepIndex > 0 ? s.jprIndex : s.jprIndex-1;Task { await save(["jprIndex":ji,"stepIndex":s.stepIndex > 0 ? s.stepIndex-1 : s.jprs[ji].content.steps.count-1]) } }.disabled(blocked || (s.stepIndex == 0 && s.jprIndex == 0))
                Spacer()
                Button("Next step") { Task { await next(s) } }.disabled(blocked)
            }.buttonStyle(WorkspaceActionStyle())
            Button("Print approved JPR") { Task { await printVersion(version.id) } }.disabled(blocked)
        }
    }
    private func guidance(_ title:String,_ text:String) -> some View { VStack(alignment:.leading,spacing:8){Text(title).font(.headline).foregroundStyle(TrainingVisualStyle.cyan);Text(text).font(.body).fixedSize(horizontal:false,vertical:true)} }
    private func observation(_ s:GuidedSession,version:GuidedVersion,step:GuidedStep,member:GuidedMember) -> some View {
        let current=s.observations[s.key(version,step,member)]
        return WorkspacePanel {
            Text(member.name).font(.headline)
            Text(current?.rating == "PASS" ? "Pass" : current?.rating == "NEEDS_WORK" ? (step.critical ? "⚠ Critical safety failure" : "⚠ Needs work") : "Not evaluated").foregroundStyle(current?.rating == "NEEDS_WORK" ? Color(red:1,green:0.61,blue:0.61) : TrainingVisualStyle.cyan)
            ViewThatFits(in:.horizontal) { ratings(s,version:version,step:step,member:member,current:current,horizontal:true);ratings(s,version:version,step:step,member:member,current:current,horizontal:false) }
            Button("Comment / reason") { commentDraft=current?.comment ?? "";commenting=member }.frame(minHeight:44).disabled(blocked)
            if let comment=current?.comment,!comment.isEmpty { Text(comment).font(.subheadline) }
        }
    }
    @ViewBuilder private func ratings(_ s:GuidedSession,version:GuidedVersion,step:GuidedStep,member:GuidedMember,current:GuidedObservation?,horizontal:Bool) -> some View {
        let layout=horizontal ? AnyLayout(HStackLayout(spacing:8)) : AnyLayout(VStackLayout(alignment:.leading,spacing:8))
        layout { ForEach(["PASS","NEEDS_WORK","NOT_EVALUATED"],id:\.self) { rating in
            Button(rating == "PASS" ? "Pass" : rating == "NEEDS_WORK" ? "Needs work" : "Not evaluated") {
                if step.critical && rating == "NEEDS_WORK" { commentDraft=current?.comment ?? "";commenting=member }
                else { Task { await save(["observation":["versionId":version.id,"stepId":step.id,"userId":member.id,"rating":rating,"comment":current?.comment ?? ""]]) } }
            }.buttonStyle(WorkspaceActionStyle(danger: rating == "NEEDS_WORK")).disabled(blocked)
        } }
    }
    private func summary(_ s:GuidedSession) -> some View {
        let attended=s.participants.filter{$0.attended != false}
        let passed=s.oneOff == true ? 0 : attended.filter{m in s.jprs.allSatisfy{s.outcome($0,m)=="Passed"}}.count
        return VStack(alignment:.leading,spacing:18) {
            Text("Training summary").font(.title2.bold())
            if s.jprs.contains(where: { v in v.content.steps.contains(where: { step in step.critical && attended.contains(where: { s.observations[s.key(v,step,$0)]?.rating == "NEEDS_WORK" }) }) }) { TrainingSafetyNotice(text: "Critical safety failures were recorded. Review the affected members and instructor feedback. These evaluations do not pass.", critical: true) }
            if s.oneOff == true { Text("\(attended.count) attended · Attendance and hours only"); if let notes = s.notes { Text(notes) } } else { Text("\(attended.count) attended · \(passed) passed required JPRs · \(attended.count-passed) need additional training or evaluation") }
            if !s.locked {
                HStack { TextField("Training minutes",text:$duration).keyboardType(.numberPad).textFieldStyle(.roundedBorder).disabled(busy || pending != nil);Button("Save duration") { Task { await save(["durationMinutes":Int(duration) ?? 0]) } }.disabled(busy || pending != nil || !durationDirty) }
            } else { Text("\(s.durationMinutes) minutes of training") }
            ForEach(s.participants) { member in
                WorkspacePanel {
                    Toggle(member.name,isOn:Binding(get:{member.attended != false},set:{value in Task {await save(["attendance":[member.id:value]])}})).disabled(blocked || s.locked)
                    ForEach(s.jprs) { v in
                        DisclosureGroup("\(v.content.number): \(member.attended == false ? "Absent" : s.outcome(v,member))") {
                            ForEach(v.content.steps) { step in
                                let observation=s.observations[s.key(v,step,member)]
                                Text("\(step.critical ? "⚠ Critical Safety · " : "")\(step.title): \(observation?.rating == "PASS" ? "Pass" : observation?.rating == "NEEDS_WORK" ? "Needs work" : "Not evaluated")").foregroundStyle(observation?.rating == "NEEDS_WORK" ? Color(red:1,green:0.61,blue:0.61) : .white)
                                if let comment=observation?.comment,!comment.isEmpty {Text(comment).font(.caption)}
                            }
                        }
                    }
                }
            }
            if !s.locked { Button("Save Training") {Task {await save(["finalize":true])}}.buttonStyle(WorkspaceActionStyle()).disabled(blocked);if s.oneOff != true {stages(s)} }
            else { Text("Training saved. Available for FirstDue CSV export; import has not been confirmed.").foregroundStyle(TrainingVisualStyle.cyan) }
            Text("Attendance records training hours. Unobserved performance stays incomplete.").font(.caption)
        }
    }
    @MainActor private func deleteSchedule() async {
        guard let session, session.status == "SCHEDULED", !blocked else { return }
        busy = true; defer { busy = false }
        do {
            let _: GuidedMutation = try await APIClient.shared.trainingWorkspace("/guided/\(id)", body: JSONSerialization.data(withJSONObject: ["action":"deleteSchedule", "revision":session.revision,"confirmed":true]))
            dismiss()
        } catch APIClient.APIError.serverError(let code, _) where code == 404 { dismiss() }
        catch { self.error = error.localizedDescription }
    }
    @MainActor private func load() async { busy=true;defer{busy=false};do {let result:GuidedSessionResponse=try await APIClient.shared.trainingWorkspace("/guided/\(id)");session=result.session;duration=String(result.session.durationMinutes);error=nil;saved="Saved session loaded"}catch{if !APIClient.isRequestCancellation(error){self.error=error.localizedDescription}} }
    @MainActor private func save(_ change:[String:Any]) async {
        guard let s=session,!busy,pending==nil else{return}
        do { var body=change;body["revision"]=s.revision;pending=try JSONSerialization.data(withJSONObject:body);await retry() }catch{self.error=error.localizedDescription}
    }
    @MainActor private func retry() async {
        guard let body=pending,!busy else{return};busy=true;saved="";error=nil;defer{busy=false}
        do { let _:GuidedMutation=try await APIClient.shared.trainingWorkspace("/guided/\(id)",body:body);let result:GuidedSessionResponse=try await APIClient.shared.trainingWorkspace("/guided/\(id)");session=result.session;duration=String(result.session.durationMinutes);pending=nil;saved=result.session.locked ? "Training saved" : "Saved" }
        catch { self.error=error.localizedDescription+" Changes are not confirmed saved. Stay here and retry. Offline training is not supported." }
    }
    @MainActor private func next(_ s:GuidedSession) async {
        if s.stepIndex+1 < s.jprs[s.jprIndex].content.steps.count {await save(["stepIndex":s.stepIndex+1])}
        else if s.jprIndex+1 < s.jprs.count {await save(["jprIndex":s.jprIndex+1,"stepIndex":0])}
        else {await save(["stage":s.stage=="TEACH" ? "PRACTICE" : s.stage=="PRACTICE" ? "EVALUATE" : "SUMMARY","jprIndex":0,"stepIndex":0])}
    }
    @MainActor private func printVersion(_ version:String) async {do{printHTML=try await APIClient.shared.guidedJPRPrint(version)}catch{self.error=error.localizedDescription}}
}

private struct GuidedScheduleEditor: View {
    let session: GuidedSession
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var location: String
    @State private var minutes: Int
    @State private var selected: Set<String>
    @State private var members: [GuidedMember] = []
    @State private var search = ""
    @State private var busy = false
    @State private var error: String?
    @State private var discard = false
    init(session: GuidedSession, onSaved: @escaping () -> Void) {
        self.session = session; self.onSaved = onSaved
        _date = State(initialValue: session.startAt ?? Date())
        _location = State(initialValue: session.location ?? "")
        _minutes = State(initialValue: session.durationMinutes)
        _selected = State(initialValue: Set(session.participants.map(\.id)))
    }
    private var dirty: Bool { date != session.startAt || location != (session.location ?? "") || minutes != session.durationMinutes || selected != Set(session.participants.map(\.id)) }
    var body: some View {
        Form {
            Section(session.title) {
                DatePicker("Date and time", selection: $date)
                TextField("Location", text: $location)
                TextField("Duration (minutes)", value: $minutes, format: .number).keyboardType(.numberPad)
            }
            Section("Participants · \(selected.count) selected") {
                TextField("Find a firefighter", text: $search).autocorrectionDisabled()
                ForEach((members.isEmpty ? session.participants : members).filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { member in
                    Toggle(member.name, isOn: Binding(get: { selected.contains(member.id) }, set: { if $0 { selected.insert(member.id) } else { selected.remove(member.id) } }))
                }
            }
            Section { Text("Changes update this session’s roster. Existing course and skill assignments remain.").font(.caption) }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            Section { Button(busy ? "Saving…" : "Save schedule changes") { Task { await save() } }.disabled(busy || selected.isEmpty || !dirty || !(1...1440).contains(minutes)) }
        }
        .navigationTitle("Edit schedule").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if dirty { discard = true } else { dismiss() } }.disabled(busy) } }
        .disabled(busy).interactiveDismissDisabled(dirty || busy)
        .confirmationDialog("Discard schedule changes?", isPresented: $discard, titleVisibility: .visible) { Button("Discard changes", role: .destructive) { dismiss() }; Button("Keep editing", role: .cancel) { } }
        .task { do { let home: GuidedHome = try await APIClient.shared.trainingWorkspace("/guided"); members = home.members } catch { if !APIClient.isRequestCancellation(error) { self.error = error.localizedDescription } } }
    }
    @MainActor private func save() async {
        busy = true; defer { busy = false }
        do {
            let body: [String:Any] = ["action":"editSchedule","revision":session.revision,"startAt":ISO8601DateFormatter().string(from:date),"location":location,"durationMinutes":minutes,"participantIds":Array(selected)]
            let _: GuidedMutation = try await APIClient.shared.trainingWorkspace("/guided/\(session.id)", body: JSONSerialization.data(withJSONObject:body))
            onSaved(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

private struct GuidedPrintSheet:UIViewControllerRepresentable {
    let html:String
    func makeUIViewController(context:Context)->GuidedPrintController {GuidedPrintController(html:html)}
    func updateUIViewController(_ uiViewController:GuidedPrintController,context:Context){}
}
private final class GuidedPrintController:UIViewController {
    private let html:String
    private var presentedPrint=false
    init(html:String){self.html=html;super.init(nibName:nil,bundle:nil)}
    required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
    override func viewDidAppear(_ animated:Bool){
        super.viewDidAppear(animated)
        guard !presentedPrint else{return};presentedPrint=true
        let controller=UIPrintInteractionController.shared
        controller.printFormatter=UIMarkupTextPrintFormatter(markupText:html)
        controller.present(from:view.bounds,in:view,animated:true,completionHandler:nil)
    }
}

private struct GuidedMemberResults:View {
    @State private var results:GuidedResults?
    @State private var error:String?
    var body:some View {VStack(alignment:.leading,spacing:16){
        NavigationLink("My Skills Progress & Upcoming Training") { GuidedSkillsView() }.buttonStyle(WorkspaceActionStyle())
        if let error {WorkspaceNotice(message:error,warning:true)}
        if let results {if results.results.isEmpty{Text("No JPR evaluations yet.")};ForEach(results.results){result in WorkspacePanel {
            Text("\(result.number) · \(result.title)").font(.headline)
            Text(result.outcome=="PASS" ? "Passed" : result.outcome=="FAIL" ? "Needs additional training" : "Incomplete").foregroundStyle(TrainingVisualStyle.cyan)
            Text("Revision \(result.revision) · \(result.evaluator)").font(.caption)
            if let date=result.completedAt {Text(date.formatted(date:.abbreviated,time:.shortened)).font(.caption)}
            ForEach(result.steps?.steps ?? [],id:\.stepId){step in Text("\(step.title ?? step.stepId): \(step.rating=="PASS" ? "Pass" : step.rating=="NEEDS_WORK" ? "Needs work" : "Not evaluated")");if !step.comment.isEmpty{Text(step.comment).font(.caption)}}
        }}}else if error==nil {ProgressView("Loading JPR results…")}
    }.task{do{results=try await APIClient.shared.trainingWorkspace("/jpr-results")}catch{if !APIClient.isRequestCancellation(error){self.error=error.localizedDescription}}}}
}

private struct GuidedLibraryView:View {
    var workspace:TrainingWorkspaceHome? = nil
    var initialCourseId = ""
    var keepCourseDraft = false
    @State private var library:GuidedLibrary?
    @State private var courseId=""
    @State private var importing=false
    @State private var selected:GuidedVersion?
    @State private var busy=false
    @State private var error:String?
    @State private var selectedDrafts=Set<String>()
    @State private var confirmingBatch=false
    @State private var reviewSearch=""
    @State private var status=""
    private var shown: [GuidedVersion] { (library?.versions ?? []).filter { (courseId.isEmpty || $0.courseId==courseId) && (reviewSearch.isEmpty || "\($0.content.number) \($0.content.title)".localizedCaseInsensitiveContains(reviewSearch)) }.sorted { $0.content.number.localizedStandardCompare($1.content.number) == .orderedAscending } }
    private func ready(_ version:GuidedVersion)->Bool { version.status=="DRAFT" && version.reviewToken != nil && version.approvalIssue == nil }
    private var selectedVersions:[GuidedVersion] { (library?.versions ?? []).filter { selectedDrafts.contains($0.id) && ready($0) } }
    var body:some View {
        ScrollView {VStack(alignment:.leading,spacing:18){
            Text(initialCourseId.isEmpty ? "Bulk import Word JPRs" : "Content & JPRs").font(.title.bold())
            Text("Review saved drafts, select ready JPRs, and approve them together. Approved revisions are locked.")
            if let error{WorkspaceNotice(message:error,warning:true)}
            if !status.isEmpty { WorkspaceNotice(message:status) }
            if initialCourseId.isEmpty { Picker("Training topic",selection:$courseId){Text("All courses / new course per document").tag("");ForEach(workspace?.manageCourses ?? []){Text($0.title).tag($0.id)}} }
            if keepCourseDraft { Text("JPR approval keeps this course in draft. Return to Review & save when you are ready to publish; assignments are optional.").font(.subheadline) }
            Button("Upload Word JPRs (.docx)"){importing=true}.buttonStyle(WorkspaceActionStyle()).disabled(busy)
            Text("Word documents up to 4 MB. Imports always start as drafts. Older .doc files must first be saved as .docx.").font(.caption)
            TextField("Find a JPR by number or title",text:$reviewSearch).workspaceInput()
            if library != nil {
                Button("Select all ready drafts shown") { selectedDrafts.formUnion(shown.filter { ready($0) && !selectedDrafts.contains($0.id) }.map(\.id).prefix(max(0,100-selectedDrafts.count))) }.buttonStyle(WorkspaceActionStyle()).disabled(busy)
                HStack {
                    Button("Clear selection") { selectedDrafts=[] }.disabled(selectedDrafts.isEmpty || busy)
                    Spacer()
                    Button("Approve selected (\(selectedVersions.count))") { confirmingBatch=true }.disabled(selectedVersions.isEmpty || busy)
                }.frame(minHeight:44)
                Text("Select up to 100 saved, reviewed drafts. Incomplete JPRs remain flagged for review.").font(.caption)
                ForEach(shown) { version in
                    HStack(alignment:.top,spacing:10) {
                        if version.status=="DRAFT" {
                            Button { if selectedDrafts.contains(version.id) { selectedDrafts.remove(version.id) } else { selectedDrafts.insert(version.id) } } label: { Image(systemName:selectedDrafts.contains(version.id) ? "checkmark.square.fill" : "square").font(.title2).frame(width:44,height:48) }
                                .accessibilityLabel("Select JPR \(version.content.number) revision \(version.revision)")
                                .accessibilityAddTraits(selectedDrafts.contains(version.id) ? .isSelected : [])
                                .disabled(busy || !ready(version) || (!selectedDrafts.contains(version.id) && selectedDrafts.count>=100))
                        }
                        VStack(alignment:.leading,spacing:6) {
                            Button{selected=version}label:{WorkspaceToolRow(title:"\(version.content.number) · \(version.content.title)",subtitle:"Revision \(version.revision) · \(version.status=="APPROVED" ? "Approved" : "Draft — review required")",icon:"doc.text")}.buttonStyle(.plain)
                            if version.status=="DRAFT",let issue=version.approvalIssue { Text("Needs review: \(issue)").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }else if error==nil{ProgressView()}
        }.padding(16)}.navigationTitle("JPR management").trainingDestinationNavigation(blocked: busy).disabled(busy).task{courseId = initialCourseId; await load()}
        .fileImporter(isPresented:$importing,allowedContentTypes:[UTType(filenameExtension:"docx") ?? .data],allowsMultipleSelection:true){result in
            switch result{case .success(let urls):Task{for url in urls {await upload(url)}};case .failure(let error):self.error=error.localizedDescription}
        }
        .onChange(of:courseId) { _,_ in selectedDrafts=[] }
        .sheet(isPresented:$confirmingBatch) {
            NavigationStack {
                List {
                    Section { Text(keepCourseDraft ? "Review all instructions and safety requirements. Approval locks the JPRs; the course stays a draft." : "Confirm you reviewed the instructions, evaluation steps, and safety requirements. Approval locks these revisions and publishes their draft practical courses.") }
                    Section("\(selectedVersions.count) JPR revisions") {
                        ForEach(selectedVersions) { version in
                            VStack(alignment:.leading,spacing:5) {
                                Text("\(version.content.number) · \(version.content.title)").font(.headline)
                                Text("Revision \(version.revision) · \(workspace?.manageCourses.first { $0.id==version.courseId }?.title ?? "Training course")").font(.caption)
                            }
                        }
                    }
                    Section { Text("If a selected draft changed or is incomplete, none will be approved.").font(.caption);Button(busy ? "Approving…" : "Confirm approval") { Task { await approveSelected() } }.disabled(busy || selectedVersions.isEmpty) }
                }.navigationTitle("Approve selected JPRs?").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { confirmingBatch=false }.disabled(busy) } }
                    .disabled(busy).interactiveDismissDisabled(busy)
            }
        }
        .sheet(item:$selected,onDismiss:{Task{await load()}}){version in NavigationStack{GuidedJPREditor(version:version, keepCourseDraft:keepCourseDraft)}}
    }
    @MainActor private func load()async{do{library=try await APIClient.shared.trainingWorkspace("/jprs");selectedDrafts=selectedDrafts.filter { id in library?.versions.contains { $0.id==id && ready($0) } == true };error=nil}catch{if !APIClient.isRequestCancellation(error){self.error=error.localizedDescription}}}
    @MainActor private func approveSelected()async {
        guard !selectedVersions.isEmpty,!busy else{return}
        busy=true;defer{busy=false};error=nil;status=""
        let count=selectedVersions.count
        do {
            let body:[String:Any]=["action":"approveBatch","confirmed":true,"publish":!keepCourseDraft,"versions":selectedVersions.map { ["id":$0.id,"reviewToken":$0.reviewToken ?? ""] }]
            let _:GuidedMutation=try await APIClient.shared.trainingWorkspace("/jprs",body:JSONSerialization.data(withJSONObject:body))
            confirmingBatch=false;selectedDrafts=[];await load();status="\(count) JPR revisions approved and locked."
        }catch{let message=error.localizedDescription;confirmingBatch=false;selectedDrafts=[];await load();self.error=message}
    }
    @MainActor private func upload(_ url:URL)async{
        busy=true;defer{busy=false};let scoped=url.startAccessingSecurityScopedResource();defer{if scoped{url.stopAccessingSecurityScopedResource()}}
        do{let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0;guard size>0,size<=4*1024*1024 else{throw NSError(domain:"JPR",code:1,userInfo:[NSLocalizedDescriptionKey:"Choose a Word document up to 4 MB."])}
            let result=try await APIClient.shared.uploadGuidedJPR(data:Data(contentsOf:url),fileName:url.lastPathComponent,courseId:courseId);selected=result.version;await load()
        }catch{self.error=error.localizedDescription}
    }
}
private struct GuidedJPREditor:View {
    let version:GuidedVersion
    let keepCourseDraft:Bool
    @Environment(\.dismiss)private var dismiss
    @State private var content:GuidedContent
    @State private var busy=false
    @State private var error:String?
    @State private var status=""
    @State private var confirmApproval=false
    @State private var confirmDiscard=false
    @State private var dirty=false
    init(version:GuidedVersion,keepCourseDraft:Bool=false){self.version=version;self.keepCourseDraft=keepCourseDraft;_content=State(initialValue:version.content)}
    var body:some View {
        Form{
            if let error{Text(error).foregroundStyle(.red)}
            if !status.isEmpty{Text(status)}
            if let original=content.importedText,!original.isEmpty {DisclosureGroup("Original Word text for review"){Text(original).font(.caption)}}
            Section("Department JPR · Revision \(version.revision)"){
                TextField("JPR number",text:$content.number);TextField("Title",text:$content.title);TextField("Category",text:$content.category)
                TextField("Performance objective",text:$content.objective,axis:.vertical)
                TextField("Conditions",text:$content.conditions,axis:.vertical);TextField("Required equipment",text:$content.equipment,axis:.vertical)
                TextField("Instructor guidance",text:$content.guidance,axis:.vertical);TextField("SOPs and standards",text:$content.standards,axis:.vertical)
                TextField("Revision notes",text:$content.revisionNotes,axis:.vertical)
                Stepper("Passing score: \(content.passingScore)%",value:$content.passingScore,in:1...100)
            }.disabled(version.status=="APPROVED" || busy)
            ForEach($content.steps){$step in Section(step.title.isEmpty ? "Performance step" : step.title){
                if step.critical { TrainingSafetyNotice(text: step.safety, critical: true) }
                TextField("Step title",text:$step.title);TextField("TEACH",text:$step.teach,axis:.vertical);TextField("SHOW",text:$step.show,axis:.vertical);TextField("CHECK",text:$step.check,axis:.vertical);TextField("SAFETY",text:$step.safety,axis:.vertical)
                Toggle("Required",isOn:$step.required);Toggle("Critical safety requirement",isOn:$step.critical)
            }.disabled(version.status=="APPROVED" || busy)}
            if version.status != "APPROVED"{
                Button("Add step"){content.steps.append(GuidedStep(id:UUID().uuidString,title:"New step",teach:"",show:"",check:"",safety:"",required:true,critical:false));dirty=true}
                Button("Save draft"){Task{await save(approve:false)}}
                Button("Approve reviewed JPR"){confirmApproval=true}
            }else{Button("Create a new revision"){Task{await revise()}};Text("This approved revision cannot be edited. Historical evaluations retain these requirements.")}
        }.disabled(busy).navigationTitle("Review JPR").toolbar{Button("Done"){if dirty{confirmDiscard=true}else{dismiss()}}.disabled(busy)}
        .interactiveDismissDisabled(busy || dirty)
        .onChange(of:contentJSON){_ in dirty=true;status="Unsaved draft changes"}
        .confirmationDialog("Discard unsaved draft changes?",isPresented:$confirmDiscard){Button("Discard changes",role:.destructive){dismiss()}}
        .confirmationDialog("Approve this department JPR?",isPresented:$confirmApproval){Button("Approve reviewed requirements"){Task{await save(approve:true)}}}message:{Text("Approval locks this revision for guided training and evaluation.")}
    }
    private var contentJSON:Data?{let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys];return try? encoder.encode(content)}
    @MainActor private func save(approve:Bool)async{
        busy=true;defer{busy=false}
        do{let object=try JSONSerialization.jsonObject(with:JSONEncoder().encode(content));let body=try JSONSerialization.data(withJSONObject:["action":"update","id":version.id,"content":object]);let _:GuidedMutation=try await APIClient.shared.trainingWorkspace("/jprs",body:body);dirty=false;status="Draft saved"
            if approve{let _:GuidedMutation=try await APIClient.shared.trainingWorkspace("/jprs",body:JSONSerialization.data(withJSONObject:["action":"approve","id":version.id,"publish":!keepCourseDraft]));dismiss()}
        }catch{self.error=error.localizedDescription}
    }
    @MainActor private func revise()async{
        busy=true;defer{busy=false}
        do{let object=try JSONSerialization.jsonObject(with:JSONEncoder().encode(content));let _:GuidedImport=try await APIClient.shared.trainingWorkspace("/jprs",body:JSONSerialization.data(withJSONObject:["courseId":version.courseId ?? "","jprId":version.jprId ?? "","content":object]));dismiss()}catch{self.error=error.localizedDescription}
    }
}

private struct GuidedSkillsView: View {
    var home: GuidedHome? = nil
    var onEvaluate: ((GuidedTopic, GuidedVersion, [String]) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var skillsTab = "directory"
    @State private var data: GuidedSkillsResponse?
    @State private var skillSearch = ""
    @State private var versionId = ""
    @State private var selected = Set<String>()
    @State private var repetitions = 1
    @State private var due = Date().addingTimeInterval(7 * 86400)
    @State private var adding = false
    @State private var busy = false
    @State private var error: String?
    @State private var status = ""
    var body: some View {
        AppScreen(title: "") {
        ScrollView {
        VStack(spacing: 0) {
            TrainingScreenHeader(title: home == nil ? "My Skills Progress" : "Skills & Evaluations", subtitle: "Assigned JPRs and instructor evaluations.", systemImage: "checkmark.seal.fill", stats: [TrainingHeaderStat(label: "Assigned", value: "\(data?.requirements.count ?? 0)"), TrainingHeaderStat(label: "Completed", value: "\(data?.requirements.filter { $0.percent >= 100 }.count ?? 0)")])
            VStack(alignment: .leading, spacing: 18) {
                Text(home == nil ? "Progress reflects instructor sign-offs on your assigned JPRs." : "Find a skill, evaluate members, or assign a future requirement. No prior assignment is required to evaluate.").font(.subheadline).foregroundStyle(.secondary)
                if let error { WorkspaceNotice(message: error, warning: true) }
                if !status.isEmpty { Text(status).font(.caption) }
                if let home {
                    Picker("Skills view", selection: $skillsTab) { Text("Skills directory").tag("directory"); Text("Assignments & progress").tag("progress") }.pickerStyle(.menu)
                    Button(adding ? "Close assignment form" : "Assign skill requirement") { adding.toggle() }.buttonStyle(WorkspaceActionStyle())
                    if adding { assignmentForm(home) }
                }
                HStack { Image(systemName: "magnifyingglass"); TextField(home == nil ? "Find a skill" : "Find a member or skill", text: $skillSearch).autocorrectionDisabled() }.workspaceCard()
                if let home, skillsTab == "directory" {
                    ForEach(home.topics) { course in
                        ForEach(course.latestJprs.filter { skillSearch.isEmpty || "\(course.title) \($0.content.number) \($0.content.title)".localizedCaseInsensitiveContains(skillSearch) }) { version in
                            WorkspacePanel {
                                Text(course.title).font(.caption).foregroundStyle(.secondary)
                                Text("\(version.content.number) · \(version.content.title)").font(.headline)
                                Text("Approved revision \(version.revision)").font(.caption)
                                Button("Evaluate members") { onEvaluate?(course,version,[]); dismiss() }.buttonStyle(WorkspaceActionStyle(primary: true)).disabled(onEvaluate == nil)
                                Button("Assign requirement") { versionId = version.id; adding = true }.buttonStyle(WorkspaceActionStyle())
                            }
                        }
                    }
                    if home.topics.isEmpty { WorkspaceNotice(message: "No approved skills are available yet. Publish a course and approve its JPRs to list them here.") }
                } else if let data {
                    ForEach(data.sessions ?? []) { session in
                        WorkspacePanel {
                            Text("Upcoming · \(session.title)").font(.headline)
                            if let date = session.startAt { Text(date.formatted(date: .abbreviated, time: .shortened)) }
                            Text("\(session.durationMinutes) min · \(session.location ?? "Location not set")").font(.caption)
                        }
                    }
                    if data.requirements.isEmpty { Text("No JPR requirements assigned yet.").foregroundStyle(.secondary) }
                    ForEach(data.requirements.filter { skillSearch.isEmpty || "\($0.member) \($0.number) \($0.title)".localizedCaseInsensitiveContains(skillSearch) }) { requirement in
                        WorkspacePanel {
                            HStack(alignment: .top, spacing: 16) {
                                TrainingProgressDial(percent: requirement.percent)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(requirement.number).font(.caption.bold()).foregroundStyle(TrainingVisualStyle.cyan)
                                    Text(requirement.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                                    if home != nil { Text(requirement.member).font(.subheadline).foregroundStyle(.white.opacity(0.75)) }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Text("Revision \(requirement.revision) · \(requirement.completed) / \(requirement.required) successful evaluations").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                            if let date = requirement.dueAt { Text("Due \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption) }
                            if let home, let course = home.topics.first(where: { $0.id == requirement.courseId }), let version = course.jprs.first(where: { $0.id == requirement.versionId }), onEvaluate != nil {
                                Button("Evaluate \(requirement.member)") { onEvaluate?(course,version,[requirement.userId]); dismiss() }.buttonStyle(WorkspaceActionStyle())
                            }
                            DisclosureGroup("Evaluation history") {
                                if requirement.history.isEmpty { Text("No finalized evaluations since assignment.").font(.caption) }
                                ForEach(requirement.history) { attempt in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(attempt.outcome == "PASS" ? "Passed" : attempt.outcome == "FAIL" ? "⚠ Needs work" : "Incomplete").foregroundStyle(attempt.outcome == "FAIL" ? Color(red:1,green:0.61,blue:0.61) : .white)
                                        Text(attempt.evaluator).font(.caption)
                                        if let date = attempt.completedAt { Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption) }
                                    }.padding(.vertical, 6)
                                }
                            }
                        }
                    }
                } else if error == nil { ProgressView("Loading skill requirements…") }
            }.padding(16)
        }
        }.refreshable { await load() }.foregroundStyle(.white)
        }.navigationTitle(home == nil ? "My Skills" : "Skills & Evaluations").trainingDestinationNavigation(blocked: busy).navigationBarTitleDisplayMode(.inline).tint(TrainingVisualStyle.cyan).environment(\.colorScheme, .dark).disabled(busy).task { await load() }
    }
    private func assignmentForm(_ home: GuidedHome) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Approved JPR", selection: $versionId) {
                Text("Choose a JPR").tag("")
                ForEach(home.topics.flatMap(\.jprs)) { version in Text("\(version.content.number) · \(version.content.title) · Rev \(version.revision)").tag(version.id) }
            }
            Stepper("\(repetitions) successful evaluations required", value: $repetitions, in: 1...100)
            DatePicker("Due", selection: $due, displayedComponents: .date)
            Text("Assign to members").font(.headline)
            ForEach(home.members) { member in
                Toggle(member.name, isOn: Binding(get: { selected.contains(member.id) }, set: { if $0 { selected.insert(member.id) } else { selected.remove(member.id) } }))
            }
            Button("Assign JPR requirement") { Task { await assign() } }.buttonStyle(WorkspaceActionStyle()).disabled(versionId.isEmpty || selected.isEmpty || busy)
            Text("Counts evaluations recorded after assignment using this exact approved revision.").font(.caption).foregroundStyle(.secondary)
        }.workspaceCard()
    }
    @MainActor private func load() async { do { data = try await APIClient.shared.trainingWorkspace(home == nil ? "/skills" : "/skills?managed=1"); error = nil } catch { if !APIClient.isRequestCancellation(error) { self.error = error.localizedDescription } } }
    @MainActor private func assign() async {
        busy = true; defer { busy = false }
        do {
            let values: [String: Any] = ["versionId": versionId, "memberIds": Array(selected), "requiredCompletions": repetitions, "dueAt": ISO8601DateFormatter().string(from: due)]
            let _: TrainingWorkspaceMutation = try await APIClient.shared.trainingWorkspace("/skills", body: JSONSerialization.data(withJSONObject: values))
            adding = false; skillsTab = "progress"; status = "JPR requirement assigned."; await load()
        } catch { self.error = error.localizedDescription }
    }
}

private struct TrainingSafetyNotice: View {
    let text: String
    var critical = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(critical ? "Critical Safety" : "Safety", systemImage: "exclamationmark.triangle.fill").font(.headline).foregroundStyle(Color(red: 1, green: 0.61, blue: 0.61))
            if !text.isEmpty { Text(text).font(.subheadline).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.7), lineWidth: 1))
    }
}
