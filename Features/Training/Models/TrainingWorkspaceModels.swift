import Foundation

// Shared replacement workflow. Optional fields keep legacy course records readable.
struct TrainingWorkspaceHome: Decodable {
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

struct GuidedStep: Codable, Identifiable {
    var id: String; var title: String; var teach: String; var show: String; var check: String; var safety: String; var required: Bool; var critical: Bool
}
struct GuidedContent: Codable {
    var importedText: String? = nil
    var number: String; var title: String; var category: String; var objective: String; var conditions: String; var equipment: String; var guidance: String; var standards: String; var revisionNotes: String; var passingScore: Int; var steps: [GuidedStep]
}
struct GuidedVersion: Codable, Identifiable {
    let id: String; let revision: Int; var content: GuidedContent
    let jprId: String?; let courseId: String?; let status: String?
}
struct GuidedTopic: Decodable, Identifiable {
    let id: String; let title: String; let description: String?; let durationMinutes: Int; let jprs: [GuidedVersion]
}
struct GuidedMember: Decodable, Identifiable { let id: String; let name: String; let attended: Bool? }
struct GuidedGroup: Decodable { let name: String; let userIds: [String] }
struct GuidedHistory: Decodable, Identifiable { let startAt: Date?; let location: String?; let oneOff: Bool?; let id: String; let title: String; let status: String; let stage: String; let updatedAt: Date; let participantCount: Int }
struct GuidedHome: Decodable { let canCreate: Bool; let topics: [GuidedTopic]; let members: [GuidedMember]; let groups: [GuidedGroup]; let sessions: [GuidedHistory] }
struct GuidedObservation: Decodable { let rating: String; let comment: String; let observedAt: String? }
struct GuidedSessionResponse: Decodable { let session: GuidedSession }
struct GuidedSession: Decodable, Identifiable {
    let id: String; let title: String; let courseId: String; let status: String; let stage: String; let jprIndex: Int; let stepIndex: Int; let durationMinutes: Int; let revision: Int
    let participants: [GuidedMember]; let jprs: [GuidedVersion]; let observations: [String: GuidedObservation]
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
