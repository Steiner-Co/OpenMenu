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
    let menuBarAnimationManager: MenuBarAnimationManager

    @State private var quickActionsService = QuickActionsService()
    @State private var projectService = ProjectService()
    @State private var settingsWindow: NSWindow?

    @AppStorage("notifyOnTaskComplete") private var notifyOnTaskComplete = true
    @AppStorage("animateMenuBarOnComplete") private var animateMenuBarOnComplete = true

    @State private var errorMessage: String?
    @State private var copiedSessionID: String?
    @State private var copiedFeedbackResetTask: Task<Void, Never>?

    @State private var projects: [(project: Project, vcs: VCSStatus?)] = []
    @State private var isLoadingProjects = false
    @State private var projectsErrorMessage: String?
    @State private var projectsLastError: String?
    @State private var projectsLoadTask: Task<Void, Never>?

    @State private var expandedProjectIDs: Set<String> = []
    @State private var projectSessions: [String: [Session]] = [:]
    @State private var projectSessionStatuses: [String: [String: SessionStatus]] = [:]
    @State private var loadingSessionsForProjectIDs: Set<String> = []
    @State private var sessionsErrorsByProjectID: [String: String] = [:]
    @State private var sessionsEndpointAvailable = true
    @State private var sessionStatusEndpointAvailable = true
    @State private var projectTodos: [String: [ProjectTodo]] = ProjectTodoStore.load()
    @State private var newTodoTitlesByProjectID: [String: String] = [:]
    @State private var projectDetailTabsByProjectID: [String: ProjectDetailTab] = ProjectDetailTabStore.load()

    @FocusState private var focusedTodoProjectID: String?

    @State private var sessionFetchTasks: [String: Task<Void, Never>] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                StatusIndicator(status: heartbeatService.status)

                HStack(spacing: 8) {
                    QuickActionPillButton(icon: "safari", label: "Portal") {
                        quickActionsService.openPortal()
                    }

                    QuickActionPillButton(icon: "arrow.clockwise", label: "Restart") {
                        restartServer()
                    }
                    .disabled(!heartbeatService.status.healthy)

                    QuickActionPillButton(icon: "gearshape", label: "Settings") {
                        openSettingsWindow()
                    }
                }

                if let errorMessage, !errorMessage.isEmpty {
                    InlineNotice(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange,
                        text: errorMessage
                    )
                }

                if let copiedSessionID, !copiedSessionID.isEmpty {
                    InlineNotice(
                        icon: "checkmark.circle.fill",
                        iconColor: .green,
                        text: "Copied session \(String(copiedSessionID.prefix(8)))…"
                    )
                }

                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Active Sessions", count: sessionActivityMonitor.workingSessions.count)

                    if sessionActivityMonitor.workingSessions.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "hourglass")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("No active sessions")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(sessionActivityMonitor.workingSessions) { session in
                                Button {
                                    copySessionToClipboard(session)
                                } label: {
                                    SessionActivityView(session: session, statusType: .busy)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Projects", count: projects.count) {
                        loadProjects(force: true)
                    }

                    if !heartbeatService.status.healthy {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("Server offline")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    } else if isLoadingProjects && projects.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading projects...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    } else if let projectsErrorMessage {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.orange)
                                Text(projectsErrorMessage)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if let projectsLastError, !projectsLastError.isEmpty {
                                Text(projectsLastError)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 4)
                    } else if projects.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("No projects open")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(projects, id: \.project.id) { item in
                                projectDisclosureGroup(project: item.project, vcs: item.vcs)
                            }
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferences")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ToggleRow(
                        icon: "bell.badge",
                        title: "Notify when task completes",
                        isOn: $notifyOnTaskComplete
                    )

                    ToggleRow(
                        icon: "sparkles",
                        title: "Animate menu bar on complete",
                        isOn: $animateMenuBarOnComplete
                    )
                }
            }
            .padding(16)
        }
        .scrollIndicators(.never)
        .background(.ultraThinMaterial)
        .frame(width: 320, height: 560)
        .onAppear {
            heartbeatService.startPolling()
            if taskCompletionMonitor.onTaskCompleted == nil {
                taskCompletionMonitor.onTaskCompleted = { [menuBarAnimationManager] sessionID in
                    let notifyEnabled = (UserDefaults.standard.object(forKey: "notifyOnTaskComplete") as? Bool) ?? true
                    if notifyEnabled {
                        NotificationService.shared.notifyTaskCompleted(sessionID: sessionID)
                    }

                    let animateEnabled = (UserDefaults.standard.object(forKey: "animateMenuBarOnComplete") as? Bool) ?? true
                    if animateEnabled {
                        Task { @MainActor in
                            menuBarAnimationManager.showTaskCompleted(sessionID: sessionID)
                        }
                    }
                }
            }

            if heartbeatService.status.healthy {
                taskCompletionMonitor.start()
                sessionActivityMonitor.start()
                loadProjects(force: false)
            }
        }
        .onChange(of: heartbeatService.status.healthy) { _, newValue in
            if newValue {
                taskCompletionMonitor.start()
                sessionActivityMonitor.start()
                loadProjects(force: true)
            } else {
                taskCompletionMonitor.stop()
                sessionActivityMonitor.stop()
                projectsLoadTask?.cancel()
                projectsLoadTask = nil
                projects = []
                isLoadingProjects = false
                projectsErrorMessage = nil
                projectSessions = [:]
                projectSessionStatuses = [:]
                loadingSessionsForProjectIDs = []
                sessionsErrorsByProjectID = [:]
            }
        }
        .onChange(of: sessionActivityMonitor.workingSessionIDs) { _, _ in
            Task { @MainActor in
                await fetchSessionDetailsForActiveSessions()
            }
        }
        .onChange(of: projectTodos) { _, newValue in
            ProjectTodoStore.save(newValue)
        }
        .onChange(of: projectDetailTabsByProjectID) { _, newValue in
            ProjectDetailTabStore.save(newValue)
        }
    }

    private func loadProjects(force: Bool) {
        guard heartbeatService.status.healthy else {
            projects = []
            projectsErrorMessage = nil
            projectsLastError = nil
            projectSessions = [:]
            projectSessionStatuses = [:]
            return
        }

        if !force, !projects.isEmpty {
            return
        }

        isLoadingProjects = true
        projectsErrorMessage = nil
        projectsLastError = nil

        projectsLoadTask?.cancel()
        projectsLoadTask = Task {
            do {
                let projectList = try await projectService.fetchAllProjectInfo()
                if Task.isCancelled { return }
                await MainActor.run {
                    projects = projectList
                    isLoadingProjects = false
                    projectSessions = [:]
                    projectSessionStatuses = [:]
                    loadingSessionsForProjectIDs = []
                    sessionsErrorsByProjectID = [:]
                    sessionsEndpointAvailable = true
                    sessionStatusEndpointAvailable = true
                }
            } catch {
                await MainActor.run {
                    projects = []
                    isLoadingProjects = false
                    projectsErrorMessage = "Unable to load projects"
                    projectsLastError = error.localizedDescription
                }
            }
        }
    }

    private func projectDisclosureGroup(project: Project, vcs: VCSStatus?) -> some View {
        let projectID = project.id
        let isExpandedBinding = Binding<Bool>(
            get: { expandedProjectIDs.contains(projectID) },
            set: { isExpanded in
                if isExpanded {
                    expandedProjectIDs.insert(projectID)
                    loadSessions(for: project, force: false)
                } else {
                    expandedProjectIDs.remove(projectID)
                }
            }
        )

        return DisclosureGroup(isExpanded: isExpandedBinding) {
            projectDetailsContent(for: project)
        } label: {
            ProjectRowLabel(
                project: project,
                vcs: vcs,
                isLoadingSessions: loadingSessionsForProjectIDs.contains(projectID),
                sessionsCount: projectSessions[projectID]?.count,
                onOpenInPortal: { openProjectInBrowser(project) }
            )
        }
    }

    @ViewBuilder
    private func projectDetailsContent(for project: Project) -> some View {
        let projectID = project.id
        let detailTabBinding = projectDetailTabBinding(for: projectID)

        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: detailTabBinding) {
                ForEach(ProjectDetailTab.allCases) { tab in
                    Text(projectDetailTabTitle(for: tab, projectID: projectID))
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.leading, 24)

            switch detailTabBinding.wrappedValue {
            case .sessions:
                projectSessionsContent(for: project)
            case .todos:
                projectTodoSection(for: project)
            }
        }
    }

    @ViewBuilder
    private func projectSessionsContent(for project: Project) -> some View {
        let projectID = project.id

        if !sessionsEndpointAvailable {
            Text("Sessions endpoint unavailable")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
        } else if let error = sessionsErrorsByProjectID[projectID], !error.isEmpty {
            Text("Unable to load sessions: \(error)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
        } else if loadingSessionsForProjectIDs.contains(projectID), projectSessions[projectID] == nil {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Loading sessions...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 24)
            .padding(.vertical, 4)
        } else {
            let sessions = projectSessions[projectID] ?? []

            if sessions.isEmpty {
                Text("No sessions")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 24)
                    .padding(.vertical, 4)
            } else {
                let displayedSessions = Array(sessions.prefix(8))
                VStack(spacing: 6) {
                    ForEach(displayedSessions) { session in
                        SessionRow(
                            session: session,
                            statusType: projectSessionStatus(for: session, projectID: projectID),
                            isCopied: copiedSessionID == session.sessionID
                        ) {
                            copySessionToClipboard(session)
                        }
                    }

                    if sessions.count > displayedSessions.count {
                        Text("Showing \(displayedSessions.count) of \(sessions.count)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                    }
                }
                .padding(.leading, 24)
            }
        }
    }

    @ViewBuilder
    private func projectTodoSection(for project: Project) -> some View {
        let projectID = project.id
        let todos = orderedTodos(for: projectID)
        let completedCount = todos.filter { $0.isDone }.count
        let newTitle = newTodoTitlesByProjectID[projectID] ?? ""
        let canAdd = !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Todos")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if !todos.isEmpty {
                    Text("\(todos.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if completedCount > 0 {
                    Button("Clear done") {
                        clearCompletedTodos(for: projectID)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear completed todos")
                }
            }

            HStack(spacing: 8) {
                TextField("Add a todo", text: todoInputBinding(for: projectID))
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .focused($focusedTodoProjectID, equals: projectID)
                    .onSubmit { addTodo(for: projectID) }

                Button(action: { addTodo(for: projectID) }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(canAdd ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .accessibilityLabel("Add todo")

                Button(action: { deleteLastTodo(for: projectID) }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(todos.isEmpty ? Color.secondary : Color.orange)
                }
                .buttonStyle(.plain)
                .disabled(todos.isEmpty)
                .accessibilityLabel("Delete last todo")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
            )

            if todos.isEmpty {
                Text("No todo items yet")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(todos) { todo in
                        ProjectTodoRow(
                            todo: todo,
                            onToggle: { toggleTodo(for: projectID, todoID: todo.id) },
                            onRename: { newTitle in updateTodoTitle(for: projectID, todoID: todo.id, title: newTitle) },
                            onDelete: { deleteTodo(for: projectID, todoID: todo.id) }
                        )
                    }
                }
            }
        }
        .padding(.leading, 24)
        .overlay(alignment: .topLeading) {
            if focusedTodoProjectID == projectID {
                Button(action: { deleteLastTodo(for: projectID) }) {
                    EmptyView()
                }
                .keyboardShortcut(.delete, modifiers: [.command])
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
            }
        }
    }

    private func projectSessionStatus(for session: Session, projectID: String) -> SessionStatus.SessionActivityStatus? {
        if sessionActivityMonitor.isSessionWorking(session.sessionID) {
            return .busy
        }
        return projectSessionStatuses[projectID]?[session.sessionID]?.type
    }

    private func orderedTodos(for projectID: String) -> [ProjectTodo] {
        let todos = projectTodos[projectID] ?? []
        return todos.sorted { lhs, rhs in
            if lhs.isDone != rhs.isDone {
                return !lhs.isDone
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private func todoInputBinding(for projectID: String) -> Binding<String> {
        Binding(
            get: { newTodoTitlesByProjectID[projectID] ?? "" },
            set: { newTodoTitlesByProjectID[projectID] = $0 }
        )
    }

    private func projectDetailTabBinding(for projectID: String) -> Binding<ProjectDetailTab> {
        Binding(
            get: { projectDetailTabsByProjectID[projectID] ?? defaultProjectTab(for: projectID) },
            set: { projectDetailTabsByProjectID[projectID] = $0 }
        )
    }

    private func projectDetailTabTitle(for tab: ProjectDetailTab, projectID: String) -> String {
        switch tab {
        case .sessions:
            return sessionTabTitle(for: projectID)
        case .todos:
            return todoTabTitle(for: projectID)
        }
    }

    private func sessionTabTitle(for projectID: String) -> String {
        guard sessionsEndpointAvailable else { return "Sessions" }
        guard let sessions = projectSessions[projectID] else { return "Sessions" }
        return "Sessions \(sessions.count)"
    }

    private func todoTabTitle(for projectID: String) -> String {
        let count = projectTodos[projectID]?.count ?? 0
        return "Todos \(count)"
    }

    private func defaultProjectTab(for projectID: String) -> ProjectDetailTab {
        if !sessionsEndpointAvailable {
            return .todos
        }

        if let sessions = projectSessions[projectID], sessions.isEmpty {
            return .todos
        }

        if let error = sessionsErrorsByProjectID[projectID], !error.isEmpty {
            return .todos
        }

        return .sessions
    }

    private func addTodo(for projectID: String) {
        let trimmed = (newTodoTitlesByProjectID[projectID] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var todos = projectTodos[projectID] ?? []
        let todo = ProjectTodo(
            id: UUID().uuidString,
            title: trimmed,
            isDone: false,
            createdAt: Date().timeIntervalSince1970
        )
        todos.append(todo)
        projectTodos[projectID] = todos
        newTodoTitlesByProjectID[projectID] = ""
    }

    private func toggleTodo(for projectID: String, todoID: String) {
        guard var todos = projectTodos[projectID] else { return }
        guard let index = todos.firstIndex(where: { $0.id == todoID }) else { return }
        var todo = todos[index]
        todo.isDone.toggle()
        todos[index] = todo
        projectTodos[projectID] = todos
    }

    private func updateTodoTitle(for projectID: String, todoID: String, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard var todos = projectTodos[projectID] else { return }
        guard let index = todos.firstIndex(where: { $0.id == todoID }) else { return }
        if todos[index].title == trimmed { return }
        var todo = todos[index]
        todo.title = trimmed
        todos[index] = todo
        projectTodos[projectID] = todos
    }

    private func clearCompletedTodos(for projectID: String) {
        guard var todos = projectTodos[projectID] else { return }
        todos.removeAll { $0.isDone }
        if todos.isEmpty {
            projectTodos.removeValue(forKey: projectID)
        } else {
            projectTodos[projectID] = todos
        }
    }

    private func deleteLastTodo(for projectID: String) {
        guard var todos = projectTodos[projectID], !todos.isEmpty else { return }
        if let index = todos.enumerated().max(by: { $0.element.createdAt < $1.element.createdAt })?.offset {
            todos.remove(at: index)
        } else {
            todos.removeLast()
        }

        if todos.isEmpty {
            projectTodos.removeValue(forKey: projectID)
        } else {
            projectTodos[projectID] = todos
        }
    }

    private func deleteTodo(for projectID: String, todoID: String) {
        guard var todos = projectTodos[projectID] else { return }
        todos.removeAll { $0.id == todoID }
        if todos.isEmpty {
            projectTodos.removeValue(forKey: projectID)
        } else {
            projectTodos[projectID] = todos
        }
    }

    private func loadSessions(for project: Project, force: Bool) {
        guard sessionsEndpointAvailable else { return }
        guard let directory = project.worktree else { return }

        let projectID = project.id
        if !force, projectSessions[projectID] != nil {
            return
        }
        if loadingSessionsForProjectIDs.contains(projectID) {
            return
        }

        loadingSessionsForProjectIDs.insert(projectID)
        sessionsErrorsByProjectID[projectID] = nil

        Task {
            defer {
                Task { @MainActor in
                    loadingSessionsForProjectIDs.remove(projectID)
                }
            }

            do {
                let sessions = try await quickActionsService.fetchSessions(directory: directory)

                var statuses: [String: SessionStatus] = [:]
                if sessionStatusEndpointAvailable {
                    do {
                        statuses = try await quickActionsService.fetchSessionStatus(directory: directory)
                    } catch let error as QuickActionsError {
                        if case .endpointNotFound = error {
                            await MainActor.run {
                                sessionStatusEndpointAvailable = false
                            }
                        }
                    } catch {}
                }

                await MainActor.run {
                    projectSessions[projectID] = sessions
                    projectSessionStatuses[projectID] = statuses
                }
            } catch let error as QuickActionsError {
                await MainActor.run {
                    switch error {
                    case .endpointNotFound:
                        sessionsEndpointAvailable = false
                    default:
                        sessionsErrorsByProjectID[projectID] = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    sessionsErrorsByProjectID[projectID] = error.localizedDescription
                }
            }
        }
    }

    private func openProjectInBrowser(_ project: Project) {
        guard let url = projectService.getProjectURL(for: project) else { return }
        NSWorkspace.shared.open(url)
    }

    private func restartServer() {
        Task {
            do {
                try quickActionsService.restartServer()
                await MainActor.run {
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to restart: \(error.localizedDescription)"
                }
            }
        }
    }

    @MainActor
    private func fetchSessionDetailsForActiveSessions() async {
        let activeIDs = sessionActivityMonitor.workingSessionIDs
        for sessionID in activeIDs {
            if sessionFetchTasks[sessionID] != nil {
                continue
            }

            sessionFetchTasks[sessionID] = Task { @MainActor in
                do {
                    let session = try await quickActionsService.fetchSession(id: sessionID)
                    if !Task.isCancelled {
                        sessionActivityMonitor.addSession(session)
                    }
                } catch {
                    // Ignore; we fall back to showing the session ID if details can't be fetched.
                }
                sessionFetchTasks.removeValue(forKey: sessionID)
            }
        }
    }

    @MainActor
    private func showCopiedSessionID(_ sessionID: String) {
        copiedFeedbackResetTask?.cancel()
        copiedSessionID = sessionID
        copiedFeedbackResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copiedSessionID = nil
        }
    }

    @MainActor
    private func copySessionToClipboard(_ session: Session) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(session.sessionID, forType: .string)
        showCopiedSessionID(session.sessionID)
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

private struct QuickActionPillButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

private struct InlineNotice: View {
    let icon: String
    let iconColor: Color
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

private struct SectionHeader: View {
    let title: String
    let count: Int?
    let onRefresh: (() -> Void)?

    init(title: String, count: Int? = nil, onRefresh: (() -> Void)? = nil) {
        self.title = title
        self.count = count
        self.onRefresh = onRefresh
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()

            if let count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.secondary)
                    )
            }

            if let onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh \(title)")
            }
        }
    }
}

private struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
        .accessibilityLabel(title)
    }
}

