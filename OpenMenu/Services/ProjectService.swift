//
//  ProjectService.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import Foundation
import Combine

@Observable
class ProjectService {
    var serverURL: String = "http://127.0.0.1:4096"

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadSettings()
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.loadSettings()
            }
            .store(in: &cancellables)
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        serverURL = defaults.string(forKey: AppSettings.serverURLKey) ?? AppSettings.defaultServerURL
    }

    func fetchProjects() async throws -> [Project] {
        guard let url = URL(string: "\(serverURL)/project") else {
            print("❌ ProjectService: Invalid URL")
            throw ProjectServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("📡 ProjectService: Fetching projects from \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ ProjectService: Invalid response type")
                throw ProjectServiceError.invalidResponse
            }

            print("📡 ProjectService: /project responded with status \(httpResponse.statusCode)")

            if let responseBody = String(data: data, encoding: .utf8) {
                print("📡 ProjectService: /project response: \(responseBody)")
            }

            if httpResponse.statusCode == 404 {
                print("ℹ️ ProjectService: /project returned 404")
                return []
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ ProjectService: Server error \(httpResponse.statusCode)")
                throw ProjectServiceError.serverError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let projects = try decoder.decode([Project].self, from: data)
            print("✅ ProjectService: Decoded \(projects.count) projects")
            return projects
        } catch let error as ProjectServiceError {
            print("❌ ProjectService: ProjectServiceError - \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ ProjectService: Network/parsing error - \(error.localizedDescription)")
            throw ProjectServiceError.networkError(error.localizedDescription)
        }
    }

    func fetchVCSStatus(for projectID: String) async throws -> VCSStatus? {
        guard let url = URL(string: "\(serverURL)/vcs?project_id=\(projectID)") else {
            print("❌ ProjectService: Invalid VCS URL")
            throw ProjectServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("📡 ProjectService: Fetching VCS for project \(projectID) from \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ ProjectService: Invalid VCS response type")
                throw ProjectServiceError.invalidResponse
            }

            print("📡 ProjectService: /vcs responded with status \(httpResponse.statusCode)")

            if let responseBody = String(data: data, encoding: .utf8) {
                print("📡 ProjectService: /vcs response: \(responseBody)")
            }

            if httpResponse.statusCode == 404 {
                print("ℹ️ ProjectService: /vcs returned 404 - VCS not available")
                return nil
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ ProjectService: VCS server error \(httpResponse.statusCode)")
                throw ProjectServiceError.serverError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()

            if let vcs = try? decoder.decode(VCSStatus.self, from: data) {
                print("✅ ProjectService: Decoded VCSStatus - branch: \(vcs.branch ?? "none"), modified: \(vcs.modifiedFilesCount ?? 0)")
                return vcs
            }

            print("❌ ProjectService: Failed to decode VCS response")
            return nil
        } catch let error as ProjectServiceError {
            print("❌ ProjectService: VCS ProjectServiceError - \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ ProjectService: VCS network/parsing error - \(error.localizedDescription)")
            throw ProjectServiceError.networkError(error.localizedDescription)
        }
    }

    func fetchAllProjectInfo() async throws -> [(project: Project, vcs: VCSStatus?)] {
        let projects = try await fetchProjects()

        var result: [(project: Project, vcs: VCSStatus?)] = []

        for project in projects {
            if project.id == "global" {
                continue
            }
            let vcs = try? await fetchVCSStatus(for: project.id)
            result.append((project: project, vcs: vcs))
        }

        return result
    }

    func getProjectURL(for project: Project) -> URL? {
        guard let worktree = project.worktree else { return nil }
        guard let encodedPath = worktree.data(using: .utf8)?.base64EncodedString() else { return nil }
        return URL(string: "\(serverURL)/\(encodedPath)/session")
    }
}

enum ProjectServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let statusCode):
            return "Server error: \(statusCode)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
