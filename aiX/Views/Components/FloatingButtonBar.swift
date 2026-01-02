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

    var body: some View {
        VStack(spacing: 12) {
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.blue.opacity(0.2))
                        .frame(width: buttonSize, height: buttonSize)
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
