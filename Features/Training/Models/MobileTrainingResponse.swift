import Foundation

struct MobileTrainingResponse: Codable, Equatable {
    let success: Bool
    let viewer: TrainingViewer
    let capabilities: TrainingCapabilities
    let scope: TrainingScope
    let summary: TrainingSummary
    let myTraining: [MobileTrainingItem]
    let pendingEvaluations: [PendingTrainingEvaluation]
    let managedMembers: [ManagedTrainingMember]
    let lastUpdated: Date?
}

struct TrainingViewer: Codable, Equatable {
    let id: String
    let name: String?
    let email: String
    let role: String
    let company: String?
}

struct TrainingCapabilities: Codable, Equatable {
    let canCreateTraining: Bool
    let canAssignTraining: Bool
    let canEvaluateTraining: Bool
    let canManageReporting: Bool
    let canViewManagedProgress: Bool
    let canViewDepartmentProgress: Bool
}

struct TrainingScope: Codable, Equatable {
    let type: String
    let company: String?
    let managedMemberCount: Int
}

struct TrainingSummary: Codable, Equatable {
    let assignedCount: Int
    let inProgressCount: Int
    let completedCount: Int
    let overdueCount: Int
    let pendingEvaluationCount: Int
}

struct MobileTrainingItem: Codable, Identifiable, Equatable {
    let id: String
    let courseId: String
    let title: String
    let description: String?
    let status: String
    let dueAt: Date?
    let isOverdue: Bool
    let assignedAt: Date?
    let assignmentType: String
    let progressStatus: String
    let progressPercent: Int
    let completedAt: Date?
    let moduleCount: Int
    let lessonCount: Int
    let objectiveCount: Int
    let practicalObjectiveCount: Int

    var progressDisplayText: String {
        switch progressStatus {
        case "COMPLETED":
            return "Completed"
        case "IN_PROGRESS":
            return "\(progressPercent)% complete"
        default:
            return progressPercent > 0 ? "\(progressPercent)% complete" : "Not started"
        }
    }

    var detailLine: String {
        "\(moduleCount) modules · \(lessonCount) lessons · \(objectiveCount) objectives"
    }
}

struct PendingTrainingEvaluation: Codable, Identifiable, Equatable {
    let id: String
    let jprId: String
    let title: String
    let courseId: String
    let courseTitle: String
    let outcome: String
    let startedAt: Date?
    let updatedAt: Date?
}

struct ManagedTrainingMember: Codable, Identifiable, Equatable {
    let id: String
    let name: String?
    let email: String
    let role: String
    let company: String?
}

extension JSONDecoder {
    static var mtfdTrainingDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if container.decodeNil() {
                throw DecodingError.valueNotFound(
                    Date.self,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected date string but found null."
                    )
                )
            }

            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: value) {
                return date
            }

            if let date = ISO8601DateFormatter.standardInternetDateTime.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }

        return decoder
    }
}

private extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let standardInternetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}//
//  MobileTrainingResponse.swift
//  MTFD Member App
//
//  Created by Michael Zucker on 5/21/26.
//

