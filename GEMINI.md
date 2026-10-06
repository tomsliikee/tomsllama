# AGENTS.md — Project Guide & Blueprint for 'tomsllama'

> **Primary Objective:** Build and maintain **`tomsllama`**, a hyper-clean, minimal, anti-ai-slop native desktop client for local Ollama models on Linux and Windows, written in Flutter.
> **Design Influences:** Claude's Web UI (warm ivory paper, subtle terracotta accents, editorial serif typography) and Pond / Butterfly OS (sharp 1px hairlines, mineral monochrome gray, Geist Mono precision).

---

## 1. Project Philosophy & Core Rules

> [!CAUTION]
> **MANDATORY AGENT RULE — ZERO GUESSWORK & IMMEDIATE STOP:**
> Bei JEDER Unklarheit, jedem unerwarteten Verhalten, jedem Bug oder Architektur-Dilemma muss der Agent **SOFORT STOPPEN** und den Benutzer konsultieren.
> **Niemals Annahmen treffen, niemals stillschweigend improvisieren!**
> Wenn etwas auch nur im Ansatz uneindeutig ist: Innehalten, das genaue Problem präzise beschreiben, Handlungsoptionen aufzeigen und auf die Antwort des Nutzers warten.

### 1.1 Strict "Anti-AI-Slop" Design Philosophy
- **NO Emojis anywhere in the UI:** Absolutely no 🤖, ✨, 🧠, 🚀, or generic AI icons.
- **NO Kitsch / AI Slop:** No purple/cyan gradients, no glowing borders, no glassmorphism cards with drop shadows, no cartoonish speech bubbles.
- **Atmosphere:** Calm, silent, architectural, and editorial. Generous whitespace, razor-sharp 1px hairline borders (`#E5E4DC` / `#E2E2E2`), subdued low-contrast accents.
- **Brand Logo (Gemini × Diamond):**
  - Position: Top-left in CSD header bar (`20x20px`).
  - Form: Geometrical vector fusion of Gemini's four-pointed star and faceted diamond cut lines.
  - Style: Clean 1.6px geometric strokes in `var(--accent)`, subtle 25% opacity center facet fill, zero 3D-kitsch.
- **Icons:** One family at one weight: Phosphor Light, bundled as `assets/fonts/PhosphorLight.ttf`. Use them only through `AppIcons` (`lib/core/constants/app_icons.dart`), which names icons by meaning. Never use Material `Icons.*`.
- **Typography (two families, all themes):**
  - **Everything that is read:** *Newsreader* (serif): answers, the user's own messages and input, chat and workspace titles, headings, dialog titles.
  - **Everything that labels, measures or is code:** *Geist Mono*: controls, chips, section labels, metadata, telemetry, code.
  - **No sans-serif.** Inter and FiraCode were removed.
  - **Scale:** only the styles in `AppTypography` (`micro` 10.5, `label` 12, `small` 15, `body` 16.5, `title` 20, `display` 30, plus `code` and `telemetry`). Do not introduce other sizes.
  - **Zero Network Reliance:** Fonts are embedded in `assets/fonts/` for 100% offline privacy.
- **Design tokens (`lib/core/constants/app_tokens.dart`):**
  - **Radii:** `panel` 18 → `card` 12 → `control` 8 → `pill`. A shape nested in another uses the next step down.
  - **Motion:** `fast` 120 ms (hover), `base` 200 ms (state), `slow` 320 ms (layout); curves `standard` and `spring`.
  - **Elevation:** one shadow, `AppElevation.floating`, only for surfaces that float (composer, popovers, dialogs, a dragged item). Everything else separates by fill.
  - **Colour:** no colour literals outside `app_colors.dart`; states use the theme's accent, never ad-hoc green, red or amber.
- **Shared widgets (`lib/core/widgets/`):** build controls from `Pressable`, `AppPill`, `AppIconButton`, `AppButton`, `AppDialog`, `appInputDecoration` and `InkFadeIn` instead of hand-rolling hover and press behaviour.
- **Reviewing a design change:** `flutter test --update-goldens test/tool/render_screens.dart` writes PNGs of the main screens in every theme to `build/renders/`.

