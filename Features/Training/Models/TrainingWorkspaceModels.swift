import Foundation

// Shared replacement workflow. Optional fields keep legacy course records readable.
struct TrainingWorkspaceHome: Decodable {
    var scheduledTraining: [ScheduledTrainingItem]? = nil
    let success: Bool
    let canCreate: Bool
    var guidedEnabled: Bool? = nil
    let canManage: Bool
    let members: [TrainingWorkspaceMember]
    let courses: [TrainingWorkspaceCourse]
    let manageCourses: [TrainingWorkspaceManagedCourse]
}
struct TrainingWorkspaceMember: Decodable, Identifiable {
    let id: String
    let name: String?
    let role: String
    let progressStatus: String?
    let creditedMinutes: Int?
    let pendingForm: Bool?
    let completions: [TrainingWorkspaceCompletion]?
}
struct TrainingWorkspaceManagedCourse: Decodable, Identifiable {
    let id: String
    let title: String
    let status: String
    let delivery: String
}
struct TrainingWorkspaceCourse: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let delivery: String
    let archived: Bool?
    let assigned: Bool
    let progressStatus: String
    let completedAt: Date?
    let dueAt: Date?
    let durationMinutes: Int?
    let creditedMinutes: Int
    let pendingForm: Bool
    var legacyItem: MobileTrainingItem {
        MobileTrainingItem(id: id, courseId: id, title: title, description: description, status: "PUBLISHED", dueAt: dueAt, isOverdue: dueAt.map { $0 < Date() && progressStatus != "COMPLETED" } ?? false, assignedAt: nil, assignmentType: "USER", progressStatus: progressStatus, progressPercent: progressStatus == "COMPLETED" ? 100 : 0, completedAt: completedAt, moduleCount: 0, lessonCount: 0, objectiveCount: 0, practicalObjectiveCount: 0)
    }
}
struct TrainingWorkspaceDetail: Decodable {
    var documents:[JPRMemberDocument]? = nil
    let success: Bool
    let legacy: Bool
    let canManage: Bool?
    let draft: WorkspaceCourseDraft?
    let course: TrainingWorkspaceDetailCourse
    let roster: [TrainingWorkspaceMember]?
}
struct TrainingWorkspaceDetailCourse: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let status: String?
    let delivery: String?
    let completionMethod: String?
    let durationMinutes: Int?
    let instructor: String?
    let quizAttemptLimit: Int?
    let enrolled: Bool?
    let progressStatus: String?
    let followUpPrompt: String?
    let followUpResponse: String?
    let completions: [TrainingWorkspaceCompletion]?
}
struct TrainingWorkspaceCompletion: Decodable, Identifiable {
    let attemptCount: Int?
    let id: String
    let completedAt: Date
    let durationMinutes: Int
    let scorePercent: Int?
    let instructor: String?
}
struct TrainingWorkspaceMutation: Decodable {
    let success: Bool
    let error: String?
    let courseId: String?
}
struct WorkspaceUploadResponse: Decodable {
    let localUpload: Bool?
    let success: Bool
    let file: WorkspaceUploadedFile?
    let error: String?
}
struct WorkspaceUploadedFile: Decodable {
    let uploadUrl: URL?
    let filePath: String
    let fileName: String
    let mimeType: String
    let assetToken: String
}

struct WorkspaceCourseDraft: Codable {
    var title = ""
    var description = ""
    var delivery = "CBT"
    var completionMethod = "INSTRUCTOR"
    var durationMinutes = 60
    var quizAttemptLimit = 3
    var catalogEnabled = false
    var catalogRoles: [String] = []
    var assignedUserIds: [String] = []
    var followUpPrompt = ""
    var publish = false
    var editCourseId: String? = nil
    var content: [WorkspaceCourseMaterial] = []
    var questions: [WorkspaceDraftQuestion] = []
}
struct WorkspaceCourseMaterial: Codable, Identifiable {
    var id: String { url }
    var title: String
    var kind: String
    var url: String
    var fileName: String? = nil
    var assetToken: String? = nil
}
struct WorkspaceDraftQuestion: Codable, Identifiable {
    var id = UUID()
    var prompt = ""
    var options = ["", "", "", ""]
    var correctIndex = 0
    private enum CodingKeys: String, CodingKey { case prompt, options, correctIndex }
}

