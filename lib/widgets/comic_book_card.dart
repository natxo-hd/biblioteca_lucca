import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book.dart';
import '../theme/comic_theme.dart';
import 'energy_bar.dart';
import 'hero_badge.dart';

/// Tarjeta de libro con estilo viñeta de cómic
class ComicBookCard extends StatefulWidget {
  final Book book;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showProgress;
  final bool showBadge;

  const ComicBookCard({
    super.key,
    required this.book,
    this.onTap,
    this.onLongPress,
    this.showProgress = true,
    this.showBadge = true,
  });

  @override
  State<ComicBookCard> createState() => _ComicBookCardState();
}

class _ComicBookCardState extends State<ComicBookCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ComicTheme.comicBorder,
              width: 3,
            ),
            boxShadow: const [
              // Sombra estilo cómic
              BoxShadow(
                color: Colors.black38,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              children: [
                // Portada
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildCover(),
                    ),
                    // Info inferior
                    _buildInfo(),
                  ],
                ),
                // Badge de completado
                if (widget.showBadge && widget.book.isFinished)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CornerBadge.completed(),
                  ),
                // Número de volumen
                if (widget.book.volumeNumber != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildVolumeTag(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    if (widget.book.coverUrl != null && widget.book.coverUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.book.coverUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(),
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
            ComicTheme.accentYellow.withValues(alpha: 0.3),
            ComicTheme.primaryOrange.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories,
              size: 40,
              color: ComicTheme.primaryOrange.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.book.title,
                style: GoogleFonts.bangers(
                  fontSize: 12,
                  color: ComicTheme.comicBorder.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: ComicTheme.comicBorder.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.book.title,
            style: GoogleFonts.bangers(
              fontSize: 12,
              color: ComicTheme.comicBorder,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            widget.book.author,
            style: GoogleFonts.comicNeue(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.showProgress && widget.book.isReading && widget.book.totalPages > 0) ...[
            const SizedBox(height: 6),
            EnergyBar(
              progress: widget.book.progress,
              height: 12,
              showPercentage: false,
              showGlow: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVolumeTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ComicTheme.secondaryBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(1, 1),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        'Vol.${widget.book.volumeNumber}',
        style: GoogleFonts.bangers(
          fontSize: 10,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Grid de libros con estilo cómic
class ComicBookGrid extends StatelessWidget {
  final List<Book> books;
  final Function(Book)? onBookTap;
  final Function(Book)? onBookLongPress;
  final bool showProgress;
  final int crossAxisCount;

  const ComicBookGrid({
    super.key,
    required this.books,
    this.onBookTap,
    this.onBookLongPress,
    this.showProgress = true,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return ComicBookCard(
          book: book,
          onTap: onBookTap != null ? () => onBookTap!(book) : null,
          onLongPress: onBookLongPress != null ? () => onBookLongPress!(book) : null,
          showProgress: showProgress,
        );
      },
    );
  }
}
