import 'dart:io';

class I18n {
  static bool get isGerman {
    try {
      final locale = Platform.localeName.toLowerCase();
      return locale.startsWith('de');
    } catch (_) {
      return false;
    }
  }

  // Common UI strings
  static String get appName => 'tomsllama';
  static String get newChat => isGerman ? '+ Neuer Chat' : '+ New Chat';
  static String get newChatTitle => isGerman ? 'Neuer Chat' : 'New Chat';
  static String get history => isGerman ? 'VERLAUF' : 'HISTORY';
  static String get noChats => isGerman ? 'Keine Chats vorhanden' : 'No conversations yet';
  static String get manageModels => isGerman ? 'Modelle verwalten...' : 'Manage models...';
  static String get noModels => isGerman ? 'Keine Modelle gefunden' : 'No models found';
  static String get selectModel => isGerman ? 'Modell wählen' : 'Select model';
  static String get roleLabel => isGerman ? 'Rolle: ' : 'Role: ';
  static String get send => isGerman ? 'Senden' : 'Send';
  static String get stop => isGerman ? 'Stopp' : 'Stop';
  static String get copy => isGerman ? 'Kopieren' : 'Copy';
  static String get copied => isGerman ? 'Kopiert!' : 'Copied!';
  static String get splitViewCanvas => 'Split-View Canvas';
  static String get regenerate => isGerman ? 'Neu generieren' : 'Regenerate';
  static String get copyMd => isGerman ? 'Markdown kopieren' : 'Copy MD';
  static String get thinkingProcess => isGerman ? 'Denkprozess' : 'Thinking Process';
  static String get thinkingOngoing => isGerman ? 'Denkprozess läuft...' : 'Thinking in progress...';
  static String get ctrlN => 'Ctrl N';
  static String get searchPlaceholder => isGerman ? 'Chats durchsuchen...' : 'Search conversations...';
  static String get modeFast => isGerman ? 'Schnell' : 'Fast';
  static String get modeFastDesc => isGerman ? 'Schnelle, direkte Antworten (T=0.3)' : 'Quick, direct answers (T=0.3)';
  static String get modeOptimal => isGerman ? 'Optimal' : 'Optimal';
  static String get modeOptimalDesc => isGerman ? 'Ausgewogene Allround-Qualität (T=0.7)' : 'Balanced all-round quality (T=0.7)';
  static String get modeThinking => isGerman ? 'Thinking' : 'Thinking';
  static String get modeThinkingDesc => isGerman ? 'Tiefes Nachdenken & strukturierte Analyse' : 'Deep step-by-step reasoning & analysis';
  static String get modeTitle => isGerman ? 'ANTWORT-MODUS' : 'RESPONSE MODE';
  static String get roleAndPrompt => isGerman ? 'ROLLE & HAUPTPROMPT' : 'ROLE & SYSTEM PROMPT';
  static String get settingsTitle => isGerman ? 'Einstellungen' : 'Settings';
  static String get close => isGerman ? 'Schließen' : 'Close';
  static String get deleteChatConfirm => isGerman ? 'Chat löschen?' : 'Delete chat?';
  static String get dropFilesToAttach => isGerman ? 'Dateien hier ablegen' : 'Drop files to attach';
  static String get willAttachToConversation =>
      isGerman ? 'Wird an diese Unterhaltung angehängt' : 'Will attach to this conversation';
  static String get toggleSidebar =>
      isGerman ? 'Seitenleiste umschalten (Strg+B)' : 'Toggle Sidebar (Ctrl+B)';
  static String get workspaces => 'Workspaces';
  static String get chats => 'Chats';
  static String get newWorkspace => isGerman ? '+ Neuer Workspace' : '+ New Workspace';
  static String get newWorkspaceTitle => isGerman ? 'Neuer Workspace' : 'New Workspace';
  static String get noWorkspaces => isGerman ? 'Keine Workspaces vorhanden' : 'No workspaces yet';
  static String get deleteWorkspaceConfirm => isGerman ? 'Workspace löschen?' : 'Delete workspace?';
  static String get workspacePromptTitle => isGerman ? 'WORKSPACE PROMPT (DAUERHAFT)' : 'WORKSPACE PROMPT (PERSISTENT)';
  static String get workspaceContextTitle => isGerman ? 'WORKSPACE KNOWLEDGE / KONTEXT' : 'WORKSPACE KNOWLEDGE / CONTEXT';
  static String get askInWorkspace =>
      isGerman ? 'Frage stellen oder neuen Chat im Workspace starten...' : 'Ask a question or start a chat in this workspace...';
  static String get workspaceChatsTitle => isGerman ? 'CHATS IN DIESEM WORKSPACE' : 'CHATS IN THIS WORKSPACE';
  static String get contextActive => isGerman ? 'Workspace Context: Aktiv' : 'Workspace Context: Active';
  static String get contextPaused => isGerman ? 'Workspace Context: Pausiert' : 'Workspace Context: Paused';
  static String get workspaceNameLabel => isGerman ? 'Name des Workspaces' : 'Workspace Name';
  static String get workspaceNameHint => isGerman ? 'z. B. Projekt Erlebnisplaner' : 'e.g. Project Mobile App';
  static String get create => isGerman ? 'Erstellen' : 'Create';
  static String get cancel => isGerman ? 'Abbrechen' : 'Cancel';
  static String get backToHub => isGerman ? 'Workspace-Hub' : 'Workspace Hub';

