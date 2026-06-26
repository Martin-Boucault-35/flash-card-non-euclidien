// Tests widget de [HomeScreen] (lib/screens/home_screen.dart).
//
// Couverture :
//  - Rendu du titre 'Mémoire Non-Euclidienne' et des trois cartes
//    ('Créer des cartes', 'Lancer une session', 'Jeu Quotidien').
//  - Description du 'Jeu Quotidien' pilotée par CardProvider.dailyCardCount :
//      * 2 cartes due  => '2 cartes à réviser — Système Leitner' (pluriel) + badge '2'
//      * 1 carte due   => '1 carte à réviser — Système Leitner' (singulier) + badge '1'
//      * 0 carte due   => 'Aucune carte à réviser aujourd'hui !' + pas de badge
//  - Les trois GestureDetector déclenchent les bons callbacks de navigation
//    (onNavigateToCreate / onNavigateToGame / onNavigateToDailyGame).
//
// Le décompte des cartes "due" repose sur DateTime.now() (horloge réelle) :
// on sème donc des cartes avec nextReviewAt dans le passé (due) ou le futur
// (non due) via daysFromNowMillis(). Aucune sync (enabled=false par défaut).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/providers/card_provider.dart';
import 'package:polymnesis/screens/home_screen.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    installFakeNotifications();
  });

  /// Construit l'écran enveloppé dans le provider partagé, avec des callbacks
  /// par défaut no-op (surchargés par les tests qui vérifient la navigation).
  Widget buildHome(
    CardProvider provider, {
    VoidCallback? onCreate,
    VoidCallback? onGame,
    VoidCallback? onDaily,
  }) {
    return wrapWithProvider(
      HomeScreen(
        onNavigateToCreate: onCreate ?? () {},
        onNavigateToGame: onGame ?? () {},
        onNavigateToDailyGame: onDaily ?? () {},
      ),
      provider: provider,
    );
  }

  group('HomeScreen - rendu', () {
    testWidgets('affiche le titre et les trois cartes', (tester) async {
      seedPrefs(cards: [buildCard(id: 'c1', nextReviewAt: daysFromNowMillis(-1))]);
      final provider = await makeInitializedProvider();

      await tester.pumpWidget(buildHome(provider));
      await tester.pumpAndSettle();

      expect(find.text('Mémoire Non-Euclidienne'), findsOneWidget);
      expect(find.text('Créer des cartes'), findsOneWidget);
      expect(find.text('Lancer une session'), findsOneWidget);
      expect(find.text('Jeu Quotidien'), findsOneWidget);
    });
  });

  group('HomeScreen - description du Jeu Quotidien', () {
    testWidgets('2 cartes due => pluriel et badge "2"', (tester) async {
      seedPrefs(cards: [
        buildCard(id: 'c1', nextReviewAt: daysFromNowMillis(-1)),
        buildCard(id: 'c2', nextReviewAt: daysFromNowMillis(-2)),
      ]);
      final provider = await makeInitializedProvider();
      expect(provider.dailyCardCount, 2);

      await tester.pumpWidget(buildHome(provider));
      await tester.pumpAndSettle();

      expect(find.text('2 cartes à réviser — Système Leitner'), findsOneWidget);
      // Badge affiché avec le décompte.
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('1 carte due => singulier et badge "1"', (tester) async {
      seedPrefs(cards: [
        buildCard(id: 'c1', nextReviewAt: daysFromNowMillis(-1)),
        buildCard(id: 'c2', nextReviewAt: daysFromNowMillis(5)),
      ]);
      final provider = await makeInitializedProvider();
      expect(provider.dailyCardCount, 1);

      await tester.pumpWidget(buildHome(provider));
      await tester.pumpAndSettle();

      expect(find.text('1 carte à réviser — Système Leitner'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('0 carte due => message "Aucune carte" et pas de badge',
        (tester) async {
      seedPrefs(cards: [
        buildCard(id: 'c1', nextReviewAt: daysFromNowMillis(5)),
        buildCard(id: 'c2', nextReviewAt: daysFromNowMillis(10)),
      ]);
      final provider = await makeInitializedProvider();
      expect(provider.dailyCardCount, 0);

      await tester.pumpWidget(buildHome(provider));
      await tester.pumpAndSettle();

      expect(
        find.text('Aucune carte à réviser aujourd\'hui !'),
        findsOneWidget,
      );
      // Aucune carte due => aucune des descriptions "à réviser".
      expect(find.textContaining('à réviser — Système Leitner'), findsNothing);
    });
  });

  group('HomeScreen - navigation', () {
    testWidgets('taper "Créer des cartes" appelle onNavigateToCreate',
        (tester) async {
      seedPrefs(cards: [buildCard(id: 'c1', nextReviewAt: daysFromNowMillis(-1))]);
      final provider = await makeInitializedProvider();

      var createTapped = false;
      var gameTapped = false;
      var dailyTapped = false;

      await tester.pumpWidget(buildHome(
        provider,
        onCreate: () => createTapped = true,
        onGame: () => gameTapped = true,
        onDaily: () => dailyTapped = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Créer des cartes'));
      await tester.pumpAndSettle();

      expect(createTapped, isTrue);
      expect(gameTapped, isFalse);
      expect(dailyTapped, isFalse);
    });

    testWidgets('taper "Lancer une session" appelle onNavigateToGame',
        (tester) async {
      seedPrefs(cards: [buildCard(id: 'c1', nextReviewAt: daysFromNowMillis(-1))]);
      final provider = await makeInitializedProvider();

      var createTapped = false;
      var gameTapped = false;
      var dailyTapped = false;

      await tester.pumpWidget(buildHome(
        provider,
        onCreate: () => createTapped = true,
        onGame: () => gameTapped = true,
        onDaily: () => dailyTapped = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lancer une session'));
      await tester.pumpAndSettle();

      expect(gameTapped, isTrue);
      expect(createTapped, isFalse);
      expect(dailyTapped, isFalse);
    });

    testWidgets('taper "Jeu Quotidien" appelle onNavigateToDailyGame',
        (tester) async {
      seedPrefs(cards: [buildCard(id: 'c1', nextReviewAt: daysFromNowMillis(-1))]);
      final provider = await makeInitializedProvider();

      var createTapped = false;
      var gameTapped = false;
      var dailyTapped = false;

      await tester.pumpWidget(buildHome(
        provider,
        onCreate: () => createTapped = true,
        onGame: () => gameTapped = true,
        onDaily: () => dailyTapped = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jeu Quotidien'));
      await tester.pumpAndSettle();

      expect(dailyTapped, isTrue);
      expect(createTapped, isFalse);
      expect(gameTapped, isFalse);
    });
  });
}
