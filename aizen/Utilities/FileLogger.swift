//
//  FileLogger.swift
//  aizen
//
//  File logging utility that writes logs to disk
//

import Foundation
import os.log
import AppKit

/// File logger that writes log messages to disk
@MainActor
class FileLogger {
    static let shared = FileLogger()

    private let fileManager = FileManager.default
    private var logFileHandle: FileHandle?
    private var currentLogFileURL: URL?
    private let maxFileSize: UInt64 = 10 * 1024 * 1024  // 10MB
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay,
                                   .withTime, .withColonSeparatorInTime]
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private init() {
        setupLogDirectory()
        openLogFile()
    }

    private func setupLogDirectory() {
        guard let logsURL = logsDirectory else {
            print("无法获取日志目录")
            return
        }

        if !fileManager.fileExists(atPath: logsURL.path) {
            do {
                try fileManager.createDirectory(at: logsURL,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
                print("创建日志目录: \(logsURL.path)")
            } catch {
                print("创建日志目录失败: \(error.localizedDescription)")
            }
        }
    }

    private func openLogFile() {
        guard let logsURL = logsDirectory else { return }

        let dateStr = logDateFormatter.string(from: Date())
        let fileName = "\(dateStr).log"
        let fileURL = logsURL.appendingPathComponent(fileName)

        // 检查文件是否存在以及大小
        if fileManager.fileExists(atPath: fileURL.path) {
            if let fileSize = try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? UInt64,
               fileSize >= maxFileSize {
                // 文件过大，创建带编号的文件
                let newFileURL = findAvailableLogFileURL(baseDate: dateStr)
                createAndOpenLogFile(at: newFileURL)
                return
            }
        }

        createAndOpenLogFile(at: fileURL)
    }

    private func findAvailableLogFileURL(baseDate: String) -> URL {
        guard let logsURL = logsDirectory else {
            fatalError("无法获取日志目录")
        }

        var counter = 1
        while true {
            let fileName = "\(baseDate)_\(counter).log"
            let fileURL = logsURL.appendingPathComponent(fileName)

            if !fileManager.fileExists(atPath: fileURL.path) {
                return fileURL
            }

            if let fileSize = try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? UInt64,
               fileSize < maxFileSize {
                return fileURL
            }

            counter += 1
        }
    }

    private func createAndOpenLogFile(at url: URL) {
        do {
            if !fileManager.fileExists(atPath: url.path) {
                fileManager.createFile(atPath: url.path, contents: nil)
            }

            let fileHandle = try FileHandle(forWritingTo: url)
            fileHandle.seekToEndOfFile()
            logFileHandle = fileHandle
            currentLogFileURL = url

            print("打开日志文件: \(url.path)")
        } catch {
            print("打开日志文件失败: \(error.localizedDescription)")
        }
    }

    func log(_ message: String, level: LogLevel, category: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logLine = "[\(timestamp)] [\(level.rawValue)] [\(category)] \(message)\n"

        guard let data = logLine.data(using: .utf8) else { return }

        // 异步写入，避免阻塞主线程
        Task.detached(priority: .utility) {
            await self.writeToLogFile(data: data)
        }
    }

    private func writeToLogFile(data: Data) async {
        await MainActor.run {
            guard let fileHandle = logFileHandle else { return }

            // 检查是否需要轮转
            if let fileURL = currentLogFileURL,
               let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? UInt64,
               fileSize >= maxFileSize {

                fileHandle.closeFile()
                openLogFile()

                // 重新获取文件句柄
                guard let newFileHandle = logFileHandle else { return }
                newFileHandle.write(data)
            } else {
                fileHandle.write(data)
            }
        }
    }

    /// 获取日志目录
    var logsDirectory: URL? {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        // 在Logs目录下创建应用名子目录
        let logsURL = appSupportURL.appendingPathComponent("Logs", isDirectory: true)
        let appLogsURL = logsURL.appendingPathComponent("aizen", isDirectory: true)
        return appLogsURL
    }

    /// 获取当前日志文件路径
    var currentLogFilePath: String? {
        currentLogFileURL?.path
    }

    /// 清理旧日志（保留最近30天）
    func cleanOldLogs() {
        guard let logsURL = logsDirectory else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        do {
            let files = try fileManager.contentsOfDirectory(at: logsURL, includingPropertiesForKeys: [.contentModificationDateKey])

            for fileURL in files {
                guard fileURL.pathExtension == "log" else { continue }

                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let modificationDate = attributes[.modificationDate] as? Date,
                   modificationDate < cutoffDate {

                    // 移动到 archive 目录
                    let archiveURL = logsURL.appendingPathComponent("archive", isDirectory: true)
                    if !fileManager.fileExists(atPath: archiveURL.path) {
                        try fileManager.createDirectory(at: archiveURL, withIntermediateDirectories: true)
                    }

                    let destURL = archiveURL.appendingPathComponent(fileURL.lastPathComponent)
                    try fileManager.moveItem(at: fileURL, to: destURL)
                    print("归档日志文件: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("清理旧日志失败: \(error.localizedDescription)")
        }
    }

    /// 打开日志目录
    func openLogsDirectory() {
        guard let logsURL = logsDirectory else {
            let alert = NSAlert()
            alert.messageText = "无法打开日志目录"
            alert.informativeText = "日志目录路径无法访问"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
            return
        }

        NSWorkspace.shared.open(logsURL)
    }
}

/// Log level enumeration
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case notice = "NOTICE"
    case warning = "WARNING"
    case error = "ERROR"
    case fault = "FAULT"
}
