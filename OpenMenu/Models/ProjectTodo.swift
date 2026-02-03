//
//  ProjectTodo.swift
//  OpenMenu
//
//  Created by Codex on 03/02/26.
//

import Foundation

struct ProjectTodo: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var isDone: Bool
    let createdAt: Double
}
