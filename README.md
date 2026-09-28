<div align="center">
  <img src="readmestuff/app_icon_512.png" width="96" height="96" alt="tomsllama logo" />
  <h1>tomsllama</h1>
  <p>A native desktop interface for local Ollama language models.</p>
</div>

---

![tomsllama screenshot](readmestuff/screenshot.png)

## Overview

tomsllama is a private, lightweight desktop client for Ollama built with Flutter. It runs entirely on your local machine with zero external network requests, telemetry, or cloud dependencies.

The user interface emphasizes typography and reading comfort, using serif typography for long-form answers, monospaced code blocks with syntax highlighting, and minimal 1px borders.

## Features

- Local streaming: Streams token-by-token responses directly from your local Ollama instance.
- Reasoning blocks: Collapsible accordions for thinking models like DeepSeek-R1 and Qwen2.5, displaying elapsed thinking time and token counts.
- Split-view canvas: Open code snippets or markdown documents in a persistent right-hand panel while continuing your chat on the left.
- Model picker and temperature slider: Switch models from the top bar and adjust generation temperature with a slider and quick presets (Code, Balanced, Creative).
- System personas: Quickly switch system prompts for roles such as Software Architect, Senior Developer, Security Auditor, and Technical Writer.
- Local SQLite storage: All conversations and messages are stored on disk in SQLite (`~/Documents/tomsllama/tomsllama.db`). Switching or creating chats never loses history.
- Three built-in themes:
  - Claude: Warm ivory paper background with terracotta accents.
  - Pond: Clean mineral light background with slate teal accents.
  - Dark: Low-contrast charcoal background with warm highlights.
- Drag and drop: Drop code or text files into the input box to automatically format them into code blocks.
- Offline fonts: Ships with local font files (Newsreader, Inter, Fira Code) so no fonts are loaded from Google servers.
- Dual-language support: Automatically adapts to English or German based on system locale.

## Keyboard Shortcuts

| Shortcut | Description |
| :--- | :--- |
| `Ctrl + N` | Start a new chat |
| `Ctrl + B` | Toggle sidebar visibility |
| `Ctrl + K` | Open quick switcher / search |
| `Esc` | Stop current generation |
| `F11` | Toggle fullscreen mode |
| `Enter` | Send message |
| `Shift + Enter` | Insert newline |

## Prerequisites

1. Install and start [Ollama](https://ollama.com):
   ```bash
   ollama serve
   ```

2. Pull one or more models:
   ```bash
   ollama pull qwen2.5:3b
   ollama pull qwen2.5-coder:7b
   ```

3. Flutter SDK (version 3.19 or higher) with Linux desktop prerequisites installed:
   ```bash
   # On Fedora:
   sudo dnf install clang cmake ninja-build gtk3-devel libayatana-appindicator-gtk3-devel
   
   # On Ubuntu / Debian:
   sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libayatana-appindicator3-dev
   
   # On Arch Linux:
   sudo pacman -S clang cmake ninja gtk3 libayatana-appindicator
   ```

## Building and Running

Clone the repository:
```bash
git clone https://github.com/tomsliikee/tomsllama.git
cd tomsllama
```

Fetch dependencies:
```bash
flutter pub get
```

Run in debug mode:
```bash
flutter run -d linux
```

Build a standalone release bundle:
```bash
flutter build linux --release
```

The compiled binary will be located in:
`build/linux/x64/release/bundle/tomsllama`

## Data and Configuration

All chat histories, custom personas, and settings are saved locally:

- Database: `~/Documents/tomsllama/tomsllama.db`
- Desktop entry: `~/.local/share/applications/tomsllama.desktop`
- Icons: `~/.local/share/icons/hicolor/`

To back up your chats, simply copy the `~/Documents/tomsllama/` directory.

## License

MIT License. See LICENSE for details.
