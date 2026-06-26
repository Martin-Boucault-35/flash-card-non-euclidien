import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polymnesis/theme/app_theme.dart';

/// Tests de [AppTheme] et de la palette [AppColors].
///
/// Le thème ne contient pas de logique métier, mais on vérifie qu'il produit
/// bien un [ThemeData] sombre cohérent (Material 3, couleurs clés) et qu'il
/// s'applique à un [MaterialApp] sans erreur — ce qui couvre l'intégralité du
/// getter `darkTheme`.
void main() {
  group('AppTheme.darkTheme', () {
    test('produit un ThemeData sombre Material 3 cohérent', () {
      final theme = AppTheme.darkTheme;

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.slate900);
      expect(theme.primaryColor, AppColors.indigo600);
      expect(theme.colorScheme.primary, AppColors.indigo600);
      expect(theme.colorScheme.secondary, AppColors.indigo400);
      expect(theme.colorScheme.surface, AppColors.slate800);
      expect(theme.colorScheme.error, AppColors.red500);
      expect(theme.inputDecorationTheme.filled, isTrue);
    });

    testWidgets("s'applique à un MaterialApp sans erreur", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: Center(child: Text('ok'))),
        ),
      );
      expect(find.text('ok'), findsOneWidget);
    });
  });

  group('AppColors', () {
    test('expose des constantes de couleur distinctes', () {
      // Échantillon représentatif des familles de teintes utilisées.
      final sample = <Color>{
        AppColors.slate900,
        AppColors.indigo600,
        AppColors.emerald400,
        AppColors.red500,
        AppColors.amber200,
        AppColors.purple400,
      };
      // Toutes distinctes (aucune collision dans l'échantillon).
      expect(sample.length, 6);
    });
  });
}
