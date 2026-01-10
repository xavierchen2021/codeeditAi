//
//  GitGraphRenderer.swift
//  aiX
//
//  Renderer for Git subway graph visualization
//

import SwiftUI

/// Renderer for Git subway graph
struct GitGraphRenderer {

    /// Draw the graph using SwiftUI Canvas
    static func drawGraph(
        commits: [GitGraphCommit],
        connections: [GitGraphConnection],
        selectedCommit: GitGraphCommit?,
        onTapCommit: @escaping (GitGraphCommit) -> Void
    ) -> some View {
        ScrollView([.vertical, .horizontal], showsIndicators: false) {
            Canvas { context, size in
                drawSubwayGraph(
                    context: context,
                    commits: commits,
                    connections: connections,
                    selectedCommit: selectedCommit
                )
            } symbols: {
                drawSymbols(context: $0)
            }
            .frame(height: CGFloat(commits.count) * 60 + 100)
            .frame(width: CGFloat(getMaxColumn(commits: commits)) * 60 + 100)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        handleTap(
                            at: value.location3D,
                            commits: commits,
                            onTap: onTapCommit
                        )
                    }
            )
        }
    }

    /// Draw subway graph on canvas
    private static func drawSubwayGraph(
        context: GraphicsContext,
        commits: [GitGraphCommit],
        connections: [GitGraphConnection],
        selectedCommit: GitGraphCommit?
    ) {
        let config = GraphConfig()

        // Draw connections (lines)
        for connection in connections {
            drawConnection(
                context: context,
                connection: connection,
                config: config
            )
        }

        // Draw commit nodes
        for commit in commits {
            drawCommitNode(
                context: context,
                commit: commit,
                selectedCommit: selectedCommit,
                config: config
            )
        }
    }

    /// Draw connection line between commits
    private static func drawConnection(
        context: GraphicsContext,
        connection: GitGraphConnection,
        config: GraphConfig
    ) {
        let startX = CGFloat(connection.fromColumn) * config.horizontalSpacing + config.padding
        let startY = CGFloat(connection.fromRow) * config.verticalSpacing + config.padding
        let endX = CGFloat(connection.toColumn) * config.horizontalSpacing + config.padding
        let endY = CGFloat(connection.toRow) * config.verticalSpacing + config.padding

        var path = Path()
        path.move(to: CGPoint(x: startX, y: startY))

        // Draw curved line for merges
        if connection.fromColumn != connection.toColumn {
            // Bezier curve for branch merges
            let midY = (startY + endY) / 2
            path.addCurve(
                to: CGPoint(x: endX, y: endY),
                control1: CGPoint(x: startX, y: midY),
                control2: CGPoint(x: endX, y: midY)
            )
        } else {
            // Straight line for normal commits
            path.addLine(to: CGPoint(x: endX, y: endY))
        }

        context.stroke(
            path,
            with: .color(Color(hex: connection.color)),
            style: StrokeStyle(
                lineWidth: 2,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    /// Draw commit node
    private static func drawCommitNode(
        context: GraphicsContext,
        commit: GitGraphCommit,
        selectedCommit: GitGraphCommit?,
        config: GraphConfig
    ) {
        let centerX = CGFloat(commit.column) * config.horizontalSpacing + config.padding
        let centerY = CGFloat(commit.row) * config.verticalSpacing + config.padding
        let isSelected = selectedCommit?.id == commit.id

        // Draw outer circle for selected commit
        if isSelected {
            context.fill(
                Circle().path(in: CGRect(
                    x: centerX - config.nodeRadius * 1.5,
                    y: centerY - config.nodeRadius * 1.5,
                    width: config.nodeRadius * 3,
                    height: config.nodeRadius * 3
                )),
                with: .color(Color.accentColor.opacity(0.3))
            )
        }

        // Draw commit circle
        context.fill(
            Circle().path(in: CGRect(
                x: centerX - config.nodeRadius,
                y: centerY - config.nodeRadius,
                width: config.nodeRadius * 2,
                height: config.nodeRadius * 2
            )),
            with: .color(Color(hex: commit.trackColor))
        )

        // Draw inner dot
        context.fill(
            Circle().path(in: CGRect(
                x: centerX - config.innerRadius,
                y: centerY - config.innerRadius,
                width: config.innerRadius * 2,
                height: config.innerRadius * 2
            )),
            with: .color(.white)
        )
    }

    /// Draw symbols for reuse
    private static func drawSymbols(context: inout GraphicsContext) {
        // Symbols can be cached here for better performance
    }

    /// Handle tap gesture
    private static func handleTap(
        at location: SIMD3<Float>,
        commits: [GitGraphCommit],
        onTap: (GitGraphCommit) -> Void
    ) {
        let config = GraphConfig()
        let tapX = CGFloat(location.x)
        let tapY = CGFloat(location.y)

        for commit in commits {
            let centerX = CGFloat(commit.column) * config.horizontalSpacing + config.padding
            let centerY = CGFloat(commit.row) * config.verticalSpacing + config.padding

            let distance = sqrt(
                pow(tapX - centerX, 2) + pow(tapY - centerY, 2)
            )

            // Check if tap is within node radius
            if distance <= config.nodeRadius * 1.5 {
                onTap(commit)
                return
            }
        }
    }

    /// Get maximum column index
    private static func getMaxColumn(commits: [GitGraphCommit]) -> Int {
        commits.map { $0.column }.max() ?? 0
    }
}

/// Configuration for graph rendering
struct GraphConfig {
    let nodeRadius: CGFloat = 8
    let innerRadius: CGFloat = 4
    let horizontalSpacing: CGFloat = 60
    let verticalSpacing: CGFloat = 60
    let padding: CGFloat = 50
}

/// Color hex extension
extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0

        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(.sRGB, red: red, green: green, blue: blue)
    }
}
