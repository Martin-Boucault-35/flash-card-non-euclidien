import 'package:flutter/material.dart';
import '../models/sync_credentials.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

/// Modal de paramètres pour la synchronisation Supabase
class SettingsModal extends StatefulWidget {
  final SyncCredentials credentials;
  final Function(SyncCredentials) onSave;

  const SettingsModal({
    super.key,
    required this.credentials,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context,
    SyncCredentials credentials,
    Function(SyncCredentials) onSave,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SettingsModal(
        credentials: credentials,
        onSave: onSave,
      ),
    );
  }

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  late TextEditingController _urlController;
  late TextEditingController _keyController;
  late bool _enabled;
  bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.credentials.url);
    _keyController = TextEditingController(text: widget.credentials.key);
    _enabled = widget.credentials.enabled;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
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
        mainAxisSize: MainAxisSize.min,
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
                const Icon(Icons.cloud, color: AppColors.indigo400),
                const SizedBox(width: 12),
                const Text(
                  'Synchronisation Cloud',
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

          const Divider(color: AppColors.slate800, height: 1),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
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
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.slate300,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => setState(() => _showHelp = !_showHelp),
                          child: Text(
                            _showHelp ? 'Masquer les instructions' : 'Comment faire ? (Instructions SQL)',
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

                  // URL Input
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

                  // Key Input
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

                  // Enable checkbox
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
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.slate200,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Buttons
                  Row(
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
                          onPressed: () {
                            widget.onSave(SyncCredentials(
                              url: _urlController.text.trim(),
                              key: _keyController.text.trim(),
                              enabled: _enabled,
                            ));
                            Navigator.pop(context);
                          },
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
