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

        // Fetch branch heads and worktrees to annotate commits
        let branchService = GitBranchService()
        let worktreeService = GitWorktreeService()
        async let branches = branchService.listBranches(at: repoPath, includeRemote: false)
        async let worktrees = worktreeService.listWorktrees(at: repoPath)

        // Build graph layout (include branches & worktrees for annotations)
        let graphCommits = await buildGraphLayout(commits: commits, branches: try await branches, worktrees: try await worktrees)

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
    private func buildGraphLayout(commits: [Libgit2CommitInfo], branches: [BranchInfo], worktrees: [WorktreeInfo]) async -> [GitGraphCommit] {
        guard !commits.isEmpty else { return [] }

        var graphCommits: [GitGraphCommit] = []

        // Build quick lookup maps for branch heads and worktrees
        var branchMap: [String: [String]] = [:] // shortCommit -> [branchName]
        for b in branches {
            if b.commit.isEmpty { continue }
            branchMap[b.commit, default: []].append(b.name)
        }

        // Map worktrees by branch name and by commit short id
        var worktreesByBranch: [String: [WorktreeInfo]] = [:]
        var worktreesByCommit: [String: [WorktreeInfo]] = [:]
        for wt in worktrees {
            worktreesByBranch[wt.branch, default: []].append(wt)
            if !wt.commit.isEmpty {
                worktreesByCommit[wt.commit, default: []].append(wt)
            }
        }

        // Columns represent active branch tracks (each holds the next expected commit id at that track)
        var columns: [String?] = []  // element is commit id expected at that column

        func getTrackColor(for index: Int) -> String {
            return GitGraphTrackColor.color(forIndex: index)
        }

        // Process commits in displayed order (newest first)
        for (index, commit) in commits.enumerated() {
            // Determine column: if commit is expected in an existing column (its id matches), use it
            var columnIndex: Int? = columns.firstIndex(where: { $0 == commit.oid })

            // If not found, reuse first free column, or append
            if columnIndex == nil {
                if let free = columns.firstIndex(where: { $0 == nil }) {
                    columnIndex = free
                } else {
                    columns.append(nil)
                    columnIndex = columns.count - 1
                }
            }

            let column = columnIndex ?? 0
            let trackColor = getTrackColor(for: column)

            // After placing this commit at column, set that column's expected next commit to the primary parent
            // Primary parent is first parent if exists
            let parentIds = commit.parentIds
            if let primaryParent = parentIds.first {
                columns[column] = primaryParent
            } else {
                // No parents (root), free this column
                columns[column] = nil
            }

            // For additional parents (merges), ensure they are present in some column so their connections draw across
            if parentIds.count > 1 {
                // Helper to allocate a free column nearest to an anchor (prefer closeness to master/current column)
                func allocateColumn(near anchor: Int) -> Int {
                    // search radiating outwards from anchor for a free slot
                    let maxIndex = columns.count - 1
                    for offset in 0...max(maxIndex, 0) {
                        let left = anchor - offset
                        if left >= 0 && columns[left] == nil {
                            return left
                        }
                        let right = anchor + offset
                        if right <= maxIndex && columns[right] == nil {
                            return right
                        }
                    }
                    // No free slot found - append at end
                    columns.append(nil)
                    return columns.count - 1
                }

                for extraParent in parentIds.dropFirst() {
                    // If already present do nothing
                    if columns.contains(where: { $0 == extraParent }) { continue }

                    // Allocate nearest free column to current commit column
                    let freeIndex = allocateColumn(near: column)
                    columns[freeIndex] = extraParent
                }
            }

            // Determine branch names that point to this commit (branch service provides short commit ids)
            let branchNames = branchMap[commit.shortOid] ?? []

            // Determine worktrees that match either by commit or by branch name
            var matchedWorktrees: [WorktreeInfo] = []
            if let byCommit = worktreesByCommit[commit.shortOid] {
                matchedWorktrees.append(contentsOf: byCommit)
            }
            for bn in branchNames {
                if let byBranch = worktreesByBranch[bn] {
                    matchedWorktrees.append(contentsOf: byBranch)
                }
            }
            // Unique names
            let worktreeNames = Array(Set(matchedWorktrees.map { URL(fileURLWithPath: $0.path).lastPathComponent }))

            // Create graph commit model
            let graphCommit = GitGraphCommit(
                id: commit.oid,
                shortHash: commit.shortOid,
                message: commit.summary,
                author: commit.author.name,
                date: commit.time,
                filesChanged: 0,
                additions: 0,
                deletions: 0,
                parentIds: parentIds,
                row: index,
                column: column,
                trackColor: trackColor,
                branchNames: branchNames,
                worktreeNames: worktreeNames
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
        return commit.parentIds
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
