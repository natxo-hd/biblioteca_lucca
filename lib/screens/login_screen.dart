import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/comic_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _entryController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideUp = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MangaBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeroIcon(),
                    const SizedBox(height: 36),
                    _buildTitle(),
                    const SizedBox(height: 16),
                    _buildSubtitle(),
                    const SizedBox(height: 52),
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(_slideUp),
                      child: _buildGoogleButton(context),
                    ),
                    const SizedBox(height: 28),
                    _buildInfoText(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo exterior
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  ComicTheme.accentYellow.withValues(alpha: 0.4),
                  ComicTheme.primaryOrange.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
                stops: const [0.3, 0.7, 1.0],
              ),
            ),
          ),
          // Contenedor principal
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ComicTheme.primaryOrange,
                  Color(0xFFFF6B35),
                  ComicTheme.heroRed,
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: ComicTheme.comicBorder,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: ComicTheme.primaryOrange.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
                const BoxShadow(
                  color: Colors.black26,
                  offset: Offset(4, 6),
                  blurRadius: 0,
                ),
              ],
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 60,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Stack(
      children: [
        // Borde del texto
        Text(
          'BIBLIOTECA\nDE LUCCA',
          textAlign: TextAlign.center,
          style: GoogleFonts.bangers(
            fontSize: 46,
            letterSpacing: 3,
            height: 1.1,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = ComicTheme.comicBorder,
          ),
        ),
        // Texto con gradiente
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ComicTheme.primaryOrange,
              ComicTheme.accentYellow,
              ComicTheme.primaryOrange,
            ],
          ).createShader(bounds),
          child: Text(
            'BIBLIOTECA\nDE LUCCA',
            textAlign: TextAlign.center,
            style: GoogleFonts.bangers(
              fontSize: 46,
              letterSpacing: 3,
              height: 1.1,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: ComicTheme.heroGradient,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ComicTheme.comicBorder,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: ComicTheme.secondaryBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          const BoxShadow(
            color: Colors.black26,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        'Tu coleccion de libros',
        style: GoogleFonts.comicNeue(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildGoogleButton(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return GestureDetector(
          onTap: authService.isLoading
              ? null
              : () async {
                  await authService.signInWithGoogle();
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: ComicTheme.comicBorder,
                width: 4,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  offset: Offset(4, 6),
                  blurRadius: 0,
                ),
              ],
            ),
            child: authService.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: ComicTheme.primaryOrange,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Icon(
                          Icons.g_mobiledata_rounded,
                          size: 28,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Entrar con Google',
                        style: GoogleFonts.bangers(
                          fontSize: 24,
                          color: ComicTheme.comicBorder,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildInfoText() {
    return Text(
      'Inicia sesion para guardar\ntus libros en la nube',
      textAlign: TextAlign.center,
      style: GoogleFonts.comicNeue(
        fontSize: 16,
        color: ComicTheme.comicBorder.withValues(alpha: 0.6),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
