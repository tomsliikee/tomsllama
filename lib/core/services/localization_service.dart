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
  static String get temperature => isGerman ? 'TEMPERATUR' : 'TEMPERATURE';
  static String get roleAndPrompt => isGerman ? 'ROLLE & HAUPTPROMPT' : 'ROLE & SYSTEM PROMPT';
  static String get settingsTitle => isGerman ? 'Einstellungen' : 'Settings';
  static String get close => isGerman ? 'Schließen' : 'Close';
  static String get deleteChatConfirm => isGerman ? 'Chat löschen?' : 'Delete chat?';
  static String get dropFilesToAttach => isGerman ? 'Dateien hier ablegen' : 'Drop files to attach';
  static String get willAttachToConversation =>
      isGerman ? 'Wird an diese Unterhaltung angehängt' : 'Will attach to this conversation';

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
        ? 'Nachricht an $model schreiben... (Enter zum Senden, Shift+Enter für Zeilenumbruch)'
        : 'Message $model... (Enter to send, Shift+Enter for new line)';
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
