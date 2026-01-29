//
//  AppSettings.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import Foundation

enum HeartbeatInterval: Double, CaseIterable {
    case fast = 5.0
    case normal = 10.0
    case slow = 30.0
    
    var label: String {
        switch self {
        case .fast:
            return "5 seconds"
        case .normal:
            return "10 seconds"
        case .slow:
            return "30 seconds"
        }
    }
}

struct AppSettings {
    static let serverURLKey = "serverURL"
    static let heartbeatIntervalKey = "heartbeatInterval"
    static let showStatusTextKey = "showStatusText"
    static let launchAtLoginKey = "launchAtLogin"
    
    static let defaultServerURL = "http://127.0.0.1:4096"
    static let defaultInterval: HeartbeatInterval = .normal
    
    /// Validates a server URL string
    static func isValidURL(_ urlString: String) -> Bool {
        guard !urlString.isEmpty,
              let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https") else {
            return false
        }
        return true
    }
}
