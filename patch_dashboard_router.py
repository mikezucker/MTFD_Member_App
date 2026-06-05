from pathlib import Path

path = Path("Features/Dashboard/Views/DashboardView.swift")
text = path.read_text()

old = """                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
"""

new = """                    ScrollView(showsIndicators: false) {

                        switch dashboardRole {

                        case .admin:
                            AdminDashboardView()

                        case .chief:
                            ChiefDashboardView()

                        case .officerCareer:
                            CareerOfficerDashboardView()

                        case .officerVolunteer:
                            VolunteerOfficerDashboardView()

                        case .memberCareer:
                            CareerMemberDashboardView()

                        case .memberVolunteer:
                            VolunteerMemberDashboardView()
                        }

                        /*
"""

if old not in text:
    print("Could not find ScrollView start")
    raise SystemExit(1)

text = text.replace(old, new, 1)

path.write_text(text)

print("Patched ScrollView start")
print("NOW WE NEED THE END LOCATION BEFORE COMPILING")
