// Tests de [computeDayStatuses] — le cœur de l'issue #7.
//
// La comparaison se fait dans l'espace NORMALISÉ (FlashCard.normalizeAnswer),
// donc « Napoléon » (archive) reconnaît « napoleon » (local) : c'est ce qui
// évite de considérer un jour comme non importé à cause d'un accent.

import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/models/models.dart';
import 'package:polymnesis/services/imported_days.dart';

void main() {
  Set<String> local(List<String> answers) =>
      answers.map(FlashCard.normalizeAnswer).toSet();

  group('computeDayStatuses - états', () {
    test('toutes les réponses présentes => jour importé', () {
      final days = computeDayStatuses(
        archiveAnswersByDay: {
          1: ['Paris', 'Mozart'],
        },
        localNormalizedAnswers: local(['Paris', 'Mozart']),
      );

      expect(days.single.state, DayImportState.fullyImported);
      expect(days.single.present, 2);
      expect(days.single.total, 2);
    });

    test('une partie seulement => partiel', () {
      final days = computeDayStatuses(
        archiveAnswersByDay: {
          1: ['Paris', 'Mozart', 'Stromae'],
        },
        localNormalizedAnswers: local(['Paris']),
      );

      expect(days.single.state, DayImportState.partial);
      expect(days.single.present, 1);
      expect(days.single.total, 3);
    });

    test('aucune réponse présente => à importer', () {
      final days = computeDayStatuses(
        archiveAnswersByDay: {
          1: ['Paris', 'Mozart'],
        },
        localNormalizedAnswers: local(['Zidane']),
      );

      expect(days.single.state, DayImportState.notImported);
      expect(days.single.present, 0);
    });

    test('jour absent de l\'archive (trou) => non joué', () {
      final days = computeDayStatuses(
        archiveAnswersByDay: {
          1: ['Paris'],
          3: ['Mozart'], // le jour 2 manque
        },
        localNormalizedAnswers: local(['Paris', 'Mozart']),
      );

      expect(days.length, 3); // jours 1..3
      expect(days[1].day, 2);
      expect(days[1].state, DayImportState.notPlayed);
      expect(days[1].total, 0);
    });
  });

  group('computeDayStatuses - normalisation et dédoublonnage', () {
    test('accents et casse n\'empêchent pas la correspondance', () {
      final days = computeDayStatuses(
        archiveAnswersByDay: {
          1: ['Napoléon', 'Élysée'],
        },
        localNormalizedAnswers: local(['napoleon', 'ELYSEE']),
      );

      expect(days.single.state, DayImportState.fullyImported);
    });

    test('deux questions à réponse identique ne comptent pas double', () {
      // Le même jour peut poser la même réponse en abordable ET en expert.
      final days = computeDayStatuses(
        archiveAnswersByDay: {
          1: ['Paris', 'paris', 'Mozart'],
        },
        localNormalizedAnswers: local(['Paris', 'Mozart']),
      );

      expect(days.single.total, 2); // et non 3
      expect(days.single.state, DayImportState.fullyImported);
    });

    test('les réponses vides sont ignorées', () {
      final days = computeDayStatuses(
        archiveAnswersByDay: {
          1: ['Paris', '', '   '],
        },
        localNormalizedAnswers: local(['Paris']),
      );

      expect(days.single.total, 1);
      expect(days.single.state, DayImportState.fullyImported);
    });
  });

  group('computeDayStatuses - bornes', () {
    test('archive vide => tableau vide (pas de jour inventé)', () {
      expect(
        computeDayStatuses(
          archiveAnswersByDay: const {},
          localNormalizedAnswers: local(['Paris']),
        ),
        isEmpty,
      );
    });

    test('le tableau s\'arrête au dernier jour archivé', () {
      final days = computeDayStatuses(
        archiveAnswersByDay: {
          5: ['Paris'],
        },
        localNormalizedAnswers: <String>{},
      );

      expect(days.length, 5); // jours 1..5, pas au-delà
      expect(days.last.day, 5);
    });
  });

  group('DayImportStatus - sérialisation', () {
    test('round-trip JSON', () {
      const s = DayImportStatus(day: 42, present: 3, total: 10);
      final round = DayImportStatus.fromJson(s.toJson());

      expect(round.day, 42);
      expect(round.present, 3);
      expect(round.total, 10);
      expect(round.state, DayImportState.partial);
    });
  });
}
