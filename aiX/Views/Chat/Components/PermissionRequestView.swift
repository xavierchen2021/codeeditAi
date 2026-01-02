//
//  PermissionRequestView.swift
//  aizen
//
//  Permission request UI
//

import SwiftUI

struct PermissionRequestView: View {
    @ObservedObject var session: AgentSession
    let request: RequestPermissionRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let toolCall = request.toolCall, let rawInput = toolCall.rawInput?.value as? [String: Any] {
                if let plan = rawInput["plan"] as? String {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("chat.plan.title", bundle: .main)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        PlanContentView(content: plan)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 400, alignment: .leading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                } else if let filePath = rawInput["file_path"] as? String {
                    Text(String(format: String(localized: "chat.permission.write"), URL(fileURLWithPath: filePath).lastPathComponent))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else if let command = rawInput["command"] as? String {
                    Text(String(format: String(localized: "chat.permission.run"), command))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 6) {
                if let options = request.options {
                    ForEach(options, id: \.optionId) { option in
                        Button {
                            session.respondToPermission(optionId: option.optionId)
                        } label: {
                            HStack(spacing: 3) {
                                if option.kind.contains("allow") {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                } else if option.kind.contains("reject") {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                }
                                Text(option.name)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(buttonForeground(for: option))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                buttonBackground(for: option)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func buttonForeground(for option: PermissionOption) -> Color {
        if option.kind.contains("allow") {
            return .white
        } else if option.kind.contains("reject") {
            return .white
        } else {
            return .primary
        }
    }

    private func buttonBackground(for option: PermissionOption) -> Color {
        if option.kind == "allow_always" {
            return .green
        } else if option.kind.contains("allow") {
            return .blue
        } else if option.kind.contains("reject") {
            return .red
        } else {
            return .clear
        }
    }
}
