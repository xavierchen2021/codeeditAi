//
//  ContentView.swift
//  aizen
//
//  Created by Uladzislau Yakauleu on 17.10.25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var repositoryManager: RepositoryManager
    @StateObject private var tabStateManager = WorktreeTabStateManager()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Workspace.order, ascending: true)],
        animation: .default)
    private var workspaces: FetchedResults<Workspace>

    @State private var selectedWorkspace: Workspace?
    @State private var selectedRepository: Repository?
    @State private var selectedWorktree: Worktree?
    @State private var searchText = ""
    @State private var showingAddRepository = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var previousWorktree: Worktree?
    @AppStorage("hasShownOnboarding") private var hasShownOnboarding = false
    @State private var showingOnboarding = false
    @AppStorage("zenModeEnabled") private var zenModeEnabled = false

    // Floating panels (lifted state to top-level so panels can overlay entire window)
    @State private var tabContainerSize: CGSize = .zero
    @State private var showFloatingPanels: Bool = false
    @State private var showTerminalPanel: Bool = false
    @State private var showFilesPanel: Bool = false
    @State private var showBrowserPanel: Bool = false
    @State private var showTaskPanel: Bool = false
    @State private var showGitPanel: Bool = false
    @State private var selectedFloatingButton: Int? = nil
    @State private var minimizedPanelIds: Set<String> = []
    @State private var activeFloatingPanel: FloatingPanelType? = nil
    @State private var fileToOpenFromSearch: String? = nil


    // Command palette state
    @State private var commandPaletteController: CommandPaletteWindowController?
    @State private var saveTask: Task<Void, Never>?

    // Git changes overlay state (passed from RootView)
    @Binding var gitChangesContext: GitChangesContext?

    // Persistent selection storage
    @AppStorage("selectedWorkspaceId") private var selectedWorkspaceId: String?
    @AppStorage("selectedRepositoryId") private var selectedRepositoryId: String?
    @AppStorage("selectedWorktreeId") private var selectedWorktreeId: String?

    init(context: NSManagedObjectContext, repositoryManager: RepositoryManager, gitChangesContext: Binding<GitChangesContext?>) {
        self.repositoryManager = repositoryManager
        _gitChangesContext = gitChangesContext
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } content: {
            middlePanelView
        } detail: {
            detailPanelView
        }
        .overlay(floatingPanelsOverlay)
        .sheet(isPresented: $showingAddRepository) {
            addRepositorySheet
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
        }
        .onAppear(perform: onAppearAction)
        .onChange(of: selectedWorkspace, perform: onWorkspaceChange)
        .onChange(of: selectedRepository, perform: onRepositoryChange)
        .onChange(of: selectedWorktree, perform: onWorktreeChange)
        .onReceive(NotificationCenter.default.publisher(for: .commandPaletteShortcut)) { _ in
            showCommandPalette()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickSwitchWorktree)) { _ in
            quickSwitchToPreviousWorktree()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToWorktree), perform: handleNavigateToWorktree)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToChatSession), perform: handleNavigateToChatSession)
    }

    // MARK: - View Components

    private var sidebarView: some View {
        WorkspaceSidebarView(
            workspaces: Array(workspaces),
            selectedWorkspace: $selectedWorkspace,
            selectedRepository: $selectedRepository,
            selectedWorktree: $selectedWorktree,
            searchText: $searchText,
            showingAddRepository: $showingAddRepository,
            repositoryManager: repositoryManager
        )
        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
    }

    private var middlePanelView: some View {
        Group {
            if let repository = selectedRepository {
                WorktreeListView(
                    repository: repository,
                    selectedWorktree: $selectedWorktree,
                    repositoryManager: repositoryManager,
                    tabStateManager: tabStateManager,
                    onOpenFile: handleOpenFile,
                    onShowDiff: handleShowDiff
                )
            } else {
                placeholderView(
                    titleKey: "contentView.selectRepository",
                    systemImage: "folder.badge.gearshape",
                    descriptionKey: "contentView.selectRepositoryDescription"
                )
            }
        }
        .navigationSplitViewColumnWidth(
            min: zenModeEnabled ? 0 : 250,
            ideal: zenModeEnabled ? 0 : 300,
            max: zenModeEnabled ? 0 : 400
        )
        .opacity(zenModeEnabled ? 0 : 1)
        .allowsHitTesting(!zenModeEnabled)
        .animation(.easeInOut(duration: 0.25), value: zenModeEnabled)
    }

    @ViewBuilder
    private var detailPanelView: some View {
        if let worktree = selectedWorktree, !worktree.isDeleted {
            WorktreeDetailView(
                worktree: worktree,
                repositoryManager: repositoryManager,
                tabStateManager: tabStateManager,
                gitChangesContext: $gitChangesContext,
                tabContainerSize: $tabContainerSize,
                showFloatingPanels: $showFloatingPanels,
                showTerminalPanel: $showTerminalPanel,
                showFilesPanel: $showFilesPanel,
                showBrowserPanel: $showBrowserPanel,
                showTaskPanel: $showTaskPanel,
                showGitPanel: $showGitPanel,
                selectedFloatingButton: $selectedFloatingButton,
                minimizedPanelIds: $minimizedPanelIds,
                activeFloatingPanel: $activeFloatingPanel,
                fileToOpenFromSearch: $fileToOpenFromSearch,
                onWorktreeDeleted: { nextWorktree in
                    selectedWorktree = nextWorktree
                }
            )
        } else {
            placeholderView(
                titleKey: "contentView.selectWorktree",
                systemImage: "arrow.triangle.branch",
                descriptionKey: "contentView.selectWorktreeDescription"
            )
        }
    }

    private var floatingPanelsOverlay: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if showFilesPanel, let worktree = selectedWorktree {
                    filesFloatingPanel(worktree: worktree, geometry: geometry)
                }

                if showBrowserPanel, let worktree = selectedWorktree {
                    browserFloatingPanel(worktree: worktree, geometry: geometry)
                }

                if showTaskPanel, let worktree = selectedWorktree {
                    taskFloatingPanel(worktree: worktree, geometry: geometry)
                }

                if showGitPanel, let worktree = selectedWorktree {
                    gitFloatingPanel(worktree: worktree, geometry: geometry)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(true)
        }
    }

    @ViewBuilder
    private var addRepositorySheet: some View {
        if let workspace = selectedWorkspace ?? workspaces.first {
            RepositoryAddSheet(
                workspace: workspace,
                repositoryManager: repositoryManager,
                onRepositoryAdded: { repository in
                    selectedWorktree = nil
                    selectedRepository = repository
                }
            )
        } else {
            EmptyView()
        }
    }

    // MARK: - Floating Panel Views

    private func filesFloatingPanel(worktree: Worktree, geometry: GeometryProxy) -> some View {
        FloatingPanelView(
            title: "Files",
            icon: "folder",
            windowId: "floating-files-\(worktree.id?.uuidString ?? "")",
            isPresented: $showFilesPanel,
            onMinimize: { minimizePanel(panelType: .files, for: worktree) },
            onActivate: { activeFloatingPanel = .files },
            tabContainerSize: geometry.size
        ) {
            FileTabView(
                worktree: worktree,
                fileToOpenFromSearch: $fileToOpenFromSearch
            )
        }
        .zIndex(activeFloatingPanel == .files ? 150 : 100)
    }

    private func browserFloatingPanel(worktree: Worktree, geometry: GeometryProxy) -> some View {
        FloatingPanelView(
            title: "Browser",
            icon: "globe",
            windowId: "floating-browser-\(worktree.id?.uuidString ?? "")",
            isPresented: $showBrowserPanel,
            onMinimize: { minimizePanel(panelType: .browser, for: worktree) },
            onActivate: { activeFloatingPanel = .browser },
            tabContainerSize: geometry.size
        ) {
            BrowserTabView(
                worktree: worktree,
                selectedSessionId: .constant(nil)
            )
        }
        .zIndex(activeFloatingPanel == .browser ? 150 : 100)
    }

    private func taskFloatingPanel(worktree: Worktree, geometry: GeometryProxy) -> some View {
        FloatingPanelView(
            title: "Tasks",
            icon: "checklist",
            windowId: "floating-tasks-\(worktree.id?.uuidString ?? "")",
            isPresented: $showTaskPanel,
            onMinimize: { minimizePanel(panelType: .task, for: worktree) },
            onActivate: { activeFloatingPanel = .task },
            tabContainerSize: geometry.size
        ) {
            TasksTabView(worktree: worktree)
        }
        .zIndex(activeFloatingPanel == .task ? 150 : 100)
    }

    private func gitFloatingPanel(worktree: Worktree, geometry: GeometryProxy) -> some View {
        FloatingPanelView(
            title: "Git",
            icon: "arrow.triangle.branch",
            windowId: "floating-git-\(worktree.id?.uuidString ?? "")",
            isPresented: $showGitPanel,
            onMinimize: { minimizePanel(panelType: .git, for: worktree) },
            onActivate: { activeFloatingPanel = .git },
            tabContainerSize: geometry.size
        ) {
            let floatingGitContext = GitChangesContext(worktree: worktree, service: GitRepositoryService(worktreePath: worktree.path ?? ""))
            GitPanelWindowContent(
                context: floatingGitContext,
                repositoryManager: repositoryManager,
                selectedTab: .constant(.git),
                showDiffPanel: .constant(false),
                onClose: { showGitPanel = false }
            )
        }
        .zIndex(activeFloatingPanel == .git ? 150 : 100)
    }

    private func navigateToChatSession(chatSessionId: UUID) {
        // Lookup chat session and navigate to its worktree
        let request: NSFetchRequest<ChatSession> = ChatSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", chatSessionId as CVarArg)
        request.fetchLimit = 1

        guard let chatSession = try? viewContext.fetch(request).first,
              let worktree = chatSession.worktree,
              let worktreeId = worktree.id,
              let repository = worktree.repository,
              let repoId = repository.id,
              let workspace = repository.workspace,
              let workspaceId = workspace.id else {
            return
        }

        navigateToWorktree(workspaceId: workspaceId, repoId: repoId, worktreeId: worktreeId)

        // Post notification to switch to chat tab with the specific session
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: .switchToChatSession,
                object: nil,
                userInfo: ["chatSessionId": chatSessionId]
            )
        }
    }

    private func showCommandPalette() {
        // Toggle behavior: close if already visible
        if let existing = commandPaletteController, existing.window?.isVisible == true {
            existing.closeWindow()
            commandPaletteController = nil
            return
        }

        let controller = CommandPaletteWindowController(
            managedObjectContext: viewContext,
            onNavigate: { workspaceId, repoId, worktreeId in
                navigateToWorktree(workspaceId: workspaceId, repoId: repoId, worktreeId: worktreeId)
            }
        )
        commandPaletteController = controller
        controller.showWindow(nil)
    }

    private func quickSwitchToPreviousWorktree() {
        let request: NSFetchRequest<Worktree> = Worktree.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Worktree.lastAccessed, ascending: false)]

        guard let worktrees = try? viewContext.fetch(request) else { return }

        // Find first worktree that isn't the current one
        let currentId = selectedWorktree?.id
        guard let target = worktrees.first(where: { $0.id != currentId }),
              let worktreeId = target.id,
              let repoId = target.repository?.id,
              let workspaceId = target.repository?.workspace?.id else {
            return
        }

        target.lastAccessed = Date()
        try? viewContext.save()
        navigateToWorktree(workspaceId: workspaceId, repoId: repoId, worktreeId: worktreeId)
    }

    private func navigateToWorktree(workspaceId: UUID, repoId: UUID, worktreeId: UUID) {
        if let workspace = workspaces.first(where: { $0.id == workspaceId }) {
            selectedWorkspace = workspace
            let repos = (workspace.repositories as? Set<Repository>) ?? []
            if let repo = repos.first(where: { $0.id == repoId }) {
                selectedRepository = repo
                let worktrees = (repo.worktrees as? Set<Worktree>) ?? []
                if let worktree = worktrees.first(where: { $0.id == worktreeId }) {
                    selectedWorktree = worktree
                }
            }
        }
    }

    // MARK: - File and Diff Handling

    private func handleOpenFile(_ filePath: String) {
        NotificationCenter.default.post(
            name: .openFileInEditor,
            object: nil,
            userInfo: ["path": filePath]
        )
    }

    private func handleShowDiff(_ filePath: String) {
        NotificationCenter.default.post(
            name: .showFileDiff,
            object: nil,
            userInfo: ["path": filePath]
        )
    }

    // MARK: - Event Handlers

    private func onAppearAction() {
        if selectedWorkspace == nil {
            if let workspaceId = selectedWorkspaceId,
               let uuid = UUID(uuidString: workspaceId),
               let workspace = workspaces.first(where: { $0.id == uuid }) {
                selectedWorkspace = workspace
            } else {
                selectedWorkspace = workspaces.first
            }
        }

        if selectedRepository == nil,
           let repositoryId = selectedRepositoryId,
           let uuid = UUID(uuidString: repositoryId),
           let workspace = selectedWorkspace {
            let repositories = (workspace.repositories as? Set<Repository>) ?? []
            selectedRepository = repositories.first(where: { $0.id == uuid })
        }

        if selectedWorktree == nil,
           let worktreeId = selectedWorktreeId,
           let uuid = UUID(uuidString: worktreeId),
           let repository = selectedRepository {
            let worktrees = (repository.worktrees as? Set<Worktree>) ?? []
            selectedWorktree = worktrees.first(where: { $0.id == uuid })
        }

        if !hasShownOnboarding {
            showingOnboarding = true
            hasShownOnboarding = true
        }
    }

    private func onWorkspaceChange(_ newValue: Workspace?) {
        selectedWorkspaceId = newValue?.id?.uuidString

        if let workspace = newValue {
            let repositories = (workspace.repositories as? Set<Repository>) ?? []
            if let lastRepoId = workspace.lastSelectedRepositoryId,
               let lastRepo = repositories.first(where: { $0.id == lastRepoId && !$0.isDeleted }) {
                selectedRepository = lastRepo
            } else {
                selectedRepository = repositories.sorted { ($0.name ?? "") < ($1.name ?? "") }.first
            }
        } else {
            selectedRepository = nil
        }
    }

    private func onRepositoryChange(_ newValue: Repository?) {
        selectedRepositoryId = newValue?.id?.uuidString

        if let repo = newValue, repo.isDeleted || repo.isFault {
            selectedRepository = nil
            selectedWorktree = nil
        } else if let repo = newValue {
            if let workspace = selectedWorkspace {
                workspace.lastSelectedRepositoryId = repo.id
                saveTask?.cancel()
                saveTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    try? viewContext.save()
                }
            }

            let worktrees = (repo.worktrees as? Set<Worktree>) ?? []
            selectedWorktree = worktrees.first(where: { $0.isPrimary })
        }
    }

    private func onWorktreeChange(_ newValue: Worktree?) {
        selectedWorktreeId = newValue?.id?.uuidString

        if let newWorktree = newValue, !newWorktree.isDeleted {
            previousWorktree = newWorktree
            Task { @MainActor in
                try? repositoryManager.updateWorktreeAccess(newWorktree)
            }
        } else if newValue?.isDeleted == true {
            selectedWorktree = nil
            if let repository = selectedRepository {
                let worktrees = (repository.worktrees as? Set<Worktree>) ?? []
                selectedWorktree = worktrees.first(where: { $0.isPrimary && !$0.isDeleted })
            }
        }
    }

    private func handleNavigateToWorktree(_ notification: Notification) {
        guard let info = notification.userInfo,
              let workspaceId = info["workspaceId"] as? UUID,
              let repoId = info["repoId"] as? UUID,
              let worktreeId = info["worktreeId"] as? UUID else {
            return
        }
        navigateToWorktree(workspaceId: workspaceId, repoId: repoId, worktreeId: worktreeId)
    }

    private func handleNavigateToChatSession(_ notification: Notification) {
        guard let chatSessionId = notification.userInfo?["chatSessionId"] as? UUID else {
            return
        }
        navigateToChatSession(chatSessionId: chatSessionId)
    }

    // MARK: - Floating panel helpers
    private func minimizePanel(panelType: FloatingPanelType, for worktree: Worktree) {
        let panelId: String
        switch panelType {
        case .files: panelId = "floating-files-\(worktree.id?.uuidString ?? "")"
        case .browser: panelId = "floating-browser-\(worktree.id?.uuidString ?? "")"
        case .task: panelId = "floating-tasks-\(worktree.id?.uuidString ?? "")"
        case .git: panelId = "floating-git-\(worktree.id?.uuidString ?? "")"
        }
        minimizedPanelIds.insert(panelId)

        // Hide panel
        withAnimation {
            switch panelType {
            case .files: showFilesPanel = false
            case .browser: showBrowserPanel = false
            case .task: showTaskPanel = false
            case .git: showGitPanel = false
            }
        }
    }

    private func restorePanel(panelType: FloatingPanelType, for worktree: Worktree) {
        let panelId: String
        switch panelType {
        case .files: panelId = "floating-files-\(worktree.id?.uuidString ?? "")"
        case .browser: panelId = "floating-browser-\(worktree.id?.uuidString ?? "")"
        case .task: panelId = "floating-tasks-\(worktree.id?.uuidString ?? "")"
        case .git: panelId = "floating-git-\(worktree.id?.uuidString ?? "")"
        }
        minimizedPanelIds.remove(panelId)

        // Show panel and activate
        withAnimation {
            switch panelType {
            case .files: showFilesPanel = true
            case .browser: showBrowserPanel = true
            case .task: showTaskPanel = true
            case .git: showGitPanel = true
            }
            activeFloatingPanel = panelType
        }
    }

    private func isPanelMinimized(panelType: FloatingPanelType, for worktree: Worktree) -> Bool {
        let panelId: String
        switch panelType {
        case .files: panelId = "floating-files-\(worktree.id?.uuidString ?? "")"
        case .browser: panelId = "floating-browser-\(worktree.id?.uuidString ?? "")"
        case .task: panelId = "floating-tasks-\(worktree.id?.uuidString ?? "")"
        case .git: panelId = "floating-git-\(worktree.id?.uuidString ?? "")"
        }
        return minimizedPanelIds.contains(panelId)
    }
}


@ViewBuilder
private func placeholderView(
    titleKey: LocalizedStringKey,
    systemImage: String,
    descriptionKey: LocalizedStringKey
) -> some View {
    if #available(macOS 14.0, *) {
        ContentUnavailableView(
            titleKey,
            systemImage: systemImage,
            description: Text(descriptionKey)
        )
    } else {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(titleKey)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(descriptionKey)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    RootView(context: PersistenceController.preview.container.viewContext)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
