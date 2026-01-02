//
//  LanguageDetection.swift
//  aizen
//
//  Helper utilities for detecting programming languages from MIME types and file extensions
//

import Foundation
import CodeEditLanguages

struct LanguageDetection {
    /// Convert markdown code fence language identifier to CodeLanguage
    static func languageFromFence(_ fenceLang: String) -> CodeLanguage {
        let normalized = normalizeLanguageIdentifier(fenceLang)
        return codeLanguageFromLanguageString(normalized)
    }

    /// Detect programming language from MIME type and URI, returns CodeLanguage
    static func detectLanguage(mimeType: String?, uri: String, content: String? = nil) -> CodeLanguage {
        // Try content-based detection first if content is provided
        if let content = content, let detectedLang = detectFromContent(content, uri: uri) {
            return detectedLang
        }

        // Try MIME type
        if let mimeType = mimeType?.lowercased() {
            if let lang = languageFromMimeType(mimeType) {
                return codeLanguageFromLanguageString(lang)
            }
        }

        // Fall back to file extension
        if let url = URL(string: uri) {
            let ext = url.pathExtension.lowercased()
            if let lang = languageFromExtension(ext) {
                return codeLanguageFromLanguageString(lang)
            }
        }

        return CodeLanguage.default
    }

    /// Detect language from file content (magic bytes, patterns, etc.)
    private static func detectFromContent(_ content: String, uri: String) -> CodeLanguage? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for XML declaration or root element
        if trimmed.hasPrefix("<?xml") ||
           (trimmed.hasPrefix("<") && (trimmed.contains("xmlns") || trimmed.contains("</"))
           ) {
            // Could be XML, SVG, plist, etc.
            if uri.hasSuffix(".svg") {
                return .html // SVG is XML but use HTML for highlighting
            }
            // No XML language in CodeEditLanguages, use plain text
            return CodeLanguage.default
        }

