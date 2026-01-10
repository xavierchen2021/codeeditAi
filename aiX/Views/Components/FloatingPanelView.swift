import SwiftUI

struct FloatingPanelView<Content: View>: View {
    let title: String
    let icon: String
    let windowId: String  // 窗口唯一标识符，用于独立存储位置
    @ViewBuilder let content: Content
    @Binding var isPresented: Bool
    var onMinimize: (() -> Void)? = nil  // 最小化回调

    @State private var currentPosition: CGPoint = .zero
    @State private var dragOffset = CGSize.zero

    let minWidth: CGFloat
    let idealWidth: CGFloat
    let maxWidth: CGFloat
    let minHeight: CGFloat
    let idealHeight: CGFloat
    let maxHeight: CGFloat

    @State private var currentWidth: CGFloat
    @State private var currentHeight: CGFloat
    @State private var resizingStartSize: CGSize = .zero
    @State private var isResizing = false

    @State private var isMaximized = false
    @State private var preMaximizePosition: CGPoint = .zero
    @State private var preMaximizeSize: CGSize = .zero

    private func defaultPosition(for windowId: String) -> CGPoint {
        // 根据窗口ID生成不同的默认位置，避免重叠
        let baseX: CGFloat = 120
        let baseY: CGFloat = 200
        let offsetX: CGFloat = CGFloat(abs(windowId.hashValue % 3)) * 40
        let offsetY: CGFloat = CGFloat(abs(windowId.hashValue % 3)) * 40
        return CGPoint(x: baseX + offsetX, y: baseY + offsetY)
    }

    private func sizeStorageKey() -> String { "floatingPanelSize.\(windowId)" }
    private func positionStorageKey() -> String { "floatingPanelPosition.\(windowId)" }

    private func clampWidth(_ w: CGFloat) -> CGFloat {
        let maxW = maxWidth.isFinite ? maxWidth : CGFloat.greatestFiniteMagnitude
        return min(max(w, minWidth), maxW)
    }

    private func clampHeight(_ h: CGFloat) -> CGFloat {
        let maxH = maxHeight.isFinite ? maxHeight : CGFloat.greatestFiniteMagnitude
        return min(max(h, minHeight), maxH)
    }

    private func saveSize() {
        UserDefaults.standard.set([Double(currentWidth), Double(currentHeight)], forKey: sizeStorageKey())
    }

    private func loadSavedSize() {
        if let arr = UserDefaults.standard.array(forKey: sizeStorageKey()) as? [Double], arr.count == 2 {
            currentWidth = clampWidth(CGFloat(arr[0]))
            currentHeight = clampHeight(CGFloat(arr[1]))
        }
    }

    private func savePosition() {
        UserDefaults.standard.set([Double(currentPosition.x), Double(currentPosition.y)], forKey: positionStorageKey())
    }

    private func loadSavedPosition() {
        if let arr = UserDefaults.standard.array(forKey: positionStorageKey()) as? [Double], arr.count == 2 {
            currentPosition.x = CGFloat(arr[0])
            currentPosition.y = CGFloat(arr[1])
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                headerView
                    .frame(height: 36)
                    .background(.ultraThinMaterial)

                content
                    .frame(minWidth: minWidth, maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity)
                    .clipped()
            }
            .frame(width: isMaximized ? nil : currentWidth, height: isMaximized ? nil : currentHeight)
            .frame(maxWidth: isMaximized ? .infinity : nil, maxHeight: isMaximized ? .infinity : nil)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: isMaximized ? 0 : 12))
            .shadow(color: .black.opacity(0.3), radius: isMaximized ? 0 : 20, x: 0, y: isMaximized ? 0 : 10)
            .offset(x: isMaximized ? 0 : (currentPosition.x + dragOffset.width), y: isMaximized ? 0 : (currentPosition.y + dragOffset.height))
            .opacity(isPresented ? 1 : 0)
            .scaleEffect(isPresented ? 1 : 0.8)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isPresented)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isMaximized)
            .allowsHitTesting(isPresented)
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        if isPresented && !isMaximized && !isResizing {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        if !isPresented || isMaximized { return }

                        currentPosition.x += value.translation.width
                        currentPosition.y += value.translation.height

                        let screen = NSScreen.main?.visibleFrame ?? .zero
                        currentPosition.x = max(0, min(currentPosition.x, screen.width - currentWidth))
                        currentPosition.y = max(0, min(currentPosition.y, screen.height - currentHeight))

                        dragOffset = .zero
                        savePosition()
                    }
            )
            .onAppear {
                if currentWidth == 0 { currentWidth = idealWidth }
                if currentHeight == 0 { currentHeight = idealHeight }
                loadSavedSize()
                if currentPosition == .zero {
                    currentPosition = defaultPosition(for: windowId)
                    loadSavedPosition()
                }
            }
            .onChange(of: isPresented) { presented in
                if !presented { saveSize() }
            }
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }

            Spacer()

            if let onMinimize = onMinimize {
                Button(action: {
                    onMinimize()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Minimize")
            }

            Button(action: { toggleMaximize() }) {
                Image(systemName: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(isMaximized ? "Restore" : "Maximize")

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPresented = false
                    if isMaximized { isMaximized = false }
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
                isMaximized = false
                currentPosition = preMaximizePosition
                currentWidth = preMaximizeSize.width
                currentHeight = preMaximizeSize.height
            } else {
                preMaximizePosition = currentPosition
                preMaximizeSize = CGSize(width: currentWidth, height: currentHeight)
                isMaximized = true
                currentPosition = .zero
            }
        }
    }
}

extension FloatingPanelView {
    init(title: String, icon: String, windowId: String = UUID().uuidString, isPresented: Binding<Bool>, onMinimize: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.windowId = windowId
        self._isPresented = isPresented
        self.onMinimize = onMinimize
        self.content = content()
        self.minWidth = 400
        self.idealWidth = 600
        self.maxWidth = .infinity
        self.minHeight = 300
        self.idealHeight = 400
        self.maxHeight = .infinity
        self._currentWidth = State(initialValue: 600)
        self._currentHeight = State(initialValue: 400)
    }

    init(title: String, icon: String, windowId: String = UUID().uuidString, isPresented: Binding<Bool>, minWidth: CGFloat, idealWidth: CGFloat, maxWidth: CGFloat, minHeight: CGFloat, idealHeight: CGFloat, maxHeight: CGFloat, onMinimize: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.windowId = windowId
        self._isPresented = isPresented
        self.onMinimize = onMinimize
        self.content = content()
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.maxWidth = maxWidth
        self.minHeight = minHeight
        self.idealHeight = idealHeight
        self.maxHeight = maxHeight
        self._currentWidth = State(initialValue: idealWidth)
        self._currentHeight = State(initialValue: idealHeight)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        FloatingPanelView(title: "Terminal", icon: "terminal", isPresented: .constant(true)) {
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