//
//  AgentFileSystemDelegate.swift
//  aizen
//
//  Created by Uladzislau Yakauleu on 17.10.25.
//

import Foundation
import os.log

/// Actor responsible for handling file system operations for agent sessions
actor AgentFileSystemDelegate {

    private let logger = Logger.forCategory("FileSystemDelegate")

    // MARK: - Initialization

    init() {}

    // MARK: - File Operations

    /// Handle file read request from agent
    /// - Parameters:
    ///   - path: File path to read
    ///   - sessionId: Session identifier (for tracking/logging)
    ///   - line: Starting line number (1-based per ACP spec)
    ///   - limit: Number of lines to read
    func handleFileReadRequest(_ path: String, sessionId: String, line: Int?, limit: Int?) async throws -> ReadTextFileResponse {
        let url = URL(fileURLWithPath: path)
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        let filteredContent: String
        if let startLine = line, let lineLimit = limit {
            // Convert 1-based line to 0-based index
            let startIdx = max(0, startLine - 1)
            let endIdx = min(lines.count, startIdx + lineLimit)
            filteredContent = lines[startIdx..<endIdx].joined(separator: "\n")
        } else if let startLine = line {
            // Convert 1-based line to 0-based index
            let startIdx = max(0, startLine - 1)
            filteredContent = lines[startIdx...].joined(separator: "\n")
        } else {
            filteredContent = content
        }

        return ReadTextFileResponse(content: filteredContent, totalLines: lines.count, _meta: nil)
    }

    /// Handle file write request from agent
    /// Per ACP spec: Client MUST create file if it doesn't exist
    func handleFileWriteRequest(_ path: String, content: String, sessionId: String) async throws -> WriteTextFileResponse {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("[handleFileWriteRequest] Starting write operation for: \(path), content size: \(content.count) chars, sessionId: \(sessionId)")

        let url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default

        logger.debug("[handleFileWriteRequest] Target path: \(url.path)")
        logger.debug("[handleFileWriteRequest] Parent directory: \(url.deletingLastPathComponent().path)")

        // Create parent directories if needed (ACP spec requires creating file if it doesn't exist)
        let parentDir = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            logger.info("[handleFileWriteRequest] Creating parent directory: \(parentDir.path)")
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            logger.debug("[handleFileWriteRequest] Parent directory created successfully")
        }

        do {
            logger.debug("[handleFileWriteRequest] Writing content to file...")
            try content.write(to: url, atomically: true, encoding: .utf8)
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("[handleFileWriteRequest] Write succeeded: \(path), elapsed time: \(String(format: "%.2f", elapsedTime * 1000))ms")
            return WriteTextFileResponse(_meta: nil)
        } catch {
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
            logger.error("[handleFileWriteRequest] Write failed for \(path): \(error.localizedDescription), elapsed time: \(String(format: "%.2f", elapsedTime * 1000))ms")
            logger.error("[handleFileWriteRequest] Error details: \(error)")
            throw error
        }
    }
}
