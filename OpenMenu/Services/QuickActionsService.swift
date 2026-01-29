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
    
    /// Opens the OpenCode portal in the default browser
    func openPortal() {
        guard let url = URL(string: serverURL) else {
            print("Invalid server URL: \(serverURL)")
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    /// Fetches the list of active sessions from the server
    func fetchSessions() async throws -> [Session] {
        guard let url = URL(string: "\(serverURL)/session") else {
            throw QuickActionsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
    func copySessionID() async throws {
        let sessions = try await fetchSessions()
        
        guard let firstSession = sessions.first else {
            throw QuickActionsError.noSessionsAvailable
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(firstSession.sessionID, forType: .string)
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
    func fetchSession(id sessionID: String) async throws -> Session {
        print("📡 Fetching session \(sessionID) via /session endpoint")
        
        do {
            let sessions = try await fetchSessions()
            
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
    func fetchSessionStatus() async throws -> [String: SessionStatus] {
        guard let url = URL(string: "\(serverURL)/session/status") else {
            throw QuickActionsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
        }
    }
}
