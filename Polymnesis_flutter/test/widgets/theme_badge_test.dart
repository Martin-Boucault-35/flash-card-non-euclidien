import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/models/card_model.dart';
import 'package:polymnesis/widgets/theme_badge.dart';

/// Tests du widget [ThemeBadge].
///
/// Couverture :
///  - pour chaque [FlashCardTheme], le badge affiche son [displayName] ;
///  - la fontSize par défaut (12) est appliquée au [Text] ;
///  - une fontSize personnalisée est respectée et propagée au style du [Text].
///
/// [ThemeBadge] est un [StatelessWidget] sans dépendance au provider ni aux
/// notifications : un simple MaterialApp/Scaffold suffit et pumpAndSettle est OK.
void main() {
  /// Enveloppe le badge dans le minimum requis pour le rendre (Directionality,
  /// thème Material, etc.).
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ThemeBadge - affichage du thème', () {
    testWidgets('affiche le displayName pour chaque FlashCardTheme',
        (tester) async {
      for (final theme in FlashCardTheme.values) {
        await tester.pumpWidget(wrap(ThemeBadge(theme: theme)));
        await tester.pumpAndSettle();

        expect(
          find.text(theme.displayName),
          findsOneWidget,
          reason: 'le badge devrait afficher "${theme.displayName}"',
        );
      }
    });

    testWidgets('affiche bien le libellé "Culture Générale" pour cultureG',
        (tester) async {
      await tester.pumpWidget(
        wrap(const ThemeBadge(theme: FlashCardTheme.cultureG)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Culture Générale'), findsOneWidget);
    });
  });

  group('ThemeBadge - fontSize', () {
    testWidgets('utilise la fontSize par défaut (12) sans surcharge',
        (tester) async {
      await tester.pumpWidget(
        wrap(const ThemeBadge(theme: FlashCardTheme.histoire)),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('Histoire'));
      expect(text.style?.fontSize, 12);
    });

    testWidgets('respecte une fontSize personnalisée', (tester) async {
      await tester.pumpWidget(
        wrap(const ThemeBadge(theme: FlashCardTheme.sciences, fontSize: 20)),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('Sciences'));
      expect(text.style?.fontSize, 20);
    });
  });
}
