//
//  MinimizedWindowsBar.swift
//  aizen
//
//  Bar at the bottom of the screen showing minimized floating panels
//

import SwiftUI
import Combine

struct MinimizedWindowItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let icon: String
    let onRestore: () -> Void
    let onClose: () -> Void

    static func == (lhs: MinimizedWindowItem, rhs: MinimizedWindowItem) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title
    }
}

class MinimizedWindowsManager: ObservableObject {
    @Published var minimizedWindows: [MinimizedWindowItem] = []

    func add(title: String, icon: String, onRestore: @escaping () -> Void, onClose: @escaping () -> Void) {
        let item = MinimizedWindowItem(title: title, icon: icon, onRestore: onRestore, onClose: onClose)
        minimizedWindows.append(item)
    }

    func remove(id: UUID) {
        minimizedWindows.removeAll { $0.id == id }
    }

    func removeAll() {
        minimizedWindows.removeAll()
    }

    func restore(id: UUID) {
        if let item = minimizedWindows.first(where: { $0.id == id }) {
            item.onRestore()
            remove(id: id)
        }
    }

    func close(id: UUID) {
        if let item = minimizedWindows.first(where: { $0.id == id }) {
            item.onClose()
            remove(id: id)
        }
    }
}

struct MinimizedWindowsBar: View {
    @ObservedObject var manager: MinimizedWindowsManager

    var body: some View {
        if !manager.minimizedWindows.isEmpty {
            VStack(spacing: 0) {
                Divider()

                HStack(spacing: 8) {
                    ForEach(manager.minimizedWindows) { item in
                        minimizedWindowItem(item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
            .padding(.bottom, 8)  // 添加底部边距，避免遮挡页面底部内容
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: manager.minimizedWindows.count)
        }
    }

    @ViewBuilder
    private func minimizedWindowItem(_ item: MinimizedWindowItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: {
                manager.restore(id: item.id)
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Restore")

            Button(action: {
                manager.close(id: item.id)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        VStack {
            Spacer()

            MinimizedWindowsBar(manager: MinimizedWindowsManager())
        }
    }
}