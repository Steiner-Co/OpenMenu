//
//  ProjectDetailTab.swift
//  OpenMenu
//
//  Created by Codex on 03/02/26.
//

import Foundation

enum ProjectDetailTab: String, CaseIterable, Identifiable, Codable {
    case sessions
    case todos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sessions:
            return "Sessions"
        case .todos:
            return "Todos"
        }
    }
}
