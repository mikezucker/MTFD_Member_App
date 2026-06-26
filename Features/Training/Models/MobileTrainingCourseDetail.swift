//
//  MobileTrainingCourseDetail.swift
//  MTFD Member App
//

import Foundation

struct MobileTrainingCourseDetailResponse: Decodable {
    let success: Bool
    let course: MobileTrainingCourseDetail?
    let error: String?
    let lastUpdated: Date?
}

struct MobileTrainingCourseDetail: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let status: String
    let trainingType: String?
    let progressStatus: String
    let progressPercent: Int
    let completedAt: Date?
    let moduleCount: Int
    let lessonCount: Int
    let objectiveCount: Int
    let completedItemCount: Int?
    let totalItemCount: Int?
    let modules: [TrainingModuleDetail]
    let assignments: [TrainingCourseAssignmentDetail]?
    let objectiveFeedbackToMessages: Bool?
    let enableInstructorDashboard: Bool?
    let allowMemberObjectiveSelfCheckoff: Bool?
    let lastUpdated: Date?
}

struct TrainingCourseAssignmentDetail: Decodable, Identifiable {
    let id: String
    let targetType: String
    let targetRole: String?
    let targetUserId: String?
    let targetUser: TrainingCourseAssignedUser?
    let dueAt: Date?
    let assignedAt: Date?
}

struct TrainingCourseAssignedUser: Decodable, Identifiable {
    let id: String
    let name: String?
    let email: String?
    let role: String
    let company: String?
}

struct TrainingModuleDetail: Decodable, Identifiable {
    let id: String
    let title: String
    let order: Int
    let lessonCount: Int
    let objectiveCount: Int
    let completedItemCount: Int
    let totalItemCount: Int
    let progressPercent: Int
    let lessons: [TrainingLessonDetail]
    let objectives: [TrainingObjectiveDetail]
}

struct TrainingLessonDetail: Decodable, Identifiable {
    let id: String
    let title: String
    let type: String?
    let order: Int
    let contentMd: String?
    let videoUrl: String?
    let filePath: String?
    let fileName: String?
    let durationSeconds: Int?
    let progressStatus: String
    let completedAt: Date?
    let skillCount: Int
    let completedSkillCount: Int
    let skills: [TrainingSkillDetail]
    let quiz: TrainingQuizDetail?
}

struct TrainingSkillDetail: Decodable, Identifiable {
    let id: String
    let title: String
    let instructions: String?
    let contentMd: String?
    let videoUrl: String?
    let videoFilePath: String?
    let videoFileName: String?
    let contentFilePath: String?
    let contentFileName: String?
    let order: Int
    let isCompleted: Bool
}

struct TrainingQuizDetail: Decodable, Identifiable {
    let id: String
    let title: String?
    let firstQuestionPrompt: String?
}

struct TrainingObjectiveDetail: Decodable, Identifiable {
    let id: String
    let title: String
    let instructions: String?
    let contentMd: String?
    let videoUrl: String?
    let videoFilePath: String?
    let videoFileName: String?
    let contentFilePath: String?
    let contentFileName: String?
    let objectiveType: String
    let jprEnabled: Bool
    let order: Int
    let progressStatus: String
    let note: String?
    let completedAt: Date?
    let updatedAt: Date?
    let jprs: [TrainingJPRDetail]
}

struct TrainingJPRDetail: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let order: Int
    let steps: [TrainingJPRStepDetail]
}

struct TrainingJPRStepDetail: Decodable, Identifiable {
    let id: String
    let text: String
    let order: Int
    let description: String?
    let required: Bool?
    let safetyCritical: Bool?
    let autoFailOnFail: Bool?

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case title
        case description
        case order
        case required
        case safetyCritical
        case autoFailOnFail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        text = try container.decodeIfPresent(String.self, forKey: .text)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? "Step"
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        description = try container.decodeIfPresent(String.self, forKey: .description)
        required = try container.decodeIfPresent(Bool.self, forKey: .required)
        safetyCritical = try container.decodeIfPresent(Bool.self, forKey: .safetyCritical)
        autoFailOnFail = try container.decodeIfPresent(Bool.self, forKey: .autoFailOnFail)
    }
}

struct TrainingProgressUpdateRequest: Encodable, Equatable {
    let itemType: String
    let itemId: String
    let status: String

    static func completeLesson(id: String) -> TrainingProgressUpdateRequest {
        TrainingProgressUpdateRequest(
            itemType: "LESSON",
            itemId: id,
            status: "COMPLETED"
        )
    }

    static func completeObjective(id: String) -> TrainingProgressUpdateRequest {
        TrainingProgressUpdateRequest(
            itemType: "OBJECTIVE",
            itemId: id,
            status: "COMPLETED"
        )
    }
}

struct TrainingProgressUpdateResponse: Decodable, Equatable {
    let success: Bool
    let status: String?
    let completedAt: Date?
    let error: String?
}

extension MobileTrainingCourseDetail {
    var progressDisplayText: String {
        switch progressStatus {
        case "COMPLETED":
            return "Completed"
        case "IN_PROGRESS":
            return "In progress"
        default:
            return "Not started"
        }
    }
}

extension TrainingModuleDetail {
    var progressDisplayText: String {
        "\(completedItemCount) of \(totalItemCount) items complete"
    }
}