// Preserve unknown JSON fields at every content level for forward-compatible saves.
indirect enum GuidedJSON: Codable {
    case object([String:GuidedJSON]), array([GuidedJSON]), string(String), number(Double), bool(Bool), null
    init(from decoder:Decoder)throws {
        let c=try decoder.singleValueContainer()
        if c.decodeNil(){self = .null}
        else if let v=try? c.decode(Bool.self){self = .bool(v)}
        else if let v=try? c.decode(String.self){self = .string(v)}
        else if let v=try? c.decode(Double.self){self = .number(v)}
        else if let v=try? c.decode([String:GuidedJSON].self){self = .object(v)}
        else {self = .array(try c.decode([GuidedJSON].self))}
    }
    func encode(to encoder:Encoder)throws {
        var c=encoder.singleValueContainer()
        switch self {
        case .object(let v):try c.encode(v)
        case .array(let v):try c.encode(v)
        case .string(let v):try c.encode(v)
        case .number(let v):try c.encode(v)
        case .bool(let v):try c.encode(v)
        case .null:try c.encodeNil()
        }
    }
}
private struct GuidedContentKey:CodingKey {
    var stringValue:String
    var intValue:Int? {nil}
    init(_ value:String){stringValue=value}
    init?(stringValue:String){self.stringValue=stringValue}
    init?(intValue:Int){return nil}
}
struct GuidedStep: Codable, Identifiable {
    var id: String = ""
    var title: String = ""
    var teach: String = ""
    var show: String = ""
    var check: String = ""
    var safety: String = ""
    var required: Bool = true
    var critical: Bool = false
    var extraFields: [String:GuidedJSON] = [:]
}
extension GuidedStep {
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:GuidedContentKey.self)
        id=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("id")) ?? ""
        title=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("title")) ?? ""
        teach=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("teach")) ?? ""
        show=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("show")) ?? ""
        check=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("check")) ?? ""
        safety=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("safety")) ?? ""
        required=try c.decodeIfPresent(Bool.self,forKey:GuidedContentKey("required")) ?? true
        critical=try c.decodeIfPresent(Bool.self,forKey:GuidedContentKey("critical")) ?? false
        let known=Set(["id","title","teach","show","check","safety","required","critical"])
        for key in c.allKeys where !known.contains(key.stringValue) {extraFields[key.stringValue]=try c.decode(GuidedJSON.self,forKey:key)}
    }
    func encode(to encoder:Encoder)throws {
        var c=encoder.container(keyedBy:GuidedContentKey.self)
        for (key,value) in extraFields {try c.encode(value,forKey:GuidedContentKey(key))}
        try c.encode(id,forKey:GuidedContentKey("id"))
        try c.encode(title,forKey:GuidedContentKey("title"))
        try c.encode(teach,forKey:GuidedContentKey("teach"))
        try c.encode(show,forKey:GuidedContentKey("show"))
        try c.encode(check,forKey:GuidedContentKey("check"))
        try c.encode(safety,forKey:GuidedContentKey("safety"))
        try c.encode(required,forKey:GuidedContentKey("required"))
        try c.encode(critical,forKey:GuidedContentKey("critical"))
    }
}
struct GuidedContent: Codable {
    var number: String = ""
    var title: String = ""
    var category: String = ""
    var objective: String = ""
    var conditions: String = ""
    var equipment: String = ""
    var guidance: String = ""
    var standards: String = ""
    var revisionNotes: String = ""
    var passingScore: Int = 100
    var steps: [GuidedStep] = []
    var importedText: String? = nil
    var schemaVersion: Int? = nil
    var teaching: GuidedTeaching? = nil
    var scenarios: [GuidedScenario]? = nil
    var extraFields: [String:GuidedJSON] = [:]
}
extension GuidedContent {
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:GuidedContentKey.self)
        number=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("number")) ?? ""
        title=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("title")) ?? ""
        category=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("category")) ?? ""
        objective=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("objective")) ?? ""
        conditions=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("conditions")) ?? ""
        equipment=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("equipment")) ?? ""
        guidance=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("guidance")) ?? ""
        standards=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("standards")) ?? ""
        revisionNotes=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("revisionNotes")) ?? ""
        passingScore=try c.decodeIfPresent(Int.self,forKey:GuidedContentKey("passingScore")) ?? 100
        steps=try c.decodeIfPresent([GuidedStep].self,forKey:GuidedContentKey("steps")) ?? []
        importedText=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("importedText"))
        schemaVersion=try c.decodeIfPresent(Int.self,forKey:GuidedContentKey("schemaVersion"))
        teaching=try c.decodeIfPresent(GuidedTeaching.self,forKey:GuidedContentKey("teaching"))
        scenarios=try c.decodeIfPresent([GuidedScenario].self,forKey:GuidedContentKey("scenarios"))
        let known=Set(["number","title","category","objective","conditions","equipment","guidance","standards","revisionNotes","passingScore","steps","importedText","schemaVersion","teaching","scenarios"])
        for key in c.allKeys where !known.contains(key.stringValue) {extraFields[key.stringValue]=try c.decode(GuidedJSON.self,forKey:key)}
    }
    func encode(to encoder:Encoder)throws {
        var c=encoder.container(keyedBy:GuidedContentKey.self)
        for (key,value) in extraFields {try c.encode(value,forKey:GuidedContentKey(key))}
        try c.encode(number,forKey:GuidedContentKey("number"))
        try c.encode(title,forKey:GuidedContentKey("title"))
        try c.encode(category,forKey:GuidedContentKey("category"))
        try c.encode(objective,forKey:GuidedContentKey("objective"))
        try c.encode(conditions,forKey:GuidedContentKey("conditions"))
        try c.encode(equipment,forKey:GuidedContentKey("equipment"))
        try c.encode(guidance,forKey:GuidedContentKey("guidance"))
        try c.encode(standards,forKey:GuidedContentKey("standards"))
        try c.encode(revisionNotes,forKey:GuidedContentKey("revisionNotes"))
        try c.encode(passingScore,forKey:GuidedContentKey("passingScore"))
        try c.encode(steps,forKey:GuidedContentKey("steps"))
        try c.encodeIfPresent(importedText,forKey:GuidedContentKey("importedText"))
        try c.encodeIfPresent(schemaVersion,forKey:GuidedContentKey("schemaVersion"))
        try c.encodeIfPresent(teaching,forKey:GuidedContentKey("teaching"))
        try c.encodeIfPresent(scenarios,forKey:GuidedContentKey("scenarios"))
    }
}
struct GuidedTeaching: Codable {
    var performanceObjectives: [String] = []
    var prerequisites: [String] = []
    var requiredEquipment: [String] = []
    var instructorPreparation: [String] = []
    var safetyConsiderations: [String] = []
    var criticalFailures: [String] = []
    var instructionalSteps: [GuidedTeachingStep] = []
    var references: [GuidedReference] = []
    var extraFields: [String:GuidedJSON] = [:]
}
extension GuidedTeaching {
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:GuidedContentKey.self)
        performanceObjectives=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("performanceObjectives")) ?? []
        prerequisites=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("prerequisites")) ?? []
        requiredEquipment=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("requiredEquipment")) ?? []
        instructorPreparation=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("instructorPreparation")) ?? []
        safetyConsiderations=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("safetyConsiderations")) ?? []
        criticalFailures=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("criticalFailures")) ?? []
        instructionalSteps=try c.decodeIfPresent([GuidedTeachingStep].self,forKey:GuidedContentKey("instructionalSteps")) ?? []
        references=try c.decodeIfPresent([GuidedReference].self,forKey:GuidedContentKey("references")) ?? []
        let known=Set(["performanceObjectives","prerequisites","requiredEquipment","instructorPreparation","safetyConsiderations","criticalFailures","instructionalSteps","references"])
        for key in c.allKeys where !known.contains(key.stringValue) {extraFields[key.stringValue]=try c.decode(GuidedJSON.self,forKey:key)}
    }
    func encode(to encoder:Encoder)throws {
        var c=encoder.container(keyedBy:GuidedContentKey.self)
        for (key,value) in extraFields {try c.encode(value,forKey:GuidedContentKey(key))}
        try c.encode(performanceObjectives,forKey:GuidedContentKey("performanceObjectives"))
        try c.encode(prerequisites,forKey:GuidedContentKey("prerequisites"))
        try c.encode(requiredEquipment,forKey:GuidedContentKey("requiredEquipment"))
        try c.encode(instructorPreparation,forKey:GuidedContentKey("instructorPreparation"))
        try c.encode(safetyConsiderations,forKey:GuidedContentKey("safetyConsiderations"))
        try c.encode(criticalFailures,forKey:GuidedContentKey("criticalFailures"))
        try c.encode(instructionalSteps,forKey:GuidedContentKey("instructionalSteps"))
        try c.encode(references,forKey:GuidedContentKey("references"))
    }
}
struct GuidedTeachingStep: Codable, Identifiable {
    var id: String = ""
    var title: String = ""
    var instruction: String = ""
    var demonstration: String = ""
    var expectedActions: [String] = []
    var safetyConsiderations: [String] = []
    var criticalFailures: [String] = []
    var commonMistakes: [GuidedMistake] = []
    var extraFields: [String:GuidedJSON] = [:]
}
extension GuidedTeachingStep {
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:GuidedContentKey.self)
        id=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("id")) ?? ""
        title=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("title")) ?? ""
        instruction=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("instruction")) ?? ""
        demonstration=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("demonstration")) ?? ""
        expectedActions=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("expectedActions")) ?? []
        safetyConsiderations=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("safetyConsiderations")) ?? []
        criticalFailures=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("criticalFailures")) ?? []
        commonMistakes=try c.decodeIfPresent([GuidedMistake].self,forKey:GuidedContentKey("commonMistakes")) ?? []
        let known=Set(["id","title","instruction","demonstration","expectedActions","safetyConsiderations","criticalFailures","commonMistakes"])
        for key in c.allKeys where !known.contains(key.stringValue) {extraFields[key.stringValue]=try c.decode(GuidedJSON.self,forKey:key)}
    }
    func encode(to encoder:Encoder)throws {
        var c=encoder.container(keyedBy:GuidedContentKey.self)
        for (key,value) in extraFields {try c.encode(value,forKey:GuidedContentKey(key))}
        try c.encode(id,forKey:GuidedContentKey("id"))
        try c.encode(title,forKey:GuidedContentKey("title"))
        try c.encode(instruction,forKey:GuidedContentKey("instruction"))
        try c.encode(demonstration,forKey:GuidedContentKey("demonstration"))
        try c.encode(expectedActions,forKey:GuidedContentKey("expectedActions"))
        try c.encode(safetyConsiderations,forKey:GuidedContentKey("safetyConsiderations"))
        try c.encode(criticalFailures,forKey:GuidedContentKey("criticalFailures"))
        try c.encode(commonMistakes,forKey:GuidedContentKey("commonMistakes"))
    }
}
struct GuidedMistake: Codable {
    var mistake: String = ""
    var correction: String = ""
    var extraFields: [String:GuidedJSON] = [:]
}
extension GuidedMistake {
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:GuidedContentKey.self)
        mistake=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("mistake")) ?? ""
        correction=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("correction")) ?? ""
        let known=Set(["mistake","correction"])
        for key in c.allKeys where !known.contains(key.stringValue) {extraFields[key.stringValue]=try c.decode(GuidedJSON.self,forKey:key)}
    }
    func encode(to encoder:Encoder)throws {
        var c=encoder.container(keyedBy:GuidedContentKey.self)
        for (key,value) in extraFields {try c.encode(value,forKey:GuidedContentKey(key))}
        try c.encode(mistake,forKey:GuidedContentKey("mistake"))
        try c.encode(correction,forKey:GuidedContentKey("correction"))
    }
}
struct GuidedReference: Codable {
    var title: String = ""
    var edition: String? = nil
    var section: String? = nil
    var url: String? = nil
    var departmentReference: String? = nil
    var extraFields: [String:GuidedJSON] = [:]
}
extension GuidedReference {
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:GuidedContentKey.self)
        title=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("title")) ?? ""
        edition=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("edition"))
        section=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("section"))
        url=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("url"))
        departmentReference=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("departmentReference"))
        let known=Set(["title","edition","section","url","departmentReference"])
        for key in c.allKeys where !known.contains(key.stringValue) {extraFields[key.stringValue]=try c.decode(GuidedJSON.self,forKey:key)}
    }
    func encode(to encoder:Encoder)throws {
        var c=encoder.container(keyedBy:GuidedContentKey.self)
        for (key,value) in extraFields {try c.encode(value,forKey:GuidedContentKey(key))}
        try c.encode(title,forKey:GuidedContentKey("title"))
        try c.encodeIfPresent(edition,forKey:GuidedContentKey("edition"))
        try c.encodeIfPresent(section,forKey:GuidedContentKey("section"))
        try c.encodeIfPresent(url,forKey:GuidedContentKey("url"))
        try c.encodeIfPresent(departmentReference,forKey:GuidedContentKey("departmentReference"))
    }
}
struct GuidedScenario: Codable, Identifiable {
    var id: String = ""
    var title: String = ""
    var difficulty: String = "BASIC"
    var trainingObjective: String = ""
    var briefing: String = ""
    var requiredEquipment: [String] = []
    var instructorSetup: [String] = []
    var expectedActions: [String] = []
    var complications: [String] = []
    var safetyStopConditions: [String] = []
    var debriefQuestions: [String] = []
    var extraFields: [String:GuidedJSON] = [:]
}
extension GuidedScenario {
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:GuidedContentKey.self)
        id=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("id")) ?? ""
        title=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("title")) ?? ""
        difficulty=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("difficulty")) ?? "BASIC"
        trainingObjective=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("trainingObjective")) ?? ""
        briefing=try c.decodeIfPresent(String.self,forKey:GuidedContentKey("briefing")) ?? ""
        requiredEquipment=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("requiredEquipment")) ?? []
        instructorSetup=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("instructorSetup")) ?? []
        expectedActions=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("expectedActions")) ?? []
        complications=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("complications")) ?? []
        safetyStopConditions=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("safetyStopConditions")) ?? []
        debriefQuestions=try c.decodeIfPresent([String].self,forKey:GuidedContentKey("debriefQuestions")) ?? []
        let known=Set(["id","title","difficulty","trainingObjective","briefing","requiredEquipment","instructorSetup","expectedActions","complications","safetyStopConditions","debriefQuestions"])
        for key in c.allKeys where !known.contains(key.stringValue) {extraFields[key.stringValue]=try c.decode(GuidedJSON.self,forKey:key)}
    }
    func encode(to encoder:Encoder)throws {
        var c=encoder.container(keyedBy:GuidedContentKey.self)
        for (key,value) in extraFields {try c.encode(value,forKey:GuidedContentKey(key))}
        try c.encode(id,forKey:GuidedContentKey("id"))
        try c.encode(title,forKey:GuidedContentKey("title"))
        try c.encode(difficulty,forKey:GuidedContentKey("difficulty"))
        try c.encode(trainingObjective,forKey:GuidedContentKey("trainingObjective"))
        try c.encode(briefing,forKey:GuidedContentKey("briefing"))
        try c.encode(requiredEquipment,forKey:GuidedContentKey("requiredEquipment"))
        try c.encode(instructorSetup,forKey:GuidedContentKey("instructorSetup"))
        try c.encode(expectedActions,forKey:GuidedContentKey("expectedActions"))
        try c.encode(complications,forKey:GuidedContentKey("complications"))
        try c.encode(safetyStopConditions,forKey:GuidedContentKey("safetyStopConditions"))
        try c.encode(debriefQuestions,forKey:GuidedContentKey("debriefQuestions"))
    }
}
struct GuidedVersion: Codable, Identifiable {
    let id: String; let revision: Int; var content: GuidedContent
    let jprId: String?; let courseId: String?; let status: String?
    var reviewToken: String? = nil
    var approvalIssue: String? = nil
}
struct GuidedCourseCategory: Decodable { let id: String; let name: String }
struct GuidedPendingCourse: Decodable, Identifiable { let id: String; let title: String; let totalJprs: Int; var category: GuidedCourseCategory? = nil }
struct GuidedTopic: Decodable, Identifiable {
    var category: GuidedCourseCategory? = nil
    let id: String; let title: String; let description: String?; let durationMinutes: Int; let jprs: [GuidedVersion]
}
extension GuidedTopic {
    var latestJprs: [GuidedVersion] {
        var seen = Set<String>()
        return jprs.filter { seen.insert($0.jprId ?? $0.id).inserted }
    }
    func matches(search: String, categoryId: String) -> Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return (categoryId.isEmpty || category?.id == categoryId) && (query.isEmpty || ([title, description ?? "", category?.name ?? ""] + jprs.map { "\($0.content.number) \($0.content.title)" }).joined(separator: " ").localizedCaseInsensitiveContains(query))
    }
}
struct GuidedMember: Decodable, Identifiable { let id: String; let name: String; let attended: Bool? }
struct GuidedGroup: Decodable { let name: String; let userIds: [String] }
struct GuidedHistory: Decodable, Identifiable { let startAt: Date?; let location: String?; let oneOff: Bool?; let id: String; let title: String; let status: String; let stage: String; let updatedAt: Date; let participantCount: Int }
struct GuidedHome: Decodable { var scheduledTraining: [ScheduledTrainingItem]? = nil; var pendingCourses: [GuidedPendingCourse]? = nil; let canCreate: Bool; let topics: [GuidedTopic]; let members: [GuidedMember]; let groups: [GuidedGroup]; let sessions: [GuidedHistory] }
struct GuidedObservation: Decodable { let rating: String; let comment: String; let observedAt: String? }
struct GuidedSessionResponse: Decodable { let session: GuidedSession }
struct GuidedSession: Decodable, Identifiable {
    let id: String; let title: String; let courseId: String; let status: String; let stage: String; let jprIndex: Int; let stepIndex: Int; let durationMinutes: Int; let revision: Int
    let participants: [GuidedMember]; let jprs: [GuidedVersion]; let observations: [String: GuidedObservation]
    var selectedScenarios: [String:String]? = nil
    var oneOff: Bool? = nil
    var notes: String? = nil
    var startAt: Date? = nil
    var location: String? = nil
    var locked: Bool { status == "FINALIZED" }
    func key(_ version: GuidedVersion, _ step: GuidedStep, _ member: GuidedMember) -> String { "\(version.id):\(step.id):\(member.id)" }
    func outcome(_ version: GuidedVersion, _ member: GuidedMember) -> String {
        let steps = version.content.steps
        if steps.contains(where: { ($0.required || $0.critical) && observations[key(version,$0,member)]?.rating == "NEEDS_WORK" }) { return "Needs additional training" }
        if steps.contains(where: { ($0.required || $0.critical) && (observations[key(version,$0,member)]?.rating ?? "NOT_EVALUATED") == "NOT_EVALUATED" }) { return "Incomplete" }
        let score = Int((100.0 * Double(steps.filter { observations[key(version,$0,member)]?.rating == "PASS" }.count) / Double(steps.count)).rounded())
        return score >= version.content.passingScore ? "Passed" : "Needs additional training"
    }
}
struct GuidedMutation: Decodable { let success: Bool; let sessionId: String?; let revision: Int? }
struct GuidedDuty: Decodable { let userIds: [String] }
struct GuidedLibrary: Decodable { let versions: [GuidedVersion] }
struct GuidedImport: Decodable { let version: GuidedVersion }
struct GuidedResults: Decodable {
    let results: [Result]
    struct Result: Decodable, Identifiable {
        let id: String; let title: String; let number: String; let revision: Int; let outcome: String; let evaluator: String; let completedAt: Date?; let steps: Details?
    }
    struct Details: Decodable { let steps: [StepResult] }
    struct StepResult: Decodable { let stepId: String; let title: String?; let rating: String; let comment: String }
}

