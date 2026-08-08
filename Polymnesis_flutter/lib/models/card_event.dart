/// Nature d'un événement de la vie d'une carte.
enum CardEventType {
  created, // carte créée à la main
  imported, // carte créée par l'import LTDS
  added, // origine inconnue (carte antérieure à l'historique) — libellé neutre
  correct, // bonne réponse au quotidien (+1 boîte)
  correctFast, // bonne réponse rapide (+2 boîtes)
  wrong, // mauvaise réponse (-1 boîte)
  skipped, // question passée (-1 boîte)
  boxesResized; // déplacée suite à un changement du nombre de boîtes

  static CardEventType fromString(String value) {
    return CardEventType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CardEventType.correct,
    );
  }

  /// Événement d'origine (naissance de la carte) : ne fait pas bouger de boîte.
  bool get isOrigin =>
      this == created || this == imported || this == added;
}

/// Un événement de l'historique d'une [FlashCard] : ce qui s'est passé,
/// de quelle boîte à quelle boîte, et quand. L'historique est conservé
/// en intégralité (pas de plafond) — ~55 octets par événement.
class CardEvent {
  final CardEventType type;
  final int fromBox;
  final int toBox;

  /// Date de l'événement (millisecondes epoch).
  final int at;

  const CardEvent({
    required this.type,
    required this.fromBox,
    required this.toBox,
    required this.at,
  });

  factory CardEvent.fromJson(Map<String, dynamic> json) {
    return CardEvent(
      type: CardEventType.fromString(json['type'] as String? ?? 'correct'),
      fromBox: json['from'] as int? ?? 1,
      toBox: json['to'] as int? ?? 1,
      at: json['at'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'from': fromBox,
        'to': toBox,
        'at': at,
      };

  /// Clé de déduplication pour l'union lors de la sync.
  String get dedupKey => '$at|${type.name}|$toBox';
}
