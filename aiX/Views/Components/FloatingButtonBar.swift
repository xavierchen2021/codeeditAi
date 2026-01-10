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

    var body: some View {
        let content = VStack(spacing: 12) {
            ForEach(Array(buttons.enumerated()), id: \.offset) { index, button in
                FloatingBarButton(
                    icon: button.icon,
                    title: button.title,
                    isSelected: selectedIndex == index,
                    action: {
                        selectedIndex = index
                        button.action()
                    }
                )
            }
        }
        .padding(8)
        .background(glassBackground())
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

        return GeometryReader { proxy in
            Color.clear.onAppear {
                barSize = proxy.size
                if currentPosition == .zero { currentPosition = CGPoint(x: 20, y: 20) }
                loadPosition()
            }
            .overlay(
                content
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                currentPosition.x += value.translation.width
                                currentPosition.y += value.translation.height

                                let screen = NSScreen.main?.visibleFrame ?? .zero
                                let maxX = max(0, screen.width - barSize.width - 40)
                                let maxY = max(0, screen.height - barSize.height - 40)
                                currentPosition.x = max(0, min(currentPosition.x, maxX))
                                currentPosition.y = max(0, min(currentPosition.y, maxY))

                                dragOffset = .zero
                                savePosition()
                            }
                    )
                    .offset(x: currentPosition.x + dragOffset.width, y: currentPosition.y + dragOffset.height)
            )
        }
        .frame(width: barSize.width > 0 ? barSize.width : nil, height: barSize.height > 0 ? barSize.height : nil)
    }
}

/// 单个悬浮按钮
struct FloatingBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    private let buttonSize: CGFloat = 44

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    selectedButtonBackground
                }

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: buttonSize, height: buttonSize)
            }
        }
        .buttonStyle(.plain)
        .help(title)
    }

    @ViewBuilder
    private var selectedButtonBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.clear)
                .glassEffect(.regular.tint(.accentColor), in: RoundedRectangle(cornerRadius: 10))
                .frame(width: buttonSize, height: buttonSize)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.blue.opacity(0.2))
                .frame(width: buttonSize, height: buttonSize)
        }
    }
}

// MARK: - FloatingButtonBar Helpers

extension FloatingButtonBar {
    @ViewBuilder
    private func glassBackground() -> some View {
        if #available(macOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: 12)
            shape
                .fill(.clear)
                .glassEffect(.regular, in: shape)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
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
            selectedIndex: .constant(nil)
        )
    }
}
