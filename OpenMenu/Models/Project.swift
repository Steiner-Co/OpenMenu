//
//  Project.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import Foundation

struct Project: Codable, Identifiable {
    let id: String
    let name: String?
    let worktree: String?
    let sandboxes: [String]?
    let time: ProjectTime?

    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        if let worktree = worktree {
            let components = worktree.components(separatedBy: "/")
            if let last = components.last, !last.isEmpty {
                return last
            }
        }
        return id
    }

    var path: String? {
        worktree
    }
}

struct ProjectTime: Codable {
    let created: Double?
    let updated: Double?
}

struct VCSStatus: Codable {
    let branch: String?
    let modifiedFilesCount: Int?
    let stagedFilesCount: Int?
    let untrackedFilesCount: Int?
    let ahead: Int?
    let behind: Int?
    let isClean: Bool?
    let hasUncommittedChanges: Bool?

    enum CodingKeys: String, CodingKey {
        case branch
        case modifiedFilesCount = "modified_files_count"
        case stagedFilesCount = "staged_files_count"
        case untrackedFilesCount = "untracked_files_count"
        case ahead
        case behind
        case isClean = "is_clean"
        case hasUncommittedChanges = "has_uncommitted_changes"
    }

    var totalModified: Int {
        (modifiedFilesCount ?? 0) + (stagedFilesCount ?? 0) + (untrackedFilesCount ?? 0)
    }

    var isRepo: Bool {
        branch != nil
    }

    var hasChanges: Bool {
        totalModified > 0 || (hasUncommittedChanges ?? false)
    }
}

struct ProjectInfo: Codable {
    let project: Project?
    let vcs: VCSStatus?
}