### 1.2 Micro-Animations & Playful Physics (Pond-Style)
Animationen sind sanft, meditativ und organisch wie Naturphänomene (kein lautes UI-Feuerwerk):
1. **Logo Ruheatmen:** Das Logo pulsiert **nur während der Generierung** in einem langsamen 3.5s Atemrhythmus (Scale 1.0 → 1.06); im Leerlauf steht es vollkommen still.
2. **Pond Button Ripple:** Klicks auf interaktive Buttons erzeugen eine ultrafeine 1px-Wasserwelle, die sich sanft ausbreitet und verblasst.
3. **Tinte-auf-Papier Fade:** Neue Chat-Nachrichten und Codeblöcke gleiten mit minimalem vertikalem Versatz (4px) und weichem Einblenden (Fade-In) hinein.
4. **Button Spring Physics:** Interaktive Knöpfe reagieren auf Klick und Release mit einer feinen, elastischen Dämpfung (`cubic-bezier(0.34, 1.56, 0.64, 1)`).
5. **Origami Fold:** Das `<think>`-Akkordeon entfaltet sich sanft wie ein gefalteter Papierbogen ohne harte Sprünge.

### 1.3 Hardware Context & Target Specs
- **Machine:** Intel Core i5-8350U (4 Cores / 8 Threads, 1.70 GHz base, up to 3.6 GHz boost, 15W TDP, AVX2).
- **RAM:** 16 GB DDR4 (7.9 GB free).
- **GPU:** Integrated Intel UHD Graphics 620 (Inference runs purely on CPU).
- **Inference Reality:**
  - 3B models (`qwen2.5:3b`, `qwen2.5-coder:3b`) are the primary daily drivers (~12–15 tokens/sec).
  - 7B models (`qwen2.5-coder:7b`) are heavyweight backups (~3–5 tokens/sec).
  - **Sliding Context Window Rule:** Must enforce a sliding context window (default 4,096 tokens) so large conversation histories do not bog down CPU inference.

---

## 2. Palettes & Theming (With Subtle Accent Anchors)

Accent colors are applied strictly as subtle visual anchors:
1. **Brand Logo & Model Online Dot:** Top-left header logo & model status indicator.
2. **Active Chat Item:** 2px vertical indicator bar on the left edge of selected conversation.
3. **Composer Focus:** Subtle 1px border highlight when the input field is active.
4. **Primary Actions:** Send button background, code block language badge (`dart`, `python`).
5. **Interactive Hover States:** Subtle color shift on links (`Regenerate`, `Copy MD`, `Persona-Chip`).

### 2.1 Claude Warm (Default)
- **Background / Paper:** `#FAF9F5` (Soft ivory / warm cream)
- **Surface / Sidebar:** `#F3F2EB` (Warm sand paper)
- **Primary Text:** `#1F1E1D` (Deep warm anthracite, never harsh `#000000`)
- **Secondary Text:** `#73726E` (Subdued muted gray)
- **Hairline Borders:** `#E5E4DC` (1px subtle divider)
- **Accent:** `#C86D51` (Earthy terracotta / clay)
- **Accent Subtle (Bg):** `#F6EDE8`
- **Code Block Background:** `#F0EFEA`
- **Body Font:** *Newsreader* (Serif)

### 2.2 Pond Mineral
- **Background / Paper:** `#FBFBFB` (Clean mineral white)
- **Surface / Sidebar:** `#F4F4F4` (Ash gray)
- **Primary Text:** `#111111` (Deep slate black)
- **Secondary Text:** `#666666`
- **Hairline Borders:** `#E2E2E2`
- **Accent:** `#3A6B7C` (Pond Mineral Slate Teal)
- **Accent Subtle (Bg):** `#EDF3F5`
- **Code Block Background:** `#EFEFEF`
- **Body Font:** *Newsreader* (Serif — same calm editorial reading flow)