        // Check for JSON
        if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) && trimmed.count > 10 {
            // Likely JSON
            return .json
        }

        // Check for shebang
        if trimmed.hasPrefix("#!") {
            if trimmed.contains("bash") || trimmed.contains("sh") {
                return .bash
            }
            if trimmed.contains("python") {
                return .python
            }
            if trimmed.contains("ruby") {
                return .ruby
            }
            if trimmed.contains("node") {
                return .javascript
            }
        }

        // Check for .h header files - detect C++ vs C
        if uri.hasSuffix(".h") || uri.hasSuffix(".hpp") {
            // Look for C++ keywords
            if trimmed.contains("class ") || trimmed.contains("namespace ") ||
               trimmed.contains("template<") || trimmed.contains("std::") {
                return .cpp
            }
            // Default to C
            return .c
        }

        return nil
    }

    /// Normalize language identifiers
    private static func normalizeLanguageIdentifier(_ lang: String) -> String {
        let lower = lang.lowercased()

        let aliases: [String: String] = [
            "jsx": "javascript",
            "sh": "bash",
            "zsh": "bash",
            "c++": "cpp",
            "c#": "csharp",
            "objective-c": "objectivec",
            "objc": "objectivec",
            "py": "python",
            "js": "javascript",
            "ts": "typescript",
            "rb": "ruby",
            "yml": "yaml",
        ]

        return aliases[lower] ?? lower
    }

    /// Convert file extension or language string to CodeLanguage
    static func codeLanguageFromString(_ lang: String) -> CodeLanguage {
        // First try to get from extension mapping
        if let mappedLang = languageFromExtension(lang.lowercased()) {
            return codeLanguageFromLanguageString(mappedLang)
        }

        // Otherwise try direct language string mapping
        return codeLanguageFromLanguageString(lang)
    }

    /// Convert language string to CodeLanguage
    private static func codeLanguageFromLanguageString(_ lang: String) -> CodeLanguage {
        switch lang.lowercased() {
        case "swift": return .swift
        case "javascript": return .javascript
        case "jsx": return .jsx
        case "typescript": return .typescript
        case "tsx": return .tsx
        case "python": return .python
        case "ruby": return .ruby
        case "java": return .java
        case "kotlin": return .kotlin
        case "c": return .c
        case "cpp": return .cpp
        case "csharp": return .cSharp
        case "go": return .go
        case "gomod": return .goMod
        case "rust": return .rust
        case "php": return .php
        case "html": return .html
        case "css": return .css
        case "scss": return .css
        case "sass": return .css
        case "less": return .css
        case "json": return .json
        case "xml": return CodeLanguage.default // No XML in tree-sitter
        case "markdown": return .markdown
        case "bash": return .bash
        case "sql": return .sql
        case "yaml": return .yaml
        case "dockerfile": return .dockerfile
        case "makefile": return CodeLanguage.default // No makefile in tree-sitter
        case "lua": return .lua
        case "perl": return .perl
        case "r": return CodeLanguage.default // No R in tree-sitter
        case "elixir": return .elixir
        case "haskell": return .haskell
        case "scala": return .scala
        case "clojure": return CodeLanguage.default // No Clojure in tree-sitter
        case "vue": return CodeLanguage.default // No Vue in tree-sitter
        case "graphql": return CodeLanguage.default // No GraphQL in tree-sitter
        case "dart": return .dart
        case "julia": return .julia
        case "toml": return .toml
        case "zig": return .zig
        case "verilog": return .verilog
        case "objc", "objective-c": return .objc
        case "ocaml": return .ocaml
        case "regex": return .regex
        case "jsdoc": return .jsdoc
        case "agda": return .agda
        default: return CodeLanguage.default
        }
    }

    /// Map MIME types to highlight.js language identifiers
    private static let mimeTypeMapping: [String: String] = [
            // Swift
            "text/x-swift": "swift",
            "application/x-swift": "swift",

            // JavaScript/TypeScript
            "text/javascript": "javascript",
            "application/javascript": "javascript",
            "application/x-javascript": "javascript",
            "text/typescript": "typescript",
            "application/typescript": "typescript",

            // Python
            "text/x-python": "python",
            "application/x-python": "python",

            // Ruby
            "text/x-ruby": "ruby",
            "application/x-ruby": "ruby",

            // Java
            "text/x-java": "java",
            "text/x-java-source": "java",

            // C/C++
            "text/x-c": "c",
            "text/x-c++": "cpp",
            "text/x-c++src": "cpp",

            // Go
            "text/x-go": "go",

            // Rust
            "text/x-rust": "rust",

            // HTML/CSS
            "text/html": "html",
            "text/css": "css",

            // JSON/XML
            "application/json": "json",
            "text/json": "json",
            "application/xml": "xml",
            "text/xml": "xml",

            // Markdown
            "text/markdown": "markdown",
            "text/x-markdown": "markdown",

            // Shell
            "text/x-sh": "bash",
            "text/x-shellscript": "bash",
            "application/x-sh": "bash",

            // SQL
            "text/x-sql": "sql",
            "application/sql": "sql",

            // YAML
            "text/yaml": "yaml",
            "text/x-yaml": "yaml",
            "application/x-yaml": "yaml",
        ]

    private static func languageFromMimeType(_ mimeType: String) -> String? {
        return mimeTypeMapping[mimeType]
    }

    /// Map file extensions to language identifiers
    private static let extensionMapping: [String: String] = [
            // Swift
            "swift": "swift",

            // JavaScript/TypeScript
            "js": "javascript",
            "jsx": "javascript",
            "mjs": "javascript",
            "cjs": "javascript",
            "ts": "typescript",
            "tsx": "tsx",

            // Python
            "py": "python",
            "pyw": "python",
            "pyi": "python",

            // Ruby
            "rb": "ruby",
            "erb": "ruby",

            // Java
            "java": "java",

            // Kotlin
            "kt": "kotlin",
            "kts": "kotlin",

            // C/C++
            "c": "c",
            "h": "c",
            "cpp": "cpp",
            "cc": "cpp",
            "cxx": "cpp",
            "hpp": "cpp",
            "hh": "cpp",
            "hxx": "cpp",

            // C#
            "cs": "csharp",

            // Go
            "go": "go",

            // Rust
            "rs": "rust",

            // PHP
            "php": "php",

            // HTML/CSS
            "html": "html",
            "htm": "html",
            "css": "css",
            "scss": "css",
            "sass": "css",
            "less": "css",

            // JSON/XML
            "json": "json",
            "xml": "xml",
            "plist": "xml",
            "svg": "html",
            "config": "xml",
            "gradle": "groovy",
            "maven": "xml",

            // Markdown
            "md": "markdown",
            "markdown": "markdown",
            "mdx": "markdown",

            // Shell
            "sh": "bash",
            "bash": "bash",
            "zsh": "bash",

            // SQL
            "sql": "sql",

            // YAML
            "yaml": "yaml",
            "yml": "yaml",

            // Docker
            "dockerfile": "dockerfile",

            // Makefile
            "makefile": "makefile",
            "make": "makefile",

            // Lua
            "lua": "lua",

            // Perl
            "pl": "perl",
            "pm": "perl",

            // R
            "r": "r",

            // Elixir
            "ex": "elixir",
            "exs": "elixir",

            // Haskell
            "hs": "haskell",

            // Scala
            "scala": "scala",

            // Clojure
            "clj": "clojure",
            "cljs": "clojure",

            // Vue
            "vue": "vue",

            // GraphQL
            "graphql": "graphql",
            "gql": "graphql",
        ]

    private static func languageFromExtension(_ ext: String) -> String? {
        return extensionMapping[ext]
    }

    /// Check if a file is likely to contain code based on MIME type or extension
    static func isCodeFile(mimeType: String?, uri: String) -> Bool {
        return detectLanguage(mimeType: mimeType, uri: uri).id != .plainText
    }
}
