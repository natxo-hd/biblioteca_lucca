import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/comic_theme.dart';

class CelebrationOverlay extends StatefulWidget {
  final String bookTitle;
  final VoidCallback onComplete;

  const CelebrationOverlay({
    super.key,
    required this.bookTitle,
    required this.onComplete,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scaleController;
  late AnimationController _burstController;
  late AnimationController _textController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _burstAnimation;
  late Animation<double> _textFade;
  late Animation<double> _textSlide;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
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

    Timer(const Duration(milliseconds: 3500), widget.onComplete);
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
                  color: ComicTheme.accentYellow,
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
              emissionFrequency: 0.04,
              numberOfParticles: 25,
              gravity: 0.15,
              colors: const [
                ComicTheme.primaryOrange,
                ComicTheme.secondaryBlue,
                ComicTheme.accentYellow,
                ComicTheme.heroRed,
                ComicTheme.powerGreen,
                Colors.white,
                ComicTheme.mangaPink,
              ],
            ),
          ),

          // Contenido central
          ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Estrella con brillo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        ComicTheme.accentYellow,
                        ComicTheme.primaryOrange,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ComicTheme.accentYellow.withValues(alpha: 0.6),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Texto COMPLETADO con efecto
                Stack(
                  children: [
                    Text(
                      'COMPLETADO!',
                      style: GoogleFonts.bangers(
                        fontSize: 44,
                        letterSpacing: 4,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 4
                          ..color = ComicTheme.comicBorder,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: ComicTheme.superSaiyanGradient,
                      ).createShader(bounds),
                      child: Text(
                        'COMPLETADO!',
                        style: GoogleFonts.bangers(
                          fontSize: 44,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Subtítulo animado
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
                        gradient: const LinearGradient(
                          colors: ComicTheme.heroGradient,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ComicTheme.secondaryBlue
                                .withValues(alpha: 0.5),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Text(
                        'NIVEL SUPERADO',
                        style: GoogleFonts.bangers(
                          fontSize: 22,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Nombre del libro
                FadeTransition(
                  opacity: _textFade,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
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
                      widget.bookTitle,
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
    return oldDelegate.progress != progress;
  }
}

Future<void> showCelebration(BuildContext context, String bookTitle) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (context) => CelebrationOverlay(
      bookTitle: bookTitle,
      onComplete: () => Navigator.of(context).pop(),
    ),
  );
}
