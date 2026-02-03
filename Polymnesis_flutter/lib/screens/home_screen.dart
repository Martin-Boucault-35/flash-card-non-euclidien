import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Écran d'accueil
class HomeScreen extends StatelessWidget {
  final VoidCallback onNavigateToCreate;
  final VoidCallback onNavigateToGame;

  const HomeScreen({
    super.key,
    required this.onNavigateToCreate,
    required this.onNavigateToGame,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 60),

          // Title
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.indigo400, AppColors.purple400],
            ).createShader(bounds),
            child: const Text(
              'Mémoire Non-Euclidienne',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Entraînez votre cerveau avec des cartes dynamiques. Une réponse, une infinité de chemins pour y arriver.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.slate400,
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Cards
          Row(
            children: [
              Expanded(
                child: _HomeCard(
                  icon: Icons.add,
                  iconColor: AppColors.indigo400,
                  title: 'Créer des cartes',
                  description: 'Ajoutez de nouvelles connaissances avec plusieurs triggers.',
                  onTap: onNavigateToCreate,
                  borderColor: AppColors.indigo500,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _HomeCard(
                  icon: Icons.play_arrow,
                  iconColor: AppColors.emerald400,
                  title: 'Lancer une session',
                  description: 'Testez votre mémoire avec le mode aléatoire adaptatif.',
                  onTap: onNavigateToGame,
                  borderColor: AppColors.emerald500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color borderColor;

  const _HomeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.slate800,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate700),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
