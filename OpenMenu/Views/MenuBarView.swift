//
//  MenuBarView.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import SwiftUI
import AppKit

struct MenuBarView: View {
    let heartbeatService: HeartbeatService
    let taskCompletionMonitor: TaskCompletionMonitor
    @State private var quickActionsService = QuickActionsService()
    @State private var projectService = ProjectService()
    @State private var settingsWindow: NSWindow?
    @AppStorage("notifyOnTaskComplete") private var notifyOnTaskComplete = true
    @State private var copyConfirmationShown = false
    @State private var sessions: [Session] = []
    @State private var isLoadingSessions = false
    @State private var errorMessage: String?
    @State private var copiedSessionID: String?
    @State private var sessionsEndpointAvailable = true
    
    var body: some View {
        VStack(spacing: 12) {
            StatusIndicator(status: heartbeatService.status)

            ProjectStatusView(
                projectService: projectService,
                isHealthy: heartbeatService.status.healthy
            )

            Divider()
                .padding(.vertical, 4)
            
            Toggle(isOn: $notifyOnTaskComplete) {
                Label("Notify when task completes", systemImage: "bell.badge")
            }
            .toggleStyle(.switch)
            
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
            
            ActionButton(icon: "gearshape", label: "Settings") {
                openSettingsWindow()
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
                                isCopied: copiedSessionID == session.sessionID
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
            if taskCompletionMonitor.onTaskCompleted == nil {
                taskCompletionMonitor.onTaskCompleted = { sessionID in
                    let enabled = (UserDefaults.standard.object(forKey: "notifyOnTaskComplete") as? Bool) ?? true
                    if enabled {
                        NotificationService.shared.notifyTaskCompleted(sessionID: sessionID)
                    }
                }
            }
            if heartbeatService.status.healthy {
                taskCompletionMonitor.start()
            }
            loadSessions()
        }
        .onChange(of: heartbeatService.status.healthy) { oldValue, newValue in
            if newValue {
                taskCompletionMonitor.start()
                loadSessions()
            } else {
                taskCompletionMonitor.stop()
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
        pasteboard.setString(session.sessionID, forType: .string)
        
        copiedSessionID = session.sessionID
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copiedSessionID = nil
        }
    }
    
    private func openSettingsWindow() {
        // Find existing settings window or create new one
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Check if window exists in NSApplication's windows
        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            settingsWindow = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create a new settings window
        let settingsView = SettingsWindow()
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 500)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "Settings"
        window.identifier = NSUserInterfaceItemIdentifier("settings")
        window.center()
        window.isReleasedWhenClosed = false
        
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
                
                Text(session.displayName)
                    .font(.system(size: 12))
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
    MenuBarView(
        heartbeatService: HeartbeatService(),
        taskCompletionMonitor: TaskCompletionMonitor()
    )
}
