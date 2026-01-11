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
        scale: CGFloat = 1.0,
        onTapCommit: @escaping (GitGraphCommit) -> Void
    ) -> some View {
        // Estimate canvas size based on computed spacing and counts
        let maxCol = max(1, getMaxColumn(commits: commits) + 1)
        let config = GraphConfig(scale: scale, columnCount: maxCol)
        let width = CGFloat(maxCol) * config.horizontalSpacing + config.padding * 2 + 200 // extra for labels
        let height = CGFloat(max(1, commits.count)) * config.verticalSpacing + config.padding * 2

        return ScrollView([.vertical, .horizontal], showsIndicators: false) {
            Canvas { context, size in
                drawSubwayGraph(
                    context: context,
                    commits: commits,
                    connections: connections,
                    selectedCommit: selectedCommit,
                    scale: scale
                )
            }
            .frame(height: height)
            .frame(width: width)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        handleTap(
                            at: value.location,
                            commits: commits,
                            scale: scale,
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
        selectedCommit: GitGraphCommit?,
        scale: CGFloat
    ) {
        let maxCol = max(1, getMaxColumn(commits: commits) + 1)
        let config = GraphConfig(scale: scale, columnCount: maxCol)

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

        // Draw with a soft aura and a vivid core using the branch color
        let trackColor = Color(hex: connection.color)
        context.stroke(path, with: .color(trackColor.opacity(0.72)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        context.stroke(path, with: .color(trackColor), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
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

        // Draw outer circle / glow for selected commit
        if isSelected {
            let outerRect = CGRect(
                x: centerX - config.nodeRadius * 1.8,
                y: centerY - config.nodeRadius * 1.8,
                width: config.nodeRadius * 3.6,
                height: config.nodeRadius * 3.6
            )
            context.fill(
                Circle().path(in: outerRect),
                with: .color(Color.accentColor.opacity(0.22))
            )

            // Draw a stroked ring for emphasis
            var ring = Path()
            ring.addEllipse(in: CGRect(
                x: centerX - config.nodeRadius * 1.25,
                y: centerY - config.nodeRadius * 1.25,
                width: config.nodeRadius * 2.5,
                height: config.nodeRadius * 2.5
            ))
            context.stroke(ring, with: .color(Color.accentColor), lineWidth: 2)
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

        // Always draw a compact label to the right of each node (anchored leading so it starts after the node)
        let raw = "\(commit.shortHash) - \(commit.message)"
        let maxLen = 120
        let labelText = raw.count > maxLen ? String(raw.prefix(maxLen - 3)) + "…" : raw
        let label = Text(labelText)
            .font(.system(size: 11))
            .foregroundColor(isSelected ? .primary : .secondary)

        // Calculate the leading point (just after the node)
        let leadingX = centerX + config.nodeRadius + 8
        let leadingPoint = CGPoint(x: leadingX, y: centerY)

        // If selected, draw a subtle rounded background starting at the leading edge
        if isSelected {
            let approxWidth = min(520, CGFloat(labelText.count) * 7.2 + 16)
            let rectHeight: CGFloat = 22
            let rect = CGRect(
                x: leadingX - 6,
                y: centerY - rectHeight / 2,
                width: approxWidth,
                height: rectHeight
            )
            context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(Color.accentColor.opacity(0.12)))
        }

        // Draw the label starting at leadingPoint (leading anchor)
        context.draw(label, at: leadingPoint, anchor: .leading)

        // --- Draw branch head pills (if any) ---
        if !commit.branchNames.isEmpty {
            var pillX = leadingX
            let pillHeight: CGFloat = max(16, config.nodeRadius * 1.6)
            let pillSpacing: CGFloat = 6
            let maxPillsToShow = 2

            for (i, bname) in commit.branchNames.enumerated() {
                if i >= maxPillsToShow {
                    // Draw a "+N" pill for extras
                    let remaining = commit.branchNames.count - maxPillsToShow + 1
                    let text = Text("+\(remaining)")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    let approxWidth = CGFloat(min(120, 10 + 7 * (String(remaining).count))) + 12
                    let rect = CGRect(x: pillX - 2, y: centerY - config.nodeRadius - pillHeight - 6, width: approxWidth, height: pillHeight)
                    context.fill(Path(roundedRect: rect, cornerRadius: pillHeight / 2), with: .color(Color(hex: commit.trackColor)))
                    context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
                    break
                }

                let text = Text(bname)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                let approxWidth = CGFloat(min(160, bname.count * 7 + 16))
                let rect = CGRect(x: pillX - 2, y: centerY - config.nodeRadius - pillHeight - 6, width: approxWidth, height: pillHeight)
                // Fill with the track color (makes branch pill visually associated)
                context.fill(Path(roundedRect: rect, cornerRadius: pillHeight / 2), with: .color(Color(hex: commit.trackColor)))
                context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)

                pillX += approxWidth + pillSpacing
            }
        }

        // --- Draw worktree badge if worktrees point to this commit ---
        if !commit.worktreeNames.isEmpty {
            // Draw a small folder emoji badge to indicate one or more worktrees
            let badge = Text("📁")
                .font(.system(size: max(12, config.nodeRadius * 1.3)))
            // Place to the right under the node/label to avoid overlap
            let badgePoint = CGPoint(x: leadingX + 6, y: centerY + config.nodeRadius + 12)
            context.draw(badge, at: badgePoint, anchor: .leading)
        }

    }

    /// Draw symbols for reuse
    private static func drawSymbols(context: inout GraphicsContext) {
        // Symbols can be cached here for better performance
    }

    /// Handle tap gesture
    private static func handleTap(
        at location: CGPoint,
        commits: [GitGraphCommit],
        scale: CGFloat,
        onTap: (GitGraphCommit) -> Void
    ) {
        let maxCol = max(1, getMaxColumn(commits: commits) + 1)
        let config = GraphConfig(scale: scale, columnCount: maxCol)
        let tapX = location.x
        let tapY = location.y

        for commit in commits {
            let centerX = CGFloat(commit.column) * config.horizontalSpacing + config.padding
            let centerY = CGFloat(commit.row) * config.verticalSpacing + config.padding

            let distance = sqrt(
                pow(tapX - centerX, 2) + pow(tapY - centerY, 2)
            )

            // Check if tap is within node radius (scaled)
            if distance <= config.nodeRadius * 1.6 {
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
    // Base sizes (at scale == 1)
    private let baseNodeRadius: CGFloat = 8
    private let baseInnerRadius: CGFloat = 4
    private let baseHorizontalSpacing: CGFloat = 60
    private let baseVerticalSpacing: CGFloat = 60
    let padding: CGFloat

    // Computed values
    let nodeRadius: CGFloat
    let innerRadius: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    init(scale: CGFloat = 1.0, columnCount: Int = 1) {
        // Clamp scale to sensible range
        let s = min(max(scale, 0.4), 2.5)

        // Compress horizontal spacing when many columns to keep branches closer to master
        let compressionFactor: CGFloat
        if columnCount <= 6 {
            compressionFactor = 1.0
        } else {
            // more columns -> compress more, but never below 0.5
            compressionFactor = max(0.5, 1.0 - CGFloat(columnCount - 6) * 0.03)
        }

        // final spacing
        horizontalSpacing = max(28, baseHorizontalSpacing * s * compressionFactor)
        verticalSpacing = max(40, baseVerticalSpacing * s)

        nodeRadius = max(4, baseNodeRadius * s)
        innerRadius = max(2, baseInnerRadius * s)

        // padding scales modestly but keep a min
        padding = max(24, 40 * s)
    }
}

/// Color hex extension
extension Color {
    init(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0

        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(.sRGB, red: red, green: green, blue: blue)
    }
}
