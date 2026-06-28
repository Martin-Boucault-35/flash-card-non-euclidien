import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Service de stockage local avec SharedPreferences
class StorageService {
  static const String _cardsKey = 'polymnesis-cards';
  static const String _syncCredsKey = 'polymnesis-sync-creds';
  static const String _leitnerSettingsKey = 'polymnesis-leitner-settings';
  static const String _ltdsSettingsKey = 'polymnesis-ltds-settings';

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
}