private struct ProjectRowLabel: View {
    let project: Project
    let vcs: VCSStatus?
    let isLoadingSessions: Bool
    let sessionsCount: Int?
    let onOpenInPortal: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundStyle(.blue)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if vcs?.isRepo == true {
                    HStack(spacing: 6) {
                        if let branch = vcs?.branch {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.branch")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                Text(branch)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        let modifiedCount = vcs?.totalModified ?? 0
                        if modifiedCount > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "pencil.circle")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.orange)
                                Text("\(modifiedCount)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.orange)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                }
            }

            Spacer()

            if isLoadingSessions {
                ProgressView()
                    .scaleEffect(0.6)
            } else if let sessionsCount {
                Text("\(sessionsCount)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
            }

            Button(action: onOpenInPortal) {
                Image(systemName: "safari")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(project.displayName) in portal")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

private struct ProjectTodoRow: View {
    let todo: ProjectTodo
    let onToggle: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var editedTitle = ""
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(todo.isDone ? .green : .secondary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isDone ? "Mark todo as incomplete" : "Mark todo as complete")

            if isEditing {
                TextField("", text: $editedTitle)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .focused($isEditorFocused)
                    .onSubmit { commitEditing() }
                    .onExitCommand { cancelEditing() }
            } else {
                Text(todo.title)
                    .font(.system(size: 12))
                    .foregroundStyle(todo.isDone ? .secondary : .primary)
                    .strikethrough(todo.isDone, color: .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onTapGesture(count: 2) { startEditing() }
            }

            Spacer()

            Button(action: { isEditing ? commitEditing() : startEditing() }) {
                Image(systemName: isEditing ? "checkmark" : "pencil")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isEditing ? "Save todo title" : "Edit todo")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete todo")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
        .onChange(of: todo.title) { _, newValue in
            if !isEditing {
                editedTitle = newValue
            }
        }
    }

    private func startEditing() {
        editedTitle = todo.title
        isEditing = true
        isEditorFocused = true
    }

    private func commitEditing() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelEditing()
            return
        }
        onRename(trimmed)
        isEditing = false
    }

    private func cancelEditing() {
        editedTitle = todo.title
        isEditing = false
    }
}

private struct SessionRow: View {
    let session: Session
    let statusType: SessionStatus.SessionActivityStatus?
    let isCopied: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if isCopied {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                        .frame(width: 16)
                } else if statusType == .busy {
                    ProgressView()
                        .scaleEffect(0.6)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .frame(width: 16)
                } else if statusType == .retry {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                        .frame(width: 16)
                } else {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 16)
                }

                Text(session.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy session ID to clipboard")
        .accessibilityHint("Copies \(session.displayName) ID")
    }
}

#Preview {
    MenuBarView(
        heartbeatService: HeartbeatService(),
        taskCompletionMonitor: TaskCompletionMonitor(),
        sessionActivityMonitor: SessionActivityMonitor(),
        menuBarAnimationManager: MenuBarAnimationManager()
    )
}
