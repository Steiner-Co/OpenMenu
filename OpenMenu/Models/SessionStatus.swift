//
//  SessionStatus.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import Foundation

struct SessionStatus: Codable {
    let type: SessionActivityStatus

    enum SessionActivityStatus: String, Codable {
        case idle
        case busy
        case retry
    }
}

extension Dictionary where Key == String, Value == SessionStatus {
    func isSessionWorking(_ sessionID: String) -> Bool {
        guard let status = self[sessionID] else { return false }
        return status.type == .busy
    }

    var workingSessionIDs: [String] {
        keys.filter { isSessionWorking($0) }
    }
}
