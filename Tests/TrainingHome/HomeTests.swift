import Foundation

@main struct TrainingHomeTests {
    static func main() {
        let date = ISO8601DateFormatter()
        let now = date.date(from: "2026-11-02T17:00:00Z")!
        func skill(_ id: String, title: String, member: String = "Firefighter", completed: Int = 0, due: String? = nil, outcome: String? = nil) -> GuidedSkillRequirement {
            GuidedSkillRequirement(id: id+member, userId: member, member: member, versionId: id, courseId: "fixture", number: "JPR-"+id, title: title, revision: 1, required: 1, completed: completed, percent: completed*100, dueAt: due.flatMap { date.date(from: $0) }, history: outcome.map { [GuidedSkillHistory(id: "result", outcome: $0, completedAt: now, evaluator: "Instructor")] } ?? [])
        }
        let done = skill("done", title: "A completed skill", completed: 1, due: "2026-01-01T17:00:00Z")
        let overdue = skill("overdue", title: "Z overdue skill", due: "2026-11-01T17:00:00Z")
        let retry = skill("retry", title: "Practice skill", due: "2026-11-10T17:00:00Z", outcome: "FAIL")
        let incomplete = skill("partial", title: "Incomplete skill", due: "2026-11-05T17:00:00Z", outcome: "INCOMPLETE")
        let newSkill = skill("new", title: "A new skill", due: "2026-11-03T17:00:00Z")
        let rows = [done, newSkill, retry, overdue, incomplete]
        precondition(AnnualTrainingHome.skillRows(rows, now: now).map { $0[0].versionId } == ["overdue", "partial", "retry", "new", "done"], "Overdue, follow-up and earlier deadlines must lead; complete skills stay last")
        precondition(AnnualTrainingHome.skillRows(rows, filter: .outstanding, now: now).count == 4)
        precondition(AnnualTrainingHome.skillRows(rows, filter: .completed, now: now).first?.first?.versionId == "done")
        precondition(AnnualTrainingHome.skillRows(rows, search: "  jpr-RETRY  ", now: now).first?.first?.versionId == "retry", "Search trims whitespace and matches JPR numbers case-insensitively")
        let partialGroup = [done, skill("done", title: done.title, member: "Another firefighter")]
        precondition(AnnualTrainingHome.skillRows(partialGroup, filter: .completed, now: now).isEmpty, "A crew skill is not complete until every selected member meets the target")
        precondition(AnnualTrainingHome.skillRows(partialGroup, filter: .outstanding, now: now).count == 1)
        precondition(AnnualTrainingHome.skillRows(partialGroup, search: "another", now: now).first?.count == 2, "Member search retains the whole selected skill group and its honest progress denominator")
        precondition(AnnualTrainingHome.skillRows([], now: now).isEmpty)
        print("PASS: training home prioritizes attention, filters complete crew skills, and searches skill/member/JPR without changing progress totals")
    }
}
