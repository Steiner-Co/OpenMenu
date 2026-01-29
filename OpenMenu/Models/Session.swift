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
    
    /// The identifier to copy to clipboard (prefers id, falls back to path)
    var identifier: String {
        if let idValue = idValue, !idValue.isEmpty {
            return idValue
        }
        if let path = path, !path.isEmpty {
            return path
        }
        return ""
    }
    
    /// For Identifiable conformance
    var id: String {
        return identifier
    }
    
    enum CodingKeys: String, CodingKey {
        case idValue = "id"
        case path
    }
}

struct SessionListResponse: Codable {
    let sessions: [Session]
}
