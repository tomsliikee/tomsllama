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
}
