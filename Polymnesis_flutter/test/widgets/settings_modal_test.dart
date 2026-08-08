// Tests widget de [SettingsModal].
//
// Le modal est organisé en 3 onglets (Sync / Import / Leitner). TabBarView ne
// construit que l'onglet actif (+ éventuellement l'adjacent) : pour interagir
// avec un champ d'un onglet, on l'ouvre d'abord via [openTab]. Le bouton
// 'Enregistrer' est fixe (hors onglets) et sauvegarde tout (les controllers
// existent dès initState, quel que soit l'onglet visité).
//
// Le modal appelle Navigator.pop(context) à la fin de _handleSave et sur les
// boutons fermeture/Annuler. On le pousse donc comme route (via un bouton dans
// un Builder) pour qu'un Navigator avec une route à dépiler existe.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/models/day_import_status.dart';
import 'package:polymnesis/models/sync_credentials.dart';
import 'package:polymnesis/models/leitner_settings.dart';
import 'package:polymnesis/models/ltds_settings.dart';
import 'package:polymnesis/providers/card_provider.dart';
import 'package:polymnesis/widgets/app_button.dart';
import 'package:polymnesis/widgets/settings_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Callbacks de capture, réinitialisés avant chaque test.
  late SyncCredentials? savedCreds;
  late LeitnerSettings? savedLeitner;
  late LtdsSettings? savedLtds;
  late List<int>? importedDays;
  late bool lastDayImported;
  late LtdsImportResult importResult;

  setUp(() {
    savedCreds = null;
    savedLeitner = null;
    savedLtds = null;
    importedDays = null;
    lastDayImported = false;
    importResult = LtdsImportResult(
      cardsCreated: 2,
      triggersAdded: 1,
      questionsFound: 3,
      daysRequested: 1,
      daysWithData: const [152],
      imported: const [
        ImportedQuestion(
            answer: 'Dracula',
            question: 'Qui a inventé Dracula ?',
            kind: ImportKind.created),
        ImportedQuestion(
            answer: 'Stromae',
            question: 'Chanteur de Papaoutai ?',
            kind: ImportKind.alreadyPresent),
      ],
    );
  });

  /// Monte le modal en le poussant comme route, afin que Navigator.pop()
  /// (appelé par _handleSave) dépile une vraie route et non la racine.
  Future<void> pumpModal(
    WidgetTester tester, {
    required SyncCredentials credentials,
    required LeitnerSettings leitnerSettings,
    LtdsSettings? ltdsSettings,
    // Tableau "jours importés" (#7)
    List<DayImportStatus> daysTable = const [],
    Future<List<DayImportStatus>> Function()? onRefreshDays,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: SettingsModal(
                          credentials: credentials,
                          onSave: (c) => savedCreds = c,
                          leitnerSettings: leitnerSettings,
                          onSaveLeitner: (l) => savedLeitner = l,
                          ltdsSettings: ltdsSettings ?? LtdsSettings(),
                          onSaveLtds: (s) async => savedLtds = s,
                          onImport: (days) async {
                            importedDays = days;
                            return importResult;
                          },
                          onImportLastDay: () async {
                            lastDayImported = true;
                            return importResult;
                          },
                          importedDays: daysTable,
                          onRefreshImportedDays: onRefreshDays,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  /// Ouvre l'onglet dont le libellé est [label] ('Sync' / 'Import' / 'Leitner').
  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// Les 6 champs d'intervalle (number, hors champ "réponse rapide").
  Finder intervalFields() => find.byWidgetPredicate((w) =>
      w is TextField &&
      w.keyboardType == TextInputType.number &&
      w.key != const ValueKey('goldenSecondsField'));

  group('SettingsModal - rendu', () {
    testWidgets('affiche l\'en-tête, les 3 onglets et les 6 intervalles',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
          url: 'https://x.supabase.co',
          key: 'abc',
          enabled: true,
        ),
        leitnerSettings: LeitnerSettings(),
      );

      // En-tête + les 3 onglets.
      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.text('Sync'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Leitner'), findsOneWidget);

      // Onglet Leitner : titre + les 6 intervalles pré-remplis.
      await openTab(tester, 'Leitner');
      expect(find.text('Système Leitner'), findsOneWidget);

      final intervalValues = tester
          .widgetList<TextField>(intervalFields())
          .map((tf) => tf.controller!.text)
          .toList();
      expect(intervalValues, ['1', '3', '7', '14', '30', '90']);
    });

    testWidgets('le bloc d\'aide SQL est masqué par défaut (onglet Sync)',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
          url: 'https://x.supabase.co',
          key: 'abc',
          enabled: true,
        ),
        leitnerSettings: LeitnerSettings(),
      );

      // L'onglet Sync est actif par défaut.
      expect(find.text('Comment faire ? (Instructions SQL)'), findsOneWidget);
      expect(find.textContaining('create table cards'), findsNothing);
    });
  });

  group('SettingsModal - aide SQL', () {
    testWidgets('taper le lien affiche le bloc create table cards',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
          url: 'https://x.supabase.co',
          key: 'abc',
          enabled: true,
        ),
        leitnerSettings: LeitnerSettings(),
      );

      await tester.tap(find.text('Comment faire ? (Instructions SQL)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('create table cards'), findsOneWidget);
      expect(find.text('Masquer les instructions'), findsOneWidget);
      expect(find.text('Comment faire ? (Instructions SQL)'), findsNothing);
    });
  });

  group('SettingsModal - sauvegarde', () {
    testWidgets('Enregistrer transmet credentials trimés et intervalles',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
          url: '  https://x.supabase.co  ',
          key: '  abc  ',
          enabled: true,
        ),
        leitnerSettings: LeitnerSettings(),
      );

      // Le bouton Enregistrer est fixe (hors onglets) : sauvegarde tout.
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(savedCreds, isNotNull);
      expect(savedCreds!.url, 'https://x.supabase.co');
      expect(savedCreds!.key, 'abc');
      expect(savedCreds!.enabled, isTrue);

      expect(savedLeitner, isNotNull);
      expect(savedLeitner!.intervals, [1, 3, 7, 14, 30, 90]);
    });

    testWidgets('un intervalle à 0 est ramené à 1 lors de la sauvegarde',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
          url: 'https://x.supabase.co',
          key: 'abc',
          enabled: true,
        ),
        leitnerSettings: LeitnerSettings(),
      );

      await openTab(tester, 'Leitner');
      expect(intervalFields(), findsNWidgets(6));

      await tester.enterText(intervalFields().first, '0');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(savedLeitner, isNotNull);
      expect(savedLeitner!.intervals, [1, 3, 7, 14, 30, 90]);
    });

    testWidgets('un intervalle non numérique vide retombe sur 1',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
          url: 'https://x.supabase.co',
          key: 'abc',
          enabled: true,
        ),
        leitnerSettings: LeitnerSettings(),
      );

      await openTab(tester, 'Leitner');

      // Vider le 5e champ (valeur 30) : int.tryParse('') == null => 1.
      await tester.enterText(intervalFields().at(4), '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(savedLeitner, isNotNull);
      expect(savedLeitner!.intervals, [1, 3, 7, 14, 1, 90]);
    });

    testWidgets('ajouter une boîte : un champ de plus, sauvegardé', (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
      );

      await openTab(tester, 'Leitner');
      expect(intervalFields(), findsNWidgets(6));

      await tester.ensureVisible(find.byKey(const ValueKey('addBoxButton')));
      await tester.tap(find.byKey(const ValueKey('addBoxButton')));
      await tester.pumpAndSettle();

      expect(intervalFields(), findsNWidgets(7));

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(savedLeitner!.boxCount, 7);
      // La nouvelle boîte est pré-remplie au double de la précédente (90 -> 180).
      expect(savedLeitner!.intervals.last, 180);
    });

    testWidgets('supprimer une boîte : un champ de moins, sauvegardé',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
      );

      await openTab(tester, 'Leitner');

      // Supprime la 3e boîte (intervalle 7 j).
      await tester.ensureVisible(find.byKey(const ValueKey('removeBox2')));
      await tester.tap(find.byKey(const ValueKey('removeBox2')));
      await tester.pumpAndSettle();

      expect(intervalFields(), findsNWidgets(5));

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(savedLeitner!.boxCount, 5);
      expect(savedLeitner!.intervals, [1, 3, 14, 30, 90]); // le 7 a sauté
    });

    testWidgets('la dernière boîte ne peut pas être supprimée', (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(intervals: const [1]),
      );

      await openTab(tester, 'Leitner');
      expect(intervalFields(), findsNWidgets(1));

      final btn = tester.widget<IconButton>(
        find.byKey(const ValueKey('removeBox0')),
      );
      expect(btn.onPressed, isNull); // désactivé : il faut au moins une boîte
    });

    testWidgets('la dernière ligne indique « → Maîtrisé »', (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
      );

      await openTab(tester, 'Leitner');

      expect(find.text('Boîte 6 → Maîtrisé'), findsOneWidget);
      expect(find.text('Boîte 1 → 2'), findsOneWidget);
    });

    testWidgets('modifier le temps "réponse rapide" est enregistré',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
      );

      await openTab(tester, 'Leitner');
      await tester.enterText(
        find.byKey(const ValueKey('goldenSecondsField')),
        '10',
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(savedLeitner, isNotNull);
      expect(savedLeitner!.goldenSeconds, 10);
    });
  });

  group('SettingsModal - import La Table des Savoirs', () {
    testWidgets('affiche la section et pré-remplit le jeton existant',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
        ltdsSettings: LtdsSettings(token: 'mon-jeton'),
      );

      await openTab(tester, 'Import');
      expect(find.text('Import "La Table des Savoirs"'), findsOneWidget);
      expect(find.text('Importer les cartes'), findsOneWidget);

      final tokenField = tester.widget<TextField>(
        find.byKey(const ValueKey('ltdsTokenField')),
      );
      expect(tokenField.controller!.text, 'mon-jeton');
    });

    testWidgets('le bouton "dernier jour" appelle onImportLastDay',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
        ltdsSettings: LtdsSettings(token: 'tok'),
      );

      await openTab(tester, 'Import');
      await tester.ensureVisible(find.text('Importer le dernier jour'));
      await tester.tap(find.text('Importer le dernier jour'));
      await tester.pumpAndSettle();

      expect(lastDayImported, isTrue);
      expect(savedLtds, isNotNull); // le jeton est sauvegardé avant l'import
      expect(savedLtds!.token, 'tok');
      expect(find.textContaining('2 carte(s) créée(s)'), findsOneWidget);
    });

    testWidgets('Importer parse la plage et appelle onImport + affiche le résumé',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
        ltdsSettings: LtdsSettings(token: 'tok'),
      );

      await openTab(tester, 'Import');
      await tester.enterText(
        find.byKey(const ValueKey('ltdsRangeField')),
        '130-132',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Importer les cartes'));
      await tester.tap(find.text('Importer les cartes'));
      await tester.pumpAndSettle();

      expect(importedDays, [130, 131, 132]);
      expect(savedLtds, isNotNull);
      expect(savedLtds!.token, 'tok');
      expect(find.textContaining('2 carte(s) créée(s)'), findsOneWidget);
    });

    testWidgets('une plage invalide affiche une erreur sans appeler onImport',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
        ltdsSettings: LtdsSettings(token: 'tok'),
      );

      await openTab(tester, 'Import');
      await tester.enterText(
        find.byKey(const ValueKey('ltdsRangeField')),
        'abc',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Importer les cartes'));
      await tester.tap(find.text('Importer les cartes'));
      await tester.pumpAndSettle();

      expect(importedDays, isNull); // onImport jamais appelé
      expect(find.textContaining('Plage invalide'), findsOneWidget);
    });

    testWidgets('sans jeton, Importer demande le jeton', (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
        ltdsSettings: LtdsSettings(), // jeton vide
      );

      await openTab(tester, 'Import');
      await tester.enterText(
        find.byKey(const ValueKey('ltdsRangeField')),
        '152',
      );
      await tester.ensureVisible(find.text('Importer les cartes'));
      await tester.tap(find.text('Importer les cartes'));
      await tester.pumpAndSettle();

      expect(importedDays, isNull);
      expect(find.textContaining('Renseigne ton jeton'), findsOneWidget);
    });

    testWidgets('l\'onglet Sync explique la portée « compte » de la sync (#42)',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
      );

      // L'onglet Sync est celui par défaut.
      expect(
        find.textContaining('restaure tout'),
        findsOneWidget,
      );
    });

    testWidgets('tableau des jours : bouton désactivé sans sync (#7)',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(), // sync désactivée
        leitnerSettings: LeitnerSettings(),
        onRefreshDays: () async => const [],
      );

      await openTab(tester, 'Import');
      await tester.ensureVisible(find.text('Jours déjà importés'));

      final btn = tester.widget<AppButton>(
        find.byKey(const ValueKey('refreshDaysButton')),
      );
      expect(btn.onPressed, isNull);
      expect(find.textContaining('Nécessite la synchronisation'), findsOneWidget);
    });

    testWidgets('tableau des jours : remplit la grille et sa légende (#7)',
        (tester) async {
      var called = false;
      await pumpModal(
        tester,
        credentials: SyncCredentials(
            url: 'https://x.supabase.co', key: 'k', enabled: true),
        leitnerSettings: LeitnerSettings(),
        onRefreshDays: () async {
          called = true;
          return const [
            DayImportStatus(day: 1, present: 2, total: 2), // importé
            DayImportStatus(day: 2, present: 1, total: 3), // partiel
            DayImportStatus(day: 3, present: 0, total: 2), // à importer
            DayImportStatus(day: 4, present: 0, total: 0), // non joué
          ];
        },
      );

      await openTab(tester, 'Import');
      await tester.ensureVisible(
          find.byKey(const ValueKey('refreshDaysButton')));
      await tester.tap(find.byKey(const ValueKey('refreshDaysButton')));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      // Les 4 pastilles de jour.
      for (final d in ['1', '2', '3', '4']) {
        expect(find.text(d), findsWidgets);
      }
      // Légende + compteur (1 jour complet sur 3 joués).
      expect(find.text('importé'), findsOneWidget);
      expect(find.text('partiel'), findsOneWidget);
      expect(find.text('non joué'), findsOneWidget);
      expect(find.text('1/3 jours'), findsOneWidget);
    });

    testWidgets('taper un jour pré-remplit le champ de plage (#7)',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
            url: 'https://x.supabase.co', key: 'k', enabled: true),
        leitnerSettings: LeitnerSettings(),
        daysTable: const [
          DayImportStatus(day: 1, present: 2, total: 2),
          DayImportStatus(day: 2, present: 0, total: 3), // à importer
        ],
        onRefreshDays: () async => const [],
      );

      await openTab(tester, 'Import');
      final chip = find.text('2');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      final range = tester.widget<TextField>(
        find.byKey(const ValueKey('ltdsRangeField')),
      );
      expect(range.controller!.text, '2');
    });

    testWidgets('taper un jour NON JOUÉ ne fait rien (#7)', (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(
            url: 'https://x.supabase.co', key: 'k', enabled: true),
        leitnerSettings: LeitnerSettings(),
        daysTable: const [
          DayImportStatus(day: 1, present: 0, total: 0), // non joué
        ],
        onRefreshDays: () async => const [],
      );

      await openTab(tester, 'Import');
      await tester.ensureVisible(find.text('1'));
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      final range = tester.widget<TextField>(
        find.byKey(const ValueKey('ltdsRangeField')),
      );
      expect(range.controller!.text, isEmpty); // rien à importer
    });

    testWidgets('résultat cliquable → popup des questions importées (#18)',
        (tester) async {
      await pumpModal(
        tester,
        credentials: SyncCredentials(),
        leitnerSettings: LeitnerSettings(),
        ltdsSettings: LtdsSettings(token: 'tok'),
      );

      await openTab(tester, 'Import');
      await tester.ensureVisible(find.text('Importer le dernier jour'));
      await tester.tap(find.text('Importer le dernier jour'));
      await tester.pumpAndSettle();

      // Un lien "Voir le détail (N question(s))" apparaît sous le résultat.
      final link = find.textContaining('Voir le détail');
      await tester.ensureVisible(link);
      expect(link, findsOneWidget);
      await tester.tap(link);
      await tester.pumpAndSettle();

      // La popup liste les questions (réponse + énoncé).
      expect(find.text('Détail de l\'import (2)'), findsOneWidget);
      expect(find.text('Qui a inventé Dracula ?'), findsOneWidget);
      expect(find.text('Chanteur de Papaoutai ?'), findsOneWidget);
    });
  });
}
