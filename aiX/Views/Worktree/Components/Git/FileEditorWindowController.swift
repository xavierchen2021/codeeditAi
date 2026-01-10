//
//  FileEditorWindowController.swift
//  aizen
//
//  Window controller for opening files in standalone windows
//

import AppKit
import SwiftUI
import os.log
import Combine

class FileEditorWindowController: NSWindowController {
    private let filePath: String
    private var windowDelegate: FileEditorWindowDelegate?

    init(filePath: String, onClose: @escaping () -> Void) {
        self.filePath = filePath

        // Calculate window size - 80% of main window size
        let mainWindowFrame = NSApp.mainWindow?.frame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)
        let width = max(900, mainWindowFrame.width * 0.8)
        let height = max(600, mainWindowFrame.height * 0.8)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // Set window properties
        window.isRestorable = true
        window.identifier = NSUserInterfaceItemIdentifier("FileEditorWindow-\(filePath)")
        window.isExcludedFromWindowsMenu = false
        window.minSize = NSSize(width: 600, height: 400)

        // Set window title to file name
        let fileName = (filePath as NSString).lastPathComponent
        window.title = fileName

        super.init(window: window)

        // Create content view
        let content = FileEditorWindowContent(
            filePath: filePath,
            onClose: {
                window.close()
                onClose()
            }
        )

        window.contentView = NSHostingView(rootView: content)
        window.center()

        // Set up delegate
        windowDelegate = FileEditorWindowDelegate(onClose: onClose)
        window.delegate = windowDelegate
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class FileEditorWindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

// MARK: - SwiftUI Content View

struct FileEditorWindowContent: View {
    let filePath: String
    let onClose: () -> Void

    @StateObject private var viewModel: FileEditorViewModel
    @AppStorage("editorFontFamily") private var editorFontFamily: String = "Menlo"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 13.0

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "win.aiX", category: "FileEditorWindow")

    init(filePath: String, onClose: @escaping () -> Void) {
        self.filePath = filePath
        self.onClose = onClose
        self._viewModel = StateObject(wrappedValue: FileEditorViewModel(filePath: filePath))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with file path
            headerView
                .frame(height: 44)
                .background(.ultraThinMaterial)

            Divider()

            // Editor content
            if let content = viewModel.content {
                CodeEditorView(
                    content: content,
                    language: viewModel.language,
                    isEditable: true,
                    filePath: filePath,
                    onContentChange: { newValue in
                        viewModel.content = newValue
                        viewModel.hasUnsavedChanges = true
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                VStack {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Error loading file")
                        .font(.headline)
                        .padding(.top, 12)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Text((filePath as NSString).lastPathComponent)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    if viewModel.hasUnsavedChanges {
                        Button(action: {
                            Task {
                                await viewModel.save()
                            }
                        }) {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(action: onClose) {
                        Label("Close", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.load()
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Text(filePath)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - View Model

class FileEditorViewModel: ObservableObject {
    @Published var content: String?
    @Published var isLoading = false
    @Published var hasUnsavedChanges = false
    @Published var error: String?

    let filePath: String
    var language: String {
        let fileExtension = (filePath as NSString).pathExtension.lowercased()
        return languageMap[fileExtension] ?? "plaintext"
    }

    private let languageMap: [String: String] = [
        "swift": "swift",
        "js": "javascript",
        "ts": "typescript",
        "jsx": "jsx",
        "tsx": "tsx",
        "py": "python",
        "rb": "ruby",
        "go": "go",
        "rs": "rust",
        "java": "java",
        "kt": "kotlin",
        "cpp": "cpp",
        "c": "c",
        "h": "c",
        "hpp": "cpp",
        "m": "objective-c",
        "mm": "objective-c++",
        "cs": "csharp",
        "php": "php",
        "html": "html",
        "css": "css",
        "scss": "scss",
        "sass": "sass",
        "json": "json",
        "xml": "xml",
        "yaml": "yaml",
        "yml": "yaml",
        "toml": "toml",
        "md": "markdown",
        "sh": "shell",
        "bash": "shell",
        "zsh": "shell",
        "sql": "sql",
        "dockerfile": "dockerfile"
    ]

    init(filePath: String) {
        self.filePath = filePath
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            if let text = String(data: data, encoding: .utf8) {
                await MainActor.run {
                    content = text
                    hasUnsavedChanges = false
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    error = "File is not UTF-8 encoded"
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    func save() async {
        guard let content = content else { return }

        do {
            try content.write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)
            await MainActor.run {
                hasUnsavedChanges = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
}