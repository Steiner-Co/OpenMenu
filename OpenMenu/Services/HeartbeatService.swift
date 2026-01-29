//
//  HeartbeatService.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import Foundation
import SwiftUI

@Observable
class HeartbeatService {
    var status: ServerStatus = .offline
    var isPolling: Bool = false
    
    var serverURL: String = "http://127.0.0.1:4096"
    var pollInterval: TimeInterval = 10.0
    
    private var pollingTask: Task<Void, Never>?
    
    init() {
        // Service can be initialized without auto-starting polling
        // Polling will be started explicitly when needed
    }
    
    deinit {
        stopPolling()
    }
    
    /// Performs a single health check request
    func checkHealth() async throws -> ServerStatus {
        guard let url = URL(string: "\(serverURL)/global/health") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ServerStatus.self, from: data)
    }
    
    /// Starts periodic polling of the health endpoint
    func startPolling() {
        guard !isPolling else { return }
        
        isPolling = true
        
        pollingTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                do {
                    let newStatus = try await self.checkHealth()
                    await MainActor.run {
                        self.status = newStatus
                    }
                } catch {
                    // Network errors → set status to offline
                    await MainActor.run {
                        self.status = .offline
                    }
                }
                
                // Wait for the poll interval before next check
                let nanoseconds = UInt64(self.pollInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
        }
    }
    
    /// Stops the polling task
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }
}
