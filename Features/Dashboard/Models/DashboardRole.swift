import Foundation

enum DashboardRole {

    case admin

    case chief

    case officerCareer

    case officerVolunteer

    case memberCareer

    case memberVolunteer

    static func from(_ rawRole: String?) -> DashboardRole {

        switch rawRole?.uppercased() {

        case "ADMIN": return .admin

        case "CHIEF": return .chief

        case "OFFICER_CAREER": return .officerCareer

        case "OFFICER_VOLUNTEER": return .officerVolunteer

        case "MEMBER_CAREER": return .memberCareer

        case "MEMBER_VOLUNTEER": return .memberVolunteer

        default: return .memberVolunteer

        }

    }

}

