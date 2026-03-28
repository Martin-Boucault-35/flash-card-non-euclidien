/// Enum représentant les thèmes disponibles pour les cartes
enum FlashCardTheme {
  classique('Classique'),
  histoire('Histoire'),
  geographie('Géographie'),
  moderne('Moderne'),
  animaux('Animaux'),
  sciences('Sciences'),
  sport('Sport'),
  cultureG('Culture Générale');

  final String displayName;
  const FlashCardTheme(this.displayName);

  static FlashCardTheme fromString(String value) {
    return FlashCardTheme.values.firstWhere(
      (e) => e.displayName == value || e.name == value,
      orElse: () => FlashCardTheme.cultureG,
    );
  }
}

/// Modèle représentant une carte mémoire
class FlashCard {
  final String id;
  final FlashCardTheme theme;
  final String answer;
  final List<String> triggers;
  final int createdAt;
  final int leitnerBox;
  final int nextReviewAt;

  FlashCard({
    required this.id,
    required this.theme,
    required this.answer,
    required this.triggers,
    required this.createdAt,
    this.leitnerBox = 1,
    int? nextReviewAt,
  }) : nextReviewAt = nextReviewAt ?? createdAt;

  /// Crée une copie de la carte avec des modifications optionnelles
  FlashCard copyWith({
    String? id,
    FlashCardTheme? theme,
    String? answer,
    List<String>? triggers,
    int? createdAt,
    int? leitnerBox,
    int? nextReviewAt,
  }) {
    return FlashCard(
      id: id ?? this.id,
      theme: theme ?? this.theme,
      answer: answer ?? this.answer,
      triggers: triggers ?? List.from(this.triggers),
      createdAt: createdAt ?? this.createdAt,
      leitnerBox: leitnerBox ?? this.leitnerBox,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
    );
  }

  /// Conversion depuis JSON (pour Supabase)
  factory FlashCard.fromJson(Map<String, dynamic> json) {
    // Support both direct format and nested 'data' format from Supabase
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final createdAt = data['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    return FlashCard(
      id: json['id'] as String? ?? data['id'] as String,
      theme: FlashCardTheme.fromString(data['theme'] as String? ?? 'Culture Générale'),
      answer: data['answer'] as String? ?? '',
      triggers: List<String>.from(data['triggers'] as List? ?? []),
      createdAt: createdAt,
      leitnerBox: data['leitnerBox'] as int? ?? 1,
      nextReviewAt: data['nextReviewAt'] as int? ?? createdAt,
    );
  }

  /// Conversion vers JSON (pour Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'theme': theme.displayName,
      'answer': answer,
      'triggers': triggers,
      'createdAt': createdAt,
      'leitnerBox': leitnerBox,
      'nextReviewAt': nextReviewAt,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlashCard && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
