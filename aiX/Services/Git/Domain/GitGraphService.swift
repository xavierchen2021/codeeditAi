//
//  GitGraphService.swift
//  aiX
//
//  Service for fetching and processing git graph data
//

import Foundation
import os.log

/// Service for managing Git graph data
actor GitGraphService {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "win.aiX",
        category: "GitGraphService"
    )

    /// Fetch commit history and build graph data
    func getGraphData(at repoPath: String, limit: Int = 100) async throws -> [GitGraphCommit] {
        // Fetch commit history with parent information
        let commits = try await fetchCommitsWithParents(at: repoPath, limit: limit)

        // Build graph layout
        let graphCommits = buildGraphLayout(commits: commits)

        return graphCommits
    }

    /// Fetch commits with parent information
    private func fetchCommitsWithParents(at repoPath: String, limit: Int) async throws -> [Libgit2CommitInfo] {
        return try await Task.detached {
            let repo = try Libgit2Repository(path: repoPath)
            let commits = try repo.log(limit: limit, skip: 0)
            return commits
        }.value
    }

    /// Build graph layout with track assignment
    private func buildGraphLayout(commits: [Libgit2CommitInfo]) -> [GitGraphCommit] {
        guard !commits.isEmpty else { return [] }

        var graphCommits: [GitGraphCommit] = []
        var trackMap: [String: Int] = [:]  // Branch name -> track index
        var currentTracks: [Int: String] = [:]  // Track index -> commit id
        var nextTrackIndex = 0

        // Track colors
        let trackColors = [
            GitGraphTrackColor.blue.hexColor,
            GitGraphTrackColor.green.hexColor,
            GitGraphTrackColor.purple.hexColor,
            GitGraphTrackColor.orange.hexColor,
            GitGraphTrackColor.pink.hexColor,
            GitGraphTrackColor.cyan.hexColor,
        ]

        func getTrackColor(for index: Int) -> String {
            return trackColors[index % trackColors.count]
        }

        // Process commits in order (already sorted by time, newest first)
        for (index, commit) in commits.enumerated() {
            var column = 0
            var trackColor = getTrackColor(for: 0)

            // Determine if this commit continues an existing track
            let parentIds = getParentIds(for: commit)
            var continuingTrack: Int?

            if parentIds.count == 1 {
                // Normal commit, try to continue from parent
                if let parentId = parentIds.first,
                   let parentTrack = currentTracks.first(where: { $0.value == parentId }) {
                    continuingTrack = parentTrack.key
                }
            } else if parentIds.count > 1 {
                // Merge commit
                // Find which track has the primary parent
                continuingTrack = currentTracks.first(where: { $0.value == parentIds.first })?.key
            }

            // Assign track
            if let trackIndex = continuingTrack {
                // Continue existing track
                column = trackIndex
                trackColor = getTrackColor(for: trackIndex)
                currentTracks[trackIndex] = commit.oid
            } else {
                // New branch - find an available track
                // Look for the first track that's free
                var assigned = false
                for track in 0..<max(3, nextTrackIndex) {
                    if currentTracks[track] == nil || currentTracks[track] == parentIds.first {
                        column = track
                        trackColor = getTrackColor(for: track)
                        currentTracks[track] = commit.oid
                        assigned = true
                        break
                    }
                }

                if !assigned {
                    // Create new track
                    column = nextTrackIndex
                    trackColor = getTrackColor(for: nextTrackIndex)
                    currentTracks[nextTrackIndex] = commit.oid
                    nextTrackIndex += 1
                }
            }

            // Create graph commit
            let graphCommit = GitGraphCommit(
                id: commit.oid,
                shortHash: commit.shortOid,
                message: commit.summary,
                author: commit.author.name,
                date: commit.time,
                filesChanged: 0,  // Will be filled later
                additions: 0,
                deletions: 0,
                parentIds: parentIds,
                row: index,
                column: column,
                trackColor: trackColor
            )

            graphCommits.append(graphCommit)
        }

        // Try to fetch stats for commits (async batch)
        await fetchStatsForCommits(
            graphCommits: &graphCommits,
            repoPath: commits.first?.oid.isEmpty == false ? "" : ""
        )

        return graphCommits
    }

    /// Get parent IDs for a commit
    private func getParentIds(for commit: Libgit2CommitInfo) -> [String] {
        var parentIds: [String] = []

        // For now, we don't have direct parent IDs in Libgit2CommitInfo
        // We'll need to enhance the data model or fetch separately
        // For the initial implementation, we'll use parentCount
        // In a full implementation, we'd fetch parent OIDs

        return parentIds
    }

    /// Fetch stats for commits in batch
    private func fetchStatsForCommits(
        graphCommits: inout [GitGraphCommit],
        repoPath: String
    ) async {
        // For now, skip stats to keep it simple
        // In a full implementation, we'd batch fetch stats for better performance
    }

    /// Get connections between commits
    func getConnections(for commits: [GitGraphCommit]) -> [GitGraphConnection] {
        var connections: [GitGraphConnection] = []
        var commitMap: [String: GitGraphCommit] = [:]

        for commit in commits {
            commitMap[commit.id] = commit
        }

        for commit in commits {
            for parentId in commit.parentIds {
                if let parent = commitMap[parentId] {
                    let connection = GitGraphConnection(
                        fromCommitId: parentId,
                        toCommitId: commit.id,
                        fromColumn: parent.column,
                        toColumn: commit.column,
                        fromRow: parent.row,
                        toRow: commit.row,
                        color: parent.trackColor
                    )
                    connections.append(connection)
                }
            }
        }

        return connections
    }
}