  static String get delete => isGerman ? 'Löschen' : 'Delete';
  static String get save => isGerman ? 'Speichern' : 'Save';
  static String get addFile => isGerman ? 'Datei hinzufügen' : 'Add File';
  static String get attach => isGerman ? 'Anhängen' : 'Attach';
  static String get openProjectWorkspace =>
      isGerman ? 'Projekt-Workspace öffnen...' : 'Open Project Workspace...';
  static String get attachFolderFiles =>
      isGerman ? 'Ordner-Dateien anhängen...' : 'Attach Folder Files...';
  static String get attachFiles =>
      isGerman ? 'Dateien anhängen...' : 'Attach Files...';
  static String get atMentionNavigationHint =>
      isGerman ? '↑↓ zum Navigieren • Enter/Tab zum Auswählen' : '↑↓ to navigate • Enter/Tab to select';
  static String get workspaceFilesPrefix =>
      isGerman ? 'Workspace-Dateien' : 'Workspace Files';
  static String get noModelsInstalled =>
      isGerman ? 'Keine Modelle installiert' : 'No models installed';
  static String deleteWorkspaceConfirmMessage(String name) => isGerman
      ? 'Möchtest du den Workspace "$name" und alle zugehörigen Chats und Dateien wirklich löschen?'
      : 'Do you really want to delete the workspace "$name" and all associated chats and files?';
  static String workspaceHubSubtitle(int chatsCount, int filesCount, int tokensCount) => isGerman
      ? 'Workspace Hub • $chatsCount Chats • $filesCount Kontext-Dateien (~$tokensCount Tokens)'
      : 'Workspace Hub • $chatsCount chats • $filesCount context files (~$tokensCount tokens)';
  static String get workspacePromptHint => isGerman
      ? 'Gib hier dauerhafte Instruktionen, Coding-Regeln oder Rollenanweisungen für diesen Workspace ein (z. B. "Du bist Principal Engineer, antworte präzise auf Deutsch")...'
      : 'Enter persistent instructions, coding rules, or role guidance for this workspace (e.g. "You are a principal engineer, reply concisely in English")...';
  static String get workspaceDropFilesHint => isGerman
      ? 'Dateien hier ablegen. Sie werden in jedem Chat dieses Workspaces automatisch geladen.'
      : 'Drop files here. They will be loaded automatically into every chat in this workspace.';
  static String get workspaceNoFilesHint => isGerman
      ? 'Noch keine Dateien hinterlegt. Ziehe Dokumente oder Code hierher.'
      : 'No files added yet. Drop documents or code files here.';
  static String get workspaceNoChatsHint => isGerman
      ? 'Noch keine Chats in diesem Workspace vorhanden.\nStelle oben eine Frage, um die erste Unterhaltung zu starten.'
      : 'No chats in this workspace yet.\nAsk a question above to start the first conversation.';
  static String workspaceConversationsCount(int count) => isGerman
      ? '$count Konversationen'
      : '$count Conversations';

