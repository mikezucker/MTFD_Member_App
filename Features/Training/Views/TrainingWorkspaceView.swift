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

    var body: some View {
        Group {
            if useLegacy { LegacyTrainingView() }
            else {
                NavigationStack {
                    AppScreen(title: "") {
                        VStack(spacing: 0) {
                            TrainingScreenHeader(title: "Training", subtitle: "Courses, practical training, and earned hours.", systemImage: "graduationcap.fill", isRefreshing: refreshing, stats: headerStats)
                            ScrollView {
                                VStack(alignment: .leading, spacing: 18) {
                                    if let error { WorkspaceNotice(message: error, warning: true); Button("Try again") { Task { await load() } }.buttonStyle(WorkspaceActionStyle()) }
                                    if let home {
                                        trainingTabs
                                        HStack(spacing: 10) {
                                            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.55))
                                            TextField("Search courses", text: $search).foregroundStyle(.white).autocorrectionDisabled()
                                            if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search") }
                                        }.workspaceCard()
                                        sectionHeading(tab == "Catalog" ? "Course Catalog" : tab == "Completed" ? "Completed Training" : "My Training", subtitle: tab == "Catalog" ? "Available for your member type. Enroll to get started." : tab == "Completed" ? "Completion dates, results, and credited hours." : "Assigned courses and your next steps.")
                                        if shownCourses.isEmpty {
                                            WorkspacePanel {
                                                Label(search.isEmpty ? (tab == "Catalog" ? "No courses available" : tab == "Completed" ? "Your training record starts here" : "You're up to date") : "No matching courses", systemImage: tab == "Completed" ? "checkmark.seal" : "graduationcap")
                                                    .font(.headline).foregroundStyle(AppTheme.gold)
                                                Text(search.isEmpty ? (tab == "Catalog" ? "Your instructors will publish eligible courses here." : tab == "Completed" ? "Completed courses and earned hours will appear here." : "You have no outstanding course assignments. Browse the catalog to find available training.") : "Try a different course name.").font(.subheadline).foregroundStyle(.white.opacity(0.72))
                                                if search.isEmpty && tab == "To Do" { Button("Browse course catalog") { tab = "Catalog" }.buttonStyle(WorkspaceActionStyle()) }
                                            }
                                        }
                                        ForEach(shownCourses) { course in
                                            NavigationLink {
                                                if course.delivery == "LEGACY" && course.archived != true { TrainingCourseDetailView(item: course.legacyItem) }
                                                else { WorkspaceCourseView(course: course, members: home.members, manage: false) }
                                            } label: { WorkspaceCourseCard(course: course) }.buttonStyle(.plain)
                                        }
                                        if tab == "To Do" && home.courses.contains(where: { $0.pendingForm }) {
                                            sectionHeading("Outstanding Forms", subtitle: "Follow-up items are separate from earned credit.")
                                            ForEach(home.courses.filter { $0.pendingForm }) { course in
                                                NavigationLink { WorkspaceCourseView(course: course, members: home.members, manage: false) } label: {
                                                    HStack(spacing: 12) {
                                                        Image(systemName: "doc.text.badge.ellipsis").font(.title2).foregroundStyle(AppTheme.gold)
                                                        VStack(alignment: .leading, spacing: 5) { Text(course.title).font(.headline); Text("Complete your evaluation or acknowledgment").font(.caption).foregroundStyle(.white.opacity(0.7)) }
                                                        Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.white.opacity(0.5))
                                                    }.workspaceCard()
                                                }.buttonStyle(.plain)
                                            }
                                        }
                                        if home.canManage { instructorTools(home) }
                                    } else if error == nil { ProgressView("Loading training…").tint(AppTheme.gold).frame(maxWidth: .infinity).padding(32) }
                                }.padding(.horizontal, 16).padding(.vertical, 16).padding(.bottom, 20)
                            }.refreshable { await load() }
                        }
                    }
                    // This tab has its own header; an empty navigation bar shifts it down.
                    .toolbar(.hidden, for: .navigationBar)
                    .tint(AppTheme.gold).environment(\.colorScheme, .dark)
                    .task { await load() }
                    .sheet(isPresented: $creating, onDismiss: { Task { await load() } }) { NavigationStack { WorkspaceCourseBuilder(members: home?.members ?? []) } }
                }
            }
        }
    }
    private var headerStats: [TrainingHeaderStat] {
        guard let home else { return [] }
        return [TrainingHeaderStat(label: "To Do", value: "\(home.courses.filter { $0.assigned && $0.progressStatus != "COMPLETED" }.count)"), TrainingHeaderStat(label: "Completed", value: "\(home.courses.filter { $0.progressStatus == "COMPLETED" }.count)"), TrainingHeaderStat(label: "Hours", value: workspaceHours(home.courses.reduce(0) { $0 + $1.creditedMinutes }))]
    }
    private var shownCourses: [TrainingWorkspaceCourse] {
        (home?.courses ?? []).filter { course in
            (search.isEmpty || course.title.localizedCaseInsensitiveContains(search)) && (tab == "Catalog" ? !course.assigned : course.assigned && (tab == "Completed" ? course.progressStatus == "COMPLETED" : course.progressStatus != "COMPLETED"))
        }.sorted { left, right in
            if tab == "Completed" { return (left.completedAt ?? .distantPast) > (right.completedAt ?? .distantPast) }
            return (left.dueAt ?? .distantFuture) < (right.dueAt ?? .distantFuture)
        }
    }
    private var trainingTabs: some View {
        HStack(spacing: 4) {
            ForEach(["To Do", "Completed", "Catalog"], id: \.self) { value in
                Button { tab = value } label: { Text(value).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12).foregroundStyle(tab == value ? AppTheme.navy : .white.opacity(0.78)).background(tab == value ? AppTheme.gold : Color.clear, in: RoundedRectangle(cornerRadius: 12)) }
                    .buttonStyle(.plain).accessibilityAddTraits(tab == value ? .isSelected : [])
            }
        }.padding(4).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
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
        do { let result: TrainingWorkspaceHome = try await APIClient.shared.trainingWorkspace(); home = result; error = nil }
        catch is CancellationError { }
        catch let failure as URLError where failure.code == .cancelled { }
        catch APIClient.APIError.serverError(let code, _) where code == 404 { useLegacy = true }
        catch { self.error = error.localizedDescription }
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
                                HStack { WorkspaceBadge(text: course.delivery == "CBT" ? "ONLINE CBT" : "PRACTICAL"); Spacer(); Text(course.status == "DRAFT" ? "Draft" : "Published").font(.caption.bold()).foregroundStyle(course.status == "DRAFT" ? AppTheme.gold : .green) }
                                Text(course.title).font(.title3.bold()).foregroundStyle(.white)
                                Label(course.delivery == "PRACTICAL" ? "Assignments & attendance" : "Assignments & quiz results", systemImage: "chevron.right").font(.subheadline).foregroundStyle(.white.opacity(0.7))
                            }.workspaceCard()
                        }.buttonStyle(.plain)
                    }
                }.padding(16)
            }
        }
    }
    private func workspaceSummary(_ c: TrainingWorkspaceManagedCourse) -> TrainingWorkspaceCourse {
        TrainingWorkspaceCourse(id: c.id, title: c.title, description: nil, delivery: c.delivery, archived: false, assigned: false, progressStatus: "NOT_STARTED", completedAt: nil, dueAt: nil, durationMinutes: nil, creditedMinutes: 0, pendingForm: false)
    }
}

