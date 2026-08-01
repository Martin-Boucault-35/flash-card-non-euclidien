import 'card_event.dart';

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

  /// Réponses supplémentaires acceptées en plus de [answer] (variantes,
  /// orthographes, synonymes). Vide pour les cartes créées à la main ; remplie
  /// à l'import "La Table des Savoirs". N'est jamais affichée pendant le jeu.
  final List<String> acceptedAnswers;

  /// Horodatage (ms) de la dernière modification. Sert d'arbitre lors de la
  /// réconciliation de synchronisation (la version la plus récente gagne).
  final int updatedAt;

  /// Historique complet de la carte (création/import, montées/descentes de
  /// boîte au jeu quotidien), du plus ancien au plus récent. Pas de plafond.
  final List<CardEvent> history;

  FlashCard({
    required this.id,
    required this.theme,
    required this.answer,
    required this.triggers,
    required this.createdAt,
    this.leitnerBox = 1,
    int? nextReviewAt,
    this.acceptedAnswers = const [],
    int? updatedAt,
    this.history = const [],
  })  : nextReviewAt = nextReviewAt ?? createdAt,
        updatedAt = updatedAt ?? createdAt;

  /// Crée une copie de la carte avec des modifications optionnelles
  FlashCard copyWith({
    String? id,
    FlashCardTheme? theme,
    String? answer,
    List<String>? triggers,
    int? createdAt,
    int? leitnerBox,
    int? nextReviewAt,
    List<String>? acceptedAnswers,
    int? updatedAt,
    List<CardEvent>? history,
  }) {
    return FlashCard(
      id: id ?? this.id,
      theme: theme ?? this.theme,
      answer: answer ?? this.answer,
      triggers: triggers ?? List.from(this.triggers),
      createdAt: createdAt ?? this.createdAt,
      leitnerBox: leitnerBox ?? this.leitnerBox,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      acceptedAnswers: acceptedAnswers ?? List.from(this.acceptedAnswers),
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? List.from(this.history),
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
      acceptedAnswers:
          List<String>.from(data['acceptedAnswers'] as List? ?? const []),
      updatedAt: data['updatedAt'] as int? ?? createdAt,
      history: (data['history'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CardEvent.fromJson)
          .toList(),
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
      'acceptedAnswers': acceptedAnswers,
      'updatedAt': updatedAt,
      'history': history.map((e) => e.toJson()).toList(),
    };
  }

  /// Toutes les réponses considérées comme correctes (principale + variantes),
  /// après normalisation et dédoublonnage. Utilisé pour la correction en jeu.
  List<String> get allAcceptedNormalized {
    final set = <String>{};
    for (final a in [answer, ...acceptedAnswers]) {
      final n = normalizeAnswer(a);
      if (n.isNotEmpty) set.add(n);
    }
    return set.toList();
  }

  /// Vrai si [input] correspond à la réponse principale OU à une variante
  /// acceptée (comparaison après [normalizeAnswer]).
  bool matchesAnswer(String input) {
    final n = normalizeAnswer(input);
    if (n.isEmpty) return false;
    return allAcceptedNormalized.contains(n);
  }

  /// Normalisation pour comparer des réponses. On rend la comparaison tolérante :
  /// minuscule, accents retirés (é→e, ô→o, å→a, ø→o…), puis suppression de TOUT
  /// ce qui n'est pas lettre/chiffre (espaces, traits d'union, apostrophes,
  /// ponctuation). Ainsi « orang-outan », « orang outan » et « orangoutan »
  /// donnent la même chose, et on n'a pas à se soucier des accents/tirets.
  /// Source unique partagée par les deux modes de jeu.
  static String normalizeAnswer(String s) {
    final lower = s.trim().toLowerCase();
    final buf = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final ch = lower[i];
      buf.write(_accentMap[ch] ?? ch);
    }
    // Tout sauf [a-z0-9] est retiré (séparateurs, ponctuation, accents non mappés).
    return buf.toString().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Accents/caractères latins courants → équivalent ASCII. Les lettres non
  /// couvertes ici tomberaient sinon dans la suppression `[^a-z0-9]`.
  static const Map<String, String> _accentMap = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a', 'ª': 'a',
    'è': 'e', 'ê': 'e', 'ë': 'e', 'é': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e',
    'ì': 'i', 'î': 'i', 'ï': 'i', 'í': 'i', 'ī': 'i', 'į': 'i', 'ı': 'i',
    'ò': 'o', 'ô': 'o', 'ö': 'o', 'ó': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', 'ū': 'u', 'ů': 'u',
    'ý': 'y', 'ÿ': 'y',
    'ñ': 'n', 'ń': 'n',
    'ç': 'c', 'ć': 'c', 'č': 'c',
    'š': 's', 'ś': 's', 'ß': 'ss',
    'ž': 'z', 'ź': 'z', 'ż': 'z',
    'ł': 'l', 'đ': 'd', 'ğ': 'g', 'ð': 'd', 'þ': 'th',
    'œ': 'oe', 'æ': 'ae',
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlashCard && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