  static String get totalLabel => isGerman ? 'Gesamt' : 'Total';

  static String get noSpeedTestedYet => isGerman
      ? 'Noch keine Geschwindigkeit getestet, bitte erste Nachricht senden'
      : 'No speed tested yet, please write first message';

  static String totalAttachedTokens(int tokens) {
    final tokenStr = tokens >= 1000 ? '~${(tokens / 1000).toStringAsFixed(1)}k' : '~$tokens';
    return isGerman ? 'Gesamt: $tokenStr tok' : 'Total: $tokenStr tok';
  }

  static String cpuLeadTime(int tokens) {
    final estSec = (tokens / 40.0).round();
    final timeStr = estSec >= 60 ? '${(estSec / 60.0).toStringAsFixed(1)} Min' : '${estSec}s';
    return isGerman ? '• CPU-Vorlauf: ca. $timeStr' : '• CPU lead time: ~$timeStr';
  }

  static String get readingPdf =>
      isGerman ? 'Lese PDF-Dokument ein...' : 'Analyzing PDF document...';
  static String cpuEvaluatingPrompt(int tokens) => isGerman
      ? 'CPU evaluiert Kontext (~$tokens Tokens)...'
      : 'CPU evaluating prompt context (~$tokens tokens)...';
  static String attachedFilePrefix(String filename) =>
      isGerman ? 'Datei: $filename' : 'File: $filename';

  static String cpuEvaluatingContext(String tokenStr, String remainingStr) => isGerman
      ? 'CPU evaluiert Kontext ($tokenStr Tokens • noch ~$remainingStr)...'
      : 'CPU evaluating context ($tokenStr tokens • ~$remainingStr left)...';
  static String cpuFinalizingContext(String tokenStr, int seconds) => isGerman
      ? 'CPU finalisiert Kontext ($tokenStr Tokens, ${seconds}s)...'
      : 'CPU finalizing context ($tokenStr tokens, ${seconds}s)...';

  static String get subtitle => isGerman
      ? 'Lokales, sicheres Interface für Ollama'
      : 'Local, secure interface for Ollama';

  static List<String> get thinkingPhrases => isGerman
      ? [
          'Kocht etwas Schönes zusammen...',
          'Denkt gründlich nach...',
          'Verbindet die Punkte...',
          'Feilt an der Antwort...',
          'Zieht logische Schlüsse...',
        ]
      : [
          'Cooking something up...',
          'Thinking it through...',
          'Connecting the dots...',
          'Brewing thoughts...',
          'Crafting your response...',
        ];

  static String composerPlaceholder(String model) {
    return isGerman
        ? 'Nachricht an $model...'
        : 'Message $model...';
  }

  // Settings & Theme
  static String get theme => isGerman ? 'Design' : 'Theme';
  static String get themeClaudeAlabaster => 'Claude (Alabaster)';
  static String get themePondMint => 'Pond (Mint)';
  static String get themeDarkCarbon => 'Dark (Carbon)';
  static String get themePondDarkMineral => 'Pond Dark (Mineral)';
  static String get ollamaApiUrl => 'Ollama API URL';
  static String get defaultPersona => isGerman ? 'Standard-Persona' : 'Default Persona';
  static String get saveAndClose => isGerman ? 'Speichern & Schließen' : 'Save & Close';

  // Model Manager
  static String get modelManager => isGerman ? 'Modellverwaltung' : 'Model Manager';
  static String get pull => isGerman ? 'Herunterladen' : 'Pull';
  static String get installedModels => isGerman ? 'Installierte Modelle' : 'Installed Models';
  static String get modelHintText => 'e.g., qwen2.5-coder:1.5b';

