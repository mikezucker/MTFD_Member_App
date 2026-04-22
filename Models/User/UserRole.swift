import Foundation

enum UserRole: String, Codable, Hashable {
    case member
    case officer
    case chief

    var displayName: String {
        switch self {
        case .member:
            return "Member"
        case .officer:
            return "Officer"
        case .chief:
            return "Chief"
        }
    }
}
