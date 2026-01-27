import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/comic_theme.dart';

/// Barra de progreso estilo "Energy Bar" de videojuegos/anime
class EnergyBar extends StatelessWidget {
  final double progress; // 0.0 a 1.0
  final double height;
  final bool showPercentage;
  final bool showGlow;
  final String? label;

  const EnergyBar({
    super.key,
    required this.progress,
    this.height = 20,
    this.showPercentage = true,
    this.showGlow = true,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final Color barColor;
    final List<Color> barGradient;

    if (progress < 0.3) {
      barColor = ComicTheme.heroRed;
      barGradient = [
        const Color(0xFFFF4444),
        ComicTheme.heroRed,
        const Color(0xFFCC2233),
      ];
    } else if (progress < 0.7) {
      barColor = ComicTheme.primaryOrange;
      barGradient = [
        ComicTheme.accentYellow,
        ComicTheme.primaryOrange,
        const Color(0xFFE67E00),
      ];
    } else {
      barColor = ComicTheme.powerGreen;
      barGradient = [
        const Color(0xFF55EFC4),
        ComicTheme.powerGreen,
        const Color(0xFF27AE60),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              label!,
              style: GoogleFonts.bangers(
                fontSize: 12,
                color: ComicTheme.comicBorder,
                letterSpacing: 1,
              ),
            ),
          ),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: ComicTheme.comicBorder,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                offset: const Offset(1, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2 - 2),
            child: Stack(
              children: [
                // Barra de fondo
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.grey[300]!,
                        Colors.grey[200]!,
                      ],
                    ),
                  ),
                ),
                // Barra de progreso animada
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: barGradient,
                      ),
                      boxShadow: showGlow
                          ? [
                              BoxShadow(
                                color: barColor.withValues(alpha: 0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        // Brillo superior
                        Positioned(
                          top: 1,
                          left: 4,
                          right: 4,
                          child: Container(
                            height: height / 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(height / 4),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.5),
                                  Colors.white.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Líneas de energía diagonales
                        if (progress > 0.1)
                          CustomPaint(
                            size: Size.infinite,
                            painter: _EnergyLinesPainter(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Porcentaje
                if (showPercentage)
                  Center(
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: GoogleFonts.bangers(
                        fontSize: height * 0.55,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            offset: const Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AnimatedFractionallySizedBox extends StatelessWidget {
  final Duration duration;
  final Curve curve;
  final double widthFactor;
  final Widget child;

  const AnimatedFractionallySizedBox({
    super.key,
    required this.duration,
    required this.curve,
    required this.widthFactor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widthFactor),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: child,
        );
      },
      child: child,
    );
  }
}

class _EnergyLinesPainter extends CustomPainter {
  final Color color;

  _EnergyLinesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const spacing = 8.0;
    for (double x = 0; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
