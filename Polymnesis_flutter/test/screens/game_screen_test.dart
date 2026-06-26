import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/screens/game_screen.dart';

import '../helpers/test_helpers.dart';

/// Tests widget de [GameScreen] (jeu libre / free-play).
///
/// Couverture :
///  - Vue SETUP : rendu du titre 'Configuration de la Partie', des chips de
///    thèmes (dont 'Tout'), du Slider et du bouton 'Commencer' ; affichage du
///    'Total disponible: N' ; démarrage de la partie (transition vers la vue
///    de jeu avec un en-tête 'Carte 1 / X').
///  - Cas VIDE (0 carte) : le bouton 'Commencer' est désactivé (onPressed null)
///    et un tap ne navigue pas (on reste sur la configuration).
///  - Vue PLAYING -> RESULTS : une bonne réponse sur une carte unique mène à la
///    vue 'Session Terminée !' avec un score de 1 ; une mauvaise réponse mène à
///    la même vue avec un score de 0.
///
/// Notes de timing : la vue de jeu n'a PAS de Timer.periodic (contrairement au
/// jeu quotidien), mais utilise des Future.delayed (1500 ms feedback correct,
/// puis +1000 ms sur dernier trigger faux). On avance donc avec
/// tester.pump(Duration) explicite plutôt que pumpAndSettle pendant le feedback.
/// L'ordre de la file est mélangé (getCardsForGame shuffle) : on n'asserte
/// jamais sur l'ordre, uniquement sur la longueur/le contenu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Tout flux pouvant atteindre les notifications doit installer le faux.
    installFakeNotifications();
  });

  group('GameScreen - vue Configuration (setup)', () {
    testWidgets('affiche le titre, le chip "Tout", un Slider et "Commencer"',
        (tester) async {
      seedPrefs(cards: [buildCard(id: 'c1')]);
      final provider = await makeInitializedProvider();

      await tester.pumpWidget(
        wrapWithProvider(const GameScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Configuration de la Partie'), findsOneWidget);
      expect(find.text('Tout'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Commencer'), findsOneWidget);

      // Chaque thème dispose de son propre chip de sélection.
      expect(find.text('Culture Générale'), findsOneWidget);
      expect(find.text('Histoire'), findsOneWidget);
    });

    testWidgets('"Total disponible: N" reflète le nombre de cartes',
        (tester) async {
      seedPrefs(cards: [
        buildCard(id: 'c1'),
        buildCard(id: 'c2'),
        buildCard(id: 'c3'),
      ]);
      final provider = await makeInitializedProvider();

      await tester.pumpWidget(
        wrapWithProvider(const GameScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total disponible: 3'), findsOneWidget);
    });

    testWidgets('"Commencer" démarre la partie (transition vers la vue de jeu)',
        (tester) async {
      seedPrefs(cards: [
        buildCard(id: 'c1'),
        buildCard(id: 'c2'),
      ]);
      final provider = await makeInitializedProvider();

      await tester.pumpWidget(
        wrapWithProvider(const GameScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      // On a quitté la configuration pour la vue de jeu.
      expect(find.text('Configuration de la Partie'), findsNothing);
      // En-tête de progression : 'Carte 1 / X' (X = nombre de questions).
      expect(find.textContaining('Carte 1 / '), findsOneWidget);
    });
  });

  group('GameScreen - cas vide (aucune carte)', () {
    testWidgets('"Commencer" est désactivé et ne navigue pas', (tester) async {
      // Un stockage vide fait que le provider réinjecte les 4 cartes par défaut
      // (cf. CardProvider.initialize). Pour atteindre réellement 0 carte — et
      // donc un bouton 'Commencer' désactivé — on les supprime après init.
      seedPrefs(cards: const []);
      final provider = await makeInitializedProvider();
      for (final c in provider.cards.toList()) {
        await provider.deleteCard(c.id);
      }
      expect(provider.cardCount, 0);

      await tester.pumpWidget(
        wrapWithProvider(const GameScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total disponible: 0'), findsOneWidget);
      // Le bouton existe mais est inactif (onPressed null quand 0 carte).
      expect(find.text('Commencer'), findsOneWidget);

      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      // Aucune navigation : on reste sur la configuration.
      expect(find.text('Configuration de la Partie'), findsOneWidget);
      expect(find.textContaining('Carte 1 / '), findsNothing);
    });
  });

  group('GameScreen - déroulement et résultats', () {
    testWidgets('une bonne réponse sur une carte unique mène au score 1',
        (tester) async {
      seedPrefs(cards: [
        buildCard(
          id: 'c1',
          answer: 'Paris',
          triggers: const ['Capitale de la France'],
        ),
      ]);
      final provider = await makeInitializedProvider();

      await tester.pumpWidget(
        wrapWithProvider(const GameScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      // Démarrage de la partie.
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      // La carte unique est affichée avec son trigger et l'en-tête 'Carte 1 / 1'.
      expect(find.text('Carte 1 / 1'), findsOneWidget);
      expect(find.text('Capitale de la France'), findsOneWidget);

      // Saisie de la bonne réponse puis soumission.
      await tester.enterText(find.byType(TextField), 'Paris');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pump();

      // Feedback "Bonne réponse !" visible avant l'avancement différé.
      expect(find.text('Bonne réponse !'), findsOneWidget);

      // Future.delayed(1500 ms) -> _nextCard -> dernière carte -> finished.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('Session Terminée !'), findsOneWidget);
      // Le score est rendu via un RichText ('1 / 1') -> findRichText: true.
      expect(find.text('1 / 1', findRichText: true), findsOneWidget);
      // Message de performance (Text simple) pour un sans-faute.
      expect(find.text('Parfait ! Mémoire absolue.'), findsOneWidget);
    });

    testWidgets('une mauvaise réponse sur une carte unique mène au score 0',
        (tester) async {
      seedPrefs(cards: [
        buildCard(
          id: 'c1',
          answer: 'Paris',
          triggers: const ['Capitale de la France'],
        ),
      ]);
      final provider = await makeInitializedProvider();

      await tester.pumpWidget(
        wrapWithProvider(const GameScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      // Réponse incorrecte sur la carte à trigger unique (donc dernier trigger).
      await tester.enterText(find.byType(TextField), 'Lyon');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pump();

      // Feedback "Faux ! ..." visible avant l'avancement différé.
      expect(find.textContaining('Faux !'), findsOneWidget);

      // Sur le dernier trigger : Future.delayed(1500 ms) puis +1000 ms avant
      // _nextCard ; on avance généreusement pour couvrir les deux délais.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(find.text('Session Terminée !'), findsOneWidget);
      // Score 0 sur 1, rendu via RichText ('0 / 1').
      expect(find.text('0 / 1', findRichText: true), findsOneWidget);
      // Message de performance (score <= moitié).
      expect(find.text('Continuez à vous entraîner.'), findsOneWidget);
    });
  });
}
