import Foundation

struct AnnouncementsResponse: Codable {
    let success: Bool
    let message: String?
    let announcements: [AnnouncementItem]?
}
