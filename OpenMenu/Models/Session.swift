//
//  Session.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import Foundation

struct Session: Codable, Identifiable {
    let idValue: String?
    let path: String?
    let title: String?
    
    /// The session ID to copy to clipboard
    var sessionID: String {
        if let idValue = idValue, !idValue.isEmpty {
            return idValue
        }
        return ""
    }
    
    /// Display name for the session (prefers title, falls back to path, then id)
    var displayName: String {
        if let title = title, !title.isEmpty {
            return title
        }
        if let path = path, !path.isEmpty {
            // Extract just the directory name from the path
            return (path as NSString).lastPathComponent
        }
        return sessionID
    }
    
    /// For Identifiable conformance
    var id: String {
        return sessionID
    }
    
    enum CodingKeys: String, CodingKey {
        case idValue = "id"
        case path
        case title
    }
}

struct SessionListResponse: Codable {
    let sessions: [Session]
}
