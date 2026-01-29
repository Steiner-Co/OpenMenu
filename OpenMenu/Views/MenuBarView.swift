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
    @ObservedObject var sessionActivityMonitor: SessionActivityMonitor
    @State private var quickActionsService = QuickActionsService()
    @State private var projectService = ProjectService()
    @State private var settingsWindow: NSWindow?
    @AppStorage("notifyOnTaskComplete") private var notifyOnTaskComplete = true
    @State private var errorMessage: String?
    @State private var copiedSessionID: String?
    @State private var sessionsEndpointAvailable = true
    @State private var sessionFetchTasks: [String: Task<Void, Never>] = [:]

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

            // Active Sessions Section
            let _ = print("🎨 View body: workingSessionIDs=\(sessionActivityMonitor.workingSessionIDs.count), workingSessions=\(sessionActivityMonitor.workingSessions.count)")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Active Sessions")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !sessionActivityMonitor.workingSessions.isEmpty {
                        Text("\(sessionActivityMonitor.workingSessions.count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.blue)
                            )
                    }
                }

                if sessionActivityMonitor.workingSessions.isEmpty {
                    HStack {
                        Image(systemName: "hourglass")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text("No active sessions")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else {
                    ForEach(sessionActivityMonitor.workingSessions) { session in
                        SessionActivityView(
                            session: session,
                            statusType: .busy
                        )
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
                sessionActivityMonitor.start()
            }
        }
        .onChange(of: heartbeatService.status.healthy) { oldValue, newValue in
            if newValue {
                taskCompletionMonitor.start()
                sessionActivityMonitor.start()
            } else {
                taskCompletionMonitor.stop()
                sessionActivityMonitor.stop()
            }
        }
        .onChange(of: sessionActivityMonitor.workingSessionIDs) { oldValues, newValues in
            print("🔄 onChange triggered: old=\(oldValues.count), new=\(newValues.count), IDs=\(newValues)")
            Task { @MainActor in
                await fetchSessionDetailsForActiveSessions()
            }
        }
    }

    @MainActor
    private func fetchSessionDetailsForActiveSessions() async {
        let activeIDs = sessionActivityMonitor.workingSessionIDs
        print("🔍 fetchSessionDetailsForActiveSessions called with \(activeIDs.count) active IDs: \(activeIDs)")

        for sessionID in activeIDs {
            if sessionFetchTasks[sessionID] != nil {
                print("🔍 Skipping \(sessionID) - fetch already in progress")
                continue
            }

            print("🔍 Starting fetch for session \(sessionID)")
            sessionFetchTasks[sessionID] = Task { @MainActor in
                do {
                    let session = try await quickActionsService.fetchSession(id: sessionID)
                    print("🔍 Fetched session: \(session.sessionID), displayName: \(session.displayName)")
                    if !Task.isCancelled {
                        print("🔍 Calling addSession for \(session.sessionID)")
                        sessionActivityMonitor.addSession(session)
                        print("🔍 After addSession, workingSessions count: \(sessionActivityMonitor.workingSessions.count)")
                    }
                } catch {
                    print("❌ Failed to fetch session \(sessionID): \(error.localizedDescription)")
                }
                sessionFetchTasks.removeValue(forKey: sessionID)
            }
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
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            settingsWindow = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

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
        taskCompletionMonitor: TaskCompletionMonitor(),
        sessionActivityMonitor: SessionActivityMonitor()
    )
}
