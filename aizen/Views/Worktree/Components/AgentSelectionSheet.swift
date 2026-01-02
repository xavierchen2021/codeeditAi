//
//  AgentSelectionSheet.swift
//  aizen
//
//  Sheet for selecting agent for new chat
//

import SwiftUI

struct AgentSelectionSheet: View {
    let worktree: Worktree
    let onDismiss: () -> Void
    let onAgentSelected: (String) -> Void

    @State private var selectedAgent: String?

    private var availableAgents: [AgentMetadata] {
        AgentRegistry.shared.getEnabledAgents()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340, height: 400)
    }

    private var header: some View {
        HStack {
            Text("New Chat")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(availableAgents, id: \.id) { agent in
                    agentRow(agent)
                }
            }
            .padding(16)
        }
    }

    private func agentRow(_ agent: AgentMetadata) -> some View {
        let isSelected = selectedAgent == agent.id

        return Button {
            selectedAgent = agent.id
        } label: {
            HStack(spacing: 10) {
                AgentIconView(agent: agent.id, size: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)

                    Text("Start new conversation")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(10)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                onDismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Button("Create") {
                if let agentId = selectedAgent {
                    onAgentSelected(agentId)
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(selectedAgent == nil)
        }
        .padding(16)
    }
}
