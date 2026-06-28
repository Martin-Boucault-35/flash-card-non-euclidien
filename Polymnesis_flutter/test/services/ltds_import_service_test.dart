import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:polymnesis/models/card_model.dart';
import 'package:polymnesis/services/ltds_import_service.dart';

/// Tests de [LtdsImportService].
///
/// Couverture :
/// - mapTheme : chaque correspondance site->app demandée, tolérance accents/casse,
///   et repli "Culture Générale" pour un thème inconnu.
/// - parseDayRange : entier seul, plage, liste mixte, tri/dédup, et erreurs.
/// - fetchDay : parsing 200 (URL /game/{difficulté}/{jour}, en-tête Bearer),
///   401 -> LtdsAuthException, 404 -> liste vide.
void main() {
  /// Construit une réponse JSON encodée UTF-8 (pour que les accents survivent
  /// au `utf8.decode(bodyBytes)` du service).
  http.Response jsonResponse(Object body, int status) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  group('mapTheme', () {
    test('correspondances exactes du site vers l\'app', () {
      expect(LtdsImportService.mapTheme('Classique'), FlashCardTheme.classique);
      expect(LtdsImportService.mapTheme('Sport'), FlashCardTheme.sport);
      expect(LtdsImportService.mapTheme('Jeux-vidéo / Culture Web'),
          FlashCardTheme.moderne);
      expect(LtdsImportService.mapTheme('Moderne'), FlashCardTheme.moderne);
      expect(LtdsImportService.mapTheme('Histoire'), FlashCardTheme.histoire);
      expect(LtdsImportService.mapTheme('Sciences'), FlashCardTheme.sciences);
      expect(LtdsImportService.mapTheme('Géographie'), FlashCardTheme.geographie);
      expect(LtdsImportService.mapTheme('Musiques'), FlashCardTheme.moderne);
      expect(LtdsImportService.mapTheme('Animaux et plantes'),
          FlashCardTheme.animaux);
      expect(LtdsImportService.mapTheme('Culture générale'),
          FlashCardTheme.cultureG);
    });

    test('tolère casse, accents et espaces superflus', () {
      expect(LtdsImportService.mapTheme('  GÉOGRAPHIE '),
          FlashCardTheme.geographie);
      expect(LtdsImportService.mapTheme('geographie'), FlashCardTheme.geographie);
      expect(LtdsImportService.mapTheme('CULTURE GENERALE'),
          FlashCardTheme.cultureG);
    });

    test('thème inconnu -> Culture Générale', () {
      expect(LtdsImportService.mapTheme('Cuisine'), FlashCardTheme.cultureG);
      expect(LtdsImportService.mapTheme(''), FlashCardTheme.cultureG);
    });
  });

  group('parseDayRange', () {
    test('entier seul', () {
      expect(LtdsImportService.parseDayRange('152'), [152]);
    });

    test('plage inclusive', () {
      expect(LtdsImportService.parseDayRange('130-135'),
          [130, 131, 132, 133, 134, 135]);
    });

    test('plage inversée tolérée', () {
      expect(LtdsImportService.parseDayRange('135-130'),
          [130, 131, 132, 133, 134, 135]);
    });

    test('liste mixte triée et dédupliquée', () {
      expect(LtdsImportService.parseDayRange('140, 130-132, 131'),
          [130, 131, 132, 140]);
    });

    test('espaces ignorés', () {
      expect(LtdsImportService.parseDayRange('  150 - 151 '), [150, 151]);
    });

    test('lève FormatException sur saisie vide ou invalide', () {
      expect(() => LtdsImportService.parseDayRange(''),
          throwsA(isA<FormatException>()));
      expect(() => LtdsImportService.parseDayRange('abc'),
          throwsA(isA<FormatException>()));
      expect(() => LtdsImportService.parseDayRange('130-'),
          throwsA(isA<FormatException>()));
      expect(() => LtdsImportService.parseDayRange('1-2-3'),
          throwsA(isA<FormatException>()));
      expect(() => LtdsImportService.parseDayRange('0'),
          throwsA(isA<FormatException>()));
    });
  });

  group('fetchDay', () {
    Object dayPayload() => {
          'message': 'ok',
          'error': false,
          'day': {
            'dayNumber': 152,
            'theme': 'Thème du jour',
            'questions': [
              {
                'order': 2,
                'text': 'Question deux ?',
                'theme': 'Sport',
                'validAnswers': ['Lanterne rouge', 'rouge'],
              },
              {
                'order': 1,
                'text': 'Qui a inventé Dracula ?',
                'theme': 'Classique',
                'validAnswers': ['Dracula', 'drcula'],
              },
            ],
          },
        };

    test('200 : parse, trie par order, mappe thème et réponse', () async {
      late Uri capturedUrl;
      String? capturedAuth;
      final client = MockClient((request) async {
        capturedUrl = request.url;
        capturedAuth = request.headers['Authorization'];
        return jsonResponse(dayPayload(), 200);
      });

      final questions = await LtdsImportService.fetchDay(
        token: 'tok123',
        day: 152,
        level: 'abordable',
        client: client,
      );

      // Bonne URL (difficulté AVANT le jour) et en-tête Bearer.
      expect(capturedUrl.path, '/game/facile/152');
      expect(capturedAuth, 'Bearer tok123');

      // Triées par order : Dracula (1) puis Lanterne rouge (2).
      expect(questions.length, 2);
      expect(questions.first.question, 'Qui a inventé Dracula ?');
      expect(questions.first.answer, 'Dracula');
      expect(questions.first.theme, FlashCardTheme.classique);
      expect(questions.first.validAnswers, ['Dracula', 'drcula']);
      expect(questions[1].answer, 'Lanterne rouge');
      expect(questions[1].theme, FlashCardTheme.sport);
      expect(questions.first.level, 'abordable');
    });

    test('expert -> difficulté difficile dans l\'URL', () async {
      late Uri capturedUrl;
      final client = MockClient((request) async {
        capturedUrl = request.url;
        return jsonResponse(dayPayload(), 200);
      });
      await LtdsImportService.fetchDay(
        token: 't',
        day: 99,
        level: 'expert',
        client: client,
      );
      expect(capturedUrl.path, '/game/difficile/99');
    });

    test('401 -> LtdsAuthException', () async {
      final client = MockClient((_) async => jsonResponse(
            {'message': 'Unauthorized', 'statusCode': 401},
            401,
          ));
      expect(
        () => LtdsImportService.fetchDay(
            token: 'bad', day: 1, level: 'abordable', client: client),
        throwsA(isA<LtdsAuthException>()),
      );
    });

    test('404 (jour non joué) -> liste vide', () async {
      final client = MockClient((_) async => jsonResponse(
            {'message': 'Not found', 'statusCode': 404},
            404,
          ));
      final questions = await LtdsImportService.fetchDay(
        token: 't',
        day: 999,
        level: 'abordable',
        client: client,
      );
      expect(questions, isEmpty);
    });

    test('ignore les questions sans réponse valide', () async {
      final client = MockClient((_) async => jsonResponse({
            'day': {
              'questions': [
                {'order': 1, 'text': 'Sans réponse', 'validAnswers': []},
                {
                  'order': 2,
                  'text': 'Avec réponse',
                  'theme': 'Histoire',
                  'validAnswers': ['Napoléon'],
                },
              ],
            },
          }, 200));
      final questions = await LtdsImportService.fetchDay(
        token: 't',
        day: 1,
        level: 'abordable',
        client: client,
      );
      expect(questions.length, 1);
      expect(questions.single.answer, 'Napoléon');
    });
  });
}
