<div align="center">
  <img src="readmestuff/app_icon_512.png" width="96" height="96" alt="tomsllama logo" />
  <h1>tomsllama</h1>
  <p>A native desktop interface for local Ollama language models with project workspaces, hardware calibration, and offline context management.</p>
</div>

---

![tomsllama screenshot](readmestuff/screenshot.png)

## Overview

tomsllama is an offline, privacy-first desktop client for Ollama built with Flutter. It executes completely on your local workstation with zero telemetry, zero analytics, and zero external cloud connections.

The interface adheres to an anti-slop, distraction-free aesthetic: 1px hairlines, floating neutral pills, monospaced code blocks with syntax highlighting, and dedicated workspace context injection designed for developer workflows.

## Features

- Local Streaming: Direct token-by-token streaming from your local Ollama daemon via HTTP.
- Project Workspaces: Organize chats inside isolated workspaces with custom workspace system prompts, Git repository awareness, active branch tracking, and dedicated file pools.
- Context & File Attachments: Attach files or whole project folders to the composer. Files are parsed, counted for token load, and injected directly into model context.
- Mention Auto-Completion: Type `@` inside the input box to open a filtered file selector matching files from the active workspace.
- Per-Model Hardware Calibration: Automatically benchmarks evaluation speed (eval tok/s) and generation speed (gen tok/s) on your hardware (CPU, Apple Silicon, or NVIDIA GPU). Displays estimated completion times before sending messages.
- Expandable Telemetry Shelf: A collapsible drawer attached directly to the top edge of the input bar displaying active workspace details, Git branch, attached file token sizes, expected model duration, and daily versus lifetime token metrics.
- Execution Modes: Switch between Schnell (fast, low-context), Optimal (balanced quality and performance), and Denken (extended reasoning budget for models like DeepSeek-R1 and Qwen2.5-Coder).
- Reasoning Accordions: Dedicated thinking blocks for reasoning models, displaying elapsed calculation time and token counts with toggleable visibility.
- Split-View Canvas: Side-by-side inspection canvas to view and edit code blocks, markdown artifacts, or generated documents while continuing conversations.
- History Navigation: Use Arrow Up and Arrow Down in the text field to cycle through past prompts without losing current draft inputs.
- Organic Dispatch Button: Circular send button with a smooth cloud-morphing animation featuring the animated mascot during dispatch.
- Built-in Themes: Four high-contrast color palettes:
  - Claude: Warm ivory paper canvas with terracotta accents.
  - Pond: Clean mineral light background with slate teal accents.
  - Dark: Low-contrast charcoal background with warm highlights.
  - Pond Dark: Deep mineral slate background with luminous teal accents.
- Local SQLite Storage: Robust persistence for chats, messages, personas, workspaces, and telemetry in `~/Documents/tomsllama/tomsllama.db`.
- Local Typography: Bundles Inter, Newsreader, and Fira Code locally without external network requests.
- Multi-Language: Automatic UI switching between English and German based on system locale.

## Keyboard Shortcuts

| Shortcut | Description |
| :--- | :--- |
| `Ctrl + N` | Start a new chat |
| `Ctrl + B` | Toggle sidebar visibility |
| `Ctrl + K` | Open quick switcher / search |
| `Esc` | Stop active generation / close autocompletion popup |
| `F11` | Toggle fullscreen mode |
| `Enter` | Send message (when text or files are attached) |
| `Shift + Enter` | Insert newline |
| `Arrow Up` | Navigate to previous prompt in history (at first line) |
| `Arrow Down` | Navigate to newer prompt in history / restore draft |
| `@` | Trigger workspace file autocomplete |

## Prerequisites

1. Install and start [Ollama](https://ollama.com):
   ```bash
   ollama serve
   ```

2. Pull desired models:
   ```bash
   ollama pull qwen2.5-coder:7b
   ollama pull deepseek-r1:14b
   ```

3. Flutter SDK (version 3.19 or higher) with Linux desktop prerequisites:
   ```bash
   # Fedora:
   sudo dnf install clang cmake ninja-build gtk3-devel libayatana-appindicator-gtk3-devel

   # Ubuntu / Debian:
   sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libayatana-appindicator3-dev

   # Arch Linux:
   sudo pacman -S clang cmake ninja gtk3 libayatana-appindicator
   ```

## Building and Running

Clone the repository:
```bash
git clone https://github.com/tomsliikee/tomsllama.git
cd tomsllama
```

Install dependencies:
```bash
flutter pub get
```

Run in development mode:
```bash
flutter run -d linux
```

Compile a standalone release bundle:
```bash
flutter build linux --release
```

The resulting executable and bundled assets are placed in:
`build/linux/x64/release/bundle/tomsllama`

## Data Storage & Paths

All persistent data remains strictly on your local disk:

- SQLite Database: `~/Documents/tomsllama/tomsllama.db`
- Configuration & Hardware Profiles: `~/Documents/tomsllama/settings.json`
- Linux Desktop Entry: `~/.local/share/applications/tomsllama.desktop`
- Application Icons: `~/.local/share/icons/hicolor/`

## License

MIT License. See LICENSE for details.
