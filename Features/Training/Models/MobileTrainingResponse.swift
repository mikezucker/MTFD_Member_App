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
    let attributes: [String]?
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


// MARK: - Training Assignment / Management Models

struct MobileTrainingManageCoursesResponse: Codable, Equatable {
    let success: Bool
    let courses: [MobileTrainingManageCourse]
    let error: String?
}

struct MobileTrainingManageCourse: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String?
    let status: String
    let updatedAt: Date?
    let moduleCount: Int
    let lessonCount: Int
    let objectiveCount: Int

    var detailLine: String {
        "\(moduleCount) modules · \(lessonCount) lessons · \(objectiveCount) objectives"
    }
}

struct CreateTrainingCourseRequest: Codable, Equatable {
    let title: String
    let description: String?
    let publish: Bool
    let trainingType: String
    let allowMemberObjectiveSelfCheckoff: Bool
    let objectiveFeedbackToMessages: Bool
    let enableInstructorDashboard: Bool
    let targetType: String?
    let targetRole: String?
    let targetStation: String?
    let targetUserId: String?
    let targetUserIds: [String]?
    let dueAt: Date?
    let includeFutureUsers: Bool?
    let modules: [CreateTrainingCourseModule]
}

struct CreateTrainingCourseModule: Codable, Equatable {
    let title: String
    let contentTypes: [String]
    let practicalSkillCount: Int
    let videoTitle: String?
    let videoUrl: String?
    let imageTitle: String?
    let imageUrl: String?
    let documentTitle: String?
    let documentUrl: String?
    let quizPrompt: String?
    let practicalTitle: String?
    let practicalInstructions: String?
    let practicalScenarios: [TrainingDraftPracticalScenario]?
}

struct TrainingDraftPracticalScenario: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var instructions: String

    private enum CodingKeys: String, CodingKey {
        case title
        case instructions
    }
}

struct CreateTrainingCourseResponse: Codable, Equatable {
    let success: Bool
    let message: String?
    let error: String?
}

struct UpdateTrainingCourseRequest: Codable, Equatable {
    let title: String
    let description: String?
    let status: String
    let trainingType: String
    let allowMemberObjectiveSelfCheckoff: Bool
    let objectiveFeedbackToMessages: Bool
    let enableInstructorDashboard: Bool
    let modules: [CreateTrainingCourseModule]
}

struct TrainingMutationResponse: Codable, Equatable {
    let success: Bool
    let message: String?
    let error: String?
}

struct TrainingUploadResponse: Codable, Equatable {
    let success: Bool
    let file: TrainingUploadedFile?
    let error: String?
}

struct TrainingUploadedFile: Codable, Equatable {
    let filePath: String
    let fileName: String
    let mimeType: String
    let sizeBytes: Int?
}

enum TrainingCourseType: String, CaseIterable, Identifiable {
    case selfPaced = "SELF_PACED"
    case practicalHandsOn = "PRACTICAL_HANDS_ON"
    case classroom = "CLASSROOM"
    case hybrid = "HYBRID"
    case policyReview = "POLICY_REVIEW"
    case emsCompetency = "EMS_COMPETENCY"
    case jprSkill = "JPR_SKILL"
    case drill = "DRILL"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .selfPaced: return "Self-paced"
        case .practicalHandsOn: return "Practical / Hands-on"
        case .classroom: return "Classroom"
        case .hybrid: return "Hybrid"
        case .policyReview: return "Policy / SOG Review"
        case .emsCompetency: return "EMS Competency"
        case .jprSkill: return "JPR / Skill Evaluation"
        case .drill: return "Drill / Company Training"
        }
    }

    var emoji: String {
        switch self {
        case .selfPaced: return "📚"
        case .practicalHandsOn: return "🧤"
        case .classroom: return "🏫"
        case .hybrid: return "🔀"
        case .policyReview: return "📋"
        case .emsCompetency: return "🚑"
        case .jprSkill: return "✅"
        case .drill: return "🚒"
        }
    }
}

struct AssignTrainingCourseRequest: Codable, Equatable {
    let targetType: String
    let targetRole: String?
    let targetStation: String?
    let targetUserId: String?
    let targetUserIds: [String]?
    let dueAt: Date?
    let includeFutureUsers: Bool?

    static func role(targetRole: String, dueAt: Date?) -> AssignTrainingCourseRequest {
        AssignTrainingCourseRequest(
            targetType: "ROLE",
            targetRole: targetRole,
            targetStation: nil,
            targetUserId: nil,
            targetUserIds: nil,
            dueAt: dueAt,
            includeFutureUsers: nil
        )
    }

    static func allUsers(dueAt: Date?, includeFutureUsers: Bool) -> AssignTrainingCourseRequest {
        AssignTrainingCourseRequest(
            targetType: "ALL_USERS",
            targetRole: nil,
            targetStation: nil,
            targetUserId: nil,
            targetUserIds: nil,
            dueAt: dueAt,
            includeFutureUsers: includeFutureUsers
        )
    }

    static func station(station: String, dueAt: Date?) -> AssignTrainingCourseRequest {
        AssignTrainingCourseRequest(
            targetType: "STATION",
            targetRole: nil,
            targetStation: station,
            targetUserId: nil,
            targetUserIds: nil,
            dueAt: dueAt,
            includeFutureUsers: nil
        )
    }

    static func users(userIds: [String], dueAt: Date?) -> AssignTrainingCourseRequest {
        AssignTrainingCourseRequest(
            targetType: userIds.count == 1 ? "USER" : "USERS",
            targetRole: nil,
            targetStation: nil,
            targetUserId: userIds.count == 1 ? userIds.first : nil,
            targetUserIds: userIds.count > 1 ? userIds : nil,
            dueAt: dueAt,
            includeFutureUsers: nil
        )
    }
}

struct AssignTrainingCourseResponse: Codable, Equatable {
    let success: Bool
    let createdCount: Int?
    let skippedCount: Int?
    let assignmentIds: [String]?
    let message: String?
    let error: String?
}

enum AssignTrainingTargetRole: String, CaseIterable, Identifiable {
    case battalionChief = "BATTALION_CHIEF"
    case officerCareer = "OFFICER_CAREER"
    case officerVolunteer = "OFFICER_VOLUNTEER"
    case memberCareer = "MEMBER_CAREER"
    case memberVolunteer = "MEMBER_VOLUNTEER"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .battalionChief:
            return "Battalion Chief"
        case .officerCareer:
            return "Career Officer"
        case .officerVolunteer:
            return "Volunteer Officer"
        case .memberCareer:
            return "Career Member"
        case .memberVolunteer:
            return "Volunteer Member"
        }
    }

    var emoji: String {
        switch self {
        case .battalionChief:
            return "🛡️"
        case .officerCareer:
            return "🏢"
        case .officerVolunteer:
            return "🚒"
        case .memberCareer:
            return "👨‍🚒"
        case .memberVolunteer:
            return "🙋"
        }
    }
}
