import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ComicTheme {
  // Colores principales - Estilo Goku/Superman
  static const Color primaryOrange = Color(0xFFFF8C00);  // Naranja Goku
  static const Color secondaryBlue = Color(0xFF0080FF);  // Azul Superman
  static const Color accentYellow = Color(0xFFFFD700);   // Amarillo energético
  static const Color heroRed = Color(0xFFE63946);        // Rojo heroico
  static const Color powerGreen = Color(0xFF2ECC71);     // Verde poder

  // Colores adicionales manga
  static const Color mangaPink = Color(0xFFFF6B9D);      // Rosa manga
  static const Color cosmicPurple = Color(0xFF7C3AED);   // Púrpura cósmico
  static const Color neonCyan = Color(0xFF00E5FF);       // Cyan neón

  // Fondos
  static const Color backgroundCream = Color(0xFFFFF8E7);  // Papel manga
  static const Color backgroundDark = Color(0xFF1A1A2E);   // Modo oscuro cómic

  // Bordes cómic
  static const Color comicBorder = Color(0xFF2D2D2D);

  // Gradientes de poder
  static const List<Color> powerGradient = [
    Color(0xFFFF8C00),
    Color(0xFFFFD700),
    Color(0xFFFF6B35),
  ];

  static const List<Color> heroGradient = [
    Color(0xFF0080FF),
    Color(0xFF00D4FF),
    Color(0xFF0066CC),
  ];

  static const List<Color> superSaiyanGradient = [
    Color(0xFFFFD700),
    Color(0xFFFFA500),
    Color(0xFFFFE44D),
  ];

  static const List<Color> ultraInstinctGradient = [
    Color(0xFF7C3AED),
    Color(0xFF00D4FF),
    Color(0xFFC084FC),
  ];

  // Tema claro
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primaryOrange,
      secondary: secondaryBlue,
      tertiary: accentYellow,
      surface: backgroundCream,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: comicBorder,
    ),
    scaffoldBackgroundColor: backgroundCream,
    appBarTheme: AppBarTheme(
      backgroundColor: primaryOrange,
      foregroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.black45,
      titleTextStyle: GoogleFonts.bangers(
        fontSize: 28,
        color: Colors.white,
        letterSpacing: 2,
        shadows: [
          const Shadow(
            color: Colors.black38,
            offset: Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      ),
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.bangers(
        fontSize: 48,
        color: comicBorder,
        letterSpacing: 2,
      ),
      displayMedium: GoogleFonts.bangers(
        fontSize: 36,
        color: comicBorder,
        letterSpacing: 1.5,
      ),
      headlineLarge: GoogleFonts.bangers(
        fontSize: 28,
        color: comicBorder,
        letterSpacing: 1,
      ),
      headlineMedium: GoogleFonts.bangers(
        fontSize: 24,
        color: comicBorder,
      ),
      titleLarge: GoogleFonts.comicNeue(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: comicBorder,
      ),
      titleMedium: GoogleFonts.comicNeue(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: comicBorder,
      ),
      bodyLarge: GoogleFonts.comicNeue(
        fontSize: 16,
        color: comicBorder,
      ),
      bodyMedium: GoogleFonts.comicNeue(
        fontSize: 14,
        color: comicBorder,
      ),
      labelLarge: GoogleFonts.bangers(
        fontSize: 16,
        letterSpacing: 1,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black45,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: comicBorder, width: 3),
        ),
        textStyle: GoogleFonts.bangers(
          fontSize: 18,
          letterSpacing: 1,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: comicBorder, width: 3),
        ),
        textStyle: GoogleFonts.bangers(
          fontSize: 18,
          letterSpacing: 1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: secondaryBlue,
        side: const BorderSide(color: secondaryBlue, width: 3),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.bangers(
          fontSize: 18,
          letterSpacing: 1,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: heroRed,
      foregroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: comicBorder, width: 3),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: accentYellow.withValues(alpha: 0.3),
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.bangers(fontSize: 14, letterSpacing: 1),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: comicBorder, width: 3),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: accentYellow.withValues(alpha: 0.3),
      labelStyle: GoogleFonts.comicNeue(
        fontWeight: FontWeight.bold,
        color: comicBorder,
      ),
      side: const BorderSide(color: comicBorder, width: 2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: comicBorder, width: 3),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: comicBorder, width: 3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: secondaryBlue, width: 3),
      ),
      labelStyle: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: comicBorder,
      contentTextStyle: GoogleFonts.comicNeue(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: backgroundCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: comicBorder, width: 4),
      ),
      titleTextStyle: GoogleFonts.bangers(
        fontSize: 24,
        color: comicBorder,
        letterSpacing: 1,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryOrange,
      linearTrackColor: Color(0xFFFFE4B5),
    ),
  );

  // Tema oscuro estilo cómic nocturno
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primaryOrange,
      secondary: secondaryBlue,
      tertiary: accentYellow,
      surface: backgroundDark,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    scaffoldBackgroundColor: backgroundDark,
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF16213E),
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: GoogleFonts.bangers(
        fontSize: 28,
        color: accentYellow,
        letterSpacing: 2,
        shadows: [
          const Shadow(
            color: Colors.black54,
            offset: Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      ),
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.bangers(
        fontSize: 48,
        color: Colors.white,
        letterSpacing: 2,
      ),
      headlineLarge: GoogleFonts.bangers(
        fontSize: 28,
        color: Colors.white,
      ),
      titleLarge: GoogleFonts.comicNeue(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      bodyLarge: GoogleFonts.comicNeue(
        fontSize: 16,
        color: Colors.white70,
      ),
      bodyMedium: GoogleFonts.comicNeue(
        fontSize: 14,
        color: Colors.white70,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF16213E),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentYellow.withValues(alpha: 0.5), width: 2),
      ),
    ),
  );
}

