import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/achievement.dart';
import '../theme/comic_theme.dart';

/// Badge/Insignia de logro estilo superhéroe
class AchievementBadge extends StatelessWidget {
  final AchievementDefinition definition;
  final bool isUnlocked;
  final double size;
  final bool animate;
  final VoidCallback? onTap;

  const AchievementBadge({
    super.key,
    required this.definition,
    this.isUnlocked = true,
    this.size = 80,
    this.animate = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isUnlocked ? definition.color : Colors.grey[400]!;

    Widget badge = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isUnlocked
              ? RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.9),
                    color,
                  ],
                )
              : RadialGradient(
                  colors: [
                    Colors.grey[300]!,
                    Colors.grey[400]!,
                  ],
                ),
          border: Border.all(
            color: isUnlocked ? ComicTheme.comicBorder : Colors.grey[500]!,
            width: 3,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                  const BoxShadow(
                    color: Colors.black26,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Colors.black12,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUnlocked ? definition.icon : Icons.lock,
              color: Colors.white,
              size: size * 0.35,
              shadows: const [
                Shadow(
                  color: Colors.black38,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            const SizedBox(height: 2),
            if (isUnlocked)
              Text(
                definition.title,
                style: GoogleFonts.bangers(
                  fontSize: size * 0.10,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  shadows: const [
                    Shadow(
                      color: Colors.black38,
                      offset: Offset(1, 1),
                      blurRadius: 1,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else
              Text(
                '?',
                style: GoogleFonts.bangers(
                  fontSize: size * 0.15,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      ),
    );

    if (animate && isUnlocked) {
      badge = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: badge,
      );
    }

    return badge;
  }
}

/// Badge pequeño para mostrar en listas
class AchievementBadgeSmall extends StatelessWidget {
  final AchievementDefinition definition;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const AchievementBadgeSmall({
    super.key,
    required this.definition,
    this.isUnlocked = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isUnlocked ? definition.color : Colors.grey[400]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUnlocked ? color.withValues(alpha: 0.15) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUnlocked ? color : Colors.grey[400]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isUnlocked ? definition.icon : Icons.lock,
              color: isUnlocked ? color : Colors.grey[500],
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              isUnlocked ? definition.title : '???',
              style: GoogleFonts.bangers(
                fontSize: 14,
                color: isUnlocked ? color : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tooltip con información del logro
class AchievementTooltip extends StatelessWidget {
  final AchievementDefinition definition;
  final Achievement? achievement;
  final bool isUnlocked;

  const AchievementTooltip({
    super.key,
    required this.definition,
    this.achievement,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 250),
      decoration: BoxDecoration(
        color: ComicTheme.backgroundCream,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? definition.color.withValues(alpha: 0.2)
                      : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUnlocked ? definition.icon : Icons.lock,
                  color: isUnlocked ? definition.color : Colors.grey[500],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUnlocked ? definition.title : '???',
                      style: GoogleFonts.bangers(
                        fontSize: 18,
                        color: isUnlocked
                            ? definition.color
                            : Colors.grey[500],
                      ),
                    ),
                    Text(
                      definition.description,
                      style: GoogleFonts.comicNeue(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isUnlocked && achievement != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ComicTheme.powerGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: ComicTheme.powerGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(achievement!.unlockedAt),
                    style: GoogleFonts.comicNeue(
                      fontSize: 12,
                      color: ComicTheme.powerGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Hoy';
    } else if (diff.inDays == 1) {
      return 'Ayer';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} dias';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
