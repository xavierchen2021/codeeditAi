//
//  FloatingButtonBar.swift
//  aizen
//
//  Created by Aizen AI on 01.01.26.
//

import SwiftUI

/// 悬浮按钮栏，包含多个悬浮按钮
struct FloatingButtonBar: View {
    let buttons: [FloatingButton]
    @Binding var selectedIndex: Int?
    @Binding var activeStates: [Int]  // 活动窗口的索引列表
    @Binding var minimizedStates: [Int]  // 最小化窗口的索引列表

    @State private var currentPosition: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var barSize: CGSize = .zero

    private func storageKey() -> String { "floatingButtonBarPosition" }

    private func savePosition() {
        UserDefaults.standard.set([Double(currentPosition.x), Double(currentPosition.y)], forKey: storageKey())
    }

    private func loadPosition() {
        if let arr = UserDefaults.standard.array(forKey: storageKey()) as? [Double], arr.count == 2 {
            currentPosition.x = CGFloat(arr[0])
            currentPosition.y = CGFloat(arr[1])
        }
    }

    private func getDefaultPosition() -> CGPoint {
        guard let screen = NSScreen.main?.visibleFrame else {
            return CGPoint(x: 20, y: 20)
        }
        // 左侧中间位置
        return CGPoint(x: 20, y: screen.height / 2)
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(buttons.enumerated()), id: \.offset) { index, button in
                FloatingBarButton(
                    icon: button.icon,
                    title: button.title,
                    isSelected: selectedIndex == index,
                    isActive: activeStates.contains(index),
                    isMinimized: minimizedStates.contains(index),
                    action: {
                        selectedIndex = index
                        button.action()
                    }
                )
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    currentPosition.x += value.translation.width
                    currentPosition.y += value.translation.height

                    let screen = NSScreen.main?.visibleFrame ?? .zero
                    // 估算悬浮栏大小：按钮宽度44 + padding 16 * 3 = 68
                    let estimatedWidth: CGFloat = 68
                    let estimatedHeight: CGFloat = CGFloat(buttons.count) * 56 + 16

                    let maxX = max(0, screen.width - estimatedWidth)
                    let maxY = max(0, screen.height - estimatedHeight)

                    currentPosition.x = max(0, min(currentPosition.x, maxX))
                    currentPosition.y = max(0, min(currentPosition.y, maxY))

                    dragOffset = .zero
                    savePosition()
                }
        )
        .offset(x: currentPosition.x + dragOffset.width, y: currentPosition.y + dragOffset.height)
        .onAppear {
            if currentPosition == .zero { currentPosition = getDefaultPosition() }
            loadPosition()
        }
    }
}

/// 单个悬浮按钮
struct FloatingBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let isActive: Bool  // 窗口是否处于活动状态（打开）
    let isMinimized: Bool  // 窗口是否被最小化
    let action: () -> Void

    private let buttonSize: CGFloat = 44

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.blue.opacity(0.2))
                        .frame(width: buttonSize, height: buttonSize)
                }

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? .blue : (isActive ? .primary : .secondary))
                    .frame(width: buttonSize, height: buttonSize)

                // 活动窗口指示器（小圆点）- 最小化时显示蓝色点
                if isActive || isMinimized {
                    Circle()
                        .fill(.blue)
                        .frame(width: 6, height: 6)
                        .offset(x: buttonSize / 2 - 8, y: -buttonSize / 2 + 8)
                }
            }
        }
        .buttonStyle(.plain)
        .help(isMinimized ? "\(title) (点击恢复)" : (isActive ? "\(title) (点击最小化)" : "\(title) (点击展开)"))
    }
}

/// 悬浮按钮的数据模型
struct FloatingButton {
    let icon: String
    let title: String
    let action: () -> Void
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        FloatingButtonBar(
            buttons: [
                FloatingButton(icon: "terminal", title: "Terminal") {},
                FloatingButton(icon: "folder", title: "Files") {},
                FloatingButton(icon: "globe", title: "Browser") {}
            ],
            selectedIndex: .constant(nil),
            activeStates: .constant([1, 2]),
            minimizedStates: .constant([])
        )
    }
}