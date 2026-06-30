import Foundation

struct MobileMessagesResponse: Decodable {
    let success: Bool
    let unreadCount: Int
    let messages: [MobileMessage]
    let manageableMessages: [MobileMessage]?
}

struct MarkMessageReadResponse: Decodable {
    let success: Bool
    let unreadCount: Int
    let message: MobileMessage
}

struct CreateCommandMessageResponse: Decodable {
    let success: Bool
    let message: MobileMessage
    let error: String?
}

struct DeleteMessageResponse: Decodable {
    let success: Bool
    let error: String?
}

struct MobileMessage: Identifiable, Decodable, Equatable {
    let id: String
    let title: String
    let body: String?
    let type: String
    let priority: String
    let audience: String?
    let stationNumberTarget: Int?
    let stationLabel: String?
    let createdByUserId: String?
    let createdByName: String?
    let createdByRole: String?
    let actionType: String
    let actionTargetId: String?
    let linkUrl: String?
    let linkLabel: String?
    let dispatchId: String?
    let announcementId: String?
    let trainingId: String?
    let isPinned: Bool?
    let isActive: Bool?
    let canDelete: Bool?
    let isRead: Bool
    let readAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let expiresAt: Date?

    var displayIcon: String {
        switch type {
        case "TRAINING", "TRAINING_REMINDER", "TRAINING_ASSIGNMENT":
            return "✅"
        case "EVENT":
            return "📅"
        case "STAFFING":
            return "👥"
        case "OFFICER_NOTE":
            return "🚒"
        case "POLICY_LINK", "DOCUMENT", "DOCUMENT_SIGNATURE":
            return "📄"
        case "ANNOUNCEMENT":
            return "📬"
        default:
            return priority == "CRITICAL" ? "⚠️" : "📬"
        }
    }

    var audienceDisplayLabel: String {
        if let stationLabel, !stationLabel.isEmpty {
            return stationLabel
        }

        switch audience {
        case "ALL_OFFICERS", "OFFICERS":
            return "Officers"
        case "CHIEFS":
            return "Chiefs"
        case "CAREER_MEMBERS":
            return "Career"
        case "VOLUNTEER_MEMBERS":
            return "Volunteers"
        case "ALL_MEMBERS":
            return "Department"
        default:
            return "Department"
        }
    }

    var typeDisplayLabel: String {
        type.replacingOccurrences(of: "_", with: " ").capitalized
    }
}//
//  MobileMessage.swift
//  MTFD Member App
//
//  Created by Michael Zucker on 5/10/26.
//