### 2.3 Dark Anthracite
- **Background / Paper:** `#1A1918` (Warm dark slate)
- **Surface / Sidebar:** `#141312`
- **Primary Text:** `#ECEBE7` (Warm light stone)
- **Secondary Text:** `#8C8B85`
- **Hairline Borders:** `#2C2B29`
- **Accent:** `#E08264` (Warm copper)
- **Accent Subtle (Bg):** `#2A1F1B`
- **Code Block Background:** `#201F1E`
- **Body Font:** *Newsreader* (Serif)

---

## 3. Complete File Tree

```text
tomsllama/
├── AGENTS.md                                       # This document
├── GEMINI.md                                       # Mirror document
├── pubspec.yaml                                    # Dependencies & asset declarations
├── analysis_options.yaml                           # Strict linting & analyzer rules
├── assets/
│   └── fonts/
│       ├── Newsreader-Regular.ttf
│       ├── Newsreader-Italic.ttf
│       ├── Newsreader-SemiBold.ttf
│       └── GeistMono-Regular.ttf
├── lib/
│   ├── main.dart                                   # App root, desktop window setup, ProviderScope
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart                     # Color constants (Claude Warm, Pond, Dark)
│   │   │   ├── app_typography.dart                 # TextStyles (Newsreader & Geist Mono)
│   │   │   ├── app_constants.dart                  # Ports, timeouts, default limits
│   │   │   └── app_shortcuts.dart                  # Global shortcuts (Ctrl+N, Ctrl+B, F11, etc.)
│   │   ├── models/
│   │   │   ├── message.dart                        # Message entity with branching & think block
│   │   │   ├── conversation.dart                   # Conversation entity with telemetry stats
│   │   │   ├── ollama_model.dart                   # Model metadata (name, size, digest)
│   │   │   ├── pull_progress.dart                  # Download status & byte progress
│   │   │   └── persona.dart                        # Role presets (Architect, Designer, etc.)
│   │   ├── services/
│   │   │   ├── ollama_service.dart                 # HTTP API, SSE streaming, pull, delete
│   │   │   ├── database_service.dart               # SQLite schema & CRUD for chats and branches
│   │   │   ├── context_manager.dart                # Sliding window & token budget for CPU guard
│   │   │   ├── title_service.dart                  # Background auto-summarizer via mini model
│   │   │   ├── export_service.dart                 # Export to Markdown (.md), JSON, HTML
│   │   │   └── window_service.dart                 # CSD window controls, tray, Zen mode
│   │   ├── theme/
│   │   │   ├── app_theme.dart                      # ThemeMode state notifier & contracts
│   │   │   ├── claude_theme.dart                   # Warm paper & terracotta theme
│   │   │   ├── pond_theme.dart                     # Mineral white & slate theme
│   │   │   └── dark_theme.dart                     # Warm anthracite theme
│   │   └── utils/
│   │       ├── think_parser.dart                   # Real-time regex/state parser for <think>
│   │       ├── smooth_streamer.dart                # Ink-on-paper ticker for chunk smoothing
│   │       └── file_utils.dart                     # Drag & Drop file reader & formatting
│   └── features/
│       ├── shell/
│       │   └── widgets/
│       │       ├── csd_header_bar.dart             # Frameless CSD title bar with window buttons
│       │       └── desktop_shell.dart              # Base shell (CSD + Sidebar + Chat + Canvas)
│       ├── chat/
│       │   ├── controllers/
│       │   │   └── chat_controller.dart            # StateNotifier for conversation & active stream
│       │   ├── widgets/
│       │   │   ├── chat_viewport.dart              # ScrollView with smart auto-scroll
│       │   │   ├── message_bubble.dart             # Frameless editorial message layout
│       │   │   ├── think_block_view.dart           # Hairline collapsible accordion for <think>
│       │   │   ├── branch_switcher.dart            # < 1/2 > switcher for edited messages
│       │   │   ├── code_block_view.dart            # Syntax highlighting, line numbers, copy, Canvas button
│       │   │   ├── markdown_view.dart              # Markdown renderer with LaTeX formula support
│       │   │   ├── composer_bar.dart               # Expanding text input, drag & drop target
│       │   │   └── telemetry_footer.dart           # 11px monospace: tok/s, total tokens, latency
│       │   └── canvas/
│       │       ├── artifact_canvas_view.dart       # 50/50 split pane for code/docs
│       │       └── canvas_controller.dart          # Active artifact state & split view toggle
│       ├── sidebar/
│       │   ├── controllers/
│       │   │   └── sidebar_controller.dart         # Search query & active chat selection
│       │   └── widgets/
│       │       ├── sidebar_view.dart               # Collapsible drawer (Ctrl+B)
│       │       ├── chat_list_item.dart             # Conversation item with title, pin, delete
│       │       └── search_bar_view.dart            # Instant local chat search
│       ├── models/
│       │   ├── controllers/
│       │   │   └── model_controller.dart           # Model list & pull progress state
│       │   └── widgets/
│       │       ├── model_selector_dropdown.dart    # Header dropdown
│       │       ├── quick_switcher_modal.dart       # Ctrl+K modal switcher
│       │       └── model_manager_dialog.dart       # Pull dialog with progress bar & delete
│       └── settings/
│           └── widgets/
│               └── settings_dialog.dart            # Theme selector, host URL, persona editor
└── test/
    ├── unit/
    │   ├── think_parser_test.dart                  # Unit test for <think> tag extraction
    │   ├── context_manager_test.dart               # Unit test for sliding window trimming
    │   ├── ollama_service_test.dart                # Mock tests for SSE streaming & REST
    │   ├── database_service_test.dart              # Tests for branching tree & SQLite CRUD
    │   └── export_service_test.dart                # Tests for Markdown, JSON, HTML export
    └── widget/
        ├── composer_bar_test.dart                  # Widget test for input & send trigger
        └── code_block_view_test.dart               # Widget test for line numbers & copy
```

