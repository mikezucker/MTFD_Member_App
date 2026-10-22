import Foundation
import SwiftUI

@main struct LayoutTests {
    static let roles = ["ADMIN", "CHIEF", "BATTALION_CHIEF", "OFFICER_CAREER", "OFFICER_VOLUNTEER", "MEMBER_CAREER", "MEMBER_VOLUNTEER"]
    static func main() throws {
        let suite = CommandLine.arguments[1]
        let phase = CommandLine.arguments[2]
        let defaults = UserDefaults(suiteName: suite)!
        if phase == "cleanup" { defaults.removePersistentDomain(forName: suite); return }
        if phase == "reopen" {
            for role in roles {
                let order = Array(DashboardCardLayoutDefaults.defaultOrder(for: role).reversed())
                precondition(DashboardCardLayoutDefaults.savedOrder(for: role, defaults: defaults) == order)
                precondition(DashboardCardLayoutDefaults.visibleCards(for: role, defaults: defaults) == Array(order.dropFirst()))
            }
            print("PASS: order and hidden settings survive a fresh process for all seven roles")
            return
        }
        var combinations = 0
        var moves = 0
        for role in roles {
            let initial = DashboardCardLayoutDefaults.defaultOrder(for: role)
            precondition(!initial.isEmpty && Set(initial).count == initial.count)
            precondition(DashboardCardLayoutDefaults.visibleCards(for: role, defaults: defaults) == initial)
            // Exercise the same Array.move used by the Settings list, in both directions,
            // with every source/destination, plus multi-selection moves.
            for source in initial.indices {
                for destination in 0...initial.count {
                    var order = initial
                    order.move(fromOffsets: IndexSet(integer: source), toOffset: destination)
                    DashboardCardLayoutDefaults.saveOrder(order, for: role, defaults: defaults)
                    precondition(DashboardCardLayoutDefaults.visibleCards(for: role, defaults: defaults) == order)
                    moves += 1
                }
            }
            var multi = initial
            multi.move(fromOffsets: IndexSet([0, 2]), toOffset: initial.count)
            DashboardCardLayoutDefaults.saveOrder(multi, for: role, defaults: defaults)
            precondition(DashboardCardLayoutDefaults.savedOrder(for: role, defaults: defaults) == multi)
            let reversed = Array(initial.reversed())
            DashboardCardLayoutDefaults.saveOrder(reversed, for: role, defaults: defaults)
            // All on/off combinations must preserve the relative saved order.
            // Includes all-off (no fallback cards) and both update cards independently.
            for mask in 0..<(1 << initial.count) {
                let hidden = Set(initial.enumerated().compactMap { mask & (1 << $0.offset) == 0 ? nil : $0.element })
                DashboardCardLayoutDefaults.saveHiddenCards(hidden, for: role, defaults: defaults)
                let visible = DashboardCardLayoutDefaults.visibleCards(for: role, defaults: defaults)
                precondition(visible == reversed.filter { !hidden.contains($0) })
                precondition(DashboardCardLayoutDefaults.savedOrder(for: role, defaults: defaults) == reversed)
                for state in 0...2 {
                    // Real dashboard switch bodies: loading, empty, and populated data.
                    let rendered = visible.flatMap { render(role: role, card: $0, state: state) }
                    precondition(rendered == visible.map(\.rawValue), "\(role), state \(state), mask \(mask): \(rendered)")
                }
                combinations += 1
            }
            DashboardCardLayoutDefaults.reset(for: role, defaults: defaults)
            precondition(DashboardCardLayoutDefaults.visibleCards(for: role, defaults: defaults) == initial)
            // Corrupted, legacy, duplicate and role-inapplicable IDs are safe to load.
            let key = "dashboard_card_order_" + role.lowercased()
            defaults.set(Data("bad json".utf8), forKey: key)
            precondition(DashboardCardLayoutDefaults.savedOrder(for: role, defaults: defaults) == initial)
            defaults.set(try JSONEncoder().encode([initial.last!.rawValue, "retiredCard", initial.last!.rawValue, "needsAttention"]), forKey: key)
            let repaired = DashboardCardLayoutDefaults.savedOrder(for: role, defaults: defaults)
            precondition(repaired == [initial.last!] + initial.dropLast())
            DashboardCardLayoutDefaults.saveOrder([.needsAttention] + reversed + reversed, for: role, defaults: defaults)
            precondition(DashboardCardLayoutDefaults.savedOrder(for: role, defaults: defaults) == reversed)
            DashboardCardLayoutDefaults.saveHiddenCards([.needsAttention], for: role, defaults: defaults)
            precondition(DashboardCardLayoutDefaults.hiddenCards(for: role, defaults: defaults).isEmpty)
            // Leave distinct persistent role-specific settings for fresh-process verification.
            DashboardCardLayoutDefaults.saveHiddenCards([reversed[0]], for: role, defaults: defaults)
        }
        // Layout changes must notify the dashboard immediately.
        final class Counter: @unchecked Sendable { var value = 0 }
        let counter = Counter()
        let observer = NotificationCenter.default.addObserver(forName: .dashboardLayoutDidChange, object: nil, queue: nil) { _ in
            counter.value += 1
        }
        DashboardCardLayoutDefaults.saveOrder(DashboardCardLayoutDefaults.savedOrder(for: "CHIEF", defaults: defaults), for: "CHIEF", defaults: defaults)
        DashboardCardLayoutDefaults.saveHiddenCards(DashboardCardLayoutDefaults.hiddenCards(for: "CHIEF", defaults: defaults), for: "CHIEF", defaults: defaults)
        DashboardCardLayoutDefaults.reset(for: "UNKNOWN_TEST_ROLE", defaults: defaults)
        NotificationCenter.default.removeObserver(observer)
        precondition(counter.value == 3)
        // Restore the fallback role's persisted fixture after the reset above.
        let volunteer = Array(DashboardCardLayoutDefaults.defaultOrder(for: "MEMBER_VOLUNTEER").reversed())
        DashboardCardLayoutDefaults.saveOrder(volunteer, for: "MEMBER_VOLUNTEER", defaults: defaults)
        DashboardCardLayoutDefaults.saveHiddenCards([volunteer[0]], for: "MEMBER_VOLUNTEER", defaults: defaults)
        // Role keys and the routing contract agree for equivalent spellings and fallback.
        precondition(DashboardRole.from(" officer-career ") == .officerCareer)
        precondition(DashboardRole.from(" battalion-chief ") == .chief)
        precondition(DashboardCardLayoutDefaults.savedOrder(for: " officer-career ", defaults: defaults) == DashboardCardLayoutDefaults.savedOrder(for: "OFFICER_CAREER", defaults: defaults))
        for fallback in [nil, "", "UNKNOWN"] as [String?] {
            precondition(DashboardRole.from(fallback) == .memberVolunteer)
            precondition(DashboardCardLayoutDefaults.defaultOrder(for: fallback) == DashboardCardLayoutDefaults.defaultOrder(for: "MEMBER_VOLUNTEER"))
        }
        // Changing one role cannot alter another role's saved order/visibility.
        let chief = DashboardCardLayoutDefaults.visibleCards(for: "CHIEF", defaults: defaults)
        DashboardCardLayoutDefaults.reset(for: "ADMIN", defaults: defaults)
        precondition(DashboardCardLayoutDefaults.visibleCards(for: "CHIEF", defaults: defaults) == chief)
        let admin = Array(DashboardCardLayoutDefaults.defaultOrder(for: "ADMIN").reversed())
        DashboardCardLayoutDefaults.saveOrder(admin, for: "ADMIN", defaults: defaults)
        DashboardCardLayoutDefaults.saveHiddenCards([admin[0]], for: "ADMIN", defaults: defaults)
        defaults.synchronize()
        print("PASS: \(moves) reorder moves, multi-moves, \(combinations) visibility combinations × three data states, seven roles, reset, repair and role isolation")
    }
}
