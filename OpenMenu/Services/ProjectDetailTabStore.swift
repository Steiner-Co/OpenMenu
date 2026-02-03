//
//  ProjectDetailTabStore.swift
//  OpenMenu
//
//  Created by Codex on 03/02/26.
//

import Foundation

struct ProjectDetailTabStore {
    private static let storageKey = "projectDetailTabs"

    static func load() -> [String: ProjectDetailTab] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: storageKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: ProjectDetailTab].self, from: data)
        } catch {
            print("❌ ProjectDetailTabStore: Failed to decode tabs - \(error.localizedDescription)")
            return [:]
        }
    }

    static func save(_ tabs: [String: ProjectDetailTab]) {
        let pruned = tabs.filter { !$0.key.isEmpty }
        do {
            let data = try JSONEncoder().encode(pruned)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("❌ ProjectDetailTabStore: Failed to encode tabs - \(error.localizedDescription)")
        }
    }
}