---

## 4. Dependencies (`pubspec.yaml`)

```yaml
name: tomsllama
description: A calm, minimalist, anti-ai-slop native desktop client for Ollama.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.19.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.5.1

  # Network & Streaming
  http: ^1.2.1

  # Database & File System
  sqflite_common_ffi: ^2.3.3
  path_provider: ^2.1.3
  path: ^1.9.0

  # Markdown, Code Highlighting & Math
  flutter_markdown: ^0.6.22
  markdown: ^7.2.2
  flutter_highlight: ^0.7.0
  highlight: ^0.7.0
  flutter_math_fork: ^0.7.2

  # Desktop Integration
  window_manager: ^0.3.9
  tray_manager: ^0.2.3
  desktop_drop: ^0.4.4

  # Utilities
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.2

flutter:
  uses-material-design: false
  assets:
    - assets/fonts/
  fonts:
    - family: Newsreader
      fonts:
        - asset: assets/fonts/Newsreader-Regular.ttf
        - asset: assets/fonts/Newsreader-Italic.ttf
          style: italic
        - asset: assets/fonts/Newsreader-SemiBold.ttf
          weight: 600
    - family: GeistMono
      fonts:
        - asset: assets/fonts/GeistMono-Regular.ttf
```

---

## 5. Detailed 12-Phase Roadmap

### Phase 1: Project Setup & Asset Provisioning
- Run `flutter create --platforms=linux,windows .` in project directory.
- Apply `pubspec.yaml` and resolve packages with `flutter pub get`.
- Bundle offline font files (`Newsreader` and `Geist Mono`) into `assets/fonts/`.

### Phase 2: Design System, Theming & Typography
- Implement `app_colors.dart` with Claude Warm, Pond Mineral, and Dark Anthracite palettes.
- Implement `app_typography.dart` configuring Newsreader (Serif) and Geist Mono.
- Build theme classes in `lib/core/theme/`.

### Phase 3: Local SQLite Engine & Branching Schema
- Initialize `sqflite_common_ffi` in `database_service.dart`.
- Create tables: `conversations`, `messages` (with `parent_id`), `personas`.
- Implement tree-branching queries allowing message editing with version traversal (`< 1/2 >`).

