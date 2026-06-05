
from pathlib import Path

BASE = Path("Features/Dashboard")

(models := BASE / "Models").mkdir(parents=True, exist_ok=True)

(views := BASE / "Views").mkdir(parents=True, exist_ok=True)

(models / "DashboardRole.swift").write_text("""import Foundation

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

""")

files = {

    "AdminDashboardView.swift": "Admin Dashboard",

    "ChiefDashboardView.swift": "Chief Dashboard",

    "CareerOfficerDashboardView.swift": "Career Officer Dashboard",

    "VolunteerOfficerDashboardView.swift": "Volunteer Officer Dashboard",

    "CareerMemberDashboardView.swift": "Career Member Dashboard",

    "VolunteerMemberDashboardView.swift": "Volunteer Member Dashboard",

}

for filename, title in files.items():

    struct_name = filename.replace(".swift", "")

    (views / filename).write_text(f"""import SwiftUI

struct {struct_name}: View {{

    var body: some View {{

        Text("{title}")

    }}

}}

""")

print("Done.")

