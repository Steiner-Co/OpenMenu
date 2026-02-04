//
//  QuickActionsService.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import Foundation
import AppKit
import Combine

@Observable
class QuickActionsService {
    var serverURL: String = "http://127.0.0.1:4096"
    var restartCommand: String = "opencode restart"
    
    private var cancellables = Set<AnyCancellable>()
    private var cachedModelSpec: ModelSpec?
    private var cachedDefaultAgent: String?
    private var hasLoadedDefaults = false
    
    init() {
        // Load settings from UserDefaults
        loadSettings()
        
        // Observe UserDefaults changes
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

    private func makeURL(path: String, directory: String? = nil) throws -> URL {
        guard var components = URLComponents(string: "\(serverURL)\(path)") else {
            throw QuickActionsError.invalidURL
        }

        var queryItems = components.queryItems ?? []
        if let directory, !directory.isEmpty {
            queryItems.append(URLQueryItem(name: "directory", value: directory))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw QuickActionsError.invalidURL
        }
        return url
    }

    private func makeRequest(url: URL, method: String, body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }
    
    /// Opens the OpenCode portal in the default browser
    func openPortal() {
        guard let url = URL(string: serverURL) else {
            print("Invalid server URL: \(serverURL)")
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    /// Fetches the list of sessions from the server (optionally scoped to a directory/project).
    func fetchSessions(directory: String? = nil) async throws -> [Session] {
        let url = try makeURL(path: "/session", directory: directory)
        let request = makeRequest(url: url, method: "GET")
        
        print("📡 Fetching sessions from: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw QuickActionsError.invalidResponse
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            // Print response body for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 Response body: \(responseString)")
            }
            
            // Check for 404 - endpoint might not exist
            if httpResponse.statusCode == 404 {
                throw QuickActionsError.endpointNotFound
            }
            
            // For 400 errors, try to extract error message from response
            if httpResponse.statusCode == 400 {
                if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                    throw QuickActionsError.badRequest(responseString)
                }
                throw QuickActionsError.serverError(statusCode: httpResponse.statusCode)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw QuickActionsError.serverError(statusCode: httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            
            // Try to decode as SessionListResponse first
            if let sessionListResponse = try? decoder.decode(SessionListResponse.self, from: data) {
                print("✅ Decoded \(sessionListResponse.sessions.count) sessions from SessionListResponse")
                return sessionListResponse.sessions
            }
            
            // If that fails, try decoding as a direct array
            if let sessions = try? decoder.decode([Session].self, from: data) {
                print("✅ Decoded \(sessions.count) sessions from array")
                return sessions
            }
            
            // If both fail, throw an error
            throw QuickActionsError.decodingFailed
        } catch let error as QuickActionsError {
            throw error
        } catch {
            throw QuickActionsError.networkError(error.localizedDescription)
        }
    }
    
    /// Fetches the first session and copies its ID to the clipboard
    @discardableResult
    func copySessionID(directory: String? = nil) async throws -> String {
        let sessions = try await fetchSessions(directory: directory)
        
        guard let firstSession = sessions.first else {
            throw QuickActionsError.noSessionsAvailable
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(firstSession.sessionID, forType: .string)

        return firstSession.sessionID
    }
    
    /// Executes the restart command in the background
    func restartServer() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", restartCommand]

        // Configure process to run in background
        process.standardOutput = nil
        process.standardError = nil

        try process.run()

        // Don't wait for completion - let it run in background
    }

    /// Fetches a single session by ID (fetches all sessions and filters)
    /// If session is not found in the list, returns a minimal session with just the ID
    func fetchSession(id sessionID: String, directory: String? = nil) async throws -> Session {
        print("📡 Fetching session \(sessionID) via /session endpoint")
        
        do {
            let sessions = try await fetchSessions(directory: directory)
            
            if let session = sessions.first(where: { $0.sessionID == sessionID }) {
                print("✅ Found session: \(session.displayName)")
                return session
            }
            
            // Session not found in list - create a minimal session
            // This can happen when the session belongs to a different project
            print("⚠️ Session \(sessionID) not in list, creating minimal session")
            return Session(idValue: sessionID, path: nil, title: nil)
        } catch {
            // If fetching fails entirely, still create a minimal session
            print("⚠️ Failed to fetch sessions: \(error.localizedDescription), creating minimal session")
            return Session(idValue: sessionID, path: nil, title: nil)
        }
    }

    /// Fetches the status of all sessions to determine which are actively working
    func fetchSessionStatus(directory: String? = nil) async throws -> [String: SessionStatus] {
        let url = try makeURL(path: "/session/status", directory: directory)

        let request = makeRequest(url: url, method: "GET")

        print("📡 Fetching session status from: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw QuickActionsError.invalidResponse
            }

            // Print response body for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 Session status response: \(responseString)")
            }

            if httpResponse.statusCode == 404 {
                throw QuickActionsError.endpointNotFound
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw QuickActionsError.serverError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            if let statusMap = try? decoder.decode([String: SessionStatus].self, from: data) {
                print("✅ Decoded session statuses: \(statusMap.count) sessions")
                return statusMap
            }

            throw QuickActionsError.decodingFailed
        } catch let error as QuickActionsError {
            throw error
        } catch {
            throw QuickActionsError.networkError(error.localizedDescription)
        }
    }

    /// Creates a new session on the server.
    func createSession(title: String? = nil, directory: String? = nil) async throws -> Session {
        let url = try makeURL(path: "/session", directory: directory)
        let payload = SessionCreateRequest(title: title)
        let body = try JSONEncoder().encode(payload)
        let request = makeRequest(url: url, method: "POST", body: body)

        print("📡 Creating session via: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw QuickActionsError.invalidResponse
            }

            if httpResponse.statusCode == 404 {
                throw QuickActionsError.endpointNotFound
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw QuickActionsError.serverError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            if let session = try? decoder.decode(Session.self, from: data) {
                print("✅ Created session \(session.sessionID)")
                return session
            }

            throw QuickActionsError.decodingFailed
        } catch let error as QuickActionsError {
            throw error
        } catch {
            throw QuickActionsError.networkError(error.localizedDescription)
        }
    }

    /// Executes a slash command in a session.
    func runCommand(sessionID: String, command: String, arguments: [String] = [], directory: String? = nil) async throws {
        guard !sessionID.isEmpty else {
            throw QuickActionsError.invalidSessionID
        }

        let url = try makeURL(path: "/session/\(sessionID)/command", directory: directory)
        let payload = SessionCommandRequest(command: command, arguments: arguments)
        let body = try JSONEncoder().encode(payload)
        let request = makeRequest(url: url, method: "POST", body: body)

        print("📡 Sending command /\(command) to session \(sessionID)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw QuickActionsError.invalidResponse
            }

            if httpResponse.statusCode == 400 {
                if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                    throw QuickActionsError.badRequest(responseString)
                }
                throw QuickActionsError.serverError(statusCode: httpResponse.statusCode)
            }

            if httpResponse.statusCode == 404 {
                throw QuickActionsError.endpointNotFound
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw QuickActionsError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch let error as QuickActionsError {
            throw error
        } catch {
            throw QuickActionsError.networkError(error.localizedDescription)
        }
    }

    /// Creates a new session and starts a code review via /review.
    func startReviewSession(title: String? = nil, directory: String? = nil) async throws -> Session {
        let session = try await createSession(title: title, directory: directory)
        let defaults = await loadDefaults()
        let agent = await selectReviewAgent(defaultAgent: defaults.agent)
        let prompt = buildReviewPrompt(directory: directory) ?? reviewPromptText()
        try await sendPromptAsync(
            sessionID: session.sessionID,
            text: prompt,
            model: defaults.model,
            agent: agent,
            directory: directory
        )
        return session
    }

    fileprivate func sendPrompt(sessionID: String, text: String, model: ModelSpec? = nil, agent: String? = nil, directory: String? = nil) async throws {
        guard !sessionID.isEmpty else {
            throw QuickActionsError.invalidSessionID
        }

        let url = try makeURL(path: "/session/\(sessionID)/message", directory: directory)
        let payload = MessageInput(
            model: model,
            agent: agent,
            noReply: nil,
            parts: [MessagePart(text: text)]
        )
        let body = try JSONEncoder().encode(payload)
        let request = makeRequest(url: url, method: "POST", body: body)

        print("📡 Sending prompt to session \(sessionID)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw QuickActionsError.invalidResponse
            }

            print("📡 Prompt response status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                print("📡 Prompt response body: \(responseString)")
            }

            if httpResponse.statusCode == 400 {
                if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                    throw QuickActionsError.badRequest(responseString)
                }
                throw QuickActionsError.serverError(statusCode: httpResponse.statusCode)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw QuickActionsError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch let error as QuickActionsError {
            throw error
        } catch {
            throw QuickActionsError.networkError(error.localizedDescription)
        }
    }

    fileprivate func sendPromptAsync(sessionID: String, text: String, model: ModelSpec? = nil, agent: String? = nil, directory: String? = nil) async throws {
        guard !sessionID.isEmpty else {
            throw QuickActionsError.invalidSessionID
        }

        let url = try makeURL(path: "/session/\(sessionID)/prompt_async", directory: directory)
        let payload = MessageInput(
            model: model,
            agent: agent,
            noReply: nil,
            parts: [MessagePart(text: text)]
        )
        let body = try JSONEncoder().encode(payload)
        let request = makeRequest(url: url, method: "POST", body: body)

        print("📡 Sending async prompt to session \(sessionID)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw QuickActionsError.invalidResponse
            }

            print("📡 Async prompt response status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                print("📡 Async prompt response body: \(responseString)")
            }

            if httpResponse.statusCode == 400 {
                if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                    throw QuickActionsError.badRequest(responseString)
                }
                throw QuickActionsError.serverError(statusCode: httpResponse.statusCode)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw QuickActionsError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch let error as QuickActionsError {
            throw error
        } catch {
            throw QuickActionsError.networkError(error.localizedDescription)
        }
    }

    private func fallbackReviewPrompt() -> String? {
        "Please review the recent changes in this project. Focus on correctness, risks, and missing tests. Provide actionable feedback."
    }

    private func reviewPromptText() -> String {
        """
        Please do a code review on the recently made unpushed changes.
        Focus on correctness, risks, edge cases, and missing tests.
        If there are no changes, say so.
        """
    }

    private func buildReviewPrompt(directory: String?) -> String? {
        guard let directory, !directory.isEmpty else {
            return nil
        }

        do {
            let status = try runGitCommand(["status", "-sb"], directory: directory)
            let upstream = (try? runGitCommand(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], directory: directory))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let hasUpstream = !(upstream ?? "").isEmpty
            let diffRange = hasUpstream ? (upstream ?? "HEAD") : "HEAD"
            let log = hasUpstream ? (try? runGitCommand(["log", "--oneline", "\(diffRange)..HEAD"], directory: directory)) : nil
            let diff = try runGitCommand(["diff", "--patch", diffRange], directory: directory)
            let (trimmedDiff, wasTrimmed) = truncate(diff, maxChars: 120_000)

            var prompt = """
            You are a code reviewer. Use ONLY the context below (do not call tools).
            Focus on correctness, risks, edge cases, and missing tests.
            Provide findings as bullets with file references where possible.

            Project root:
            \(directory)

            Git status:
            \(status)

            Unpushed commits:
            \(log?.isEmpty == false ? log! : "(none or upstream not set)")

            Diff vs \(diffRange):
            \(trimmedDiff)
            """

            if wasTrimmed {
                prompt += "\n\nNote: Diff truncated for length."
            }

            return prompt
        } catch {
            return nil
        }
    }

    private func runGitCommand(_ arguments: [String], directory: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let outString = String(data: outData, encoding: .utf8) ?? ""
        let errString = String(data: errData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            if !errString.isEmpty {
                return errString
            }
        }

        return outString
    }

    private func truncate(_ text: String, maxChars: Int) -> (String, Bool) {
        if text.count <= maxChars {
            return (text, false)
        }
        let index = text.index(text.startIndex, offsetBy: maxChars)
        return (String(text[..<index]), true)
    }

    private func selectReviewAgent(defaultAgent: String?) async -> String? {
        do {
            let agents = try await fetchAgents()
            if let review = agents.first(where: { $0.matchesReview }) {
                return review.id
            }
            if let plan = agents.first(where: { $0.matchesPlan }) {
                return plan.id
            }
        } catch {
            // Ignore and fall back to default.
        }
        return defaultAgent
    }

    private func fetchAgents() async throws -> [AgentInfo] {
        let url = try makeURL(path: "/agent")
        let request = makeRequest(url: url, method: "GET")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw QuickActionsError.invalidResponse
            }

            if httpResponse.statusCode == 404 {
                throw QuickActionsError.endpointNotFound
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw QuickActionsError.serverError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            if let agents = try? decoder.decode([AgentInfo].self, from: data) {
                return agents
            }

            throw QuickActionsError.decodingFailed
        } catch let error as QuickActionsError {
            throw error
        } catch {
            throw QuickActionsError.networkError(error.localizedDescription)
        }
    }

