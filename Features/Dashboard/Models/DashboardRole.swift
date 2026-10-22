import Foundation

enum DashboardRole {

    case admin

    case chief

    case officerCareer

    case officerVolunteer

    case memberCareer

    case memberVolunteer

    static func from(_ rawRole: String?) -> DashboardRole {

        let role = rawRole?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")

        switch role {

        case "ADMIN": return .admin

        case "CHIEF", "BATTALION_CHIEF": return .chief

        case "OFFICER_CAREER": return .officerCareer

        case "OFFICER_VOLUNTEER": return .officerVolunteer

        case "MEMBER_CAREER": return .memberCareer

        case "MEMBER_VOLUNTEER": return .memberVolunteer

        default: return .memberVolunteer

        }

    }

}
