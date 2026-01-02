//
//  FloatingPanelView.swift
//  aizen
//
//  Created by Aizen AI on 01.01.26.
//

import SwiftUI

/// 浮窗视图，支持拖拽、最大化和关闭
struct FloatingPanelView<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    @Binding var isPresented: Bool

    // 拖拽状态
    @State private var offset = CGSize.zero
    @State private var currentPosition: CGPoint = .zero
    @State private var dragOffset = CGSize.zero

    // 尺寸状态
    let minWidth: CGFloat
    let idealWidth: CGFloat
    let maxWidth: CGFloat
    let minHeight: CGFloat
    let idealHeight: CGFloat
    let maxHeight: CGFloat

    // 最大化状态
    @State private var isMaximized = false
    @State private var preMaximizePosition: CGPoint = .zero
    @State private var preMaximizeSize: CGSize = .zero

    // 默认位置（屏幕左中位置）
    private let defaultPosition = CGPoint(x: 120, y: 200)

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 浮窗主体（使用opacity控制显示/隐藏）
            VStack(spacing: 0) {
                // 标题栏
                headerView
                    .frame(height: 36)
                    .background(.ultraThinMaterial)

                // 内容区域
                content
                    .frame(
                        minWidth: isMaximized ? 0 : minWidth,
                        idealWidth: isMaximized ? .infinity : idealWidth,
                        maxWidth: isMaximized ? .infinity : maxWidth,
                        minHeight: isMaximized ? 0 : minHeight,
                        idealHeight: isMaximized ? .infinity : idealHeight,
                        maxHeight: isMaximized ? .infinity : maxHeight
                    )
                    .clipped()
            }
            .frame(
                width: isMaximized ? nil : idealWidth,
                height: isMaximized ? nil : idealHeight
            )
            .frame(maxWidth: isMaximized ? .infinity : nil, maxHeight: isMaximized ? .infinity : nil)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: isMaximized ? 0 : 12))
            .shadow(color: .black.opacity(0.3), radius: isMaximized ? 0 : 20, x: 0, y: isMaximized ? 0 : 10)
            .offset(
                x: isMaximized ? 0 : (currentPosition.x + dragOffset.width),
                y: isMaximized ? 0 : (currentPosition.y + dragOffset.height)
            )
            .opacity(isPresented ?1 : 0)
            .scaleEffect(isPresented ?1 : 0.8)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isPresented)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isMaximized)
            .allowsHitTesting(isPresented)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if isPresented && !isMaximized {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        if !isPresented || isMaximized { return }

                        // 更新位置
                        currentPosition.x += value.translation.width
                        currentPosition.y += value.translation.height

                        // 限制在屏幕范围内（简单限制）
                        let screen = NSScreen.main?.visibleFrame ?? .zero
                        currentPosition.x = max(0, min(currentPosition.x, screen.width - idealWidth))
                        currentPosition.y = max(0, min(currentPosition.y, screen.height - idealHeight))

                        dragOffset = .zero
                    }
            )
            .onAppear {
                if currentPosition == .zero {
                    currentPosition = defaultPosition
                }
            }
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 8) {
            // 图标和标题
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }

            Spacer()

            // 最大化/还原按钮
            Button(action: {
                toggleMaximize()
            }) {
                Image(systemName: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(isMaximized ? "Restore" : "Maximize")

            // 关闭按钮
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPresented = false
                    // 关闭时还原最大化状态
                    if isMaximized {
                        isMaximized = false
                    }
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }

    private func toggleMaximize() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if isMaximized {
                // 还原
                isMaximized = false
                currentPosition = preMaximizePosition
            } else {
                // 最大化
                preMaximizePosition = currentPosition
                isMaximized = true
            }
        }
    }
}

// MARK: - Convenience Initializers

extension FloatingPanelView {
    /// 使用默认尺寸初始化
    init(
        title: String,
        icon: String,
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self._isPresented = isPresented
        self.content = content()
        self.minWidth = 400
        self.idealWidth = 600
        self.maxWidth = .infinity
        self.minHeight = 300
        self.idealHeight = 400
        self.maxHeight = .infinity
    }

    /// 自定义尺寸初始化
    init(
        title: String,
        icon: String,
        isPresented: Binding<Bool>,
        minWidth: CGFloat,
        idealWidth: CGFloat,
        maxWidth: CGFloat,
        minHeight: CGFloat,
        idealHeight: CGFloat,
        maxHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self._isPresented = isPresented
        self.content = content()
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.maxWidth = maxWidth
        self.minHeight = minHeight
        self.idealHeight = idealHeight
        self.maxHeight = maxHeight
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        FloatingPanelView(
            title: "Terminal",
            icon: "terminal",
            isPresented: .constant(true)
        ) {
            VStack {
                Text("Terminal Content")
                    .font(.title)
                Text("This is a preview of floating panel with maximize")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