    private func loadDefaults() async -> (model: ModelSpec?, agent: String?) {
        if hasLoadedDefaults {
            return (cachedModelSpec, cachedDefaultAgent)
        }
        hasLoadedDefaults = true
        do {
            let config = try await fetchConfig()
            cachedModelSpec = parseModelSpec(config.model)
            cachedDefaultAgent = config.defaultAgent
        } catch {
            cachedModelSpec = nil
            cachedDefaultAgent = nil
        }
        return (cachedModelSpec, cachedDefaultAgent)
    }

    private func fetchConfig() async throws -> OpencodeConfig {
        let url = try makeURL(path: "/config")
        let request = makeRequest(url: url, method: "GET")

        print("📡 Fetching config from: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw QuickActionsError.invalidResponse
            }

            if httpResponse.statusCode == 404 {
                throw QuickActionsError.endpointNotFound
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw QuickActionsError.serverError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            if let config = try? decoder.decode(OpencodeConfig.self, from: data) {
                return config
            }

            throw QuickActionsError.decodingFailed
        } catch let error as QuickActionsError {
            throw error
        } catch {
            throw QuickActionsError.networkError(error.localizedDescription)
        }
    }

    private func parseModelSpec(_ modelString: String?) -> ModelSpec? {
        guard let modelString, !modelString.isEmpty else {
            return nil
        }

        let parts = modelString.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return nil
        }
        return ModelSpec(providerID: parts[0], modelID: parts[1])
    }
}