private struct WorkspaceCourseView: View {
    let course: TrainingWorkspaceCourse
    let members: [TrainingWorkspaceMember]
    let manage: Bool
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
                    } else if error == nil { ProgressView("Loading course…").tint(AppTheme.gold).frame(maxWidth: .infinity).padding(30) }
                }.padding(16).padding(.bottom, 20)
            }.refreshable { await load() }
        }
        .tint(AppTheme.gold).environment(\.colorScheme, .dark)
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
                Button("Publish course") { perform(["action": "publish"]) }.buttonStyle(WorkspaceActionStyle(primary: true))
            }
        }
        WorkspacePanel("Assignments") {
            Text("\(detail.roster?.count ?? 0) \((detail.roster?.count ?? 0) == 1 ? "member" : "members") assigned").font(.subheadline).foregroundStyle(.white.opacity(0.7))
            DisclosureGroup("Assign more members") {
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
                    HStack { Text(member.name ?? "Member").font(.headline); Spacer(); Image(systemName: member.progressStatus == "COMPLETED" ? "checkmark.seal.fill" : "clock").foregroundStyle(member.progressStatus == "COMPLETED" ? .green : AppTheme.gold) }
                    Text("\(member.progressStatus == "COMPLETED" ? "Completed" : member.progressStatus == "IN_PROGRESS" ? "In progress" : "Not started") · \(workspaceHours(member.creditedMinutes ?? 0)) hours credited").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    if member.pendingForm == true { Text("Follow-up form outstanding · credit retained").font(.caption).foregroundStyle(AppTheme.gold) }
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
                    NavigationLink { TrainingCourseDetailView(item: course.legacyItem) } label: { Label(c.progressStatus == "COMPLETED" ? "Review course" : "Start / resume course", systemImage: "play.circle.fill").frame(maxWidth: .infinity) }.buttonStyle(WorkspaceActionStyle(primary: true))
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
        catch let failure as URLError where failure.code == .cancelled { }
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
            }.tint(AppTheme.gold).padding(.vertical, 4)
        }
        Text("\(selected.count) selected").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.gold)
    }
}

