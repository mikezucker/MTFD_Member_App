from pathlib import Path

path = Path("Features/Dashboard/Views/DashboardView.swift")

text = path.read_text()

target = '@State private var selectedChiefScheduleDayId: String?\n'

insert = '''
    private var dashboardRole: DashboardRole {
        DashboardRole.from(session.currentUser?.role)
    }

'''

if "private var dashboardRole: DashboardRole" in text:
    print("dashboardRole already exists")
    raise SystemExit(0)

if target not in text:
    print("Target not found")
    raise SystemExit(1)

text = text.replace(target, target + insert, 1)

path.write_text(text)

print("✅ Inserted dashboardRole property")
