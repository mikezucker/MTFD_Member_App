import Foundation

struct AssignedTrainingCourse: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let assignmentStatus: String
    let assignedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case assignmentStatus
        case assignedAt
    }
}
