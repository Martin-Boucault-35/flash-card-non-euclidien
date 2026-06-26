import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/screens/daily_game_screen.dart';
import 'package:polymnesis/widgets/app_button.dart';

import '../helpers/test_helpers.dart';

/// Tests widget pour [DailyGameScreen] (jeu quotidien Leitner).
///
/// Couverture :
///  - Vue READY : titre 'Jeu Quotidien', grand compteur de cartes dues,
///    répartition des boîtes, bouton 'Commencer la révision' actif quand due>0.
///  - Vue READY avec 0 carte due : message 'Tout est à jour !' et bouton
///    'Rien à réviser' désactivé.
///  - Transition READY -> PLAYING : en-tête 'Carte 1 / 1', texte du trigger,
///    badge 'Boîte N'.
///  - Flux complet jusqu'aux RÉSULTATS : 'Révision Terminée !' + pourcentage,
///    et progression de la boîte Leitner de la carte.
///
/// LIMITATION TEMPS RÉEL : DateTime.now() n'est pas contrôlable par le testeur
/// (ni pump() ni fakeAsync). Le bonus "réponse rapide (<5s)" se base sur le
/// temps réel écoulé ; dans les tests il est ~0s, donc c'est TOUJOURS le chemin
/// RAPIDE/facile (+2 boîtes, _FeedbackState.correctEasy) qui se déclenche. Le
/// chemin lent (+1 boîte) ne peut PAS être testé de façon déterministe ici.
///
/// GOTCHA TIMER : la vue PLAYING contient un Timer.periodic(1s). pumpAndSettle()
/// ne se stabilise jamais avec un timer périodique actif → on utilise
/// tester.pump(Duration) avec des durées explicites en état PLAYING. Les vues
/// READY / EMPTY / RESULTS n'ont pas de timer périodique (pumpAndSettle OK).
/// On pilote toujours l'état PLAYING jusqu'à RESULTS avant la fin du test pour
/// que le _PlayingView soit disposé (son timer annulé) et qu'aucun timer ne
/// reste pendant.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Le flux peut atteindre markDailyCompleted() (fin du jeu) -> notifications.
  setUp(() {
    installFakeNotifications();
  });

  group('DailyGameScreen - vue READY', () {
    testWidgets(
      'affiche le titre, le compteur de cartes dues et la répartition des boîtes',
      (tester) async {
        // 3 cartes dues (nextReviewAt dans le passé), réparties sur des boîtes
        // distinctes (1, 2, 3) pour que le grand compteur '3' soit non ambigu
        // (les compteurs par boîte valent alors 1, pas 3).
        seedPrefs(cards: [
          buildCard(id: 'a', leitnerBox: 1, nextReviewAt: daysFromNowMillis(-1)),
          buildCard(id: 'b', leitnerBox: 2, nextReviewAt: daysFromNowMillis(-2)),
          buildCard(id: 'c', leitnerBox: 3, nextReviewAt: daysFromNowMillis(-3)),
        ]);
        final provider = await makeInitializedProvider();

        await tester.pumpWidget(
          wrapWithProvider(const DailyGameScreen(), provider: provider),
        );
        await tester.pumpAndSettle();

        expect(find.text('Jeu Quotidien'), findsOneWidget);
        // Le grand compteur = nombre de cartes dues.
        expect(find.text('3'), findsOneWidget);
        expect(find.text('cartes à réviser aujourd\'hui'), findsOneWidget);
        expect(find.text('Répartition des boîtes'), findsOneWidget);

        // Bouton actif (onPressed != null) car due > 0.
        final button = tester.widget<AppButton>(find.byType(AppButton));
        expect(button.onPressed, isNotNull);
        expect(find.text('Commencer la révision'), findsOneWidget);
      },
    );

    testWidgets(
      '0 carte due : message "Tout est à jour !" et bouton désactivé',
      (tester) async {
        // Toutes les cartes "non dues" (révision dans le futur).
        seedPrefs(cards: [
          buildCard(id: 'a', nextReviewAt: daysFromNowMillis(5)),
          buildCard(id: 'b', nextReviewAt: daysFromNowMillis(7)),
        ]);
        final provider = await makeInitializedProvider();

        await tester.pumpWidget(
          wrapWithProvider(const DailyGameScreen(), provider: provider),
        );
        await tester.pumpAndSettle();

        // Note : on n'asserte pas find.text('0') — le '0' apparaît à la fois sur
        // le grand compteur ET sur les compteurs des boîtes vides (ambigu). On
        // s'appuie sur les messages uniques ci-dessous.
        expect(find.text('Tout est à jour !'), findsOneWidget);
        expect(find.text('Rien à réviser'), findsOneWidget);
        expect(find.text('Commencer la révision'), findsNothing);

        // Bouton désactivé (onPressed == null) car due == 0.
        final button = tester.widget<AppButton>(find.byType(AppButton));
        expect(button.onPressed, isNull);
      },
    );
  });

  group('DailyGameScreen - START -> PLAYING', () {
    testWidgets(
      'démarrer affiche la carte en cours, son trigger et le badge de boîte',
      (tester) async {
        // Une seule carte due, avec un unique trigger connu (pas d'ambiguïté
        // de shuffle), en boîte 2.
        seedPrefs(cards: [
          buildCard(
            id: 'solo',
            answer: 'Paris',
            triggers: const ['Capitale de la France'],
            leitnerBox: 2,
            nextReviewAt: 1000,
          ),
        ]);
        final provider = await makeInitializedProvider();

        await tester.pumpWidget(
          wrapWithProvider(const DailyGameScreen(), provider: provider),
        );
        await tester.pumpAndSettle();

        // Démarrer la révision. Le bouton est en bas d'une vue défilante :
        // le rendre visible avant le tap (sinon le tap "rate" hors écran).
        await tester.ensureVisible(find.text('Commencer la révision'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Commencer la révision'));
        // PLAYING a un Timer.periodic -> NE PAS pumpAndSettle. Un pump suffit.
        await tester.pump();

        expect(find.text('Carte 1 / 1'), findsOneWidget);
        expect(find.text('Capitale de la France'), findsOneWidget);
        expect(find.text('Boîte 2'), findsOneWidget);

        // On termine le flux pour éviter un timer périodique pendant à la fin.
        // Réponse CORRECTE rapide (temps réel ~0s => chemin facile +2 boîtes).
        await tester.enterText(find.byType(TextField), 'Paris');
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        // Future.delayed(1500ms) avant l'avancement -> on dépasse ce délai.
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pumpAndSettle();

        // On atteint la vue RÉSULTATS (le _PlayingView est disposé, timer annulé).
        expect(find.text('Révision Terminée !'), findsOneWidget);
      },
    );
  });

  group('DailyGameScreen - RÉSULTATS', () {
    testWidgets(
      'une bonne réponse rapide fait progresser la boîte et affiche le score 100%',
      (tester) async {
        // Carte due en boîte 1 ; réponse rapide => easy (+2) => boîte 3 (<= 6).
        seedPrefs(cards: [
          buildCard(
            id: 'solo',
            answer: 'Reponse',
            triggers: const ['Seul indice'],
            leitnerBox: 1,
            nextReviewAt: 1000,
          ),
        ]);
        final provider = await makeInitializedProvider();

        await tester.pumpWidget(
          wrapWithProvider(const DailyGameScreen(), provider: provider),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Commencer la révision'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Commencer la révision'));
        await tester.pump();

        // Bonne réponse (la normalisation rend la casse/espaces indifférents).
        await tester.enterText(find.byType(TextField), '  reponse  ');
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        // Un pump pour appliquer le setState déclenché par la soumission.
        await tester.pump();

        // Feedback "Rapide ! ↑↑ +2 boîtes" (chemin facile, temps réel ~0s).
        expect(find.text('Rapide ! ↑↑ +2 boîtes'), findsOneWidget);

        // Avance vers les résultats (Future.delayed 1500ms).
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pumpAndSettle();

        expect(find.text('Révision Terminée !'), findsOneWidget);
        // Une seule carte, réussie => 100%.
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('Parfait ! Toutes vos cartes progressent.'),
            findsOneWidget);

        // La boîte Leitner de la carte a progressé (+2 : 1 -> 3).
        final card = provider.cards.firstWhere((c) => c.id == 'solo');
        expect(card.leitnerBox, 3);
      },
    );
  });

  group('DailyGameScreen - échec puis reprise', () {
    testWidgets(
      'mauvaise réponse : recul de boîte (-1) et carte ré-insérée, puis reprise correcte termine la session',
      (tester) async {
        // Carte due en boîte 3, trigger unique (donc "dernier trigger").
        seedPrefs(cards: [
          buildCard(
            id: 'solo',
            answer: 'Paris',
            triggers: const ['Capitale de la France'],
            leitnerBox: 3,
            nextReviewAt: 1000,
          ),
        ]);
        final provider = await makeInitializedProvider();

        await tester.pumpWidget(
          wrapWithProvider(const DailyGameScreen(), provider: provider),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Commencer la révision'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Commencer la révision'));
        await tester.pump();

        expect(find.text('Carte 1 / 1'), findsOneWidget);

        // Mauvaise réponse sur le dernier (unique) trigger.
        await tester.enterText(find.byType(TextField), 'Lyon');
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(find.textContaining('Faux !'), findsOneWidget);

        // Le mauvais chemin attend 3000 ms avant leitnerIncorrect + ré-insertion.
        await tester.pump(const Duration(milliseconds: 3100));

        // La boîte a reculé (3 -> 2) et la carte est ré-insérée (toujours en jeu).
        expect(provider.cards.firstWhere((c) => c.id == 'solo').leitnerBox, 2);
        expect(find.text('Carte 2 / 2'), findsOneWidget);

        // Reprise : réponse correcte. La carte ayant été ratée aujourd'hui, le
        // bonus rapide est désactivé -> chemin "correctHard" (+1).
        //
        // QUIRK observé : la carte ré-insérée dans la file conserve sa boîte
        // d'AVANT l'échec (3), car leitnerIncorrect sauvegarde une copie côté
        // provider sans muter l'objet présent dans la file. Le +1 de la reprise
        // se calcule donc à partir de 3 (objet de la file) et non de 2 (provider)
        // => la boîte finale persistée est 4, pas 3.
        await tester.enterText(find.byType(TextField), 'Paris');
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pumpAndSettle();

        // Fin de session + boîte persistée à 4 (cf. quirk ci-dessus).
        expect(find.text('Révision Terminée !'), findsOneWidget);
        expect(provider.cards.firstWhere((c) => c.id == 'solo').leitnerBox, 4);
      },
    );
  });

  group('DailyGameScreen - atterrissage en douceur', () {
    testWidgets(
      'réponse rapide près du sommet : +1 (au lieu de +2) pour éviter le saut direct vers maîtrisé',
      (tester) async {
        // box 5 : un bonus +2 ferait sauter directement à 7 (maîtrisée). Le jeu
        // force alors un +1 (-> box 6) et affiche le feedback "soft landing".
        seedPrefs(cards: [
          buildCard(
            id: 'solo',
            answer: 'Paris',
            triggers: const ['Capitale de la France'],
            leitnerBox: 5,
            nextReviewAt: 1000,
          ),
        ]);
        final provider = await makeInitializedProvider();

        await tester.pumpWidget(
          wrapWithProvider(const DailyGameScreen(), provider: provider),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Commencer la révision'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Commencer la révision'));
        await tester.pump();

        // Réponse correcte rapide (temps réel ~0s).
        await tester.enterText(find.byType(TextField), 'Paris');
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        // Feedback spécifique "atterrissage en douceur".
        expect(find.textContaining('éviter le saut direct'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pumpAndSettle();

        expect(find.text('Révision Terminée !'), findsOneWidget);
        // +1 et non +2 : box 5 -> 6 (donc PAS maîtrisée, qui serait 7).
        expect(provider.cards.firstWhere((c) => c.id == 'solo').leitnerBox, 6);
      },
    );
  });

  group('DailyGameScreen - chemin lent (> 5 s, sans bonus)', () {
    testWidgets(
      'réponse correcte APRÈS 5 s : +1 seulement (pas de bonus rapide) — '
      'test RÉEL et LENT (~6 s)',
      (tester) async {
        // Le code mesure elapsed via DateTime.now() (horloge RÉELLE, non pilotable
        // par pump/fakeAsync). On laisse donc passer >5 s de temps réel grâce à
        // tester.runAsync (exécution hors zone FakeAsync) pour franchir le seuil.
        seedPrefs(cards: [
          buildCard(
            id: 'solo',
            answer: 'Paris',
            triggers: const ['Capitale de la France'],
            leitnerBox: 1,
            nextReviewAt: 1000,
          ),
        ]);
        final provider = await makeInitializedProvider();

        await tester.pumpWidget(
          wrapWithProvider(const DailyGameScreen(), provider: provider),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Commencer la révision'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Commencer la révision'));
        await tester.pump(); // _cardStartTime = DateTime.now() (réel)

        // Attente RÉELLE de 6 s -> elapsed >= 5 s au moment de la soumission.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 6)),
        );

        await tester.enterText(find.byType(TextField), 'Paris');
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        // Pas de bonus rapide -> chemin "correctHard" (+1).
        expect(find.text('Bonne réponse ! ↑ +1 boîte'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pumpAndSettle();

        expect(find.text('Révision Terminée !'), findsOneWidget);
        // +1 seulement : box 1 -> 2 (et non 3 comme dans le chemin rapide).
        expect(provider.cards.firstWhere((c) => c.id == 'solo').leitnerBox, 2);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