private struct WorkspaceCourseBuilder: View {
    let members: [TrainingWorkspaceMember]
    var courseId: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var draft = WorkspaceCourseDraft()
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
                TrainingScreenHeader(title: courseId == nil ? "Create a Course" : "Edit Draft", subtitle: "Online CBT or practical training.", systemImage: "graduationcap.fill")
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
                WorkspacePanel("Assign Specific Members") { WorkspaceMemberSelection(members: members, selected: $selected) }
                WorkspacePanel("Member Preview") {
                    Text(draft.title.isEmpty ? "Course name" : draft.title).font(.headline)
                    Text("\(draft.durationMinutes) training minutes")
                    Text(draft.delivery == "CBT" ? "View the material, then pass the quiz at 80%. Up to \(draft.quizAttemptLimit) attempts." : draft.completionMethod == "INSTRUCTOR" ? "Your instructor records attendance and completion." : "Record your completion after training.")
                    if !draft.followUpPrompt.isEmpty { Text("Separate follow-up form").font(.caption) }
                }
                WorkspacePanel { Button("Save draft") { save(publish: false) }.buttonStyle(WorkspaceActionStyle()); Button("Publish course") { save(publish: true) }.buttonStyle(WorkspaceActionStyle(primary: true)) }
            }
            WorkspacePanel {
                HStack { if step > 0 { Button("Back") { step -= 1 }.buttonStyle(WorkspaceActionStyle()) }; if step < 2 { Button("Next step") { step += 1 }.buttonStyle(WorkspaceActionStyle(primary: true)).disabled(step == 0 && draft.title.trimmingCharacters(in: .whitespacesAndNewlines).count < 3) } }
            }
            if busy { ProgressView("Saving…").tint(AppTheme.gold) }
                    }.padding(16).padding(.bottom, 20)
                }
            }
        }
        .foregroundStyle(.white).tint(AppTheme.gold).environment(\.colorScheme, .dark)
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
    private func save(publish: Bool) {
        Task { @MainActor in
            busy = true; error = nil; defer { busy = false }
            draft.publish = publish; draft.assignedUserIds = Array(selected); draft.editCourseId = courseId
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
        Text(text).font(.caption2.weight(.bold)).foregroundStyle(AppTheme.gold)
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(AppTheme.gold.opacity(0.1), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct WorkspaceActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity).padding(.horizontal, 12).padding(.vertical, 14)
            .foregroundStyle(primary ? AppTheme.navy : .white)
            .background(primary ? AppTheme.gold : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            .overlay { RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(primary ? 0 : 0.1), lineWidth: 1) }
            .opacity(!enabled ? 0.4 : configuration.isPressed ? 0.75 : 1)
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
            AppDashboardIcon(systemImage: icon, size: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.68)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 2)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.white.opacity(0.45))
        }.workspaceCard()
    }
}

