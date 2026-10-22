"""Run isolated persistence and real card-dispatch regression tests without a login.

Compile the production layout model unchanged. Extract each production card switch
into a recording builder so empty-data suppression, missing cases, merged cards,
and saved ordering are tested without networking or changing a member's settings.
"""
from pathlib import Path
import re
import subprocess
import tempfile
import uuid

root = Path(__file__).resolve().parents[2]
views = root / 'Features/Dashboard/Views'
roles = {'Chief': ['ADMIN', 'CHIEF', 'BATTALION_CHIEF'], 'CareerOfficer': ['OFFICER_CAREER'], 'VolunteerOfficer': ['OFFICER_VOLUNTEER'], 'CareerMember': ['MEMBER_CAREER'], 'VolunteerMember': ['MEMBER_VOLUNTEER']}

def method(source, signature):
    start = source.index(signature)
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

preamble = '''import Foundation
@resultBuilder enum CardBuilder {
    static func buildBlock(_ parts: [String]...) -> [String] { parts.flatMap { $0 } }
    static func buildExpression(_ part: [String]) -> [String] { part }
    static func buildExpression(_ part: EmptyView) -> [String] { [] }
    static func buildOptional(_ part: [String]?) -> [String] { part ?? [] }
    static func buildEither(first part: [String]) -> [String] { part }
    static func buildEither(second part: [String]) -> [String] { part }
}
struct EmptyView {}
struct Schedule { let isWorkingNow: Bool; let nextShift: Int? }
'''
markers = {
    'commandOverview': ['chiefBriefSection', 'careerOfficerOverviewSection', 'volunteerOfficerOverviewSection', 'belongingCard'],
    'messages': ['commandMessagesSection', 'messagesSection', 'messagesCard'],
    'assignedTraining': ['trainingSection', 'nextStepCard'],
    'apparatusWorkOrders': ['apparatusWorkOrdersSection', 'workOrdersSection', 'apparatusStatusCard'],
    'documents': ['documentsSection'], 'scheduleEvents': ['scheduleOutlookSection', 'scheduleSection'],
    'recentCalls': ['recentDispatchesSection', 'pastDispatchesSection'],
}
stubs = '\n'.join(f'    var {name}: [String] {{ ["{card}"] }}' for card, names in markers.items() for name in names)
stubs += '''
    func updatesGroup(title: String, emptyMessage: String, updates: [Int]) -> [String] {
        [title == "Station Updates" ? "stationUpdates" : "departmentUpdates"]
    }
    func announcementsCard(title: String, updates: [Int]) -> [String] {
        [title == "Station Updates" ? "stationUpdates" : "departmentUpdates"]
    }
'''
fixtures = '''
    let state: Int
    var isLoading: Bool { state == 0 }
    var upcomingSchedule: Schedule? { state == 2 ? Schedule(isWorkingNow: true, nextShift: 1) : nil }
    var workOrders: [Int] { state == 2 ? [1] : [] }
    var assignedTraining: [Int] { state == 2 ? [1] : [] }
    var pendingDocuments: Int { state == 2 ? 1 : 0 }
    var recentCalls: [Int] { state == 2 ? [1] : [] }
    var stationUpdates: [Int] { state == 2 ? [1] : [] }
    var departmentUpdates: [Int] { state == 2 ? [1] : [] }
'''
generated = preamble
for name in roles:
    source = (views / f'{name}DashboardView.swift').read_text()
    assert 'ForEach(dashboardCards)' in source, f'{name} must render the configured list directly'
    dispatch = method(source, 'private func dashboardCard(').replace('private func', 'func', 1).replace('-> some View', '-> [String]', 1)
    generated += f'\nstruct {name}Recorder {{\n' + fixtures + stubs + '\n@CardBuilder\n' + dispatch + '\n}\n'
generated += 'func render(role: String, card: DashboardCardID, state: Int) -> [String] {\n switch role {\n'
for name, role_names in roles.items():
    generated += 'case ' + ', '.join(f'"{role}"' for role in role_names) + f': return {name}Recorder(state: state).dashboardCard(card)\n'
generated += 'default: preconditionFailure("Unexpected role")\n}\n}\n'
router = (views / 'DashboardView.swift').read_text()
assert 'DashboardCardLayoutDefaults.visibleCards(for:' in router
assert 'publisher(for: .dashboardLayoutDidChange)' in router and 'dashboardLayoutRefreshID = UUID()' in router
assert router.count('dashboardCards: configuredDashboardCards') == 5
assert 'case .admin, .chief:' in router and 'AdminDashboardView()' not in router
settings = (root / 'Features/Settings/Views/DashboardLayoutView.swift').read_text()
assert '.onMove(perform: moveCards)' in settings and 'cards.move(fromOffsets: source, toOffset: destination)' in settings
assert 'usesFixedDashboardLayout' not in settings
assert 'saveOrder(cards, for: session.currentUser?.role)' in settings
assert 'saveHiddenCards(hiddenCards, for: session.currentUser?.role)' in settings
suite = 'mtfd-dashboard-tests-' + str(uuid.uuid4())
with tempfile.TemporaryDirectory(prefix='mtfd-dashboard-tests-') as directory:
    directory = Path(directory)
    recorders = directory / 'Recorders.swift'
    recorders.write_text(generated)
    executable = directory / 'tests'
    subprocess.run(['swiftc', '-parse-as-library', str(root / 'Features/Dashboard/Models/DashboardCardLayout.swift'), str(root / 'Features/Dashboard/Models/DashboardRole.swift'), str(recorders), str(root / 'Tests/DashboardLayout/LayoutTests.swift'), '-o', str(executable)], check=True)
    try:
        for phase in ['exercise', 'reopen']:
            subprocess.run([str(executable), suite, phase], check=True)
    finally:
        subprocess.run([str(executable), suite, 'cleanup'], check=True)
print('PASS: Settings movement/persistence and all dashboard routing contracts')
