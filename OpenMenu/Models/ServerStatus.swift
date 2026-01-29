//
//  ServerStatus.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import Foundation

struct ServerStatus: Codable {
    let healthy: Bool
    let version: String?
    
    /// Convenience initializer for offline state
    static var offline: ServerStatus {
        ServerStatus(healthy: false, version: nil)
    }
}
