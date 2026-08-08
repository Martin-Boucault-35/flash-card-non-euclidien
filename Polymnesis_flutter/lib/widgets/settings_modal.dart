import 'package:flutter/material.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
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

  /// Lance l'import du dernier jour (jour courant − 1) et renvoie un résumé.
  final Future<LtdsImportResult> Function() onImportLastDay;

  /// Tableau « jours importés » en cache, et date de son dernier calcul.
  final List<DayImportStatus> importedDays;
  final DateTime? importedDaysComputedAt;

  /// Recalcule le tableau (archive Supabase ⨯ cartes locales) et le renvoie.
  /// `null` = fonctionnalité indisponible (bouton désactivé).
  final Future<List<DayImportStatus>> Function()? onRefreshImportedDays;

  const SettingsModal({
    super.key,
    required this.credentials,
    required this.onSave,
    required this.leitnerSettings,
    required this.onSaveLeitner,
    required this.ltdsSettings,
    required this.onSaveLtds,
    required this.onImport,
    required this.onImportLastDay,
    this.importedDays = const [],
    this.importedDaysComputedAt,
    this.onRefreshImportedDays,
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
    Future<LtdsImportResult> Function() onImportLastDay, {
    List<DayImportStatus> importedDays = const [],
    DateTime? importedDaysComputedAt,
    Future<List<DayImportStatus>> Function()? onRefreshImportedDays,
  }) {
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
        onImportLastDay: onImportLastDay,
        importedDays: importedDays,
        importedDaysComputedAt: importedDaysComputedAt,
        onRefreshImportedDays: onRefreshImportedDays,
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
  // Un seul import à la fois, mais on distingue quel bouton tourne (spinner).
  bool _importingLast = false;
  bool _importingRange = false;
  bool get _importing => _importingLast || _importingRange;
  String? _importMessage;
  bool _importIsError = false;
  List<ImportedQuestion> _importedQuestions = const [];

  // Tableau "jours importés" (#7)
  late List<DayImportStatus> _days;
  DateTime? _daysAt;
  bool _refreshingDays = false;
  String? _daysError;

  @override
  void initState() {
    super.initState();
    _days = widget.importedDays;
    _daysAt = widget.importedDaysComputedAt;
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
        const SizedBox(height: 8),
        // Le projet Supabase fait office de « compte » (#42).
        const Text(
          'La synchronisation couvre les cartes, les réglages Leitner et le '
          'jeton d\'import : saisir ces identifiants sur un nouvel appareil '
          'restaure tout.',
          style: TextStyle(fontSize: 12, color: AppColors.slate500),
        ),
      ],
    );
  }

  // ==================== ONGLET LEITNER ====================

  /// Ajoute une boîte à la fin, pré-remplie avec le double du dernier
  /// intervalle (les paliers Leitner vont en s'espaçant).
  void _addBox() {
    final last = _intervalControllers.isEmpty
        ? 0
        : int.tryParse(_intervalControllers.last.text) ?? 0;
    final suggested = last > 0 ? last * 2 : 1;
    setState(() {
      _intervalControllers.add(TextEditingController(text: '$suggested'));
    });
  }

  /// Supprime la boîte [index] (jamais la dernière restante).
  void _removeBox(int index) {
    if (_intervalControllers.length <= 1) return;
    final removed = _intervalControllers[index];
    setState(() => _intervalControllers.removeAt(index));
    // On libère APRÈS le rebuild : le TextField qui l'utilisait doit d'abord
    // être démonté, sinon il toucherait un controller déjà disposé.
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

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
          'Configurez l\'espacement entre chaque boîte (en jours). Quand vous répondez bien, la carte monte d\'une boîte. Sinon, elle retourne en boîte 1. Après la dernière boîte, la carte est « Maîtrisée ».',
          style: TextStyle(fontSize: 13, color: AppColors.slate400),
        ),
        const SizedBox(height: 16),

        ...List.generate(_intervalControllers.length, (i) {
          final isLast = i == _intervalControllers.length - 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 118,
                  child: Text(
                    // Sortir de la dernière boîte, c'est être maîtrisé.
                    isLast ? 'Boîte ${i + 1} → Maîtrisé' : 'Boîte ${i + 1} → ${i + 2}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.slate300,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
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
                const SizedBox(width: 6),
                const Text(
                  'j',
                  style: TextStyle(fontSize: 13, color: AppColors.slate500),
                ),
                const Spacer(),
                // Il faut au moins une boîte : on ne peut pas tout supprimer.
                IconButton(
                  key: ValueKey('removeBox$i'),
                  tooltip: 'Supprimer cette boîte',
                  onPressed: _intervalControllers.length > 1
                      ? () => _removeBox(i)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  color: AppColors.slate500,
                  disabledColor: AppColors.slate700,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          );
        }),

        // Ajout d'une boîte (aucune limite haute)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('addBoxButton'),
            onPressed: _addBox,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Ajouter une boîte'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.indigo400,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),

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

        // Bouton "jour actuel" (cas le plus courant)
        SizedBox(
          width: double.infinity,
          child: AppButton(
            onPressed: _importing ? null : _handleImportLastDay,
            child: _importingLast
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.today, size: 18),
                      SizedBox(width: 8),
                      Text('Importer le dernier jour'),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(child: Divider(color: AppColors.slate700)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('ou une plage précise',
                  style: TextStyle(fontSize: 12, color: AppColors.slate500)),
            ),
            Expanded(child: Divider(color: AppColors.slate700)),
          ],
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
            child: _importingRange
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
          Builder(builder: (context) {
            final hasList = _importedQuestions.isNotEmpty;
            final color =
                _importIsError ? AppColors.red500 : AppColors.emerald400;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: hasList ? _showImportedDialog : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _importIsError
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            size: 18,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _importMessage!,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.slate200),
                            ),
                          ),
                        ],
                      ),
                      if (hasList) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.list_alt,
                                size: 14, color: AppColors.indigo400),
                            const SizedBox(width: 4),
                            Text(
                              'Voir le détail (${_importedQuestions.length} question(s))',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.indigo400,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 20),
        const Divider(color: AppColors.slate700, height: 1),
        const SizedBox(height: 16),
        _buildImportedDaysSection(),
      ],
    );
  }

  // ---- Tableau des jours déjà importés (#7) ----

  Widget _buildImportedDaysSection() {
    // Le tableau se calcule depuis l'archive Supabase : sans sync, impossible.
    final available =
        widget.onRefreshImportedDays != null && widget.credentials.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month, size: 18, color: AppColors.indigo400),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Jours déjà importés',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            if (_days.isNotEmpty)
              Text(
                '${_days.where((d) => d.state == DayImportState.fullyImported).length}'
                '/${_days.where((d) => d.total > 0).length} jours',
                style: const TextStyle(fontSize: 12, color: AppColors.slate400),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          available
              ? 'Comparé à l\'archive Supabase.'
              : 'Nécessite la synchronisation Supabase (l\'archive y est stockée).',
          style: const TextStyle(fontSize: 12, color: AppColors.slate400),
        ),
        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          child: AppButton(
            key: const ValueKey('refreshDaysButton'),
            variant: AppButtonVariant.secondary,
            onPressed: (available && !_refreshingDays) ? _handleRefreshDays : null,
            child: _refreshingDays
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 18),
                      SizedBox(width: 8),
                      Text('Remplir le tableau'),
                    ],
                  ),
          ),
        ),

        if (_daysError != null) ...[
          const SizedBox(height: 10),
          Text(
            _daysError!,
            style: const TextStyle(fontSize: 12, color: AppColors.red400),
          ),
        ],

        if (_days.isNotEmpty) ...[
          const SizedBox(height: 12),
          // Légende
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _dayLegend(DayImportState.fullyImported, 'importé'),
              _dayLegend(DayImportState.partial, 'partiel'),
              _dayLegend(DayImportState.notImported, 'à importer'),
              _dayLegend(DayImportState.notPlayed, 'non joué'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _days.map(_dayChip).toList(),
          ),
          if (_daysAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Calculé le ${formatEventDate(_daysAt!.millisecondsSinceEpoch)}',
              style: const TextStyle(fontSize: 11, color: AppColors.slate500),
            ),
          ],
        ],
      ],
    );
  }

  /// Couleurs d'un état de jour : (fond, texte).
  (Color, Color) _dayColors(DayImportState state) {
    switch (state) {
      case DayImportState.fullyImported:
        return (AppColors.emerald900.withValues(alpha: 0.6), AppColors.emerald400);
      case DayImportState.partial:
        return (AppColors.amber900.withValues(alpha: 0.5), AppColors.amber200);
      case DayImportState.notImported:
        return (AppColors.slate700.withValues(alpha: 0.7), AppColors.slate200);
      case DayImportState.notPlayed:
        return (AppColors.slate900, AppColors.slate600);
    }
  }

  Widget _dayLegend(DayImportState state, String label) {
    final (bg, fg) = _dayColors(state);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: fg.withValues(alpha: 0.6), width: 0.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
      ],
    );
  }

  /// Une pastille de jour. Taper un jour JOUÉ pré-remplit le champ de plage.
  Widget _dayChip(DayImportStatus status) {
    final (bg, fg) = _dayColors(status.state);
    final played = status.total > 0;

    return InkWell(
      onTap: played ? () => _pickDay(status.day) : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 34,
        padding: const EdgeInsets.symmetric(vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fg.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Text(
          '${status.day}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  /// Met le jour choisi dans le champ de plage, prêt à importer.
  void _pickDay(int day) {
    setState(() {
      _rangeController.text = '$day';
      _importMessage = null;
      _importedQuestions = const [];
    });
  }

  /// Recalcule le tableau des jours (archive Supabase ⨯ cartes locales).
  Future<void> _handleRefreshDays() async {
    final refresh = widget.onRefreshImportedDays;
    if (refresh == null) return;

    setState(() {
      _refreshingDays = true;
      _daysError = null;
    });
    try {
      final days = await refresh();
      if (!mounted) return;
      setState(() {
        _days = days;
        _daysAt = DateTime.now();
        if (days.isEmpty) {
          _daysError = 'Archive vide : lance le workflow « Archive LTDS ».';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _daysError = 'Impossible de lire l\'archive : $e');
    } finally {
      if (mounted) setState(() => _refreshingDays = false);
    }
  }

  /// Import du dernier jour : sauve le jeton puis délègue à onImportLastDay.
  Future<void> _handleImportLastDay() async {
    _importedQuestions = const [];
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _importIsError = true;
        _importMessage = 'Renseigne ton jeton avant d\'importer.';
      });
      return;
    }

    setState(() {
      _importingLast = true;
      _importMessage = null;
      _importIsError = false;
    });

    try {
      await widget.onSaveLtds(LtdsSettings(token: token));
      final result = await widget.onImportLastDay();
      if (!mounted) return;
      setState(() {
        _importIsError = result.questionsFound == 0;
        _importMessage = result.summary;
        _importedQuestions = result.imported;
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
      if (mounted) setState(() => _importingLast = false);
    }
  }

  Future<void> _handleImport() async {
    _importedQuestions = const [];
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
      _importingRange = true;
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
        _importedQuestions = result.imported;
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
      if (mounted) setState(() => _importingRange = false);
    }
  }

  /// Popup listant les questions réellement importées (réponse + énoncé).
  void _showImportedDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.slate900,
        // Marges réduites -> dialog plus large (légende sur 1 ligne).
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        title: Text(
          'Détail de l\'import (${_importedQuestions.length})',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Légende des couleurs
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  _legendItem(AppColors.emerald400, 'nouvelle carte'),
                  _legendItem(AppColors.amber200, 'indice ajouté'),
                  _legendItem(AppColors.red400, 'déjà présente'),
                ],
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.62,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _importedQuestions.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AppColors.slate800, height: 16),
                  itemBuilder: (context, i) {
                    final q = _importedQuestions[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.answer,
                          style: TextStyle(
                            color: _kindColor(q.kind), // couleur selon la nature
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          q.question,
                          style: const TextStyle(
                              color: AppColors.slate300, fontSize: 13),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer',
                style: TextStyle(color: AppColors.indigo400)),
          ),
        ],
      ),
    );
  }

  /// Couleur de la réponse selon la nature de l'import.
  Color _kindColor(ImportKind kind) {
    switch (kind) {
      case ImportKind.created:
        return AppColors.emerald400;
      case ImportKind.triggerAdded:
        return AppColors.amber200;
      case ImportKind.alreadyPresent:
        return AppColors.red400;
    }
  }

  /// Petit item de légende : une pastille de couleur + un libellé.
  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
      ],
    );
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