  // Persona Dropdown
  static String get additionalRoles => isGerman ? 'ZUSÄTZLICHE' : 'ADDITIONAL';

  // Temperature Presets
  static String get tempCode => '0.2 Code';
  static String get tempNormal => '0.7 Normal';
  static String get tempCreative => isGerman ? '1.0 Kreativ' : '1.0 Creative';

  // Canvas & Code Block
  static String get canvas => 'Canvas';

  // Quick Switcher
  static String get quickSearchPlaceholder => isGerman
      ? 'Chats durchsuchen... (Tippen zum Filtern)'
      : 'Search chats... (Type to filter)';
  static String get searchChats => isGerman ? 'Chats durchsuchen...' : 'Search chats...';

  // Export
  static String get you => isGerman ? 'Du' : 'You';
  static String get assistant => 'Assistant';
  static String get thoughtProcess => isGerman ? 'Denkprozess' : 'Thought Process';

  // System Tray
  static String get showApp => isGerman ? 'tomsllama anzeigen' : 'Show tomsllama';
  static String get exitApp => isGerman ? 'Beenden' : 'Exit';

  // Drag-and-Drop
  static String get dropFileHere => isGerman ? 'Datei hier ablegen...' : 'Drop file here...';

  // Persona Names
  static String get personaStandard => 'Standard';
  static String get personaStandardDesc => isGerman
      ? 'Ausgewogener, präziser und ruhiger Allround-Assistent.'
      : 'Balanced, precise and calm all-round assistant.';
  static String get personaArchitect => 'Architect';
  static String get personaArchitectDesc => isGerman
      ? 'System-Design, SOLID, Skalierbarkeit & saubere Architektur.'
      : 'System design, SOLID, scalability & clean architecture.';
  static String get personaCoder => 'Senior Coder';
  static String get personaCoderDesc => isGerman
      ? 'Pragmatischer, fehlerfreier und performanter Produktionscode.'
      : 'Pragmatic, bug-free and performant production code.';
  static String get personaSecurity => 'Security Guard';
  static String get personaSecurityDesc => isGerman
      ? 'Schwachstellenanalyse, Härtung und Risikominimierung.'
      : 'Vulnerability analysis, hardening and risk mitigation.';
  static String get personaWriter => 'Tech Writer';
  static String get personaWriterDesc => isGerman
      ? 'Prägnante Dokumentation und Spezifikationen.'
      : 'Concise documentation and specifications.';
  static String get personaAnalyst => 'Deep Analyst';
  static String get personaAnalystDesc => isGerman
      ? 'Strukturierte Logik-, Daten- und Ursachenanalyse.'
      : 'Structured logic, data and root cause analysis.';
  static String get personaPlanner => 'Project Planner';
  static String get personaPlannerDesc => isGerman
      ? 'Roadmaps, Sprint-Ziele, Meilensteine & strukturierte Projektplanung.'
      : 'Roadmaps, sprint goals, milestones & structured project planning.';
  static String get personaCreativeWriter => isGerman ? 'Kreativer Schreiber' : 'Creative Writer';
  static String get personaCreativeWriterDesc => isGerman
      ? 'Storytelling, kreative Texte, Drehbücher & fesselnde Prosa.'
      : 'Storytelling, creative texts, screenplays & captivating prose.';
  static String get personaMarketing => isGerman ? 'Marketing-Experte' : 'Marketing Expert';
  static String get personaMarketingDesc => isGerman
      ? 'Positionierung, Go-to-Market Strategien & Conversion Copywriting.'
      : 'Positioning, go-to-market strategies & conversion copywriting.';
  static String get personaSocialMedia => isGerman ? 'Social-Media-Experte' : 'Social Media Expert';
  static String get personaSocialMediaDesc => isGerman
      ? 'Plattform-Strategien, Hooks, Viralität & Community Growth.'
      : 'Platform strategies, hooks, virality & community growth.';
}
