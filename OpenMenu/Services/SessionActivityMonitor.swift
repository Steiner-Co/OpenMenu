//
//  SessionActivityMonitor.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import Foundation
import Combine

final class SessionActivityMonitor: ObservableObject {
    @Published private(set) var workingSessions: [Session] = []
    @Published private(set) var workingSessionIDs: Set<String> = []

    var serverURL: String = "http://127.0.0.1:4096"

    private var monitorTask: Task<Void, Never>?
    private let reconnectDelay: TimeInterval = 5.0
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadSettings()

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.handleSettingsChange()
            }
            .store(in: &cancellables)
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        serverURL = defaults.string(forKey: AppSettings.serverURLKey) ?? AppSettings.defaultServerURL
    }

    private func handleSettingsChange() {
        let defaults = UserDefaults.standard
        let newServerURL = defaults.string(forKey: AppSettings.serverURLKey) ?? AppSettings.defaultServerURL

        let wasMonitoring = monitorTask != nil
        let urlChanged = serverURL != newServerURL

        serverURL = newServerURL

        if wasMonitoring && urlChanged {
            stop()
            start()
        }
    }

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

    func isSessionWorking(_ sessionID: String) -> Bool {
        workingSessionIDs.contains(sessionID)
    }

    @MainActor
    func addSession(_ session: Session) {
        if workingSessionIDs.contains(session.sessionID) {
            if !workingSessions.contains(where: { $0.sessionID == session.sessionID }) {
                workingSessions.append(session)
                print("📡 SessionActivityMonitor: Added session \(session.displayName) to workingSessions (count: \(workingSessions.count))")
            }
        }
    }

    private func runEventLoop() async {
        while !Task.isCancelled {
            do {
                try await connectAndReadEvents()
            } catch {
                try? await Task.sleep(nanoseconds: UInt64(reconnectDelay * 1_000_000_000))
            }
        }
    }

    private func connectAndReadEvents() async throws {
        guard let url = URL(string: "\(serverURL)/global/event") else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 86400
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
                if let (sessionID, statusType) = extractSessionStatus(from: jsonString) {
                    Task { @MainActor in
                        self.updateSessionStatus(sessionID: sessionID, status: statusType)
                    }
                }
            }
        }
    }

    private func extractSessionStatus(from jsonString: String) -> (String, String)? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let event = (json["payload"] as? [String: Any]) ?? json
        guard let type = event["type"] as? String else { return nil }

        if type == "session.status" {
            guard let props = event["properties"] as? [String: Any],
                  let sessionID = props["sessionID"] as? String,
                  let status = props["status"] as? [String: Any],
                  let statusType = status["type"] as? String else {
                return nil
            }
            return (sessionID, statusType)
        }

        if type == "session.start" || type == "session.busy" {
            guard let props = event["properties"] as? [String: Any],
                  let sessionID = props["sessionID"] as? String else {
                return nil
            }
            return (sessionID, "busy")
        }

        return nil
    }

    private func updateSessionStatus(sessionID: String, status: String) {
        if status == "busy" {
            workingSessionIDs.insert(sessionID)
            print("📡 SessionActivityMonitor: \(sessionID) started working")
        } else if status == "idle" {
            workingSessionIDs.remove(sessionID)
            workingSessions.removeAll { $0.sessionID == sessionID }
            print("📡 SessionActivityMonitor: \(sessionID) finished working")
        }
    }
}
