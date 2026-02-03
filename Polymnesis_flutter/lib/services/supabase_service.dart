import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Service de synchronisation Supabase
class SupabaseService {
  static SupabaseClient? _client;
  static bool _isInitialized = false;

  /// Initialise le client Supabase avec les credentials fournis
  static Future<bool> initialize(SyncCredentials creds) async {
    if (!creds.enabled || !creds.isConfigured) {
      _client = null;
      _isInitialized = false;
      return false;
    }

    try {
      await Supabase.initialize(
        url: creds.url,
        anonKey: creds.key,
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
      return true;
    } catch (e) {
      print('Failed to init Supabase: $e');
      _client = null;
      _isInitialized = false;
      return false;
    }
  }

  /// Réinitialise le client avec de nouveaux credentials
  static Future<bool> reinitialize(SyncCredentials creds) async {
    if (!creds.enabled || !creds.isConfigured) {
      _client = null;
      _isInitialized = false;
      return false;
    }

    try {
      // Si déjà initialisé avec les mêmes credentials, ne rien faire
      if (_isInitialized && _client != null) {
        return true;
      }

      // Sinon, on réinitialise
      await Supabase.initialize(
        url: creds.url,
        anonKey: creds.key,
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
      return true;
    } catch (e) {
      // Si déjà initialisé avec une erreur, on log et on retourne false
      print('Failed to reinit Supabase: $e');
      return false;
    }
  }

  /// Vérifie si le service est prêt
  static bool get isReady => _isInitialized && _client != null;

  /// Récupère toutes les cartes depuis Supabase
  static Future<List<FlashCard>?> fetchRemoteCards() async {
    if (!isReady) return null;

    try {
      final response = await _client!.from('cards').select();

      return (response as List).map((row) {
        return FlashCard.fromJson(row as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('Error fetching cards: $e');
      return null;
    }
  }

  /// Sauvegarde ou met à jour une carte sur Supabase
  static Future<bool> upsertCard(FlashCard card) async {
    if (!isReady) return false;

    try {
      await _client!.from('cards').upsert({
        'id': card.id,
        'data': card.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error saving card: $e');
      return false;
    }
  }

  /// Supprime une carte de Supabase
  static Future<bool> deleteCard(String id) async {
    if (!isReady) return false;

    try {
      await _client!.from('cards').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Error deleting card: $e');
      return false;
    }
  }
}
