import 'package:flutter_test/flutter_test.dart';
import 'package:polymnesis/models/card_model.dart';

void main() {
  group('FlashCardTheme', () {
    test('chaque thème expose un displayName non vide', () {
      for (final theme in FlashCardTheme.values) {
        expect(theme.displayName, isNotEmpty);
      }
    });

    test('fromString reconnaît le displayName', () {
      expect(FlashCardTheme.fromString('Géographie'),
          FlashCardTheme.geographie);
      expect(FlashCardTheme.fromString('Culture Générale'),
          FlashCardTheme.cultureG);
    });

    test('fromString reconnaît le name technique de l\'enum', () {
      expect(FlashCardTheme.fromString('geographie'),
          FlashCardTheme.geographie);
      expect(FlashCardTheme.fromString('cultureG'), FlashCardTheme.cultureG);
    });

    test('fromString retombe sur cultureG pour une valeur inconnue', () {
      expect(FlashCardTheme.fromString('inexistant'), FlashCardTheme.cultureG);
      expect(FlashCardTheme.fromString(''), FlashCardTheme.cultureG);
    });
  });

  group('FlashCard - construction', () {
    test('nextReviewAt vaut createdAt par défaut', () {
      final card = FlashCard(
        id: '1',
        theme: FlashCardTheme.histoire,
        answer: 'A',
        triggers: const ['t'],
        createdAt: 4242,
      );
      expect(card.nextReviewAt, 4242);
      expect(card.leitnerBox, 1);
    });

    test('nextReviewAt explicite est respecté', () {
      final card = FlashCard(
        id: '1',
        theme: FlashCardTheme.histoire,
        answer: 'A',
        triggers: const ['t'],
        createdAt: 1000,
        nextReviewAt: 9999,
      );
      expect(card.nextReviewAt, 9999);
    });
  });

  group('FlashCard.copyWith', () {
    final base = FlashCard(
      id: '1',
      theme: FlashCardTheme.histoire,
      answer: 'Charles V',
      triggers: const ['roi sage'],
      createdAt: 1000,
      leitnerBox: 2,
      nextReviewAt: 2000,
    );

    test('sans argument renvoie une copie équivalente', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.theme, base.theme);
      expect(copy.answer, base.answer);
      expect(copy.triggers, base.triggers);
      expect(copy.createdAt, base.createdAt);
      expect(copy.leitnerBox, base.leitnerBox);
      expect(copy.nextReviewAt, base.nextReviewAt);
    });

    test('surcharge uniquement les champs fournis', () {
      final copy = base.copyWith(answer: 'Charles VI', leitnerBox: 3);
      expect(copy.answer, 'Charles VI');
      expect(copy.leitnerBox, 3);
      // inchangés
      expect(copy.id, '1');
      expect(copy.theme, FlashCardTheme.histoire);
      expect(copy.nextReviewAt, 2000);
    });

    test('copie défensive de la liste de triggers', () {
      final copy = base.copyWith();
      expect(identical(copy.triggers, base.triggers), isFalse);
    });
  });

  group('FlashCard.toJson / fromJson', () {
    test('round-trip toJson -> fromJson préserve les champs', () {
      final card = FlashCard(
        id: 'abc',
        theme: FlashCardTheme.geographie,
        answer: 'Stromboli',
        triggers: const ['Volcan', 'Italie'],
        createdAt: 1234,
        leitnerBox: 4,
        nextReviewAt: 5678,
      );
      final restored = FlashCard.fromJson(card.toJson());
      expect(restored.id, card.id);
      expect(restored.theme, card.theme);
      expect(restored.answer, card.answer);
      expect(restored.triggers, card.triggers);
      expect(restored.createdAt, card.createdAt);
      expect(restored.leitnerBox, card.leitnerBox);
      expect(restored.nextReviewAt, card.nextReviewAt);
    });

    test('toJson sérialise le thème via displayName', () {
      final json = buildJsonCard(theme: FlashCardTheme.moderne).toJson();
      expect(json['theme'], 'Moderne');
    });

    test('fromJson supporte le format imbriqué "data" de Supabase', () {
      final json = {
        'id': 'remote-1',
        'data': {
          'theme': 'Histoire',
          'answer': 'Napoléon',
          'triggers': ['empereur'],
          'createdAt': 111,
          'leitnerBox': 3,
          'nextReviewAt': 222,
        },
      };
      final card = FlashCard.fromJson(json);
      expect(card.id, 'remote-1');
      expect(card.theme, FlashCardTheme.histoire);
      expect(card.answer, 'Napoléon');
      expect(card.leitnerBox, 3);
      expect(card.nextReviewAt, 222);
    });

    test('fromJson applique les valeurs par défaut sur champs manquants', () {
      final card = FlashCard.fromJson({'id': 'x'});
      expect(card.id, 'x');
      expect(card.theme, FlashCardTheme.cultureG);
      expect(card.answer, '');
      expect(card.triggers, isEmpty);
      expect(card.leitnerBox, 1);
      // createdAt défaut = now ; nextReviewAt défaut = createdAt
      expect(card.nextReviewAt, card.createdAt);
    });

    test('fromJson : nextReviewAt absent retombe sur createdAt', () {
      final card = FlashCard.fromJson({
        'id': 'x',
        'answer': 'a',
        'createdAt': 777,
      });
      expect(card.createdAt, 777);
      expect(card.nextReviewAt, 777);
    });
  });

  group('FlashCard - égalité', () {
    test('deux cartes de même id sont égales (et même hashCode)', () {
      final a = buildJsonCard(id: 'same', answer: 'A');
      final b = buildJsonCard(id: 'same', answer: 'B différent');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('deux cartes d\'id différent ne sont pas égales', () {
      final a = buildJsonCard(id: 'a');
      final b = buildJsonCard(id: 'b');
      expect(a, isNot(equals(b)));
    });
  });
}

/// Petit fabricant local (le helper global est testé ailleurs).
FlashCard buildJsonCard({
  String id = '1',
  FlashCardTheme theme = FlashCardTheme.cultureG,
  String answer = 'r',
}) {
  return FlashCard(
    id: id,
    theme: theme,
    answer: answer,
    triggers: const ['t'],
    createdAt: 1000,
  );
}
