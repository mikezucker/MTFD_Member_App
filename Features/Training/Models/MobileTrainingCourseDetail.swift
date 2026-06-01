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
    let progressStatus: String
    let progressPercent: Int
    let completedAt: Date?
    let moduleCount: Int
    let lessonCount: Int
    let objectiveCount: Int
    let completedItemCount: Int?
    let totalItemCount: Int?
    let modules: [TrainingModuleDetail]
    let lastUpdated: Date?
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
}

struct TrainingObjectiveDetail: Decodable, Identifiable {
    let id: String
    let title: String
    let instructions: String?
    let contentMd: String?
    let videoUrl: String?
    let videoFileName: String?
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
