//
//  GitGraphView.swift
//  aiX
//
//  Git subway graph view
//

import SwiftUI
import os.log

/// Git subway graph view
struct GitGraphView: View {
    let worktreePath: String
    let selectedCommit: GitCommit?
    let onSelectCommit: (GitCommit?) -> Void

    @State private var graphCommits: [GitGraphCommit] = []
    @State private var connections: [GitGraphConnection] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedGraphCommit: GitGraphCommit?
    @State private var graphScale: CGFloat = 1.0  // Zoom scale for the graph

    private let graphService = GitGraphService()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "win.aiX",
        category: "GitGraphView"
    )

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if isLoading && graphCommits.isEmpty {
                loadingView
            } else if let error = errorMessage, graphCommits.isEmpty {
                errorView(error)
            } else if graphCommits.isEmpty {
                emptyView
            } else {
                graphContentView
            }
        }
        .task {
            await loadGraphData()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(String(localized: "git.panel.graph"))
                .font(.system(size: 13, weight: .medium))

            Spacer()

            if !graphCommits.isEmpty {
                Text("\(graphCommits.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Capsule())
            }

            // Refresh
            Button {
                Task { await refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help(String(localized: "git.history.refresh"))
            .disabled(isLoading)

            // Zoom controls
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut) {
                        graphScale = max(0.5, graphScale - 0.1)
                    }
                }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.plain)
                .help("Zoom Out")

                Button(action: {
                    withAnimation(.easeInOut) {
                        graphScale = 1.0
                    }
                }) {
                    Image(systemName: "scope")
                }
                .buttonStyle(.plain)
                .help("Reset Zoom")

                Button(action: {
                    withAnimation(.easeInOut) {
                        graphScale = min(3.0, graphScale + 0.1)
                    }
                }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.plain)
                .help("Zoom In")
            }
            .padding(.leading, 6)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text(String(localized: "git.history.loading"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            Text(String(localized: "git.history.loadFailed"))
                .font(.system(size: 13, weight: .medium))

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(String(localized: "general.retry")) {
                Task { await loadGraphData() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text(String(localized: "git.history.empty"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var graphContentView: some View {
        VStack(spacing: 0) {
            // Commit details bar
            if let selected = selectedGraphCommit {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.shortHash)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        Text(selected.message)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Text(selected.author)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Button(action: {
                            // Send selection to parent to show diff/details
                            let gitCommit = GitCommit(
                                id: selected.id,
                                shortHash: selected.shortHash,
                                message: selected.message,
                                author: selected.author,
                                date: selected.date,
                                filesChanged: selected.filesChanged,
                                additions: selected.additions,
                                deletions: selected.deletions
                            )
                            onSelectCommit(gitCommit)
                        }) {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(.plain)
                        .help("Show Diff")
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 46)
                Divider()
            }

            // Graph canvas with zoom and magnification
            GitGraphRenderer.drawGraph(
                commits: graphCommits,
                connections: connections,
                selectedCommit: selectedGraphCommit,
                scale: graphScale,
                onTapCommit: { commit in
                    selectedGraphCommit = commit
                    // Convert to GitCommit for compatibility
                    let gitCommit = GitCommit(
                        id: commit.id,
                        shortHash: commit.shortHash,
                        message: commit.message,
                        author: commit.author,
                        date: commit.date,
                        filesChanged: commit.filesChanged,
                        additions: commit.additions,
                        deletions: commit.deletions
                    )
                    onSelectCommit(gitCommit)
                }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        // MagnificationGesture provides scale relative to the gesture start.
                        // We map the magnification into our graphScale clamps and keep it stable
                        let clamped = min(max(value, 0.4), 2.5)
                        graphScale = clamped
                    }
            )
            .animation(.easeInOut, value: graphScale)
        }
    }

    private func loadGraphData() async {
        isLoading = true
        errorMessage = nil

        do {
            let commits = try await graphService.getGraphData(at: worktreePath, limit: 100)
            graphCommits = commits
            connections = graphService.getConnections(for: commits)
        } catch {
            logger.error("Failed to load graph data: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func refresh() async {
        graphCommits = []
        connections = []
        await loadGraphData()
    }
}
