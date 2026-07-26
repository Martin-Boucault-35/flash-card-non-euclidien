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

import 'package:polymnesis/models/sync_credentials.dart';
import 'package:polymnesis/models/leitner_settings.dart';
import 'package:polymnesis/models/ltds_settings.dart';
import 'package:polymnesis/providers/card_provider.dart';
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
