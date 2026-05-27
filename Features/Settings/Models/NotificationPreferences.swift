import Foundation

struct NotificationPreferences: Codable {
    // Master switch
    var isEnabled: Bool = true

    // 🚒 Dispatch
    var dispatchAlertsEnabled: Bool = true
    var criticalDispatchAlerts: Bool = false
    var callTypes: Set<String> = ["FIRE", "EMS", "MVA"]
    var workingOnly: Bool = false

    // 🚓 Apparatus / Stations
    var allUnits: Bool = true
    var units: Set<String> = []
    var stations: Set<String> = []

    // 📣 Messages
    var departmentMessagesEnabled: Bool = true
    var stationMessagesEnabled: Bool = true
    var messageCenterEnabled: Bool = true

    // 🎓 Training
    var trainingAssignmentsEnabled: Bool = true

    // 📄 Documents / SOPs
    var documentAssignmentsEnabled: Bool = true

    // ⏰ Quiet Hours
    var quietHoursEnabled: Bool = false
    var quietStart: Date = Date()
    var quietEnd: Date = Date()

    // 🔕 Behavior
    var respectDoNotDisturb: Bool = true
}
//  NotificationPreferences.swift.swift
//  MTFD Member App
//
//  Created by Michael Zucker on 4/27/26.
//

