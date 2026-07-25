import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/card_model.dart';

/// Une question récupérée depuis l'API de "La Table des Savoirs".
class LtdsQuestion {
  final int day;
  final String level; // 'abordable' | 'expert'
  final int order;
  final String siteTheme; // thème brut renvoyé par le site
  final String question;
  final List<String> validAnswers;

  LtdsQuestion({
    required this.day,
    required this.level,
    required this.order,
    required this.siteTheme,
    required this.question,
    required this.validAnswers,
  });

  /// Réponse attendue = première réponse valide (la version propre).
  String get answer => validAnswers.isNotEmpty ? validAnswers.first : '';

  /// Thème de l'app correspondant au thème du site.
  FlashCardTheme get theme => LtdsImportService.mapTheme(siteTheme);
}

/// Levée quand l'API renvoie 401 : le jeton est invalide ou expiré.
class LtdsAuthException implements Exception {
  final String message;
  LtdsAuthException([this.message = 'Jeton invalide ou expiré (401).']);
  @override
  String toString() => message;
}

/// Service d'import des quiz de https://latabledessavoirs.fr/
///
/// Le site est une SPA Angular : aucun HTML à scraper, tout passe par une API
/// JSON. L'endpoint utile (pour un jour déjà joué) est :
///   GET https://api.latabledessavoirs.fr/game/{difficulté}/{jour}
/// avec l'en-tête `Authorization: Bearer <token>`.
class LtdsImportService {
  static const String apiBase = 'https://api.latabledessavoirs.fr';

  /// Route du site -> difficulté réelle envoyée à l'API.
  static const Map<String, String> levels = {
    'abordable': 'facile',
    'expert': 'difficile',
  };

  static const String _userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Safari/537.36';

