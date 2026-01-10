//
//  WorktreeDetailView.swift
//  aizen
//
//  Created by Uladzislau Yakauleu on 17.10.25.
//

import SwiftUI
import os.log
import Combine

struct WorktreeDetailView: View {
    @ObservedObject var worktree: Worktree
    @ObservedObject var repositoryManager: RepositoryManager
    @ObservedObject var appDetector = AppDetector.shared
    @Binding var gitChangesContext: GitChangesContext?
    var onWorktreeDeleted: ((Worktree?) -> Void)?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "win.aiX", category: "WorktreeDetailView")

    @StateObject private var viewModel: WorktreeViewModel
    @ObservedObject var tabStateManager: WorktreeTabStateManager

    @AppStorage("showChatTab") private var showChatTab = true
    @AppStorage("showTerminalTab") private var showTerminalTab = true
    @AppStorage("showFilesTab") private var showFilesTab = true
    @AppStorage("showBrowserTab") private var showBrowserTab = true
    @AppStorage("showTaskTab") private var showTaskTab = true
    @AppStorage("showGitTab") private var showGitTab = true
    @AppStorage("showOpenInApp") private var showOpenInApp = true
    @AppStorage("showGitStatus") private var showGitStatus = true
    @AppStorage("showXcodeBuild") private var showXcodeBuild = true
    @AppStorage("zenModeEnabled") private var zenModeEnabled = false
    @AppStorage("terminalThemeName") private var terminalThemeName = "Aizen Dark"
    @State private var selectedTab = "chat"
    @State private var lastOpenedApp: DetectedApp?
    @StateObject private var gitRepositoryService: GitRepositoryService
    @StateObject private var xcodeBuildManager = XcodeBuildManager()
    @StateObject private var tabConfig = TabConfigurationManager.shared
    @StateObject private var minimizedWindowsManager = MinimizedWindowsManager()
    @State private var gitIndexWatchToken: UUID?
    @State private var gitIndexWatchPath: String?
    @State private var fileSearchWindowController: FileSearchWindowController?
    @State private var fileToOpenFromSearch: String?
    @State private var cachedTerminalBackgroundColor: Color?
    @State private var showAgentSelectionSheet = false

    // Tab 页容器大小，用于悬浮窗口的自动大小计算
    @State private var tabContainerSize: CGSize = .zero

    // 浮窗状态 - 提升到 WorktreeDetailView 层级，使其在所有标签页都可见
    @AppStorage("showFloatingPanels") private var showFloatingPanels = false
    @State private var showTerminalPanel = false
    @State private var showFilesPanel = false
    @State private var showBrowserPanel = false
    @State private var showTaskPanel = false
    @State private var showGitPanel = false
    @State private var selectedFloatingButton: Int?
    // 最小化窗口的 ID 列表
    @State private var minimizedPanelIds: Set<String> = []
    // 当前激活的悬浮面板（用于判断点击图标时的行为）
    @State private var activeFloatingPanel: FloatingPanelType? = nil

    init(worktree: Worktree, repositoryManager: RepositoryManager, tabStateManager: WorktreeTabStateManager, gitChangesContext: Binding<GitChangesContext?>, onWorktreeDeleted: ((Worktree?) -> Void)? = nil) {
        self.worktree = worktree
        self.repositoryManager = repositoryManager
        self.tabStateManager = tabStateManager
        _gitChangesContext = gitChangesContext
        self.onWorktreeDeleted = onWorktreeDeleted
        _viewModel = StateObject(wrappedValue: WorktreeViewModel(worktree: worktree, repositoryManager: repositoryManager))
        _gitRepositoryService = StateObject(wrappedValue: GitRepositoryService(worktreePath: worktree.path ?? ""))
    }

    // MARK: - Helper Managers

    private var gitOperations: WorktreeGitOperations {
        WorktreeGitOperations(
            gitRepositoryService: gitRepositoryService,
            repositoryManager: repositoryManager,
            worktree: worktree,
            logger: logger
        )
    }

    private var sessionManager: WorktreeSessionManager {
        WorktreeSessionManager(
            worktree: worktree,
            viewModel: viewModel,
            logger: logger
        )
    }

    var browserSessions: [BrowserSession] {
        let sessions = (worktree.browserSessions as? Set<BrowserSession>) ?? []
        return sessions.sorted { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }
    }

    var hasActiveSessions: Bool {
        (selectedTab == "chat" && !sessionManager.chatSessions.isEmpty) ||
        (selectedTab == "terminal" && !sessionManager.terminalSessions.isEmpty) ||
        (selectedTab == "browser" && !browserSessions.isEmpty)
    }

    var shouldShowSessionToolbar: Bool {
        selectedTab != "files" && selectedTab != "browser" && hasActiveSessions
    }

    var hasGitChanges: Bool {
        gitRepositoryService.currentStatus.additions > 0 ||
        gitRepositoryService.currentStatus.deletions > 0 ||
        gitRepositoryService.currentStatus.untrackedFiles.count > 0
    }

    private func getTerminalBackgroundColor() -> Color? {
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let themesPath = (resourcePath as NSString).appendingPathComponent("ghostty/themes")
        let themeFile = (themesPath as NSString).appendingPathComponent(terminalThemeName)

        guard let content = try? String(contentsOfFile: themeFile, encoding: .utf8) else {
            return nil
        }

        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("background") {
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let colorHex = parts[1].trimmingCharacters(in: .whitespaces)
                    return Color(hex: colorHex)
                }
            }
        }

        return nil
    }

    @ViewBuilder
    var contentView: some View {
        GeometryReader { geometry in
            Group {
                if selectedTab == "chat" {
                    ChatTabView(
                        worktree: worktree,
                        selectedSessionId: $viewModel.selectedChatSessionId
                    )
                } else if selectedTab == "terminal" {
                    TerminalTabView(
                        worktree: worktree,
                        selectedSessionId: $viewModel.selectedTerminalSessionId,
                        repositoryManager: repositoryManager
                    )
                } else if selectedTab == "files" {
                    FileTabView(
                        worktree: worktree,
                        fileToOpenFromSearch: $fileToOpenFromSearch
                    )
                } else if selectedTab == "browser" {
                    BrowserTabView(
                        worktree: worktree,
                        selectedSessionId: $viewModel.selectedBrowserSessionId
                    )
                } else if selectedTab == "task" {
                    TasksTabView(worktree: worktree)
                }
            }
            .onAppear {
                tabContainerSize = geometry.size
            }
            .onChange(of: geometry.size) { newSize in
                tabContainerSize = newSize
            }
        }
    }

    @ToolbarContentBuilder
    var tabPickerToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 4) {
                ForEach(tabConfig.tabOrder) { tab in
                    if isTabVisible(tab.id) {
                        Button {
                            handleTabTap(tabId: tab.id)
                        } label: {
                            ZStack {
                                Image(systemName: tab.icon)

                                // 活动窗口指示器（蓝点）
                                if isTabActive(tab.id) {
                                    Circle()
                                        .fill(.blue)
                                        .frame(width: 5, height: 5)
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                        .labelStyle(.iconOnly)
                        .help(LocalizedStringKey(tab.localizedKey))
                    }
                }

                
            }
        }
    }

    private func handleTabTap(tabId: String) {
        // 点击Tab时打开对应的悬浮窗，允许同时打开多个窗口
        switch tabId {
        case "files":
            showFilesPanel.toggle()
        case "browser":
            showBrowserPanel.toggle()
        case "task":
            showTaskPanel.toggle()
        case "git":
            showGitPanel.toggle()
        default:
            // chat 和 terminal 保持原有的切换Tab行为
            selectedTab = tabId
        }
    }

    private func isTabVisible(_ tabId: String) -> Bool {
        switch tabId {
        case "chat": return showChatTab
        case "terminal": return showTerminalTab
        case "files": return showFilesTab
        case "browser": return showBrowserTab
        case "task": return showTaskTab
        case "git": return showGitTab
        default: return false
        }
    }

    private func isTabActive(_ tabId: String) -> Bool {
        // 判断Tab是否有活动的悬浮窗口（显示中或最小化中）
        switch tabId {
        case "files":
            return showFilesPanel || isPanelMinimized(panelType: .files)
        case "browser":
            return showBrowserPanel || isPanelMinimized(panelType: .browser)
        case "task":
            return showTaskPanel || isPanelMinimized(panelType: .task)
        case "git":
            return showGitPanel || isPanelMinimized(panelType: .git)
        default:
            return false
        }
    }

    @ToolbarContentBuilder
    var sessionToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            SessionTabsScrollView(
                selectedTab: selectedTab,
                chatSessions: sessionManager.chatSessions,
                terminalSessions: sessionManager.terminalSessions,
                selectedChatSessionId: $viewModel.selectedChatSessionId,
                selectedTerminalSessionId: $viewModel.selectedTerminalSessionId,
                onCloseChatSession: sessionManager.closeChatSession,
                onCloseTerminalSession: sessionManager.closeTerminalSession,
                onCreateChatSession: {
                    showAgentSelectionSheet = true
                },
                onCreateTerminalSession: sessionManager.createNewTerminalSession,
                onCreateChatWithAgent: { agentId in
                    sessionManager.createNewChatSession(withAgent: agentId)
                },
                onCreateTerminalWithPreset: { preset in
                    sessionManager.createNewTerminalSession(withPreset: preset)
                }
            )
        }
    }

    @ToolbarContentBuilder
    var leadingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 12) {
                zenModeButton
            }
        }
    }
    
    @ViewBuilder
    private var zenModeButton: some View {
        let button = Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                zenModeEnabled.toggle()
            }
        }) {
            Label("Zen Mode", systemImage: zenModeEnabled ? "pip.enter" : "pip.exit")
        }
        .labelStyle(.iconOnly)
        .help(zenModeEnabled ? "Show Worktree List" : "Hide Worktree List (Zen Mode)")
        
        if #available(macOS 14.0, *) {
            button.symbolEffect(.bounce, value: zenModeEnabled)
        } else {
            button
        }
    }

    @ToolbarContentBuilder
    var trailingToolbarItems: some ToolbarContent {
        // Xcode build button (only if fully loaded and ready)
        if showXcodeBuild, xcodeBuildManager.isReady {
            ToolbarItem {
                XcodeBuildButton(buildManager: xcodeBuildManager, worktree: worktree)
            }

            if #available(macOS 26.0, *) {
                ToolbarSpacer(.fixed)
            } else {
                ToolbarItem(placement: .automatic) {
                    Spacer().frame(width: 12).fixedSize()
                }
            }
        }

        if showOpenInApp {
            ToolbarItem {
                OpenInAppButton(
                    lastOpenedApp: lastOpenedApp,
                    appDetector: appDetector,
                    onOpenInLastApp: openInLastApp,
                    onOpenInDetectedApp: openInDetectedApp
                )
            }
        }

        if #available(macOS 26.0, *) {
            ToolbarSpacer(.fixed)
        } else {
            ToolbarItem(placement: .automatic) {
                Spacer().frame(width: 12).fixedSize()
            }
        }

        if showGitStatus {
            ToolbarItem(placement: .automatic) {
                if hasGitChanges {
                    gitStatusView
                }
            }
        }

        // Hidden Git sidebar button
        // ToolbarItem(placement: .automatic) {
        //     gitSidebarButton
        // }
    }
    
    @ViewBuilder
    private var gitStatusView: some View {
        let view = GitStatusView(
            additions: gitRepositoryService.currentStatus.additions,
            deletions: gitRepositoryService.currentStatus.deletions,
            untrackedFiles: gitRepositoryService.currentStatus.untrackedFiles.count
        )
        
        if #available(macOS 14.0, *) {
            view.symbolEffect(.pulse, options: .repeating, value: hasGitChanges)
        } else {
            view
        }
    }
    
    private var showingGitChanges: Bool {
        gitChangesContext != nil
    }

    private var gitStatusIcon: String {
        let status = gitRepositoryService.currentStatus
        if !status.conflictedFiles.isEmpty {
            // Has conflicts - warning state
            return "arrow.triangle.branch"
        } else if hasGitChanges {
            // Has uncommitted changes
            return "arrow.triangle.branch"
        } else {
            // Clean state - all committed
            return "arrow.triangle.branch"
        }
    }

    private var gitStatusHelp: String {
        let status = gitRepositoryService.currentStatus
        if !status.conflictedFiles.isEmpty {
            return "Git Changes - \(status.conflictedFiles.count) conflict(s)"
        } else if hasGitChanges {
            return "Git Changes - uncommitted changes"
        } else {
            return "Git Changes - clean"
        }
    }

    private var gitStatusColor: Color {
        let status = gitRepositoryService.currentStatus
        if !status.conflictedFiles.isEmpty {
            return .red
        } else if hasGitChanges {
            return .orange
        } else {
            return .green
        }
    }

    @ViewBuilder
    private var gitSidebarButton: some View {
        let button = Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                if gitChangesContext == nil {
                    gitChangesContext = GitChangesContext(worktree: worktree, service: gitRepositoryService)
                } else {
                    gitChangesContext = nil
                }
            }
        }) {
            Label("Git Changes", systemImage: gitStatusIcon)
                .symbolRenderingMode(.palette)
                .foregroundStyle(gitStatusColor, .primary, .clear)
        }
        .labelStyle(.iconOnly)
        .help(gitStatusHelp)

        if #available(macOS 14.0, *) {
            button.symbolEffect(.bounce, value: showingGitChanges)
        } else {
            button
        }
    }

    private func validateSelectedTab() {
        let visibleTabs = tabConfig.tabOrder.filter { isTabVisible($0.id) }
        if !visibleTabs.contains(where: { $0.id == selectedTab }) {
            selectedTab = visibleTabs.first?.id ?? "files"
        }
    }

    private func openFile(_ filePath: String) {
        // Remember the file path so the files panel can open it
        fileToOpenFromSearch = filePath

        // Show Files floating panel instead of switching to files tab
        showFilesPanel = true
        showBrowserPanel = false
        showTaskPanel = false
        showGitPanel = false
    }

    private func showFileSearch() {
        // Toggle behavior: close if already visible
        if let existing = fileSearchWindowController, existing.window?.isVisible == true {
            existing.closeWindow()
            fileSearchWindowController = nil
            return
        }

        guard let worktreePath = worktree.path else { return }

        let windowController = FileSearchWindowController(
            worktreePath: worktreePath,
            onFileSelected: { filePath in
                self.openFile(filePath)
            }
        )

        fileSearchWindowController = windowController
        windowController.showWindow(nil)
    }

    @ViewBuilder
    private var mainContentWithSidebars: some View {
        ZStack(alignment: .topLeading) {
            // 主内容区域
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(selectedTab == "terminal" ? cachedTerminalBackgroundColor : nil)

            // Permission banner for pending requests in other sessions
            PermissionBannerView(
                currentChatSessionId: viewModel.selectedChatSessionId,
                onNavigate: { sessionId in
                    navigateToChatSession(sessionId)
                }
            )

            // 左侧悬浮按钮栏
            if showFloatingPanels {
                VStack {
                    floatingButtonBar
                        .padding(20)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(200)  // 确保悬浮按钮始终显示在最上层
            }

            // 浮窗 - 在所有标签页都显示
            // Files浮窗
            if showFilesPanel {
                FloatingPanelView(
                    title: "Files",
                    icon: "folder",
                    windowId: "floating-files-\(worktree.id?.uuidString ?? "")",
                    isPresented: $showFilesPanel,
                    onMinimize: {
                        minimizePanel(panelType: .files)
                    },
                    onActivate: {
                        activeFloatingPanel = .files
                    },
                    tabContainerSize: tabContainerSize
                ) {
                    FileTabView(
                        worktree: worktree,
                        fileToOpenFromSearch: $fileToOpenFromSearch
                    )
                }
                .zIndex(activeFloatingPanel == .files ? 150 : 100)
            }

            // Browser浮窗
            if showBrowserPanel {
                FloatingPanelView(
                    title: "Browser",
                    icon: "globe",
                    windowId: "floating-browser-\(worktree.id?.uuidString ?? "")",
                    isPresented: $showBrowserPanel,
                    onMinimize: {
                        minimizePanel(panelType: .browser)
                    },
                    onActivate: {
                        activeFloatingPanel = .browser
                    },
                    tabContainerSize: tabContainerSize
                ) {
                    BrowserTabView(
                        worktree: worktree,
                        selectedSessionId: $viewModel.selectedBrowserSessionId
                    )
                }
                .zIndex(activeFloatingPanel == .browser ? 150 : 100)
            }

            // Tasks浮窗
            if showTaskPanel {
                FloatingPanelView(
                    title: "Tasks",
                    icon: "checklist",
                    windowId: "floating-tasks-\(worktree.id?.uuidString ?? "")",
                    isPresented: $showTaskPanel,
                    onMinimize: {
                        minimizePanel(panelType: .task)
                    },
                    onActivate: {
                        activeFloatingPanel = .task
                    },
                    tabContainerSize: tabContainerSize
                ) {
                    TasksTabView(worktree: worktree)
                }
                .zIndex(activeFloatingPanel == .task ? 150 : 100)
            }

            // Git浮窗
            if showGitPanel {
                FloatingPanelView(
                    title: "Git",
                    icon: "arrow.triangle.branch",
                    windowId: "floating-git-\(worktree.id?.uuidString ?? "")",
                    isPresented: $showGitPanel,
                    onMinimize: {
                        minimizePanel(panelType: .git)
                    },
                    onActivate: {
                        activeFloatingPanel = .git
                    },
                    tabContainerSize: tabContainerSize
                ) {
                    let floatingGitContext = GitChangesContext(worktree: worktree, service: gitRepositoryService)
                    GitPanelWindowContent(
                        context: floatingGitContext,
                        repositoryManager: repositoryManager,
                        selectedTab: .constant(.git),
                        onClose: {
                            showGitPanel = false
                        }
                    )
                }
                .zIndex(activeFloatingPanel == .git ? 150 : 100)
            }

            
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileSearchShortcut)) { _ in
            showFileSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileSearchShortcut)) { _ in
            showFileSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFileInEditor)) { notification in
            if let path = notification.userInfo?["path"] as? String {
                openFile(path)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sendMessageToChat)) { notification in
            handleSendMessageToChat(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToChat)) { notification in
            handleSwitchToChat(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToChatSession)) { notification in
                        handleSwitchToChatSession(notification)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .showFileDiff)) { notification in
                        handleShowFileDiff(notification)
                    }    }

    private func navigateToChatSession(_ sessionId: UUID) {
        // Check if this session belongs to current worktree
        let chatSessions = (worktree.chatSessions as? Set<ChatSession>) ?? []
        if chatSessions.contains(where: { $0.id == sessionId }) {
            // Same worktree - just switch to chat tab and select session
            selectedTab = "chat"
            viewModel.selectedChatSessionId = sessionId
        } else {
            // Different worktree - post navigation notification
            NotificationCenter.default.post(
                name: .navigateToChatSession,
                object: nil,
                userInfo: ["chatSessionId": sessionId]
            )
        }
    }

    private func handleSwitchToChatSession(_ notification: Notification) {
        guard let sessionId = notification.userInfo?["chatSessionId"] as? UUID else {
            return
        }
        // Verify this session belongs to current worktree before switching
        let chatSessions = (worktree.chatSessions as? Set<ChatSession>) ?? []
        if chatSessions.contains(where: { $0.id == sessionId }) {
            selectedTab = "chat"
            viewModel.selectedChatSessionId = sessionId
        }
    }

    private func handleShowFileDiff(_ notification: Notification) {
        guard let filePath = notification.userInfo?["path"] as? String else {
            return
        }

        // Open Git changes sidebar and navigate to the file
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            if gitChangesContext == nil {
                gitChangesContext = GitChangesContext(worktree: worktree, service: gitRepositoryService)
            }

            // Post a notification to select the file in the Git changes view
            // This will be handled by the Git changes view
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(
                    name: .selectFileInGitChanges,
                    object: nil,
                    userInfo: ["path": filePath]
                )
            }
        }
    }

    private func handleSendMessageToChat(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let sessionId = userInfo["sessionId"] as? UUID else {
            return
        }

        // Get attachment from notification (new way) or create from message (legacy way)
        let attachment: ChatAttachment
        if let existingAttachment = userInfo["attachment"] as? ChatAttachment {
            attachment = existingAttachment
        } else if let message = userInfo["message"] as? String {
            attachment = .reviewComments(message)
        } else {
            return
        }

        // Store attachment (user can add context before sending)
        ChatSessionManager.shared.setPendingAttachments([attachment], for: sessionId)

        // Switch to chat tab and select the session
        selectedTab = "chat"
        viewModel.selectedChatSessionId = sessionId
    }

    private func handleSwitchToChat(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let sessionId = userInfo["sessionId"] as? UUID else {
            return
        }

        // Switch to chat tab and select the session
        selectedTab = "chat"
        viewModel.selectedChatSessionId = sessionId
    }

    var body: some View {
        NavigationStack {
            navigationContent
                .navigationTitle("")
        }
    }

    @ViewBuilder
    private var contentWithBasicModifiers: some View {
        mainContentWithSidebars
            .toolbarBackground(.hidden, for: .windowToolbar)
            .toast()
            .onAppear {
                validateSelectedTab()
                cachedTerminalBackgroundColor = getTerminalBackgroundColor()
            }
            .onChange(of: terminalThemeName) { _ in
                cachedTerminalBackgroundColor = getTerminalBackgroundColor()
            }
            .toolbar {
                leadingToolbarItems
                
                tabPickerToolbarItem

                if shouldShowSessionToolbar {
                    sessionToolbarItems
                }

                ToolbarItem(placement: .automatic) {
                    Spacer()
                }

                trailingToolbarItems
            }
            .task(id: worktree.id) {
                await setupGitMonitoring()
                xcodeBuildManager.detectProject(at: worktree.path ?? "")
                loadTabState()
                validateSelectedTab()
            }
    }

    @ViewBuilder
    private var navigationContent: some View {
        contentWithBasicModifiers
            .onChange(of: selectedTab) { _ in
                saveTabState()
            }
            .onChange(of: viewModel.selectedChatSessionId) { newValue in
                guard let worktreeId = worktree.id else { return }
                tabStateManager.saveSessionId(newValue, for: "chat", worktreeId: worktreeId)
            }
            .onChange(of: viewModel.selectedTerminalSessionId) { newValue in
                guard let worktreeId = worktree.id else { return }
                tabStateManager.saveSessionId(newValue, for: "terminal", worktreeId: worktreeId)
            }
            .onChange(of: viewModel.selectedBrowserSessionId) { newValue in
                guard let worktreeId = worktree.id else { return }
                tabStateManager.saveSessionId(newValue, for: "browser", worktreeId: worktreeId)
            }
            .onChange(of: viewModel.selectedFileSessionId) { newValue in
                guard let worktreeId = worktree.id else { return }
                tabStateManager.saveSessionId(newValue, for: "files", worktreeId: worktreeId)
            }
            .sheet(isPresented: $showAgentSelectionSheet) {
                AgentSelectionSheet(
                    worktree: worktree,
                    onDismiss: {
                        showAgentSelectionSheet = false
                    },
                    onAgentSelected: { agentId in
                        sessionManager.createNewChatSession(withAgent: agentId)
                        showAgentSelectionSheet = false
                    }
                )
            }
            .onDisappear {
                if let token = gitIndexWatchToken, let path = gitIndexWatchPath {
                    Task {
                        await GitIndexWatchCenter.shared.removeSubscriber(worktreePath: path, id: token)
                    }
                }
                gitIndexWatchToken = nil
                gitIndexWatchPath = nil
            }
    }

    private func loadTabState() {
        guard let worktreeId = worktree.id else { return }

        if tabStateManager.hasStoredState(for: worktreeId) {
            // Restore saved state
            let state = tabStateManager.getState(for: worktreeId)
            selectedTab = state.viewType
            viewModel.selectedChatSessionId = state.chatSessionId
            viewModel.selectedTerminalSessionId = state.terminalSessionId
            viewModel.selectedBrowserSessionId = state.browserSessionId
            viewModel.selectedFileSessionId = state.fileSessionId
        } else {
            // Fresh worktree - use configured default tab
            selectedTab = tabConfig.effectiveDefaultTab(
                showChat: showChatTab,
                showTerminal: showTerminalTab,
                showFiles: showFilesTab,
                showBrowser: showBrowserTab
            )
        }
    }

    private func saveTabState() {
        guard let worktreeId = worktree.id else { return }
        tabStateManager.saveViewType(selectedTab, for: worktreeId)
    }

    private func setupGitMonitoring() async {
        guard let worktreePath = worktree.path else { return }

        // Update service path and reload status
        gitRepositoryService.updateWorktreePath(worktreePath)

        // Dedupe polling per worktree path
        if let token = gitIndexWatchToken, let path = gitIndexWatchPath {
            await GitIndexWatchCenter.shared.removeSubscriber(worktreePath: path, id: token)
            gitIndexWatchToken = nil
            gitIndexWatchPath = nil
        }

        let token = await GitIndexWatchCenter.shared.addSubscriber(worktreePath: worktreePath) { [weak gitRepositoryService] in
            Task { @MainActor in
                gitRepositoryService?.reloadStatus(lightweight: true)
            }
        }
        gitIndexWatchToken = token
        gitIndexWatchPath = worktreePath
    }


    // MARK: - App Actions

    private func openInLastApp() {
        guard let app = lastOpenedApp else {
            if let finder = appDetector.getApps(for: .finder).first {
                openInDetectedApp(finder)
            }
            return
        }
        openInDetectedApp(app)
    }

    private func openInDetectedApp(_ app: DetectedApp) {
        guard let path = worktree.path else { return }
        lastOpenedApp = app
        appDetector.openPath(path, with: app)
    }

    // MARK: - Floating Button Bar

    private var floatingButtonBar: some View {
        let selectedIndex: Int? = {
            // 返回第一个打开的窗口的索引，如果没有窗口打开则返回 nil
            if showFilesPanel { return 0 }
            if showBrowserPanel { return 1 }
            if showTaskPanel { return 2 }
            if showGitPanel { return 3 }
            return nil
        }()

        return FloatingButtonBar(
            buttons: [
                FloatingButton(
                    icon: "folder",
                    title: "Files"
                ) {
                    if isPanelMinimized(panelType: .files) {
                        restorePanel(panelType: .files)
                    } else if showFilesPanel {
                        minimizePanel(panelType: .files)
                    } else {
                        handleFloatingButtonTap(panelType: .files)
                    }
                },
                FloatingButton(
                    icon: "globe",
                    title: "Browser"
                ) {
                    if isPanelMinimized(panelType: .browser) {
                        restorePanel(panelType: .browser)
                    } else if showBrowserPanel {
                        minimizePanel(panelType: .browser)
                    } else {
                        handleFloatingButtonTap(panelType: .browser)
                    }
                },
                FloatingButton(
                    icon: "checklist",
                    title: "Tasks"
                ) {
                    if isPanelMinimized(panelType: .task) {
                        restorePanel(panelType: .task)
                    } else if showTaskPanel {
                        minimizePanel(panelType: .task)
                    } else {
                        handleFloatingButtonTap(panelType: .task)
                    }
                },
                FloatingButton(
                    icon: "arrow.triangle.branch",
                    title: "Git"
                ) {
                    if isPanelMinimized(panelType: .git) {
                        restorePanel(panelType: .git)
                    } else if showGitPanel {
                        minimizePanel(panelType: .git)
                    } else {
                        handleFloatingButtonTap(panelType: .git)
                    }
                }
            ],
            selectedIndex: Binding<Int?>(
                get: { selectedIndex },
                set: { _ in }
            ),
            activeStates: Binding<[Int]>(
                get: {
                    var active: [Int] = []
                    // 显示的窗口或最小化的窗口都标记为活动状态
                    if showFilesPanel || isPanelMinimized(panelType: .files) { active.append(0) }
                    if showBrowserPanel || isPanelMinimized(panelType: .browser) { active.append(1) }
                    if showTaskPanel || isPanelMinimized(panelType: .task) { active.append(2) }
                    if showGitPanel || isPanelMinimized(panelType: .git) { active.append(3) }
                    return active
                },
                set: { _ in }
            ),
            minimizedStates: Binding<[Int]>(
                get: {
                    var minimized: [Int] = []
                    if isPanelMinimized(panelType: .files) { minimized.append(0) }
                    if isPanelMinimized(panelType: .browser) { minimized.append(1) }
                    if isPanelMinimized(panelType: .task) { minimized.append(2) }
                    if isPanelMinimized(panelType: .git) { minimized.append(3) }
                    return minimized
                },
                set: { _ in }
            )
        )
    }

    private enum FloatingPanelType {
        case files
        case browser
        case task
        case git
    }

    private func handleFloatingButtonTap(panelType: FloatingPanelType) {
        // 检查当前面板是否已打开
        let isPanelOpen: Bool
        switch panelType {
        case .files: isPanelOpen = showFilesPanel
        case .browser: isPanelOpen = showBrowserPanel
        case .task: isPanelOpen = showTaskPanel
        case .git: isPanelOpen = showGitPanel
        }

        // 如果面板已打开
        if isPanelOpen {
            // 如果面板不是当前激活的面板，则激活它（前置）
            if activeFloatingPanel != panelType {
                activeFloatingPanel = panelType
            } else {
                // 如果面板已经是当前激活的面板，则隐藏它
                withAnimation {
                    switch panelType {
                    case .files: showFilesPanel = false
                    case .browser: showBrowserPanel = false
                    case .task: showTaskPanel = false
                    case .git: showGitPanel = false
                    }
                    activeFloatingPanel = nil
                }
            }
        } else {
            // 如果面板未打开，则打开它并激活
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
    }

    private func minimizePanel(panelType: FloatingPanelType) {
        let panelId: String
        switch panelType {
        case .files: panelId = "floating-files-\(worktree.id?.uuidString ?? "")"
        case .browser: panelId = "floating-browser-\(worktree.id?.uuidString ?? "")"
        case .task: panelId = "floating-tasks-\(worktree.id?.uuidString ?? "")"
        case .git: panelId = "floating-git-\(worktree.id?.uuidString ?? "")"
        }
        minimizedPanelIds.insert(panelId)

        // 隐藏面板
        withAnimation {
            switch panelType {
            case .files: showFilesPanel = false
            case .browser: showBrowserPanel = false
            case .task: showTaskPanel = false
            case .git: showGitPanel = false
            }
        }
    }

    private func restorePanel(panelType: FloatingPanelType) {
        let panelId: String
        switch panelType {
        case .files: panelId = "floating-files-\(worktree.id?.uuidString ?? "")"
        case .browser: panelId = "floating-browser-\(worktree.id?.uuidString ?? "")"
        case .task: panelId = "floating-tasks-\(worktree.id?.uuidString ?? "")"
        case .git: panelId = "floating-git-\(worktree.id?.uuidString ?? "")"
        }
        minimizedPanelIds.remove(panelId)

        // 显示面板并激活
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

    private func isPanelMinimized(panelType: FloatingPanelType) -> Bool {
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

#Preview {
    WorktreeDetailView(
        worktree: Worktree(),
        repositoryManager: RepositoryManager(viewContext: PersistenceController.preview.container.viewContext),
        tabStateManager: WorktreeTabStateManager(),
        gitChangesContext: .constant(nil)
    )
}
