import 'package:flutter_test/flutter_test.dart';
import 'package:polymnesis/models/game_model.dart';

/// Tests du modèle de jeu (lib/models/game_model.dart).
///
/// Couverture :
///  - GameState : présence des trois états (setup / playing / finished).
///  - GameConfig : valeurs par défaut (themes vide, questionCount == 5).
///  - GameConfig.copyWith : surcharge ciblée des champs fournis, conservation
///    des autres, et copie défensive de la liste de thèmes.
void main() {
  group('GameState', () {
    test('expose les trois états setup / playing / finished', () {
      expect(GameState.values,
          containsAll(<GameState>[
            GameState.setup,
            GameState.playing,
            GameState.finished,
          ]));
    });

    test('compte exactement trois états', () {
      expect(GameState.values, hasLength(3));
    });
  });

  group('GameConfig - construction par défaut', () {
    test('themes est une liste vide par défaut', () {
      final config = GameConfig();
      expect(config.themes, isEmpty);
    });

    test('questionCount vaut 5 par défaut', () {
      final config = GameConfig();
      expect(config.questionCount, 5);
    });

    test('les valeurs fournies au constructeur sont respectées', () {
      final config = GameConfig(themes: ['Histoire'], questionCount: 10);
      expect(config.themes, ['Histoire']);
      expect(config.questionCount, 10);
    });
  });

  group('GameConfig.copyWith', () {
    final base = GameConfig(themes: ['Histoire', 'Géographie'], questionCount: 7);

    test('sans argument conserve toutes les valeurs', () {
      final copy = base.copyWith();
      expect(copy.themes, base.themes);
      expect(copy.questionCount, base.questionCount);
    });

    test('surcharge uniquement questionCount', () {
      final copy = base.copyWith(questionCount: 20);
      expect(copy.questionCount, 20);
      // inchangé
      expect(copy.themes, ['Histoire', 'Géographie']);
    });

    test('surcharge uniquement themes', () {
      final copy = base.copyWith(themes: ['Sciences']);
      expect(copy.themes, ['Sciences']);
      // inchangé
      expect(copy.questionCount, 7);
    });

    test('copie défensive de la liste de thèmes (référence distincte)', () {
      final copy = base.copyWith();
      expect(identical(copy.themes, base.themes), isFalse);
      // muter la copie ne doit pas affecter l'original
      copy.themes.add('Sport');
      expect(base.themes, ['Histoire', 'Géographie']);
    });
  });
}