  /// Récupère le numéro du jour courant du site via l'endpoint public `/info`
  /// (pas besoin de jeton). Lève en cas d'erreur réseau ou de réponse invalide.
  static Future<int> getCurrentDay({http.Client? client}) async {
    final httpClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      final uri = Uri.parse('$apiBase/info');
      final response = await httpClient.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': _userAgent,
      });
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode} pour $uri', uri);
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final day = (data is Map) ? data['currentDay'] : null;
      if (day is! int) {
        throw const FormatException('currentDay absent de la réponse /info.');
      }
      return day;
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  /// Table de correspondance thème du site -> thème de l'app.
  /// Clés normalisées (minuscules, sans accents). Voir [_normalize].
  static final Map<String, FlashCardTheme> _themeMap = {
    'classique': FlashCardTheme.classique,
    'sport': FlashCardTheme.sport,
    'jeux-video / culture web': FlashCardTheme.moderne,
    'moderne': FlashCardTheme.moderne,
    'histoire': FlashCardTheme.histoire,
    'sciences': FlashCardTheme.sciences,
    'geographie': FlashCardTheme.geographie,
    'musiques': FlashCardTheme.moderne,
    'animaux et plantes': FlashCardTheme.animaux,
    'culture generale': FlashCardTheme.cultureG,
  };

  /// Minuscule + suppression des accents + espaces normalisés.
  static String _normalize(String value) {
    var s = value.toLowerCase().trim();
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i',
      'ô': 'o', 'ö': 'o',
      'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c',
    };
    accents.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Mappe un thème brut du site vers un [FlashCardTheme].
  /// Tout thème inconnu retombe sur "Culture Générale".
  static FlashCardTheme mapTheme(String siteTheme) {
    final key = _normalize(siteTheme);
    if (key.isEmpty) return FlashCardTheme.cultureG;
    final exact = _themeMap[key];
    if (exact != null) return exact;
    // Tolérance : correspondance partielle (libellés qui varient un peu).
    // On exige >= 3 caractères pour éviter qu'une chaîne trop courte ne
    // "matche" tout (ex. la sous-chaîne vide est contenue partout).
    if (key.length >= 3) {
      for (final entry in _themeMap.entries) {
        if (key.contains(entry.key) || entry.key.contains(key)) {
          return entry.value;
        }
      }
    }
    return FlashCardTheme.cultureG;
  }

  /// Parse une saisie de plage de jours en liste triée et dédupliquée.
  ///
  /// Accepte : `"152"`, `"130-135"`, `"130-135, 140, 145-147"`.
  /// Lève [FormatException] si la saisie est vide ou invalide.
  static List<int> parseDayRange(String input) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) {
      throw const FormatException('Plage de jours vide.');
    }

    final days = <int>{};
    for (final rawPart in cleaned.split(',')) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;

      if (part.contains('-')) {
        final bounds = part.split('-');
        if (bounds.length != 2) {
          throw FormatException('Plage invalide : "$part".');
        }
        final start = int.tryParse(bounds[0].trim());
        final end = int.tryParse(bounds[1].trim());
        if (start == null || end == null) {
          throw FormatException('Plage invalide : "$part".');
        }
        final lo = start <= end ? start : end;
        final hi = start <= end ? end : start;
        if (lo < 1) {
          throw FormatException('Les jours doivent être >= 1 : "$part".');
        }
        for (var d = lo; d <= hi; d++) {
          days.add(d);
        }
      } else {
        final single = int.tryParse(part);
        if (single == null) {
          throw FormatException('Jour invalide : "$part".');
        }
        if (single < 1) {
          throw FormatException('Les jours doivent être >= 1 : "$part".');
        }
        days.add(single);
      }
    }

    if (days.isEmpty) {
      throw const FormatException('Aucun jour valide.');
    }
    final sorted = days.toList()..sort();
    return sorted;
  }

  /// Parcourt récursivement le JSON et renvoie tous les objets "question"
  /// (un map possédant un champ texte ET une liste `validAnswers` non vide).
  static List<Map<String, dynamic>> _findQuestions(dynamic node) {
    final found = <Map<String, dynamic>>[];
    void visit(dynamic n) {
      if (n is Map) {
        final text = n['text'] ?? n['question'];
        final valid = n['validAnswers'];
        if (text is String &&
            text.trim().isNotEmpty &&
            valid is List &&
            valid.isNotEmpty) {
          found.add(n.cast<String, dynamic>());
        }
        for (final v in n.values) {
          visit(v);
        }
      } else if (n is List) {
        for (final v in n) {
          visit(v);
        }
      }
    }

    visit(node);
    found.sort((a, b) {
      final oa = (a['order'] as num?)?.toInt() ?? 0;
      final ob = (b['order'] as num?)?.toInt() ?? 0;
      return oa.compareTo(ob);
    });
    return found;
  }

  /// Récupère les questions d'un jour pour un niveau du site
  /// (`'abordable'` ou `'expert'`).
  ///
  /// - 401 -> lève [LtdsAuthException]
  /// - 404 -> renvoie `[]` (jour non joué à ce niveau)
  /// - autre code -> lève [http.ClientException]
  static Future<List<LtdsQuestion>> fetchDay({
    required String token,
    required int day,
    required String level,
    http.Client? client,
  }) async {
    final difficulty = levels[level];
    if (difficulty == null) {
      throw ArgumentError('Niveau inconnu : "$level".');
    }

    final httpClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      final uri = Uri.parse('$apiBase/game/$difficulty/$day');
      final response = await httpClient.get(uri, headers: {
        'Authorization': 'Bearer ${token.trim()}',
        'Accept': 'application/json',
        'User-Agent': _userAgent,
        'Origin': 'https://latabledessavoirs.fr',
        'Referer': 'https://latabledessavoirs.fr/',
      });

      if (response.statusCode == 401) {
        throw LtdsAuthException();
      }
      if (response.statusCode == 404) {
        return const [];
      }
      if (response.statusCode != 200) {
        throw http.ClientException(
          'HTTP ${response.statusCode} pour $uri',
          uri,
        );
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final dayTheme = (data is Map && data['day'] is Map)
          ? (data['day']['theme'] as String? ?? '')
          : '';

      return _findQuestions(data).map((q) {
        final valid = (q['validAnswers'] as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        return LtdsQuestion(
          day: day,
          level: level,
          order: (q['order'] as num?)?.toInt() ?? 0,
          siteTheme: (q['theme'] as String?)?.trim().isNotEmpty == true
              ? (q['theme'] as String).trim()
              : dayTheme,
          question: (q['text'] as String? ?? q['question'] as String? ?? '')
              .trim(),
          validAnswers: valid,
        );
      }).where((q) => q.question.isNotEmpty && q.answer.isNotEmpty).toList();
    } finally {
      if (ownsClient) httpClient.close();
    }
  }
}
