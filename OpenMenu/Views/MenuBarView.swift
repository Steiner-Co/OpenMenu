//
//  MenuBarView.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import SwiftUI

struct MenuBarView: View {
    let heartbeatService: HeartbeatService
    @State private var quickActionsService = QuickActionsService()
    @State private var copyConfirmationShown = false
    @State private var sessions: [Session] = []
    @State private var isLoadingSessions = false
    @State private var errorMessage: String?
    @State private var copiedSessionID: String?
    @State private var sessionsEndpointAvailable = true
    
    var body: some View {
        VStack(spacing: 12) {
            StatusIndicator(status: heartbeatService.status)
            
            Divider()
                .padding(.vertical, 4)
            
            ActionButton(icon: "safari", label: "Open Portal") {
                quickActionsService.openPortal()
            }
            
            ActionButton(icon: "arrow.clockwise", label: "Restart Server") {
                Task {
                    do {
                        try quickActionsService.restartServer()
                        errorMessage = nil
                    } catch {
                        errorMessage = "Failed to restart: \(error.localizedDescription)"
                    }
                }
            }
            
            // Only show sessions section if endpoint is available
            if sessionsEndpointAvailable {
                Divider()
                    .padding(.vertical, 4)
                
                // Active Sessions Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Active Sessions")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button {
                            loadSessions()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .rotationEffect(.degrees(isLoadingSessions ? 360 : 0))
                        .animation(isLoadingSessions ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoadingSessions)
                    }
                    
                    if isLoadingSessions {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.7)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else if sessions.isEmpty {
                        Text("No active sessions")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(sessions) { session in
                            SessionRow(
                                session: session,
                                isCopied: copiedSessionID == session.identifier
                            ) {
                                copySessionToClipboard(session)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .frame(width: 280)
        .onAppear {
            heartbeatService.startPolling()
            quickActionsService.serverURL = heartbeatService.serverURL
            loadSessions()
        }
        .onChange(of: heartbeatService.serverURL) { oldValue, newValue in
            quickActionsService.serverURL = newValue
        }
        .onChange(of: heartbeatService.status.healthy) { oldValue, newValue in
            if newValue {
                loadSessions()
            }
        }
    }
    
    private func loadSessions() {
        guard heartbeatService.status.healthy else {
            sessions = []
            errorMessage = "Server is offline"
            return
        }
        
        isLoadingSessions = true
        errorMessage = nil
        
        Task {
            do {
                sessions = try await quickActionsService.fetchSessions()
                errorMessage = nil
                sessionsEndpointAvailable = true
            } catch let error as QuickActionsError {
                sessions = []
                // If endpoint doesn't exist, hide the section
                if case .endpointNotFound = error {
                    sessionsEndpointAvailable = false
                } else {
                    errorMessage = error.localizedDescription
                }
            } catch {
                sessions = []
                errorMessage = error.localizedDescription
            }
            isLoadingSessions = false
        }
    }
    
    private func copySessionToClipboard(_ session: Session) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(session.identifier, forType: .string)
        
        copiedSessionID = session.identifier
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copiedSessionID = nil
        }
    }
}

struct SessionRow: View {
    let session: Session
    let isCopied: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.clipboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isCopied ? .green : .primary)
                    .frame(width: 16)
                
                Text(session.identifier)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MenuBarView(heartbeatService: HeartbeatService())
}