/// Fondo con líneas radiales estilo manga (speed lines) con animación sutil
class MangaBackground extends StatefulWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? lineColor;
  final Offset? centerOffset;
  final bool animate;

  const MangaBackground({
    super.key,
    required this.child,
    this.backgroundColor,
    this.lineColor,
    this.centerOffset,
    this.animate = true,
  });

  @override
  State<MangaBackground> createState() => _MangaBackgroundState();
}

class _MangaBackgroundState extends State<MangaBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.backgroundColor ?? ComicTheme.backgroundCream,
            (widget.backgroundColor ?? ComicTheme.backgroundCream)
                .withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.3),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _MangaRadialLinesPainter(
              lineColor: widget.lineColor ??
                  ComicTheme.comicBorder.withValues(alpha: 0.06),
              centerOffset: widget.centerOffset,
              animationValue: _controller.value,
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _MangaRadialLinesPainter extends CustomPainter {
  final Color lineColor;
  final Offset? centerOffset;
  final double animationValue;

  _MangaRadialLinesPainter({
    required this.lineColor,
    this.centerOffset,
    this.animationValue = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = centerOffset ?? Offset(size.width / 2, size.height * 0.25);
    final maxRadius = size.width > size.height
        ? size.width * 1.5
        : size.height * 1.5;

    const int numLines = 48;
    final rotationOffset = animationValue * 2 * math.pi / numLines;

    for (int i = 0; i < numLines; i++) {
      final angle = (i / numLines) * 2 * math.pi + rotationOffset;
      final thickness = 0.5 + (i % 3) * 0.3;
      final opacity = 0.4 + (i % 4) * 0.15;

      final paint = Paint()
        ..color = lineColor.withValues(alpha: lineColor.a * opacity)
        ..strokeWidth = thickness
        ..style = PaintingStyle.stroke;

      final startRadius = 100.0 + (i % 4) * 25;
      final startX = center.dx + startRadius * math.cos(angle);
      final startY = center.dy + startRadius * math.sin(angle);
      final endX = center.dx + maxRadius * math.cos(angle);
      final endY = center.dy + maxRadius * math.sin(angle);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }

    // Puntos decorativos tipo halftone manga
    final dotPaint = Paint()
      ..color = lineColor.withValues(alpha: lineColor.a * 0.3)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 1.0 + random.nextDouble() * 2.0;
      final dist = (Offset(x, y) - center).distance;
      if (dist > 150) {
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MangaRadialLinesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.lineColor != lineColor;
  }
}

/// Decoración para bordes estilo viñeta de cómic
class ComicBorder extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final List<BoxShadow>? shadows;

  const ComicBorder({
    super.key,
    required this.child,
    this.borderColor,
    this.borderWidth = 3,
    this.borderRadius = 14,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? ComicTheme.comicBorder,
          width: borderWidth,
        ),
        boxShadow: shadows ?? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - borderWidth),
        child: child,
      ),
    );
  }
}

/// Efecto de brillo pulsante para elementos destacados
class PulseGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double maxRadius;

  const PulseGlow({
    super.key,
    required this.child,
    this.glowColor = ComicTheme.accentYellow,
    this.maxRadius = 12,
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.glowColor
                    .withValues(alpha: 0.3 + _controller.value * 0.3),
                blurRadius: widget.maxRadius * (0.5 + _controller.value * 0.5),
                spreadRadius: _controller.value * 4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Efecto shimmer para elementos cargando o especiales
class MangaShimmer extends StatefulWidget {
  final Widget child;
  final Color shimmerColor;

  const MangaShimmer({
    super.key,
    required this.child,
    this.shimmerColor = ComicTheme.accentYellow,
  });

  @override
  State<MangaShimmer> createState() => _MangaShimmerState();
}

class _MangaShimmerState extends State<MangaShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + _controller.value * 3, 0),
              end: Alignment(_controller.value * 3, 0),
              colors: [
                Colors.white,
                widget.shimmerColor.withValues(alpha: 0.5),
                Colors.white,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Action lines estilo manga para momentos de impacto
class ActionLines extends StatelessWidget {
  final Color color;
  final double intensity;

  const ActionLines({
    super.key,
    this.color = ComicTheme.primaryOrange,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ActionLinesPainter(
        color: color.withValues(alpha: 0.15 * intensity),
      ),
    );
  }
}

class _ActionLinesPainter extends CustomPainter {
  final Color color;

  _ActionLinesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const numLines = 24;
    for (int i = 0; i < numLines; i++) {
      final angle = (i / numLines) * 2 * math.pi;
      final startRadius = math.min(size.width, size.height) * 0.3;
      final endRadius = math.max(size.width, size.height) * 0.8;

      final start = Offset(
        center.dx + startRadius * math.cos(angle),
        center.dy + startRadius * math.sin(angle),
      );
      final end = Offset(
        center.dx + endRadius * math.cos(angle),
        center.dy + endRadius * math.sin(angle),
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
