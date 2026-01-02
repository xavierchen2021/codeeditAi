//
//  ChatTabView.swift
//  aizen
//
//  Chat tab management and empty state
//

import SwiftUI
import CoreData
import os.log

struct ChatTabView: View {
    let worktree: Worktree
    @Binding var selectedSessionId: UUID?

    @Environment(\.managedObjectContext) private var viewContext
    private let sessionManager = ChatSessionManager.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.aizen", category: "ChatTabView")
    @State private var enabledAgents: [AgentMetadata] = []
    @State private var cachedSessionIds: [UUID] = []
    private let maxCachedSessions = 10

    // 浮窗状态
    @State private var showTerminalPanel = false
    @State private var showFilesPanel = false
    @State private var showBrowserPanel = false
    @State private var selectedFloatingButton: Int?

    // 浮窗内部的会话ID
    @State private var terminalSessionId: UUID?
    @State private var browserSessionId: UUID?

    @FetchRequest private var sessions: FetchedResults<ChatSession>

    init(worktree: Worktree, selectedSessionId: Binding<UUID?>) {
        self.worktree = worktree
        self._selectedSessionId = selectedSessionId

        // Handle deleted worktree gracefully - use impossible predicate to return empty results
        let predicate: NSPredicate
        if let worktreeId = worktree.id {
            predicate = NSPredicate(format: "worktree.id == %@", worktreeId as CVarArg)
        } else {
            predicate = NSPredicate(value: false)
        }

        self._sessions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \ChatSession.createdAt, ascending: true)],
            predicate: predicate,
            animation: nil
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 主内容区域
            if sessions.isEmpty {
                chatEmptyState
            } else {
                ForEach(cachedSessions) { session in
                    let isSelected = selectedSessionId == session.id
                    ChatSessionView(
                        worktree: worktree,
                        session: session,
                        sessionManager: sessionManager,
                        viewContext: viewContext
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(isSelected ? 1 : 0)
                    .allowsHitTesting(isSelected)
                    .zIndex(isSelected ? 1 : 0)
                }
            }

            // 左侧悬浮按钮栏 - 始终显示在所有内容之上
            VStack {
                floatingButtonBar
                    .padding(20)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .zIndex(200)  // 确保悬浮按钮始终显示在最上层

            // Terminal浮窗
            if showTerminalPanel {
                FloatingPanelView(
                    title: "Terminal",
                    icon: "terminal",
                    isPresented: $showTerminalPanel
                ) {
                    TerminalTabView(
                        worktree: worktree,
                        selectedSessionId: $terminalSessionId,
                        repositoryManager: RepositoryManager(viewContext: viewContext)
                    )
                }
                .zIndex(100)
            }

            // Files浮窗
            if showFilesPanel {
                FloatingPanelView(
                    title: "Files",
                    icon: "folder",
                    isPresented: $showFilesPanel
                ) {
                    FileTabView(
                        worktree: worktree,
                        fileToOpenFromSearch: .constant(nil)
                    )
                }
                .zIndex(100)
            }

            // Browser浮窗
            if showBrowserPanel {
                FloatingPanelView(
                    title: "Browser",
                    icon: "globe",
                    isPresented: $showBrowserPanel
                ) {
                    BrowserTabView(
                        worktree: worktree,
                        selectedSessionId: $browserSessionId
                    )
                }
                .zIndex(100)
            }
        }
        .onAppear {
            syncSelectionAndCache()
        }
        .onChange(of: selectedSessionId) { _ in
            updateCacheForSelection()
        }
        .onChange(of: sessions.count) { _ in
            syncSelectionAndCache()
        }
    }

    // MARK: - Floating Button Bar

    private var floatingButtonBar: some View {
        let selectedIndex: Int? = {
            if showTerminalPanel { return 0 }
            if showFilesPanel { return 1 }
            if showBrowserPanel { return 2 }
            return nil
        }()

        return FloatingButtonBar(
            buttons: [
                FloatingButton(
                    icon: "terminal",
                    title: "Terminal"
                ) {
                    logger.info("Terminal button clicked, current state: \(showTerminalPanel)")
                    withAnimation {
                        showTerminalPanel.toggle()
                    }
                    logger.info("Terminal panel state after toggle: \(showTerminalPanel)")
                },
                FloatingButton(
                    icon: "folder",
                    title: "Files"
                ) {
                    logger.info("Files button clicked, current state: \(showFilesPanel)")
                    withAnimation {
                        showFilesPanel.toggle()
                    }
                    logger.info("Files panel state after toggle: \(showFilesPanel)")
                },
                FloatingButton(
                    icon: "globe",
                    title: "Browser"
                ) {
                    logger.info("Browser button clicked, current state: \(showBrowserPanel)")
                    withAnimation {
                        showBrowserPanel.toggle()
                    }
                    logger.info("Browser panel state after toggle: \(showBrowserPanel)")
                }
            ],
            selectedIndex: Binding<Int?>(
                get: { selectedIndex },
                set: { _ in }  // setter为空，因为我们在按钮action中直接toggle状态
            )
        )
    }

    private var cachedSessions: [ChatSession] {
        if cachedSessionIds.isEmpty {
            let fallbackId = selectedSessionId ?? sessions.last?.id
            if let fallbackId,
               let fallback = sessions.first(where: { $0.id == fallbackId }) {
                return [fallback]
            }
            if let last = sessions.last {
                return [last]
            }
        }
        return cachedSessionIds.compactMap { id in
            sessions.first(where: { $0.id == id })
        }
    }

    private func syncSelectionAndCache() {
        if selectedSessionId == nil {
            selectedSessionId = sessions.last?.id
        } else if let currentId = selectedSessionId,
                  !sessions.contains(where: { $0.id == currentId }) {
            selectedSessionId = sessions.last?.id
        }
        pruneCache()
        updateCacheForSelection()
    }

    private func updateCacheForSelection() {
        guard let selectedId = selectedSessionId else { return }
        guard sessions.contains(where: { $0.id == selectedId }) else { return }
        cachedSessionIds.removeAll { $0 == selectedId }
        cachedSessionIds.append(selectedId)
        if cachedSessionIds.count > maxCachedSessions {
            cachedSessionIds.removeFirst(cachedSessionIds.count - maxCachedSessions)
        }
    }

    private func pruneCache() {
        let validIds = Set(sessions.compactMap { $0.id })
        cachedSessionIds.removeAll { !validIds.contains($0) }
    }

    private var chatEmptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "message.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    Text("chat.noChatSessions", bundle: .main)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("chat.startConversation", bundle: .main)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            // Responsive layout: row if <=5 agents, column if >5
            if enabledAgents.count <= 5 {
                HStack(spacing: 12) {
                    ForEach(enabledAgents, id: \.id) { agentMetadata in
                        agentButton(for: agentMetadata)
                    }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(100), spacing: 12), count: 3), spacing: 12) {
                    ForEach(enabledAgents, id: \.id) { agentMetadata in
                        agentButton(for: agentMetadata)
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadEnabledAgents()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentMetadataDidChange)) { _ in
            loadEnabledAgents()
        }
    }

    @ViewBuilder
    private func agentButton(for agentMetadata: AgentMetadata) -> some View {
        Button {
            createNewSession(withAgent: agentMetadata.id)
        } label: {
            VStack(spacing: 8) {
                AgentIconView(metadata: agentMetadata, size: 12)
                Text(agentMetadata.name)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(width: 100, height: 80)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.separator.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func loadEnabledAgents() {
        Task {
            enabledAgents = AgentRegistry.shared.getEnabledAgents()
        }
    }

    private func createNewSession(withAgent agent: String) {
        guard let context = worktree.managedObjectContext else { return }

        let session = ChatSession(context: context)
        session.id = UUID()
        session.agentName = agent
        session.createdAt = Date()
        session.worktree = worktree

        // Use agent display name instead of ID
        let displayName = AgentRegistry.shared.getMetadata(for: agent)?.name ?? agent.capitalized
        session.title = displayName

        do {
            try context.save()
            // Update binding immediately (synchronous post-save)
            selectedSessionId = session.id
            logger.info("Created new chat session: \(session.id?.uuidString ?? "unknown")")
        } catch {
            logger.error("Failed to create chat session: \(error.localizedDescription)")
        }
    }
}
