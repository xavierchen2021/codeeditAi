//
//  WorktreeListItemView.swift
//  aizen
//
//  Created by Uladzislau Yakauleu on 17.10.25.
//

import SwiftUI
import os.log

struct WorktreeListItemView: View {
    @ObservedObject var worktree: Worktree
    let isSelected: Bool
    @ObservedObject var repositoryManager: RepositoryManager
    let allWorktrees: [Worktree]
    @Binding var selectedWorktree: Worktree?
    @ObservedObject var tabStateManager: WorktreeTabStateManager
    var onOpenFile: ((String) -> Void)? = nil
    var onShowDiff: ((String) -> Void)? = nil

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "win.aiX.app", category: "WorktreeListItemView")

    @AppStorage("defaultTerminalBundleId") private var defaultTerminalBundleId: String?
    @AppStorage("defaultEditorBundleId") private var defaultEditorBundleId: String?

    // Git 状态相关状态
    @State private var gitStatus: GitStatus = .empty
    @State private var isLoadingGitStatus = false
    @State private var showGitChanges = false
    @State private var selectedChangedFile: String?

    private var defaultTerminal: DetectedApp? {
        guard let bundleId = defaultTerminalBundleId else { return nil }
        return AppDetector.shared.getTerminals().first { $0.bundleIdentifier == bundleId }
    }

    private var defaultEditor: DetectedApp? {
        guard let bundleId = defaultEditorBundleId else { return nil }
        return AppDetector.shared.getEditors().first { $0.bundleIdentifier == bundleId }
    }

    private var finderApp: DetectedApp? {
        AppDetector.shared.getApps(for: .finder).first
    }

    private func sortedApps(_ apps: [DetectedApp], defaultBundleId: String?) -> [DetectedApp] {
        guard let defaultId = defaultBundleId else { return apps }
        var sorted = apps.filter { $0.bundleIdentifier != defaultId }
        if let defaultApp = apps.first(where: { $0.bundleIdentifier == defaultId }) {
            sorted.insert(defaultApp, at: 0)
        }
        return sorted
    }

    @State private var showingDetails = false
    @State private var showingDeleteConfirmation = false
    @State private var hasUnsavedChanges = false
    @State private var errorMessage: String?
    @State private var worktreeStatuses: [WorktreeStatusInfo] = []
    @State private var isLoadingStatuses = false
    @State private var mergeErrorMessage: String?
    @State private var mergeConflictFiles: [String] = []
    @State private var showingMergeConflict = false
    @State private var showingMergeSuccess = false
    @State private var mergeSuccessMessage = ""
    @State private var availableBranches: [BranchInfo] = []
    @State private var isLoadingBranches = false
    @State private var showingBranchSelector = false
    @State private var branchSwitchError: String?
    @State private var selectedBranchForSwitch: BranchInfo?
    @State private var showingNoteEditor = false

    private var worktreeStatus: ItemStatus {
        ItemStatus(rawValue: worktree.status ?? "active") ?? .active
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: worktree.isPrimary ? "arrow.triangle.branch" : "arrow.triangle.2.circlepath")
                .foregroundStyle(isSelected ? Color.accentColor : worktreeStatus.color)
                .imageScale(.medium)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(worktree.branch ?? String(localized: "worktree.list.unknown"))
                        .font(.headline)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)

                    if worktree.isPrimary {
                        Text("worktree.detail.main", bundle: .main)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue, in: Capsule())
                    }
                }

                Text(worktree.path ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let note = worktree.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if let lastAccessed = worktree.lastAccessed {
                    Text(String(localized: "worktree.list.lastAccessed \(lastAccessed.formatted(.relative(presentation: .named)))"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                ActiveTabIndicatorView(
                    worktree: worktree,
                    tabStateManager: tabStateManager
                )

                // Git 修改情况显示区域
                if gitStatus.hasChanges {
                    HStack(spacing: 4) {
                        Text("worktree.git.changes")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            loadGitStatus()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Refresh Git status")
                    }
                    
                    GitChangesExpandedView(
                        gitStatus: gitStatus,
                        onFileTap: { file in
                            selectedChangedFile = file
                            onOpenFile?(file)
                        },
                        onShowDiff: { file in
                            selectedChangedFile = file
                            onShowDiff?(file)
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    // 调试：显示无修改状态
                    Text("无修改")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.15))
                : nil
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                showingDetails = true
            } label: {
                Label(String(localized: "worktree.detail.showDetails"), systemImage: "info.circle")
            }

            Divider()

            // Open in Terminal (with real name and icon)
            Button {
                if let path = worktree.path {
                    if let terminal = defaultTerminal {
                        AppDetector.shared.openPath(path, with: terminal)
                    } else {
                        repositoryManager.openInTerminal(path)
                    }
                }
            } label: {
                if let terminal = defaultTerminal {
                    AppMenuLabel(app: terminal)
                } else {
                    Label(String(localized: "worktree.detail.openTerminal"), systemImage: "terminal")
                }
            }

            // Open in Finder (with real icon)
            Button {
                if let path = worktree.path {
                    repositoryManager.openInFinder(path)
                }
            } label: {
                if let finder = finderApp {
                    AppMenuLabel(app: finder)
                } else {
                    Label(String(localized: "worktree.detail.openFinder"), systemImage: "folder")
                }
            }

            // Open in Editor (with real name and icon)
            Button {
                if let path = worktree.path {
                    if let editor = defaultEditor {
                        AppDetector.shared.openPath(path, with: editor)
                    } else {
                        repositoryManager.openInEditor(path)
                    }
                }
            } label: {
                if let editor = defaultEditor {
                    AppMenuLabel(app: editor)
                } else {
                    Label(String(localized: "worktree.detail.openEditor"), systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            // Open in... submenu
            Menu {
                Text(String(localized: "worktree.openIn.terminals"))
                    .font(.caption)

                ForEach(sortedApps(AppDetector.shared.getTerminals(), defaultBundleId: defaultTerminalBundleId)) { terminal in
                    Button {
                        if let path = worktree.path {
                            AppDetector.shared.openPath(path, with: terminal)
                        }
                    } label: {
                        HStack {
                            AppMenuLabel(app: terminal)
                            if terminal.bundleIdentifier == defaultTerminalBundleId {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Text(String(localized: "worktree.openIn.editors"))
                    .font(.caption)

                ForEach(sortedApps(AppDetector.shared.getEditors(), defaultBundleId: defaultEditorBundleId)) { editor in
                    Button {
                        if let path = worktree.path {
                            AppDetector.shared.openPath(path, with: editor)
                        }
                    } label: {
                        HStack {
                            AppMenuLabel(app: editor)
                            if editor.bundleIdentifier == defaultEditorBundleId {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label(String(localized: "worktree.openIn.title"), systemImage: "arrow.up.forward.app")
            }

            Button {
                if let branch = worktree.branch {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(branch, forType: .string)
                }
            } label: {
                Label(String(localized: "worktree.detail.copyBranchName"), systemImage: "doc.on.doc")
            }

            Button {
                if let path = worktree.path {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                }
            } label: {
                Label(String(localized: "worktree.detail.copyPath"), systemImage: "doc.on.clipboard")
            }

            Divider()

            Menu {
                ForEach(worktreeStatuses.filter { $0.worktree.id != worktree.id }, id: \.worktree.id) { statusInfo in
                    Button {
                        performMerge(from: statusInfo.worktree, to: worktree)
                    } label: {
                        HStack {
                            Text(statusInfo.branch)
                            if statusInfo.hasUncommittedChanges {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            } label: {
                Label(String(localized: "worktree.merge.pullFrom"), systemImage: "arrow.down.circle")
            }

            Divider()

            Menu {
                if availableBranches.isEmpty && !isLoadingBranches {
                    Text(String(localized: "general.loading"))
                        .foregroundStyle(.secondary)
                        .onAppear { loadAvailableBranches() }
                } else if isLoadingBranches {
                    Text(String(localized: "general.loading"))
                        .foregroundStyle(.secondary)
                } else {
                    // Show top local branches (excluding current)
                    ForEach(availableBranches.filter { !$0.isRemote && $0.name != worktree.branch }) { branch in
                        Button {
                            switchToBranch(branch)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.caption)
                                Text(branch.name)
                            }
                        }
                    }

                    // Show remote branches that can be tracked
                    if !availableBranches.filter({ $0.isRemote }).isEmpty {
                        Divider()

                        ForEach(availableBranches.filter { $0.isRemote }) { branch in
                            Button {
                                switchToBranch(branch)
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.caption)
                                    Text(branch.name)
                                    Text(String(localized: "worktree.branch.remote"))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        showingBranchSelector = true
                    } label: {
                        Label(String(localized: "worktree.branch.browseOrCreate"), systemImage: "ellipsis.circle")
                    }
                }
            } label: {
                Label(String(localized: "worktree.branch.switch"), systemImage: "arrow.triangle.swap")
            }

            Divider()

            // Status submenu
            Menu {
                ForEach(ItemStatus.allCases) { status in
                    Button {
                        setWorktreeStatus(status)
                    } label: {
                        HStack {
                            Circle()
                                .fill(status.color)
                                .frame(width: 8, height: 8)
                            Text(status.title)
                            if worktreeStatus == status {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("worktree.setStatus", systemImage: "circle.fill")
            }

            Button {
                showingNoteEditor = true
            } label: {
                Label("worktree.editNote", systemImage: "note.text")
            }

            if !worktree.isPrimary {
                Divider()

                Button(role: .destructive) {
                    checkUnsavedChanges()
                } label: {
                    Label(String(localized: "worktree.detail.delete"), systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingDetails) {
            WorktreeDetailsSheet(worktree: worktree, repositoryManager: repositoryManager)
        }
        .sheet(isPresented: $showingBranchSelector) {
            if let repo = worktree.repository {
                BranchSelectorView(
                    repository: repo,
                    repositoryManager: repositoryManager,
                    selectedBranch: $selectedBranchForSwitch,
                    allowCreation: true,
                    onCreateBranch: { branchName in
                        createNewBranch(name: branchName)
                    }
                )
            }
        }
        .sheet(isPresented: $showingNoteEditor) {
            NoteEditorView(
                note: Binding(
                    get: { worktree.note ?? "" },
                    set: { worktree.note = $0 }
                ),
                title: String(localized: "worktree.note.title \(worktree.branch ?? "")"),
                onSave: {
                    try? repositoryManager.updateWorktreeNote(worktree, note: worktree.note)
                }
            )
        }
        .onChange(of: selectedBranchForSwitch) { newBranch in
            if let branch = newBranch {
                switchToBranch(branch)
                selectedBranchForSwitch = nil
            }
        }
        .alert(hasUnsavedChanges ? String(localized: "worktree.detail.unsavedChangesTitle") : String(localized: "worktree.detail.deleteConfirmTitle"), isPresented: $showingDeleteConfirmation) {
            Button(String(localized: "worktree.create.cancel"), role: .cancel) {}
            Button(String(localized: "worktree.detail.delete"), role: .destructive) {
                deleteWorktree()
            }
        } message: {
            if hasUnsavedChanges {
                Text(String(localized: "worktree.detail.unsavedChangesMessage \(worktree.branch ?? String(localized: "worktree.list.unknown"))"))
            } else {
                Text(String(localized: "worktree.detail.deleteConfirmMessageWithName \(worktree.branch ?? String(localized: "worktree.list.unknown"))"))
            }
        }
        .alert(String(localized: "worktree.list.error"), isPresented: .constant(errorMessage != nil)) {
            Button(String(localized: "worktree.list.ok")) {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .alert(String(localized: "worktree.merge.conflict"), isPresented: $showingMergeConflict) {
            Button(String(localized: "worktree.list.ok")) {
                mergeConflictFiles = []
            }
        } message: {
            VStack(alignment: .leading) {
                Text(String(localized: "worktree.merge.conflictMessage"))
                ForEach(mergeConflictFiles, id: \.self) { file in
                    Text("• \(file)")
                }
                Text(String(localized: "worktree.merge.resolveHint"))
            }
        }
        .alert(String(localized: "worktree.merge.successful"), isPresented: $showingMergeSuccess) {
            Button(String(localized: "worktree.list.ok")) {}
        } message: {
            Text(mergeSuccessMessage)
        }
        .alert(String(localized: "worktree.merge.error"), isPresented: .constant(mergeErrorMessage != nil)) {
            Button(String(localized: "worktree.list.ok")) {
                mergeErrorMessage = nil
            }
        } message: {
            if let error = mergeErrorMessage {
                Text(error)
            }
        }
        .alert(String(localized: "worktree.branch.switchError"), isPresented: .constant(branchSwitchError != nil)) {
            Button(String(localized: "worktree.list.ok")) {
                branchSwitchError = nil
            }
        } message: {
            if let error = branchSwitchError {
                Text(error)
            }
        }
        .onAppear {
            loadWorktreeStatuses()
            loadGitStatus()
        }
    }

    // MARK: - Private Methods

    private func setWorktreeStatus(_ status: ItemStatus) {
        do {
            try repositoryManager.updateWorktreeStatus(worktree, status: status)
        } catch {
            logger.error("Failed to update worktree status: \(error.localizedDescription)")
        }
    }

    private func checkUnsavedChanges() {
        Task {
            do {
                let changes = try await repositoryManager.hasUnsavedChanges(worktree)
                await MainActor.run {
                    hasUnsavedChanges = changes
                    showingDeleteConfirmation = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func deleteWorktree() {
        Task {
            do {
                // Find closest worktree to select after deletion
                if let currentIndex = allWorktrees.firstIndex(where: { $0.id == worktree.id }) {
                    let nextWorktree: Worktree?

                    // Try next worktree, then previous, then nil
                    if currentIndex + 1 < allWorktrees.count {
                        nextWorktree = allWorktrees[currentIndex + 1]
                    } else if currentIndex > 0 {
                        nextWorktree = allWorktrees[currentIndex - 1]
                    } else {
                        nextWorktree = nil
                    }

                    try await repositoryManager.deleteWorktree(worktree, force: hasUnsavedChanges)

                    await MainActor.run {
                        selectedWorktree = nextWorktree
                    }
                } else {
                    try await repositoryManager.deleteWorktree(worktree, force: hasUnsavedChanges)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadWorktreeStatuses() {
        guard !isLoadingStatuses else { return }

        Task {
            await MainActor.run {
                isLoadingStatuses = true
            }

            var statuses: [WorktreeStatusInfo] = []

            for wt in allWorktrees {
                do {
                    let hasChanges = try await repositoryManager.hasUnsavedChanges(wt)
                    let branch = wt.branch ?? "unknown"
                    statuses.append(WorktreeStatusInfo(
                        worktree: wt,
                        hasUncommittedChanges: hasChanges,
                        branch: branch
                    ))
                } catch {
                    // Skip worktrees with errors
                    continue
                }
            }

            await MainActor.run {
                worktreeStatuses = statuses
                isLoadingStatuses = false
            }
        }
    }

    private func performMerge(from source: Worktree, to target: Worktree) {
        Task {
            do {
                let result = try await repositoryManager.mergeFromWorktree(target: target, source: source)

                await MainActor.run {
                    switch result {
                    case .success:
                        mergeSuccessMessage = "Successfully merged \(source.branch ?? "unknown") into \(target.branch ?? "unknown")"
                        showingMergeSuccess = true

                    case .conflict(let files):
                        mergeConflictFiles = files
                        showingMergeConflict = true

                    case .alreadyUpToDate:
                        mergeSuccessMessage = "Already up to date with \(source.branch ?? "unknown")"
                        showingMergeSuccess = true
                    }

                    // Reload statuses after merge
                    loadWorktreeStatuses()
                }
            } catch {
                await MainActor.run {
                    mergeErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadAvailableBranches() {
        guard !isLoadingBranches else { return }

        Task {
            await MainActor.run {
                isLoadingBranches = true
            }

            do {
                guard let repo = worktree.repository else {
                    logger.warning("Cannot load branches: worktree has no repository")
                    await MainActor.run { isLoadingBranches = false }
                    return
                }
                let branches = try await repositoryManager.getBranches(for: repo)

                await MainActor.run {
                    // Show top 5 local branches + top 3 remote branches
                    let localBranches = branches
                        .filter { !$0.isRemote && $0.name != worktree.branch }
                        .prefix(5)

                    let remoteBranches = branches
                        .filter { $0.isRemote }
                        .prefix(3)

                    availableBranches = Array(localBranches) + Array(remoteBranches)
                    isLoadingBranches = false
                }
            } catch {
                logger.error("Failed to load available branches: \(error.localizedDescription)")
                await MainActor.run { isLoadingBranches = false }
            }
        }
    }

    private func switchToBranch(_ branch: BranchInfo) {
        Task {
            do {
                // Handle remote branches by creating local tracking branch
                if branch.isRemote {
                    // Extract local branch name (e.g., "origin/feature" -> "feature")
                    let localName = branch.name.split(separator: "/").dropFirst().joined(separator: "/")

                    // Create and checkout new local branch tracking the remote
                    try await repositoryManager.createAndSwitchBranch(
                        worktree,
                        name: localName,
                        from: branch.name
                    )
                } else {
                    // Switch to existing local branch
                    try await repositoryManager.switchBranch(worktree, to: branch.name)
                }

                await MainActor.run {
                    loadAvailableBranches()
                }
            } catch {
                await MainActor.run {
                    branchSwitchError = error.localizedDescription
                }
            }
        }
    }

    private func createNewBranch(name: String) {
        Task {
            do {
                // Create new branch from current branch
                guard let currentBranch = worktree.branch else {
                    throw Libgit2Error.branchNotFound("No current branch")
                }

                try await repositoryManager.createAndSwitchBranch(
                    worktree,
                    name: name,
                    from: currentBranch
                )

                await MainActor.run {
                    loadAvailableBranches()
                }
            } catch {
                await MainActor.run {
                    branchSwitchError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Git Status Loading

    private func loadGitStatus() {
        guard let worktreePath = worktree.path else {
            logger.error("Worktree path is nil")
            return
        }

        logger.info("Loading git status for: \(worktreePath)")

        Task {
            await MainActor.run {
                isLoadingGitStatus = true
            }

            do {
                // 使用 GitStatusService 获取状态
                let statusService = GitStatusService()
                let detailedStatus = try await statusService.getDetailedStatus(
                    at: worktreePath,
                    includeUntracked: true,
                    includeDiffStats: true
                )
                
                let status = GitStatus(
                    stagedFiles: detailedStatus.stagedFiles,
                    modifiedFiles: detailedStatus.modifiedFiles,
                    untrackedFiles: detailedStatus.untrackedFiles,
                    conflictedFiles: detailedStatus.conflictedFiles,
                    currentBranch: detailedStatus.currentBranch ?? "",
                    aheadCount: detailedStatus.aheadBy,
                    behindCount: detailedStatus.behindBy,
                    additions: detailedStatus.additions,
                    deletions: detailedStatus.deletions
                )
                
                await MainActor.run {
                    self.gitStatus = status
                    isLoadingGitStatus = false
                    logger.info("Git status loaded: staged=\(gitStatus.stagedFiles.count), modified=\(gitStatus.modifiedFiles.count), untracked=\(gitStatus.untrackedFiles.count), hasChanges=\(gitStatus.hasChanges)")
                }
            } catch {
                logger.error("Failed to load git status: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingGitStatus = false
                }
            }
        }
    }
}

// MARK: - Git Changes Indicator View

struct GitChangesIndicatorView: View {
    let gitStatus: GitStatus
    let isExpanded: Bool
    let onTap: () -> Void
    let onFileTap: (String) -> Void
    let onShowDiff: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 折叠/展开指示器
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)

                    changesSummary

                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 0)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 展开的文件列表
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    changedFilesList
                }
                .padding(.leading, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var changesSummary: some View {
        HStack(spacing: 6) {
            if !gitStatus.stagedFiles.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.blue)
                Text("\(gitStatus.stagedFiles.count)")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }

            if gitStatus.additions > 0 {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
                Text("\(gitStatus.additions)")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }

            if gitStatus.deletions > 0 {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.red)
                Text("\(gitStatus.deletions)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            if !gitStatus.untrackedFiles.isEmpty {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange)
                Text("\(gitStatus.untrackedFiles.count)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var changedFilesList: some View {
        if gitStatus.stagedFiles.isEmpty &&
           gitStatus.modifiedFiles.isEmpty &&
           gitStatus.untrackedFiles.isEmpty {
            Text("worktree.git.noChanges")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } else {
            // Staged files
            if !gitStatus.stagedFiles.isEmpty {
                fileSection(
                    title: "worktree.git.staged",
                    icon: "checkmark.circle.fill",
                    color: .green,
                    files: gitStatus.stagedFiles
                )
            }

            // Modified files
            if !gitStatus.modifiedFiles.isEmpty {
                fileSection(
                    title: "worktree.git.modified",
                    icon: "pencil.circle.fill",
                    color: .orange,
                    files: gitStatus.modifiedFiles
                )
            }

            // Untracked files
            if !gitStatus.untrackedFiles.isEmpty {
                fileSection(
                    title: "worktree.git.untracked",
                    icon: "questionmark.circle.fill",
                    color: .orange,
                    files: gitStatus.untrackedFiles
                )
            }
        }
    }

    private func fileSection(title: String, icon: String, color: Color, files: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            ForEach(files, id: \.self) { file in
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 7))
                        .foregroundStyle(color)
                        .frame(width: 10)

                    Text(fileName(from: file))
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    // Diff 按钮
                    Button {
                        onShowDiff(file)
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("View diff")
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(3)
                .onTapGesture {
                    onFileTap(file)
                }
            }
        }
        .frame(maxHeight: 150)
    }

    private func fileName(from path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

// MARK: - Git Changes Expanded View

struct GitChangesExpandedView: View {
    let gitStatus: GitStatus
    let onFileTap: (String) -> Void
    let onShowDiff: (String) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                // Staged files
                if !gitStatus.stagedFiles.isEmpty {
                    fileSection(
                        title: "worktree.git.staged",
                        icon: "checkmark.circle.fill",
                        color: .blue,
                        files: gitStatus.stagedFiles
                    )
                }

                // Modified files
                if !gitStatus.modifiedFiles.isEmpty {
                    fileSection(
                        title: "worktree.git.modified",
                        icon: "pencil.circle.fill",
                        color: .orange,
                        files: gitStatus.modifiedFiles
                    )
                }

                // Untracked files
                if !gitStatus.untrackedFiles.isEmpty {
                    fileSection(
                        title: "worktree.git.untracked",
                        icon: "questionmark.circle.fill",
                        color: .orange,
                        files: gitStatus.untrackedFiles
                    )
                }
            }
            .padding(.top, 4)
        }
        .frame(maxHeight: 200)
    }

    private func fileSection(title: String, icon: String, color: Color, files: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            ForEach(files, id: \.self) { file in
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 7))
                        .foregroundStyle(color)
                        .frame(width: 10)

                    Text(fileName(from: file))
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    // 打开文件按钮
                    Button {
                        onFileTap(file)
                    } label: {
                        Image(systemName: "doc.text")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open file")
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onFileTap(file)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(3)
            }
        }
    }

    private func fileName(from path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}
