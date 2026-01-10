//
//  GitGraphModels.swift
//  aiX
//
//  Data models for Git graph visualization
//

import Foundation

/// Graph node representing a commit in the subway view
struct GitGraphCommit: Identifiable {
    let id: String
    let shortHash: String
    let message: String
    let author: String
    let date: Date
    let filesChanged: Int
    let additions: Int
    let deletions: Int

    // Graph layout properties
    let parentIds: [String]  // Parent commit IDs for drawing connections
    let row: Int             // Vertical position (time order)
    let column: Int           // Horizontal position (branch track)
    let trackColor: String    // Color for the branch track

    /// Display relative date
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    init(
        id: String,
        shortHash: String,
        message: String,
        author: String,
        date: Date,
        filesChanged: Int,
        additions: Int,
        deletions: Int,
        parentIds: [String] = [],
        row: Int = 0,
        column: Int = 0,
        trackColor: String = "#007AFF"
    ) {
        self.id = id
        self.shortHash = shortHash
        self.message = message
        self.author = author
        self.date = date
        self.filesChanged = filesChanged
        self.additions = additions
        self.deletions = deletions
        self.parentIds = parentIds
        self.row = row
        self.column = column
        self.trackColor = trackColor
    }
}

/// Connection line between commits
struct GitGraphConnection {
    let fromCommitId: String
    let toCommitId: String
    let fromColumn: Int
    let toColumn: Int
    let fromRow: Int
    let toRow: Int
    let color: String

    init(
        fromCommitId: String,
        toCommitId: String,
        fromColumn: Int,
        toColumn: Int,
        fromRow: Int,
        toRow: Int,
        color: String
    ) {
        self.fromCommitId = fromCommitId
        self.toCommitId = toCommitId
        self.fromColumn = fromColumn
        self.toColumn = toColumn
        self.fromRow = fromRow
        self.toRow = toRow
        self.color = color
    }
}

/// Branch track information
struct GitGraphTrack {
    let column: Int
    let name: String
    let color: String
}

/// Colors for different branch tracks
enum GitGraphTrackColor: CaseIterable {
    case blue, green, purple, orange, pink, cyan, red, yellow

    var hexColor: String {
        switch self {
        case .blue: return "#007AFF"
        case .green: return "#34C759"
        case .purple: return "#AF52DE"
        case .orange: return "#FF9500"
        case .pink: return "#FF2D55"
        case .cyan: return "#32ADE6"
        case .red: return "#FF3B30"
        case .yellow: return "#FFCC00"
        }
    }

    static func color(forIndex index: Int) -> String {
        allCases[index % allCases.count].hexColor
    }
}
