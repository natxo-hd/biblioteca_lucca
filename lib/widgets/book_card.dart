import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book.dart';
import '../screens/book_detail_screen.dart';
import '../theme/comic_theme.dart';
import 'energy_bar.dart';
import '../widgets/power_button.dart';

class BookCard extends StatefulWidget {
  final Book book;
  final bool showProgress;

  const BookCard({
    super.key,
    required this.book,
    this.showProgress = false,
  });

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant BookCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Forzar rebuild si la portada cambió
    if (oldWidget.book.localCoverPath != widget.book.localCoverPath ||
        oldWidget.book.coverUrl != widget.book.coverUrl) {
      debugPrint('🖼️ BookCard: portada cambió para ${widget.book.title}');
      // Limpiar cache de imagen si el path cambió
      if (widget.book.localCoverPath != null) {
        imageCache.evict(FileImage(File(widget.book.localCoverPath!)));
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        Navigator.push(
          context,
          PowerUpPageRoute(page: BookDetailScreen(book: widget.book)),
        );
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portada con estilo cómic
            Expanded(
              child: Stack(
                children: [
                  // Sombra 3D
                  Positioned(
                    left: 5,
                    top: 5,
                    right: -5,
                    bottom: -5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  // Portada
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: ComicTheme.comicBorder,
                        width: 3,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: _buildCoverImage(),
                    ),
                  ),
                  // Energy bar de progreso
                  if (widget.showProgress && widget.book.totalPages > 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(11),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(6, 18, 6, 6),
                        child: Column(
                          children: [
                            EnergyBar(
                              progress: widget.book.progress,
                              height: 12,
                              showPercentage: false,
                              showGlow: true,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.book.currentPage}/${widget.book.totalPages}',
                              style: GoogleFonts.bangers(
                                color: Colors.white,
                                fontSize: 10,
                                letterSpacing: 0.5,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(1, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Badge completado
                  if (widget.book.isFinished)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: ComicTheme.superSaiyanGradient,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ComicTheme.accentYellow
                                    .withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  // Badge de volumen
                  if (widget.book.isPartOfSeries &&
                      widget.book.volumeNumber != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              ComicTheme.secondaryBlue,
                              Color(0xFF00B4FF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ComicTheme.secondaryBlue
                                  .withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          'Vol.${widget.book.volumeNumber}',
                          style: GoogleFonts.bangers(
                            color: Colors.white,
                            fontSize: 10,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Título
            Text(
              widget.book.title,
              style: GoogleFonts.bangers(
                fontSize: 12,
                color: ComicTheme.comicBorder,
                letterSpacing: 0.3,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Autor
            Text(
              widget.book.author,
              style: GoogleFonts.comicNeue(
                color: ComicTheme.secondaryBlue,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Construye la imagen de portada, priorizando local > URL > placeholder
  Widget _buildCoverImage() {
    // 1. Prioridad: imagen local guardada
    if (widget.book.localCoverPath != null &&
        widget.book.localCoverPath!.isNotEmpty) {
      final file = File(widget.book.localCoverPath!);
      // Mostrar imagen directamente, el errorBuilder maneja si no existe
      return Image.file(
        file,
        key: ValueKey(widget.book.localCoverPath),
        fit: BoxFit.cover,
        gaplessPlayback: false, // Forzar rebuild visual
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Error cargando imagen local: $error');
          return _buildNetworkCover();
        },
      );
    }

    // 2. Fallback: URL remota
    return _buildNetworkCover();
  }

  /// Construye imagen desde URL remota
  Widget _buildNetworkCover() {
    if (widget.book.coverUrl != null && widget.book.coverUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.book.coverUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: ComicTheme.accentYellow.withValues(alpha: 0.2),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ComicTheme.primaryOrange,
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ComicTheme.backgroundCream,
            ComicTheme.accentYellow.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: 32,
            color: ComicTheme.primaryOrange.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.book.title.isNotEmpty ? widget.book.title : 'Sin portada',
              textAlign: TextAlign.center,
              style: GoogleFonts.comicNeue(
                color: ComicTheme.comicBorder.withValues(alpha: 0.5),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
