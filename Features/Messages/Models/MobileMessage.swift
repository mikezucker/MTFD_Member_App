import Foundation

struct MobileMessagesResponse: Decodable {
    let success: Bool
    let unreadCount: Int
    let messages: [MobileMessage]
}

struct MarkMessageReadResponse: Decodable {
    let success: Bool
    let unreadCount: Int
    let message: MobileMessage
}

struct MobileMessage: Identifiable, Decodable, Equatable {
    let id: String
    let title: String
    let body: String?
    let type: String
    let priority: String
    let actionType: String
    let actionTargetId: String?
    let dispatchId: String?
    let announcementId: String?
    let trainingId: String?
    let isRead: Bool
    let readAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let expiresAt: Date?
}//
//  MobileMessage.swift
//  MTFD Member App
//
//  Created by Michael Zucker on 5/10/26.
//

