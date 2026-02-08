import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/achievement.dart';
import '../theme/comic_theme.dart';

/// Overlay de celebración cuando se desbloquea un logro
class AchievementCelebration extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onComplete;

  const AchievementCelebration({
    super.key,
    required this.achievement,
    required this.onComplete,
  });

  @override
  State<AchievementCelebration> createState() => _AchievementCelebrationState();
}

class _AchievementCelebrationState extends State<AchievementCelebration>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scaleController;
  late AnimationController _burstController;
  late AnimationController _textController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _burstAnimation;
  late Animation<double> _textFade;
  late Animation<double> _textSlide;

  AchievementDefinition get definition => widget.achievement.definition;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _burstAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _burstController, curve: Curves.easeOut),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textFade = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );
    _textSlide = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutBack,
    );

    // Secuencia de animaciones
    _burstController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _confettiController.play();
        _scaleController.forward();
      }
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _textController.forward();
    });

    Timer(const Duration(milliseconds: 2500), widget.onComplete);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    _burstController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Generar colores de confetti basados en el logro
    final confettiColors = [
      definition.color,
      definition.color.withValues(alpha: 0.7),
      ComicTheme.accentYellow,
      Colors.white,
      ComicTheme.powerGreen,
    ];

    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Burst de energía
          AnimatedBuilder(
            animation: _burstAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _EnergyBurstPainter(
                  progress: _burstAnimation.value,
                  color: definition.color,
                ),
              );
            },
          ),

          // Confetti desde arriba
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 6,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.15,
              colors: confettiColors,
            ),
          ),

          // Contenido central
          ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge del logro con brillo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        definition.color.withValues(alpha: 0.8),
                        definition.color,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: definition.color.withValues(alpha: 0.6),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                  ),
                  child: Icon(
                    definition.icon,
                    size: 64,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        color: Colors.black38,
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Texto "LOGRO DESBLOQUEADO" con efecto
                Stack(
                  children: [
                    Text(
                      'LOGRO DESBLOQUEADO',
                      style: GoogleFonts.bangers(
                        fontSize: 28,
                        letterSpacing: 3,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 4
                          ..color = ComicTheme.comicBorder,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          definition.color,
                          ComicTheme.accentYellow,
                          definition.color,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'LOGRO DESBLOQUEADO',
                        style: GoogleFonts.bangers(
                          fontSize: 28,
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Título del logro animado
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_textSlide),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            definition.color,
                            definition.color.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: definition.color.withValues(alpha: 0.5),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Text(
                        definition.title,
                        style: GoogleFonts.bangers(
                          fontSize: 26,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Descripción del logro
                FadeTransition(
                  opacity: _textFade,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ComicTheme.comicBorder,
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          offset: Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      definition.description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.comicNeue(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ComicTheme.comicBorder,
                      ),
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
}

class _EnergyBurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  _EnergyBurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.6 * progress;

    // Rayos de energía
    const numRays = 16;
    for (int i = 0; i < numRays; i++) {
      final angle = (i / numRays) * 2 * pi;
      final rayLength = maxRadius * (0.6 + (i % 3) * 0.2);
      final opacity = (1.0 - progress) * 0.6;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = 3 + (i % 2) * 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final start = Offset(
        center.dx + maxRadius * 0.2 * cos(angle),
        center.dy + maxRadius * 0.2 * sin(angle),
      );
      final end = Offset(
        center.dx + rayLength * cos(angle),
        center.dy + rayLength * sin(angle),
      );
      canvas.drawLine(start, end, paint);
    }

    // Círculo de onda expansiva
    final wavePaint = Paint()
      ..color = color.withValues(alpha: (1.0 - progress) * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, maxRadius, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _EnergyBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Muestra la celebración de un logro
Future<void> showAchievementCelebration(
  BuildContext context,
  Achievement achievement,
) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (context) => AchievementCelebration(
      achievement: achievement,
      onComplete: () => Navigator.of(context).pop(),
    ),
  );
}
