//
//  ProjectTodoStore.swift
//  OpenMenu
//
//  Created by Codex on 03/02/26.
//

import Foundation

struct ProjectTodoStore {
    private static let storageKey = "projectTodos"

    static func load() -> [String: [ProjectTodo]] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: storageKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: [ProjectTodo]].self, from: data)
        } catch {
            print("❌ ProjectTodoStore: Failed to decode todos - \(error.localizedDescription)")
            return [:]
        }
    }

    static func save(_ todos: [String: [ProjectTodo]]) {
        let pruned = todos.filter { !$0.value.isEmpty }
        do {
            let data = try JSONEncoder().encode(pruned)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("❌ ProjectTodoStore: Failed to encode todos - \(error.localizedDescription)")
        }
    }
}