private struct SessionCreateRequest: Encodable {
    let title: String?
}

private struct SessionCommandRequest: Encodable {
    let messageID: String?
    let agent: String?
    let model: String?
    let command: String
    let arguments: [String]?

    init(command: String, arguments: [String]? = nil) {
        self.messageID = nil
        self.agent = nil
        self.model = nil
        self.command = command
        self.arguments = arguments
    }
}

private struct MessageInput: Encodable {
    let messageID: String?
    let model: ModelSpec?
    let agent: String?
    let noReply: Bool?
    let system: String?
    let parts: [MessagePart]

    init(model: ModelSpec? = nil, agent: String? = nil, noReply: Bool? = nil, system: String? = nil, parts: [MessagePart]) {
        self.messageID = nil
        self.model = model
        self.agent = agent
        self.noReply = noReply
        self.system = system
        self.parts = parts
    }
}

private struct MessagePart: Encodable {
    let type: String
    let text: String

    init(text: String) {
        self.type = "text"
        self.text = text
    }
}

private struct OpencodeConfig: Decodable {
    let model: String?
    let defaultAgent: String?

    enum CodingKeys: String, CodingKey {
        case model
        case defaultAgent = "default_agent"
    }
}

private struct ModelSpec: Encodable {
    let providerID: String
    let modelID: String
}

