import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/comic_theme.dart';

/// Botón estilo power-up con efecto 3D
class PowerButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final double? width;
  final bool isLoading;
  final PowerButtonStyle style;

  const PowerButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.color,
    this.textColor,
    this.width,
    this.isLoading = false,
    this.style = PowerButtonStyle.primary,
  });

  factory PowerButton.primary({
    required String text,
    IconData? icon,
    VoidCallback? onPressed,
    double? width,
    bool isLoading = false,
  }) {
    return PowerButton(
      text: text,
      icon: icon,
      onPressed: onPressed,
      color: ComicTheme.primaryOrange,
      width: width,
      isLoading: isLoading,
      style: PowerButtonStyle.primary,
    );
  }

  factory PowerButton.secondary({
    required String text,
    IconData? icon,
    VoidCallback? onPressed,
    double? width,
    bool isLoading = false,
  }) {
    return PowerButton(
      text: text,
      icon: icon,
      onPressed: onPressed,
      color: ComicTheme.secondaryBlue,
      width: width,
      isLoading: isLoading,
      style: PowerButtonStyle.secondary,
    );
  }

  factory PowerButton.success({
    required String text,
    IconData? icon,
    VoidCallback? onPressed,
    double? width,
    bool isLoading = false,
  }) {
    return PowerButton(
      text: text,
      icon: icon,
      onPressed: onPressed,
      color: ComicTheme.powerGreen,
      width: width,
      isLoading: isLoading,
      style: PowerButtonStyle.success,
    );
  }

  factory PowerButton.danger({
    required String text,
    IconData? icon,
    VoidCallback? onPressed,
    double? width,
    bool isLoading = false,
  }) {
    return PowerButton(
      text: text,
      icon: icon,
      onPressed: onPressed,
      color: ComicTheme.heroRed,
      width: width,
      isLoading: isLoading,
      style: PowerButtonStyle.danger,
    );
  }

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    _controller.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.color ?? ComicTheme.primaryOrange;
    final darkerColor = HSLColor.fromColor(buttonColor)
        .withLightness(
            (HSLColor.fromColor(buttonColor).lightness - 0.15).clamp(0.0, 1.0))
        .toColor();

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                buttonColor,
                buttonColor.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: ComicTheme.comicBorder,
              width: 3,
            ),
            boxShadow: [
              // Sombra 3D inferior
              BoxShadow(
                color: darkerColor,
                offset: Offset(0, _isPressed ? 2 : 4),
                blurRadius: 0,
              ),
              // Sombra exterior
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: Offset(3, _isPressed ? 3 : 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.textColor ?? Colors.white,
                  ),
                )
              else ...[
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    color: widget.textColor ?? Colors.white,
                    size: 22,
                    shadows: const [
                      Shadow(
                        color: Colors.black38,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  widget.text,
                  style: GoogleFonts.bangers(
                    fontSize: 18,
                    color: widget.textColor ?? Colors.white,
                    letterSpacing: 1,
                    shadows: const [
                      Shadow(
                        color: Colors.black38,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum PowerButtonStyle { primary, secondary, success, danger }

/// Transición de página estilo power-up
class PowerUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  PowerUpPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Combinación de escala y fade
            final scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
            );
            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
        );
}

/// Transición de slide con bounce
class BounceSlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SlideDirection direction;

  BounceSlideRoute({
    required this.page,
    this.direction = SlideDirection.right,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            Offset begin;
            switch (direction) {
              case SlideDirection.right:
                begin = const Offset(1.0, 0.0);
                break;
              case SlideDirection.left:
                begin = const Offset(-1.0, 0.0);
                break;
              case SlideDirection.up:
                begin = const Offset(0.0, 1.0);
                break;
              case SlideDirection.down:
                begin = const Offset(0.0, -1.0);
                break;
            }

            final slideAnimation = Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
            );

            return SlideTransition(
              position: slideAnimation,
              child: child,
            );
          },
        );
}

enum SlideDirection { right, left, up, down }
