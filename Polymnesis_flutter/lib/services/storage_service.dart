import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Service de stockage local avec SharedPreferences
class StorageService {
  static const String _cardsKey = 'polymnesis-cards';
  static const String _syncCredsKey = 'polymnesis-sync-creds';
  static const String _leitnerSettingsKey = 'polymnesis-leitner-settings';
  static const String _ltdsSettingsKey = 'polymnesis-ltds-settings';
  static const String _importedDaysKey = 'polymnesis-imported-days';

  static SharedPreferences? _prefs;

  /// Initialise le service de stockage
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Charge les cartes depuis le stockage local
  static List<FlashCard> loadCards() {
    if (_prefs == null) return [];

    final String? jsonString = _prefs!.getString(_cardsKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => FlashCard.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading cards: $e');
      return [];
    }
  }

  /// Sauvegarde les cartes dans le stockage local
  static Future<void> saveCards(List<FlashCard> cards) async {
    if (_prefs == null) return;

    final jsonList = cards.map((card) => card.toJson()).toList();
    await _prefs!.setString(_cardsKey, jsonEncode(jsonList));
  }

  /// Charge les credentials de synchronisation
  static SyncCredentials loadSyncCredentials() {
    if (_prefs == null) return SyncCredentials();

    final String? jsonString = _prefs!.getString(_syncCredsKey);
    if (jsonString == null) return SyncCredentials();

    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return SyncCredentials.fromJson(json);
    } catch (e) {
      print('Error loading sync credentials: $e');
      return SyncCredentials();
    }
  }

  /// Sauvegarde les credentials de synchronisation
  static Future<void> saveSyncCredentials(SyncCredentials creds) async {
    if (_prefs == null) return;
    await _prefs!.setString(_syncCredsKey, jsonEncode(creds.toJson()));
  }

  /// Charge les paramètres Leitner
  static LeitnerSettings loadLeitnerSettings() {
    if (_prefs == null) return LeitnerSettings();

    final String? jsonString = _prefs!.getString(_leitnerSettingsKey);
    if (jsonString == null) return LeitnerSettings();

    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return LeitnerSettings.fromJson(json);
    } catch (e) {
      print('Error loading leitner settings: $e');
      return LeitnerSettings();
    }
  }

  /// Sauvegarde les paramètres Leitner
  static Future<void> saveLeitnerSettings(LeitnerSettings settings) async {
    if (_prefs == null) return;
    await _prefs!.setString(_leitnerSettingsKey, jsonEncode(settings.toJson()));
  }

  /// Charge les paramètres d'import "La Table des Savoirs"
  static LtdsSettings loadLtdsSettings() {
    if (_prefs == null) return LtdsSettings();

    final String? jsonString = _prefs!.getString(_ltdsSettingsKey);
    if (jsonString == null) return LtdsSettings();

    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return LtdsSettings.fromJson(json);
    } catch (e) {
      print('Error loading ltds settings: $e');
      return LtdsSettings();
    }
  }

  /// Sauvegarde les paramètres d'import "La Table des Savoirs"
  static Future<void> saveLtdsSettings(LtdsSettings settings) async {
    if (_prefs == null) return;
    await _prefs!.setString(_ltdsSettingsKey, jsonEncode(settings.toJson()));
  }

  /// Sauvegarde le tableau « jours importés » (statuts + date de calcul), pour
  /// ne pas le recalculer à chaque ouverture des paramètres.
  static Future<void> saveImportedDays(
    List<DayImportStatus> days,
    int computedAtMillis,
  ) async {
    if (_prefs == null) return;
    await _prefs!.setString(
      _importedDaysKey,
      jsonEncode({
        'at': computedAtMillis,
        'days': days.map((d) => d.toJson()).toList(),
      }),
    );
  }

  /// Charge le tableau mis en cache. `at` est null si jamais calculé.
  static (List<DayImportStatus> days, int? computedAtMillis) loadImportedDays() {
    if (_prefs == null) return (const [], null);

    final String? jsonString = _prefs!.getString(_importedDaysKey);
    if (jsonString == null) return (const [], null);

    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      final days = (json['days'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DayImportStatus.fromJson)
          .toList();
      return (days, json['at'] as int?);
    } catch (e) {
      print('Error loading imported days: $e');
      return (const [], null);
    }
  }
}
