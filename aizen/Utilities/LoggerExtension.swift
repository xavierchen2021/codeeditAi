//
//  LoggerExtension.swift
//  aizen
//
//  Unified logging utility for the application
//

import Foundation
import os.log

extension Logger {
    /// The app's logging subsystem - must match bundle identifier for proper filtering
    private static let appSubsystem = Bundle.main.bundleIdentifier ?? "win.aizen.app"

    /// Create a logger for a specific category
    nonisolated static func forCategory(_ category: String) -> Logger {
        Logger(subsystem: appSubsystem, category: category)
    }

    /// Convenience logger instances for common categories
    static let agent = Logger.forCategory("Agent")
    static let git = Logger.forCategory("Git")
    static let terminal = Logger.forCategory("Terminal")
    static let chat = Logger.forCategory("Chat")
    static let workspace = Logger.forCategory("Workspace")
    static let worktree = Logger.forCategory("Worktree")
    static let settings = Logger.forCategory("Settings")
    static let audio = Logger.forCategory("Audio")
    static let acp = Logger.forCategory("ACP")
    static let crash = Logger.forCategory("CrashReporter")
}

/// Custom logger wrapper that writes to both console and file
class FileLoggingLogger {
    private let logger: Logger
    private let category: String

    init(category: String) {
        self.category = category
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "win.aizen.app", category: category)
    }

    func debug(_ message: String) {
        logger.debug("\(message)")
        Task { @MainActor in
            FileLogger.shared.log(message, level: .debug, category: category)
        }
    }

    func info(_ message: String) {
        logger.info("\(message)")
        Task { @MainActor in
            FileLogger.shared.log(message, level: .info, category: category)
        }
    }

    func notice(_ message: String) {
        logger.notice("\(message)")
        Task { @MainActor in
            FileLogger.shared.log(message, level: .notice, category: category)
        }
    }

    func warning(_ message: String) {
        logger.warning("\(message)")
        Task { @MainActor in
            FileLogger.shared.log(message, level: .warning, category: category)
        }
    }

    func error(_ message: String) {
        logger.error("\(message)")
        Task { @MainActor in
            FileLogger.shared.log(message, level: .error, category: category)
        }
    }

    func fault(_ message: String) {
        logger.fault("\(message)")
        Task { @MainActor in
            FileLogger.shared.log(message, level: .fault, category: category)
        }
    }
}