private struct WorkspaceCourseCard: View {
    let course: TrainingWorkspaceCourse
    private var completed: Bool { course.progressStatus == "COMPLETED" }
    private var overdue: Bool { !completed && (course.dueAt.map { $0 < Date() } ?? false) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                AppDashboardIcon(systemImage: completed ? "checkmark.seal.fill" : course.delivery == "CBT" ? "play.circle.fill" : "person.2.fill", size: 30)
                VStack(alignment: .leading, spacing: 5) {
                    Text(course.delivery == "CBT" ? "ONLINE CBT" : course.delivery == "PRACTICAL" ? "PRACTICAL TRAINING" : "TRAINING").font(.caption2.bold()).foregroundStyle(AppTheme.gold)
                    Text(course.title).font(.headline).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.white.opacity(0.45)).padding(.top, 6)
            }
            if let description = course.description, !description.isEmpty { Text(description).font(.subheadline).foregroundStyle(.white.opacity(0.72)).lineLimit(3) }
            HStack(spacing: 14) {
                if completed { Label("\(workspaceHours(course.creditedMinutes)) hours credited", systemImage: "checkmark.seal").foregroundStyle(.green) }
                else if let duration = course.durationMinutes { Label("\(workspaceHours(duration)) hours", systemImage: "clock").foregroundStyle(.white.opacity(0.7)) }
                Spacer(minLength: 0)
                Text(completed ? "Completed" : !course.assigned ? "Available" : course.progressStatus == "IN_PROGRESS" ? "In progress" : "Not started").fontWeight(.semibold).foregroundStyle(completed ? .green : AppTheme.gold)
            }.font(.caption)
            if completed, let date = course.completedAt { Label("Completed \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar").font(.caption).foregroundStyle(.white.opacity(0.65)) }
            else if let due = course.dueAt { Label("\(overdue ? "Overdue" : "Due") · \(due.formatted(date: .abbreviated, time: .omitted))", systemImage: overdue ? "exclamationmark.triangle.fill" : "calendar").font(.caption.weight(.semibold)).foregroundStyle(overdue ? .orange : .white.opacity(0.7)) }
            Divider().overlay(.white.opacity(0.08))
            Text(completed ? "View training record" : !course.assigned ? "View course & enroll" : course.delivery == "PRACTICAL" ? "View session & completion details" : "Start / resume course").font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.gold)
        }.workspaceCard()
    }
}

private struct WorkspaceCreditRow: View {
    let credit: TrainingWorkspaceCompletion
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("\(credit.completedAt.formatted(date: .abbreviated, time: .omitted)) · \(workspaceHours(credit.durationMinutes)) hours", systemImage: "calendar.badge.checkmark")
            Text("Recorded by \(credit.instructor ?? "Training staff")").foregroundStyle(.white.opacity(0.65))
            if let score = credit.scorePercent { Text("Quiz score: \(score)%\(credit.attemptCount.map { " · \($0) attempts" } ?? "")").foregroundStyle(AppTheme.gold) }
        }.font(.caption).padding(.vertical, 4)
    }
}

private struct WorkspaceBuilderSteps: View {
    let step: Int
    private let labels = ["Details", "Training", "Audience"]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STEP \(step + 1) OF 3").font(.caption.bold()).foregroundStyle(AppTheme.gold)
            HStack(alignment: .top, spacing: 8) {
                ForEach(labels.indices, id: \.self) { index in
                    VStack(spacing: 8) {
                        Text(index < step ? "✓" : "\(index + 1)").font(.subheadline.bold())
                            .frame(width: 32, height: 32).foregroundStyle(index <= step ? AppTheme.navy : .white.opacity(0.6))
                            .background(index <= step ? AppTheme.gold : .white.opacity(0.08), in: Circle())
                        Text(labels[index]).font(.caption.weight(.semibold)).foregroundStyle(index == step ? .white : .white.opacity(0.55))
                    }.frame(maxWidth: .infinity)
                }
            }
        }.workspaceCard()
    }
}

private extension View {
    func workspaceCard() -> some View {
        self.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1) }
    }
    func workspaceInput() -> some View {
        self.textFieldStyle(.plain).foregroundStyle(.white).padding(12)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.12), lineWidth: 1) }
    }
}
