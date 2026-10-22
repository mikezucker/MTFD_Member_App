import Foundation

// Shared replacement workflow. Optional fields keep legacy course records readable.
struct TrainingWorkspaceHome: Decodable {
    let success: Bool
    let canCreate: Bool
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
