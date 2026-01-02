//
//  Worktree+Extensions.swift
//  aizen
//
//  Worktree extensions for computed properties
//

import Foundation

extension Worktree {
    /// Check if the worktree is in detached HEAD state (e.g., during rebase, cherry-pick)
    var isDetached: Bool {
        guard let branch = self.branch else { return false }
        return branch.starts(with: "detached at ")
    }
}
