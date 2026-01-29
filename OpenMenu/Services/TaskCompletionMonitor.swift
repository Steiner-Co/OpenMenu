//
//  TaskCompletionMonitor.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import Foundation

/// Subscribes to OpenCode's SSE event stream and invokes a callback when a session becomes idle (task completed).
final class TaskCompletionMonitor {
    var serverURL: String = "http://127.0.0.1:4096"
    
    /// Called when a task completes. Set to nil to disable notifications.
    var onTaskCompleted: ((String?) -> Void)?
    
    private var monitorTask: Task<Void, Never>?
    private let reconnectDelay: TimeInterval = 5.0
    
    func start() {
        guard monitorTask == nil else { return }
        
        monitorTask = Task { [weak self] in
            await self?.runEventLoop()
        }
    }
    
    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
    }
    
    private func runEventLoop() async {
        while !Task.isCancelled {
            do {
                try await connectAndReadEvents()
            } catch {
                // Reconnect after delay
                try? await Task.sleep(nanoseconds: UInt64(reconnectDelay * 1_000_000_000))
            }
        }
    }
    
    private func connectAndReadEvents() async throws {
        // Use /global/event for server-wide session events; stream is long-lived (no data until events occur).
        guard let url = URL(string: "\(serverURL)/global/event") else { return }
        
        var request = URLRequest(url: url)
        // SSE stays open indefinitely; use long timeout so we don't close an idle stream before any event.
        request.timeoutInterval = 86400 // 24 hours
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return
        }
        
        var buffer = ""
        for try await byte in bytes {
            if Task.isCancelled { break }
            buffer.append(Character(Unicode.Scalar(byte)))
            if buffer.hasSuffix("\n\n") || buffer.hasSuffix("\n\r\n") {
                processSSELines(buffer)
                buffer = ""
            }
        }
    }
    
    private func processSSELines(_ text: String) {
        let lines = text.split(separator: "\n")
        for line in lines {
            let s = line.trimmingCharacters(in: .whitespaces)
            if s.hasPrefix("data: ") {
                let jsonString = String(s.dropFirst(6))
                if let sessionID = extractSessionIdle(from: jsonString) {
                    Task { @MainActor in
                        onTaskCompleted?(sessionID)
                    }
                }
            }
        }
    }
    
    /// Parses SSE data line; returns sessionID if this event indicates task completion (session.idle or session.status idle).
    /// Handles both raw Event and GlobalEvent wrapper { directory, payload }.
    private func extractSessionIdle(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        // /global/event sends GlobalEvent: { directory, payload: Event }
        let event = (json["payload"] as? [String: Any]) ?? json
        guard let type = event["type"] as? String else { return nil }
        
        if type == "session.idle" {
            let props = event["properties"] as? [String: Any]
            return props?["sessionID"] as? String
        }
        
        if type == "session.status" {
            guard let props = event["properties"] as? [String: Any],
                  let status = props["status"] as? [String: Any],
                  (status["type"] as? String) == "idle" else {
                return nil
            }
            return props["sessionID"] as? String
        }
        
        return nil
    }
}
