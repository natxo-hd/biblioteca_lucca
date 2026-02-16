import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/comic_theme.dart';

/// Indicador de refresh personalizado con estilo cómic
class ComicRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;

  const ComicRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? ComicTheme.primaryOrange,
      backgroundColor: Colors.white,
      strokeWidth: 3,
      displacement: 60,
      child: child,
    );
  }
}

/// Widget que muestra texto animado estilo cómic durante la carga
class ComicLoadingText extends StatefulWidget {
  final String text;
  final Color color;

  const ComicLoadingText({
    super.key,
    this.text = 'CARGANDO',
    this.color = ComicTheme.primaryOrange,
  });

  @override
  State<ComicLoadingText> createState() => _ComicLoadingTextState();
}

class _ComicLoadingTextState extends State<ComicLoadingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ComicTheme.comicBorder, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                widget.text,
                style: GoogleFonts.bangers(
                  fontSize: 18,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Mensajes aleatorios estilo cómic para mostrar durante la carga
class ComicLoadingMessages {
  static const List<String> messages = [
    'POW!',
    'ZAP!',
    'BOOM!',
    'WHOOSH!',
    'WHAM!',
    'CRACK!',
    'KAPOW!',
    'BANG!',
  ];

  static String getRandomMessage() {
    return messages[(DateTime.now().millisecond % messages.length)];
  }
}
