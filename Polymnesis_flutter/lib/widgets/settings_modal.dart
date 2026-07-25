import 'package:flutter/material.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

/// Modal de paramètres, organisé en onglets (Sync / Import / Leitner).
class SettingsModal extends StatefulWidget {
  final SyncCredentials credentials;
  final Function(SyncCredentials) onSave;
  final LeitnerSettings leitnerSettings;
  final Function(LeitnerSettings) onSaveLeitner;
  final LtdsSettings ltdsSettings;
  final Future<void> Function(LtdsSettings) onSaveLtds;

  /// Lance l'import pour les jours donnés et renvoie un résumé.
  final Future<LtdsImportResult> Function(List<int> days) onImport;

  const SettingsModal({
    super.key,
    required this.credentials,
    required this.onSave,
    required this.leitnerSettings,
    required this.onSaveLeitner,
    required this.ltdsSettings,
    required this.onSaveLtds,
    required this.onImport,
  });

  static Future<void> show(
    BuildContext context,
    SyncCredentials credentials,
    Function(SyncCredentials) onSave,
    LeitnerSettings leitnerSettings,
    Function(LeitnerSettings) onSaveLeitner,
    LtdsSettings ltdsSettings,
    Future<void> Function(LtdsSettings) onSaveLtds,
    Future<LtdsImportResult> Function(List<int> days) onImport,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SettingsModal(
        credentials: credentials,
        onSave: onSave,
        leitnerSettings: leitnerSettings,
        onSaveLeitner: onSaveLeitner,
        ltdsSettings: ltdsSettings,
        onSaveLtds: onSaveLtds,
        onImport: onImport,
      ),
    );
  }

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late TextEditingController _urlController;
  late TextEditingController _keyController;
  late bool _enabled;
  bool _showHelp = false;
  late List<TextEditingController> _intervalControllers;
  late TextEditingController _goldenController;

  // Import "La Table des Savoirs"
  late TextEditingController _tokenController;
  late TextEditingController _rangeController;
  bool _showTokenHelp = false;
  bool _importing = false;
  String? _importMessage;
  bool _importIsError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _urlController = TextEditingController(text: widget.credentials.url);
    _keyController = TextEditingController(text: widget.credentials.key);
    _enabled = widget.credentials.enabled;
    _intervalControllers = widget.leitnerSettings.intervals
        .map((d) => TextEditingController(text: d.toString()))
        .toList();
    _goldenController = TextEditingController(
      text: widget.leitnerSettings.goldenSeconds.toString(),
    );
    _tokenController = TextEditingController(text: widget.ltdsSettings.token);
    _rangeController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _keyController.dispose();
    for (final c in _intervalControllers) {
      c.dispose();
    }
    _goldenController.dispose();
    _tokenController.dispose();
    _rangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.slate700),
          left: BorderSide(color: AppColors.slate700),
          right: BorderSide(color: AppColors.slate700),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.slate600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.settings, color: AppColors.indigo400),
                const SizedBox(width: 12),
                const Text(
                  'Paramètres',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.slate400),
                ),
              ],
            ),
          ),

          // Onglets
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.indigo400,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.slate400,
            tabs: const [
              Tab(icon: Icon(Icons.cloud_sync, size: 20), text: 'Sync'),
              Tab(icon: Icon(Icons.download, size: 20), text: 'Import'),
              Tab(icon: Icon(Icons.inbox, size: 20), text: 'Leitner'),
            ],
          ),

          // Contenu de l'onglet actif
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _tabScroll(_buildSyncSection()),
                _tabScroll(_buildLtdsSection()),
                _tabScroll(_buildLeitnerSection()),
              ],
            ),
          ),

          const Divider(color: AppColors.slate800, height: 1),

          // Boutons (fixes, communs à tous les onglets)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: () => Navigator.pop(context),
                    variant: AppButtonVariant.ghost,
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    onPressed: _handleSave,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save, size: 18),
                        SizedBox(width: 8),
                        Text('Enregistrer'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Enveloppe le contenu d'un onglet dans une zone défilable.
  Widget _tabScroll(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }

  // ==================== ONGLET SYNC SUPABASE ====================
  Widget _buildSyncSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.slate800.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pour synchroniser vos cartes entre PC et Mobile, vous devez créer un projet gratuit sur Supabase.com.',
                style: TextStyle(fontSize: 14, color: AppColors.slate300),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _showHelp = !_showHelp),
                child: Text(
                  _showHelp
                      ? 'Masquer les instructions'
                      : 'Comment faire ? (Instructions SQL)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.indigo400,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              if (_showHelp) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '// 1. Créez un projet sur Supabase',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.slate500,
                        ),
                      ),
                      Text(
                        '// 2. Allez dans SQL Editor et exécutez :',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.slate500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'create table cards (\n'
                        '  id text primary key,\n'
                        '  data jsonb,\n'
                        '  updated_at timestamptz default now()\n'
                        ');\n\n'
                        'alter table cards enable row level security;\n'
                        'create policy "Public Access" on cards for all using (true);',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.emerald400,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '// 3. Copiez l\'URL et la Clé Anon depuis Project Settings > API',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          'Project URL',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.slate300,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _urlController,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'https://xyz.supabase.co',
            fillColor: AppColors.slate950,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate800),
            ),
          ),
        ),

        const SizedBox(height: 16),

        const Text(
          'API Key (public/anon)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.slate300,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _keyController,
          obscureText: true,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'eyJhbGciOiJIUzI1NiIsInR5...',
            fillColor: AppColors.slate950,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate800),
            ),
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value ?? false),
                activeColor: AppColors.indigo600,
                side: const BorderSide(color: AppColors.slate700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() => _enabled = !_enabled),
              child: const Text(
                'Activer la synchronisation',
                style: TextStyle(fontSize: 14, color: AppColors.slate200),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== ONGLET LEITNER ====================
  Widget _buildLeitnerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.inbox, size: 20, color: AppColors.amber200),
            SizedBox(width: 8),
            Text(
              'Système Leitner',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Configurez l\'espacement entre chaque boîte (en jours). Quand vous répondez bien, la carte monte d\'une boîte. Sinon, elle retourne en boîte 1.',
          style: TextStyle(fontSize: 13, color: AppColors.slate400),
        ),
        const SizedBox(height: 16),

        ...List.generate(_intervalControllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    'Boîte ${i + 1} → ${i + 2}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.slate300,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _intervalControllers[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      fillColor: AppColors.slate950,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.slate700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'jours',
                  style: TextStyle(fontSize: 13, color: AppColors.slate500),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 8),

        // Seuil "réponse rapide" (bonus +2 boîtes)
        Row(
          children: [
            const Icon(Icons.bolt, size: 18, color: AppColors.amber200),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Réponse rapide (+2 boîtes) en moins de',
                style: TextStyle(fontSize: 13, color: AppColors.slate300),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: TextField(
                key: const ValueKey('goldenSecondsField'),
                controller: _goldenController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  fillColor: AppColors.slate950,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.slate700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'sec',
              style: TextStyle(fontSize: 13, color: AppColors.slate500),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== ONGLET IMPORT LTDS ====================
  /// Section "Import La Table des Savoirs" : jeton + plage de jours + bouton.
  Widget _buildLtdsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.download_for_offline, size: 20, color: AppColors.emerald400),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Import "La Table des Savoirs"',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Crée automatiquement des cartes à partir des quiz que tu as joués '
          '(niveaux abordable + expert).',
          style: TextStyle(fontSize: 13, color: AppColors.slate400),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _showTokenHelp = !_showTokenHelp),
          child: Text(
            _showTokenHelp
                ? 'Masquer les instructions'
                : 'Où trouver mon jeton ?',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.indigo400,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        if (_showTokenHelp) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '1. Connecte-toi sur latabledessavoirs.fr (sur PC)\n'
              '2. F12 → Application → Local Storage → latabledessavoirs.fr\n'
              '3. Clé "ltds-auth" → copie la valeur du champ "token"\n'
              '4. Colle-la ci-dessous. (Le jeton expire : recopie-le si besoin.)',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppColors.slate400,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Token
        const Text(
          'Jeton (token)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.slate300,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('ltdsTokenField'),
          controller: _tokenController,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'Colle ici la valeur "token" de ltds-auth',
            fillColor: AppColors.slate950,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate800),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Range
        const Text(
          'Jours à importer',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.slate300,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('ltdsRangeField'),
          controller: _rangeController,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'ex : 152  ou  130-135',
            fillColor: AppColors.slate950,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate800),
            ),
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: AppButton(
            onPressed: _importing ? null : _handleImport,
            child: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_download, size: 18),
                      SizedBox(width: 8),
                      Text('Importer les cartes'),
                    ],
                  ),
          ),
        ),

        if (_importMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_importIsError ? AppColors.red500 : AppColors.emerald400)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (_importIsError ? AppColors.red500 : AppColors.emerald400)
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _importIsError ? Icons.error_outline : Icons.check_circle_outline,
                  size: 18,
                  color: _importIsError ? AppColors.red500 : AppColors.emerald400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _importMessage!,
                    style: const TextStyle(fontSize: 13, color: AppColors.slate200),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleImport() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _importIsError = true;
        _importMessage = 'Renseigne ton jeton avant d\'importer.';
      });
      return;
    }

    final List<int> days;
    try {
      days = LtdsImportService.parseDayRange(_rangeController.text);
    } on FormatException catch (e) {
      setState(() {
        _importIsError = true;
        _importMessage = 'Plage invalide : ${e.message}';
      });
      return;
    }

    setState(() {
      _importing = true;
      _importMessage = null;
      _importIsError = false;
    });

    try {
      // On enregistre d'abord le jeton (pour qu'il soit dispo côté provider).
      await widget.onSaveLtds(LtdsSettings(token: token));
      final result = await widget.onImport(days);
      if (!mounted) return;
      setState(() {
        _importIsError = result.questionsFound == 0;
        _importMessage = result.summary;
      });
    } on LtdsAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _importIsError = true;
        _importMessage = '$e Recopie un nouveau jeton.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importIsError = true;
        _importMessage = 'Erreur lors de l\'import : $e';
      });
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _handleSave() {
    // Save sync credentials
    widget.onSave(SyncCredentials(
      url: _urlController.text.trim(),
      key: _keyController.text.trim(),
      enabled: _enabled,
    ));

    // Save Leitner settings
    final intervals = _intervalControllers
        .map((c) => int.tryParse(c.text) ?? 1)
        .map((v) => v < 1 ? 1 : v)
        .toList();
    final golden = (int.tryParse(_goldenController.text) ??
            LeitnerSettings.defaultGoldenSeconds)
        .clamp(1, 60);
    widget.onSaveLeitner(
      LeitnerSettings(intervals: intervals, goldenSeconds: golden),
    );

    // Save LTDS token
    widget.onSaveLtds(LtdsSettings(token: _tokenController.text.trim()));

    Navigator.pop(context);
  }
}
