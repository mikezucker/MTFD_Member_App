import Foundation

struct User: Codable {
    let name: String
    let role: String
    let memberID: String
    let expiration: String

    enum CodingKeys: String, CodingKey {
        case name
        case role
        case memberID = "member_id"
        case expiration
    }
}