struct GuidedSkillsResponse: Decodable {
 let requirements: [GuidedSkillRequirement]
 let sessions: [GuidedUpcomingSession]?
}
struct GuidedUpcomingSession: Decodable, Identifiable {
 let id: String; let title: String; let startAt: Date?; let location: String?; let durationMinutes: Int
}
struct GuidedSkillRequirement: Decodable, Identifiable {
 let id: String; let userId: String; let member: String; let versionId: String; let courseId: String; let number: String; let title: String; let revision: Int
 let required: Int; let completed: Int; let percent: Int; let dueAt: Date?; let history: [GuidedSkillHistory]
}
struct GuidedSkillHistory: Decodable, Identifiable {
 let id: String; let outcome: String; let completedAt: Date?; let evaluator: String
}

struct ScheduledTrainingItem: Decodable, Identifiable {
    let id: String
    let title: String
    let startAt: Date?
    let location: String?
    let durationMinutes: Int
    let instructor: String?
    let conducting: Bool?
}

// Media keeps unknown keys verbatim, just like the existing versioned JPR model.
struct JPRMedia: Codable, Identifiable {
    var fields:[String:GuidedJSON] = [:]
    init(assetId:String,type:String,order:Int){id=UUID().uuidString;self.assetId=assetId;self.type=type;self.order=order}
    init(from decoder:Decoder)throws{fields=try decoder.singleValueContainer().decode([String:GuidedJSON].self)}
    func encode(to encoder:Encoder)throws{var c=encoder.singleValueContainer();try c.encode(fields)}
    func string(_ key:String)->String{if case .string(let value)=fields[key]{return value};return ""}
    mutating func set(_ key:String,_ value:String){fields[key] = .string(value)}
    var id:String {get{string("id")}set{set("id",newValue)}}
    var assetId:String {get{string("assetId")}set{set("assetId",newValue)}}
    var type:String {get{string("type")}set{set("type",newValue)}}
    var caption:String {get{string("caption")}set{set("caption",newValue)}}
    var order:Int {get{if case .number(let v)=fields["order"]{return Int(v)};return 0}set{fields["order"] = .number(Double(newValue))}}
    var aiGenerated:Bool {get{if case .bool(let v)=fields["aiGenerated"]{return v};return false}set{fields["aiGenerated"] = .bool(newValue)}}
    var verified:Bool {get{string("verificationStatus")=="INSTRUCTOR_VERIFIED"}set{set("verificationStatus",newValue ? "INSTRUCTOR_VERIFIED" : "UNVERIFIED");fields.removeValue(forKey:"verifiedAt");fields.removeValue(forKey:"verifiedById")}}
}
private func readStepMedia(_ fields:[String:GuidedJSON])->[JPRMedia]{guard let value=fields["media"],let data=try? JSONEncoder().encode(value) else{return []};return (try? JSONDecoder().decode([JPRMedia].self,from:data)) ?? []}
private func writeStepMedia(_ media:[JPRMedia])->GuidedJSON{guard let data=try? JSONEncoder().encode(media),let value=try? JSONDecoder().decode(GuidedJSON.self,from:data) else{return .array([])};return value}
extension GuidedStep {var media:[JPRMedia]{get{readStepMedia(extraFields)}set{extraFields["media"]=writeStepMedia(newValue)}}}
extension GuidedTeachingStep {var media:[JPRMedia]{get{readStepMedia(extraFields)}set{extraFields["media"]=writeStepMedia(newValue)}}}
struct JPRMediaAsset:Decodable,Identifiable {let id:String;let kind:String;let fileName:String}
struct JPRMediaLibrary:Decodable {let assets:[JPRMediaAsset];var nextCursor:String? = nil}
struct JPRMediaTicket:Decodable {let assetId:String;let uploadUrl:URL}
struct JPRMediaLocation:Decodable {let url:URL;let expiresIn:Int}
struct JPRMemberDocument:Decodable,Identifiable {let id:String;let revision:Int;let content:JPRMemberContent}
struct JPRMemberContent:Decodable {let number:String;let title:String;let objective:String;let equipment:String;let conditions:String?;let performanceObjectives:[String]?;let prerequisites:[String]?;let requiredEquipment:[String]?;let safetyConsiderations:[String]?;let steps:[GuidedTeachingStep]}
