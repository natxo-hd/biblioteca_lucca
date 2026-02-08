import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/achievement.dart';
import '../theme/comic_theme.dart';
import 'achievement_badge.dart';

/// Grid de logros agrupados por categoría
class AchievementsGrid extends StatelessWidget {
  final List<Achievement> unlockedAchievements;
  final Function(AchievementDefinition, Achievement?)? onTapAchievement;

  const AchievementsGrid({
    super.key,
    required this.unlockedAchievements,
    this.onTapAchievement,
  });

  @override
  Widget build(BuildContext context) {
    final unlockedIds = unlockedAchievements.map((a) => a.id).toSet();

    return Column(
      children: [
        _buildCategorySection(
          context,
          title: 'RACHAS',
          icon: Icons.local_fire_department,
          color: const Color(0xFFFF5722),
          category: AchievementCategory.streak,
          unlockedIds: unlockedIds,
        ),
        const SizedBox(height: 24),
        _buildCategorySection(
          context,
          title: 'VELOCIDAD',
          icon: Icons.flash_on,
          color: const Color(0xFF2196F3),
          category: AchievementCategory.speed,
          unlockedIds: unlockedIds,
        ),
        const SizedBox(height: 24),
        _buildCategorySection(
          context,
          title: 'PRODUCTIVIDAD',
          icon: Icons.trending_up,
          color: const Color(0xFF4CAF50),
          category: AchievementCategory.productivity,
          unlockedIds: unlockedIds,
        ),
        const SizedBox(height: 24),
        _buildCategorySection(
          context,
          title: 'ESPECIALES',
          icon: Icons.star,
          color: const Color(0xFFFFD700),
          category: AchievementCategory.special,
          unlockedIds: unlockedIds,
        ),
      ],
    );
  }

  Widget _buildCategorySection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required AchievementCategory category,
    required Set<String> unlockedIds,
  }) {
    final achievements = AchievementDefinitions.byCategory(category);
    final unlockedCount = achievements.where((a) => unlockedIds.contains(a.id)).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ComicTheme.comicBorder, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header de la categoría
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.bangers(
                    fontSize: 18,
                    color: ComicTheme.comicBorder,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: unlockedCount == achievements.length
                        ? ComicTheme.powerGreen.withValues(alpha: 0.2)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unlockedCount/${achievements.length}',
                    style: GoogleFonts.bangers(
                      fontSize: 14,
                      color: unlockedCount == achievements.length
                          ? ComicTheme.powerGreen
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Grid de badges
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: achievements.map((def) {
                final isUnlocked = unlockedIds.contains(def.id);
                final achievement = isUnlocked
                    ? unlockedAchievements.firstWhere((a) => a.id == def.id)
                    : null;

                return _AchievementItem(
                  definition: def,
                  achievement: achievement,
                  isUnlocked: isUnlocked,
                  onTap: onTapAchievement != null
                      ? () => onTapAchievement!(def, achievement)
                      : null,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementItem extends StatelessWidget {
  final AchievementDefinition definition;
  final Achievement? achievement;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const _AchievementItem({
    required this.definition,
    this.achievement,
    required this.isUnlocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap?.call();
        _showTooltip(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AchievementBadge(
            definition: definition,
            isUnlocked: isUnlocked,
            size: 70,
            animate: false,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 80,
            child: Text(
              isUnlocked ? definition.title : '???',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.comicNeue(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? ComicTheme.comicBorder : Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTooltip(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: AchievementTooltip(
          definition: definition,
          achievement: achievement,
          isUnlocked: isUnlocked,
        ),
      ),
    );
  }
}

/// Widget para mostrar resumen de logros
class AchievementsSummary extends StatelessWidget {
  final int unlockedCount;
  final int totalCount;
  final int currentStreak;
  final int pagesReadToday;

  const AchievementsSummary({
    super.key,
    required this.unlockedCount,
    required this.totalCount,
    required this.currentStreak,
    required this.pagesReadToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: ComicTheme.heroGradient,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ComicTheme.comicBorder, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            icon: Icons.emoji_events,
            value: '$unlockedCount/$totalCount',
            label: 'LOGROS',
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.local_fire_department,
            value: '$currentStreak',
            label: 'RACHA',
            valueColor: currentStreak >= 3 ? ComicTheme.accentYellow : null,
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.auto_stories,
            value: '$pagesReadToday',
            label: 'PAGS HOY',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    Color? valueColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.bangers(
            fontSize: 24,
            color: valueColor ?? Colors.white,
            shadows: const [
              Shadow(
                color: Colors.black38,
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        Text(
          label,
          style: GoogleFonts.comicNeue(
            fontSize: 11,
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 50,
      width: 2,
      color: Colors.white30,
    );
  }
}
