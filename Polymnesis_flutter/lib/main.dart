import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/models.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';
import 'theme/app_theme.dart';
import 'widgets/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force dark status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const PolyMnesisApp());
}

class PolyMnesisApp extends StatelessWidget {
  const PolyMnesisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CardProvider()..initialize(),
      child: MaterialApp(
        title: 'PolyMnesis',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }
}

/// Écran principal avec navigation
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
  }

  void _openSettings() {
    final provider = context.read<CardProvider>();
    SettingsModal.show(
      context,
      provider.syncCredentials,
      (creds) => provider.updateSyncCredentials(creds),
    );
  }

  void _handleEditCard(FlashCard card) {
    final provider = context.read<CardProvider>();
    provider.setEditingCard(card);
    setState(() => _currentIndex = 1); // Navigate to create screen
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CardProvider>();

    if (!provider.isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.slate900,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.indigo600,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'PolyMnesis',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(
                color: AppColors.indigo400,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.slate900,
      appBar: _buildAppBar(provider),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar(CardProvider provider) {
    return AppBar(
      backgroundColor: AppColors.slate900.withValues(alpha: 0.5),
      elevation: 0,
      title: GestureDetector(
        onTap: () => _navigateTo(0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.indigo600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.psychology,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'PolyMnesis',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: _openSettings,
          icon: provider.isSyncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.indigo400,
                  ),
                )
              : const Icon(Icons.settings, color: AppColors.slate400),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: AppColors.slate800,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(
          onNavigateToCreate: () => _navigateTo(1),
          onNavigateToGame: () => _navigateTo(3),
        );
      case 1:
        return CreateScreen(
          onCancel: () => _navigateTo(2),
          onSaved: () {
            final provider = context.read<CardProvider>();
            if (provider.editingCard == null) {
              // Stay on create screen after saving new card
            } else {
              // Go to collection after editing
              _navigateTo(2);
            }
          },
        );
      case 2:
        return CollectionScreen(
          onEdit: _handleEditCard,
        );
      case 3:
        return const GameScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomNav() {
    final provider = context.watch<CardProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.slate900,
        border: Border(
          top: BorderSide(color: AppColors.slate800),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Accueil',
                isSelected: _currentIndex == 0,
                onTap: () => _navigateTo(0),
              ),
              _NavItem(
                icon: Icons.add_circle_outline,
                selectedIcon: Icons.add_circle,
                label: 'Créer',
                isSelected: _currentIndex == 1,
                onTap: () {
                  provider.resetEditingCard();
                  _navigateTo(1);
                },
              ),
              _NavItem(
                icon: Icons.grid_view_outlined,
                selectedIcon: Icons.grid_view,
                label: 'Pokédex',
                isSelected: _currentIndex == 2,
                onTap: () => _navigateTo(2),
                badge: provider.cardCount.toString(),
              ),
              _NavItem(
                icon: Icons.play_circle_outline,
                selectedIcon: Icons.play_circle_filled,
                label: 'Jouer',
                isSelected: _currentIndex == 3,
                onTap: () => _navigateTo(3),
                isPrimary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;
  final bool isPrimary;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? (isPrimary ? AppColors.indigo400 : Colors.white)
        : AppColors.slate400;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isPrimary && isSelected
            ? BoxDecoration(
                color: AppColors.indigo600.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: color,
                  size: 24,
                ),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.indigo600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
