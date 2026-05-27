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
