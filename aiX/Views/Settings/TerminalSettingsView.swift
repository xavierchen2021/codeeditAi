//
//  TerminalSettingsView.swift
//  aizen
//
//  Created by Uladzislau Yakauleu on 17.10.25.
//

import SwiftUI
import os.log

struct TerminalSettingsView: View {
    private let logger = Logger.settings
    @Binding var fontName: String
    @Binding var fontSize: Double
    @AppStorage("terminalThemeName") private var themeName = "Aizen Dark"
    @AppStorage("terminalThemeNameLight") private var themeNameLight = "Aizen Light"
    @AppStorage("terminalUsePerAppearanceTheme") private var usePerAppearanceTheme = false
    @AppStorage("terminalNotificationsEnabled") private var terminalNotificationsEnabled = true
    @AppStorage("terminalProgressEnabled") private var terminalProgressEnabled = true
    @AppStorage("terminalSessionPersistence") private var sessionPersistence = false

    // Copy settings
    @AppStorage("terminalCopyTrimTrailingWhitespace") private var copyTrimTrailingWhitespace = true
    @AppStorage("terminalCopyCollapseBlankLines") private var copyCollapseBlankLines = false
    @AppStorage("terminalCopyStripShellPrompts") private var copyStripShellPrompts = false
    @AppStorage("terminalCopyFlattenCommands") private var copyFlattenCommands = false
    @AppStorage("terminalCopyRemoveBoxDrawing") private var copyRemoveBoxDrawing = false
    @AppStorage("terminalCopyStripAnsiCodes") private var copyStripAnsiCodes = true

    @StateObject private var presetManager = TerminalPresetManager.shared
    @State private var tmuxAvailable = false
    @State private var clearingTmuxSessions = false
    @State private var availableFonts: [String] = []
    @State private var themeNames: [String] = []
    @State private var showingAddPreset = false
    @State private var editingPreset: TerminalPreset?

    private static var themesPath: String? {
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        return (resourcePath as NSString).appendingPathComponent("ghostty/themes")
    }

    private func loadSystemFonts() -> [String] {
        let fontManager = NSFontManager.shared
        
        // 首先加载所有等宽字体（终端推荐）
        let monospaceFonts = fontManager.availableFontFamilies.filter { familyName in
            guard let font = NSFont(name: familyName, size: 12) else { return false }
            return font.isFixedPitch
        }
        
        // 添加一些常用的等宽字体（确保它们在列表中）
        let commonMonospaceFonts = [
            "Menlo", "Monaco", "Courier New", "Courier", 
            "SF Mono", "SF Pro Text", "SF Pro Display",
            "Source Code Pro", "Fira Code", "JetBrains Mono",
            "Hack", "Ubuntu Mono", "Consolas", "Lucida Console",
            "DejaVu Sans Mono", "Liberation Mono", "Inconsolata",
            "Roboto Mono", "PT Mono", "Oxygen Mono"
        ]
        
        // 合并并去重，保持等宽字体优先
        var allFonts = Set<String>()
        
        // 先添加常用等宽字体
        for font in commonMonospaceFonts {
            if fontManager.availableFontFamilies.contains(font) {
                allFonts.insert(font)
            }
        }
        
        // 再添加所有等宽字体
        for font in monospaceFonts {
            allFonts.insert(font)
        }
        
        // 最后添加其他字体（可选，如果用户想用非等宽字体）
        let allAvailableFonts = fontManager.availableFontFamilies
        for font in allAvailableFonts {
            allFonts.insert(font)
        }
        
        return Array(allFonts).sorted()
    }

    private func loadThemeNames() -> [String] {
        guard let themesPath = Self.themesPath else {
            logger.error("Unable to locate themes directory")
            return []
        }

        logger.info("Loading themes from: \(themesPath)")

        guard let themeFiles = try? FileManager.default.contentsOfDirectory(atPath: themesPath) else {
            logger.error("Unable to read themes from \(themesPath)")
            return []
        }

        logger.info("Found \(themeFiles.count) files in themes directory")

        // Filter out directories and hidden files
        let themes = themeFiles.filter { file in
            let path = (themesPath as NSString).appendingPathComponent(file)
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            let isFile = exists && !isDir.boolValue
            let isNotHidden = !file.hasPrefix(".")
            let result = isFile && isNotHidden
            if !result {
                logger.debug("Skipping: \(file) - exists: \(exists), isDir: \(isDir.boolValue), isHidden: \(file.hasPrefix("."))")
            }
            return result
        }.sorted()

        logger.info("Loaded \(themes.count) themes: \(themes.prefix(10).joined(separator: ", "))\(themes.count > 10 ? "..." : "")")
        return themes
    }

