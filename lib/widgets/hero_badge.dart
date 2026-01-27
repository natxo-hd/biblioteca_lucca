import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/comic_theme.dart';

/// Badge/Insignia estilo superhéroe
class HeroBadge extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;
  final double size;
  final bool animate;

  const HeroBadge({
    super.key,
    required this.text,
    required this.icon,
    this.color,
    this.size = 60,
    this.animate = true,
  });

  factory HeroBadge.completed({double size = 60}) {
    return HeroBadge(
      text: 'COMPLETADO',
      icon: Icons.star,
      color: ComicTheme.accentYellow,
      size: size,
    );
  }

  factory HeroBadge.reading({double size = 60}) {
    return HeroBadge(
      text: 'LEYENDO',
      icon: Icons.auto_stories,
      color: ComicTheme.primaryOrange,
      size: size,
    );
  }

  factory HeroBadge.series({required int count, double size = 60}) {
    return HeroBadge(
      text: '$count VOLS',
      icon: Icons.collections_bookmark,
      color: ComicTheme.secondaryBlue,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? ComicTheme.accentYellow;

    Widget badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            badgeColor,
            badgeColor.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: ComicTheme.comicBorder,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Colors.black26,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
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
          Text(
            text,
            style: GoogleFonts.bangers(
              fontSize: size * 0.12,
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
          ),
        ],
      ),
    );

    if (animate) {
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

/// Insignia pequeña para esquina de tarjetas
class CornerBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? tooltip;

  const CornerBadge({
    super.key,
    required this.icon,
    required this.color,
    this.tooltip,
  });

  factory CornerBadge.completed() {
    return const CornerBadge(
      icon: Icons.check_circle,
      color: ComicTheme.powerGreen,
      tooltip: 'Completado',
    );
  }

  factory CornerBadge.favorite() {
    return const CornerBadge(
      icon: Icons.favorite,
      color: ComicTheme.heroRed,
      tooltip: 'Favorito',
    );
  }

  factory CornerBadge.newBadge() {
    return const CornerBadge(
      icon: Icons.fiber_new,
      color: ComicTheme.secondaryBlue,
      tooltip: 'Nuevo',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}
