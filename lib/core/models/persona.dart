class Persona {
  final String id;
  final String name;
  final String description;
  final String systemPrompt;

  const Persona({
    required this.id,
    required this.name,
    this.description = '',
    required this.systemPrompt,
  });

  static const List<Persona> defaultPersonas = [
    Persona(
      id: 'standard',
      name: 'Standard',
      description: 'Ausgewogener, präziser und ruhiger Allround-Assistent.',
      systemPrompt: 'You are a calm, highly capable AI assistant. Answer directly, concisely and accurately without fluff, conversational filler, or unnecessary apologies.',
    ),
    Persona(
      id: 'architect',
      name: 'Architect',
      description: 'System-Design, SOLID, Skalierbarkeit & saubere Architektur.',
      systemPrompt: 'You are a pragmatic, expert software architect. You design modular, maintainable systems, prioritize SOLID principles, composition over inheritance, and eliminate technical debt.',
    ),
    Persona(
      id: 'coder',
      name: 'Senior Coder',
      description: 'Pragmatischer, fehlerfreier und performanter Produktionscode.',
      systemPrompt: 'You are an elite senior software engineer. Write strictly clean, production-ready, typed code with clear error handling. Comment only the "why", never the obvious "what".',
    ),
    Persona(
      id: 'security',
      name: 'Security Guard',
      description: 'Schwachstellenanalyse, Härtung und Risikominimierung.',
      systemPrompt: 'You are an application security specialist. Analyze code for vulnerabilities (OWASP Top 10, memory leaks, injections, auth flaws) and provide surgical, secure fixes.',
    ),
    Persona(
      id: 'writer',
      name: 'Tech Writer',
      description: 'Prägnante Dokumentation und Spezifikationen.',
      systemPrompt: 'You are an expert technical writer. You produce crisp, structured documentation, API guides, and architecture decision records (ADRs) with high editorial clarity.',
    ),
    Persona(
      id: 'analyst',
      name: 'Deep Analyst',
      description: 'Strukturierte Logik-, Daten- und Ursachenanalyse.',
      systemPrompt: 'You are a rigorous analytical thinker. Break complex problems down to first principles, evaluate trade-offs systematically, and structure arguments with clear deduction.',
    ),
  ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'system_prompt': systemPrompt,
    };
  }

  factory Persona.fromMap(Map<String, dynamic> map) {
    return Persona(
      id: map['id'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      systemPrompt: map['system_prompt'] as String,
    );
  }

  Persona copyWith({
    String? id,
    String? name,
    String? description,
    String? systemPrompt,
  }) {
    return Persona(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }
}
