# Aizen

[![macOS](https://img.shields.io/badge/macOS-13.5+-black?logo=apple)](https://aizen.win)
[![Swift](https://img.shields.io/badge/Swift-5.0+-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/License-GPL%203.0-blue)](LICENSE)
[![Discord](https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white)](https://discord.gg/eKW7GNesuS)
[![Twitter](https://img.shields.io/badge/Twitter-@aizenwin-1DA1F2?logo=x&logoColor=white)](https://x.com/aizenwin)

## Requirements / 系统要求

- macOS 13.5+
- Apple Silicon or Intel Mac

### Building from Source / 从源码构建

- Xcode 16.0+
- Swift 5.0+
- Git LFS
- Zig (for building libghostty): `brew install zig`

```bash
git lfs install
git clone https://github.com/vivy-company/aizen.git
cd aizen

# Build libghostty (universal arm64 + x86_64)
# 构建 libghostty（通用 arm64 + x86_64）
./scripts/build-libghostty.sh

# Open in Xcode and build
# 在 Xcode 中打开并构建
open aizen.xcodeproj
```

To rebuild libghostty at a specific commit:
在指定 commit 重新构建 libghostty：
```bash
./scripts/build-libghostty.sh <commit-sha>
```

## Installation / 安装

Download from [aizen.win](https://aizen.win)
从 [aizen.win](https://aizen.win) 下载

Signed and notarized with an Apple Developer certificate.
已使用 Apple 开发者证书签名和公证。

## Configuration / 配置

### Agents / 代理

Settings > Agents:
设置 > 代理：

| Agent / 代理 | Install Method / 安装方式 | Package / 包名 |
|-------|---------------|---------|
| Claude | NPM | `@anthropic-ai/claude-code` |
| Codex | GitHub | `openai/codex` |
| Gemini | NPM | `@anthropic-ai/claude-code` |
| Kimi | GitHub | `MoonshotAI/kimi-cli` |

Agents can be auto-discovered and installed, or manually configured.
代理可自动发现和安装，也可手动配置。

### Terminal / 终端

Settings > Terminal:
设置 > 终端：
- Font family and size / 字体和大小
- Color theme / 配色主题

### Editor / 编辑器

Settings > General:
设置 > 通用：
- Default external editor / 默认外部编辑器（VS Code、Cursor、Sublime Text）

## Keyboard Shortcuts / 快捷键

| Shortcut / 快捷键 | Action / 操作 |
|----------|--------|
| `⌘ D` | Split terminal right / 向右分屏终端 |
| `⌘ ⇧ D` | Split terminal down / 向下分屏终端 |
| `⌘ W` | Close pane / 关闭面板 |
| `⌘ T` | New tab / 新建标签 |
| `⇧ ⇥` | Cycle chat mode / 切换聊天模式 |
| `ESC` | Interrupt agent / 中断代理 |

## Dependencies / 依赖项

- [libghostty](https://github.com/ghostty-org/ghostty) — Terminal emulator / 终端模拟器
- [CodeEdit](https://github.com/CodeEditApp/CodeEdit) packages — Syntax highlighting (Tree-sitter) / 语法高亮（Tree-sitter）
- [Sparkle](https://github.com/sparkle-project/Sparkle) — Auto-updates / 自动更新

## Architecture / 架构

```
aizen/
├── App/                    # Entry / 入口
├── Models/                 # Data models, ACP types / 数据模型、ACP 类型
├── Services/
│   ├── Agent/              # ACP client, installers, session management / ACP 客户端、安装器、会话管理
│   ├── Git/                # Worktree, branch, staging, diff services / Worktree、分支、暂存、差异服务
│   ├── Audio/              # Voice recording, transcription / 语音录制、转写
│   └── Highlighting/       # Tree-sitter integration / Tree-sitter 集成
├── Views/
│   ├── Workspace/          # Sidebar, create/edit sheets / 侧边栏、创建/编辑弹窗
│   ├── Worktree/           # List, detail, git sidebar / 列表、详情、Git 侧边栏
│   ├── Terminal/           # Tabs, split layout, panes / 标签、分屏布局、面板
│   ├── Chat/               # Sessions, input, markdown, tool calls / 会话、输入、Markdown、工具调用
│   ├── Files/              # Tree view, content tabs / 树形视图、内容标签
│   ├── Browser/            # Tabs, controls / 标签、控件
│   └── Settings/           # All settings panels / 所有设置面板
├── GhosttyTerminal/        # libghostty wrapper / libghostty 封装
└── Utilities/              # Helpers / 工具函数
```

**Patterns / 设计模式：**
- MVVM with `@ObservableObject` / MVVM 配合 `@ObservableObject`
- Actor model for concurrency / Actor 模型处理并发
- Core Data for persistence / Core Data 持久化
- SwiftUI + async/await

## License / 许可证

GNU General Public License v3.0

Copyright © 2025 Vivy Technologies Co., Limited
版权所有 © 2025 Vivy Technologies Co., Limited
