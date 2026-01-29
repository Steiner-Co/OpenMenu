//
//  ProjectStatusView.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import SwiftUI

struct ProjectStatusView: View {
    let projectService: ProjectService
    let isHealthy: Bool

    @State private var projects: [(project: Project, vcs: VCSStatus?)] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Projects")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if isHealthy {
                    Button {
                        loadProjects()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                }
            }

            if isLoading && projects.isEmpty {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else if projects.isEmpty {
                emptyView
            } else {
                projectsList
            }
        }
        .onAppear {
            if isHealthy {
                loadProjects()
            }
        }
        .onChange(of: isHealthy) { _, newValue in
            if newValue {
                loadProjects()
            } else {
                projects = []
                errorMessage = nil
            }
        }
    }

    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.7)
            Text("Loading projects...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let lastError = lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyView: some View {
        HStack {
            Image(systemName: "folder")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("No projects open")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var projectsList: some View {
        VStack(spacing: 6) {
            ForEach(projects, id: \.project.id) { item in
                ProjectRow(
                    project: item.project,
                    vcs: item.vcs
                )
            }
        }
    }

    private func loadProjects() {
        guard isHealthy else {
            projects = []
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        lastError = nil

        Task {
            do {
                let projectList = try await projectService.fetchAllProjectInfo()
                await MainActor.run {
                    self.projects = projectList
                    self.errorMessage = nil
                    self.isLoading = false
                }
            } catch {
                let errorDesc = error.localizedDescription
                await MainActor.run {
                    self.projects = []
                    self.errorMessage = "Unable to load projects"
                    self.lastError = errorDesc
                    self.isLoading = false
                }
            }
        }
    }
}

struct ProjectRow: View {
    let project: Project
    let vcs: VCSStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)

                Text(project.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()
            }

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

                    Spacer()
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

#Preview {
    ProjectStatusView(
        projectService: ProjectService(),
        isHealthy: true
    )
    .padding(16)
    .background(.ultraThinMaterial)
    .frame(width: 280)
}