    var body: some View {
        Form {
            Section(LocalizedStringKey("settings.terminal.font.section")) {
                Picker(LocalizedStringKey("settings.terminal.font.picker"), selection: $fontName) {
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }
                .disabled(availableFonts.isEmpty)

                HStack {
                    Text(String(format: NSLocalizedString("settings.terminal.font.size", comment: ""), Int(fontSize)))
                        .frame(width: 120, alignment: .leading)

                    Slider(value: $fontSize, in: 8...24, step: 1)

                    Stepper("", value: $fontSize, in: 8...24, step: 1)
                        .labelsHidden()
                }
            }

            Section(LocalizedStringKey("settings.terminal.theme.section")) {
                Toggle("Use different themes for Light/Dark mode", isOn: $usePerAppearanceTheme)

                if usePerAppearanceTheme {
                    Picker("Dark Mode Theme", selection: $themeName) {
                        ForEach(themeNames, id: \.self) { theme in
                            Text(theme).tag(theme)
                        }
                    }
                    .disabled(themeNames.isEmpty)

                    Picker("Light Mode Theme", selection: $themeNameLight) {
                        ForEach(themeNames, id: \.self) { theme in
                            Text(theme).tag(theme)
                        }
                    }
                    .disabled(themeNames.isEmpty)
                } else {
                    Picker(LocalizedStringKey("settings.terminal.theme.picker"), selection: $themeName) {
                        ForEach(themeNames, id: \.self) { theme in
                            Text(theme).tag(theme)
                        }
                    }
                    .disabled(themeNames.isEmpty)
                }
            }

            Section("Terminal Behavior") {
                Toggle("Enable terminal notifications", isOn: $terminalNotificationsEnabled)
                Toggle("Show progress overlays", isOn: $terminalProgressEnabled)
            }

            Section {
                Toggle("Trim trailing whitespace", isOn: $copyTrimTrailingWhitespace)
                Toggle("Collapse multiple blank lines", isOn: $copyCollapseBlankLines)
                Toggle("Strip shell prompts ($ #)", isOn: $copyStripShellPrompts)
                Toggle("Flatten multi-line commands", isOn: $copyFlattenCommands)
                Toggle("Remove box-drawing characters", isOn: $copyRemoveBoxDrawing)
                Toggle("Strip ANSI escape codes", isOn: $copyStripAnsiCodes)
            } header: {
                Text("Copy Text Processing")
            } footer: {
                Text("Transformations applied when copying text from terminal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Persist terminal sessions", isOn: $sessionPersistence)
                    .disabled(!tmuxAvailable)

                if sessionPersistence {
                    Text("Terminal sessions will survive app restarts using tmux")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        clearingTmuxSessions = true
                        Task {
                            await TmuxSessionManager.shared.killAllAizenSessions()
                            clearingTmuxSessions = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if clearingTmuxSessions {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Clear All Persistent Sessions")
                        }
                    }
                    .disabled(clearingTmuxSessions)
                }

                if !tmuxAvailable {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("tmux not installed. Install via: brew install tmux")
                            .font(.caption)
                    }
                }
            } header: {
                Text("Advanced")
            } footer: {
                if tmuxAvailable && !sessionPersistence {
                    Text("When enabled, terminals run inside hidden tmux sessions and preserve their state when the app is closed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(presetManager.presets) { preset in
                    HStack(spacing: 12) {
                        Image(systemName: preset.icon)
                            .frame(width: 20)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                                .fontWeight(.medium)
                            Text(preset.command)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            editingPreset = preset
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)

                        Button {
                            presetManager.deletePreset(id: preset.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
                .onMove { source, destination in
                    presetManager.movePreset(from: source, to: destination)
                }

                Button {
                    showingAddPreset = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("Add Preset")
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("Terminal Presets")
            } footer: {
                Text("Presets appear in the empty terminal state and when long-pressing the + button")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if availableFonts.isEmpty {
                availableFonts = loadSystemFonts()
            }
            if themeNames.isEmpty {
                themeNames = loadThemeNames()
            }
            tmuxAvailable = TmuxSessionManager.shared.isTmuxAvailable()
        }
        .sheet(isPresented: $showingAddPreset) {
            TerminalPresetFormView(
                onSave: { _ in },
                onCancel: {}
            )
        }
        .sheet(item: $editingPreset) { preset in
            TerminalPresetFormView(
                existingPreset: preset,
                onSave: { _ in },
                onCancel: {}
            )
        }
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