private struct AgentInfo: Decodable {
    let id: String
    let name: String?

    var matchesReview: Bool {
        let lowerID = id.lowercased()
        if lowerID == "review" { return true }
        if let name, name.lowercased().contains("review") { return true }
        return false
    }

    var matchesPlan: Bool {
        let lowerID = id.lowercased()
        if lowerID == "plan" { return true }
        if let name, name.lowercased().contains("plan") { return true }
        return false
    }
}

enum QuickActionsError: LocalizedError {
    case noSessionsAvailable
    case invalidURL
    case invalidResponse
    case endpointNotFound
    case badRequest(String)
    case serverError(statusCode: Int)
    case decodingFailed
    case networkError(String)
    case sessionNotFound(String)
    case invalidSessionID
    
    var errorDescription: String? {
        switch self {
        case .noSessionsAvailable:
            return "No active sessions found"
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .endpointNotFound:
            return "Sessions endpoint not available"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .serverError(let statusCode):
            return "Server error: \(statusCode)"
        case .decodingFailed:
            return "Unable to parse response"
        case .networkError(let message):
            return "Network error: \(message)"
        case .sessionNotFound(let sessionID):
            return "Session not found: \(sessionID)"
        case .invalidSessionID:
            return "Session ID is missing"
        }
    }
}