### Phase 4: Ollama API Client & Streaming Engine
- Implement `ollama_service.dart` with `streamChat(...)`, `listModels()`, `pullModelStream(...)`, and `deleteModel(...)`.
- Implement `think_parser.dart` to split `<think>` content from the answer stream in real time.
- Implement `smooth_streamer.dart` (ticker-based interpolation) for seamless ink-on-paper streaming.

### Phase 5: Hardware Protection & Context Manager
- Implement `context_manager.dart` with sliding-window heuristic.
- Keep system prompt intact and trim older turns when approaching limit (4,096 tokens) to prevent CPU throttle on Intel i5-8350U.

### Phase 6: Code Block Engine, LaTeX & Markdown
- Implement `code_block_view.dart` with low-contrast syntax highlighting, language badge, line numbers toggle, word wrap toggle, 1-click copy, and "Open in Canvas" button.
- Implement `markdown_view.dart` with `flutter_markdown` and `flutter_math_fork` for LaTeX formulas ($E=mc^2$).

### Phase 7: Chat UI, Message Bubbles & Smart Scroll
- Implement `message_bubble.dart` (frameless editorial layout, `SelectableText.rich`, hover actions).
- Implement `think_block_view.dart` (collapsible hairline accordion showing duration & tokens).
- Implement `branch_switcher.dart` (`< 1/2 >`).
- Implement `telemetry_footer.dart` (`tok/s`, tokens, latency).
- Implement `chat_viewport.dart` with smart auto-scroll (stops on user scroll-up).

### Phase 8: Composer & Drag & Drop File Injection
- Implement `composer_bar.dart` with auto-expanding borderless input, `Enter` to send, `Shift+Enter` for newline, persona selector chip, and send/stop toggle.
- Integrate `desktop_drop` to ingest `.py`, `.dart`, `.txt`, `.json` files directly into the prompt as formatted markdown code blocks.

### Phase 9: Claude Artifacts Split-View Canvas
- Implement `artifact_canvas_view.dart` (50/50 vertical split pane for long code or documents).
- Allow user to chat in the left pane while code remains stationary in full height in the right pane.

### Phase 10: Sidebar, Search, Auto-Title & Export
- Implement `sidebar_view.dart` with chronological sections (Today, Yesterday, Older).
- Implement `search_bar_view.dart` with instant filtering.
- Implement `title_service.dart` (background auto-summary via `qwen2.5-coder:1.5b` with prompt-prefix fallback).
- Implement `export_service.dart` for 1-click export to Markdown (.md), JSON, and HTML.

### Phase 11: Model Management & Quick-Switcher
- Implement `model_selector_dropdown.dart` in the CSD header.
- Implement `quick_switcher_modal.dart` (`Ctrl+K` modal search).
- Implement `model_manager_dialog.dart` (in-app download with live byte progress bar and model deletion).
- Implement `settings_dialog.dart` (theme switch, Ollama URL, default parameters, persona editor).

### Phase 12: Desktop CSD Header, Zen Mode, Tray & Verification
- Implement `csd_header_bar.dart` using `window_manager` (frameless titlebar with window buttons).
- Setup global shortcuts: `Ctrl+N` (New Chat), `Ctrl+B` (Sidebar toggle), `Ctrl+K` (Model search), `Esc` (Stop), `F11` (Zen Focus Mode).
- Integrate `tray_manager` for background minimization.
- Run verification tests: `flutter analyze`, `flutter test`, and `flutter build linux --debug`.

---

## 6. Coding Standards for AI Agents
- **IMMEDIATE USER CONSULTATION:** Bei der geringsten Unklarheit, fehlenden Spezifikationen, Build-Fehlern oder unerwarteten Seiteneffekten: **SOFORT STOPPEN** und den Benutzer fragen. Niemals eigenmächtig weiterraten!
- **Surgical Updates:** Touch only files explicitly relevant to the active task.
- **Type Safety:** Never use `dynamic` or bypass the Dart type system without strict justification.
- **Pure Functions & Composition:** Prefer composition over inheritance; prefer pure functions over side effects.
- **Documentation:** Comment the "why" (architectural intent, edge cases), never just the "what".
- **Verification:** Execute `flutter analyze` and `flutter test` after every major implementation step.
