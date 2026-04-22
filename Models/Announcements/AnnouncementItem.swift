import Foundation

struct AnnouncementItem: Codable, Identifiable {
    let id: String
    let title: String
    let message: String
    let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case message
        case publishedAt = "published_at"
    }
}
