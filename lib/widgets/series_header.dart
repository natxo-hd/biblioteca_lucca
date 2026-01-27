import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book.dart';
import '../theme/comic_theme.dart';

/// Widget que muestra el header de una serie en la vista agrupada
class SeriesHeader extends StatelessWidget {
  final String series;
  final int count;
  final bool isCollapsed;
  final int nextVol;
  final bool hasNextInReading;
  final bool hasNextInWishlist;
  final bool isLoading;
  final bool isSeriesComplete;
  final List<Book> books;
  final int? knownMaxVols;

  // Callbacks
  final VoidCallback onToggle;
  final VoidCallback onLongPress;
  final VoidCallback onResumeComplete;
  final VoidCallback onRequestNext;

  const SeriesHeader({
    super.key,
    required this.series,
    required this.count,
    required this.isCollapsed,
    required this.nextVol,
    required this.hasNextInReading,
    required this.hasNextInWishlist,
    required this.isLoading,
    required this.isSeriesComplete,
    required this.books,
    this.knownMaxVols,
    required this.onToggle,
    required this.onLongPress,
    required this.onResumeComplete,
    required this.onRequestNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ComicTheme.secondaryBlue.withValues(alpha: 0.2),
            ComicTheme.primaryOrange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ComicTheme.comicBorder,
          width: 3,
        ),
        boxShadow: [
          const BoxShadow(
            color: Colors.black26,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
          BoxShadow(
            color: ComicTheme.secondaryBlue.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildExpandButton(),
          _buildSeriesName(),
          _buildVolumeCounter(),
          const SizedBox(width: 8),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildExpandButton() {
    return GestureDetector(
      onTap: onToggle,
      child: Row(
        children: [
          Icon(
            isCollapsed ? Icons.chevron_right : Icons.expand_more,
            color: ComicTheme.secondaryBlue,
            size: 24,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSeriesName() {
    return Expanded(
      child: GestureDetector(
        onTap: onToggle,
        onLongPress: onLongPress,
        child: Text(
          series.toUpperCase(),
          style: GoogleFonts.bangers(
            fontSize: 15,
            color: ComicTheme.comicBorder,
            letterSpacing: 1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildVolumeCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ComicTheme.secondaryBlue, Color(0xFF00D4FF)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        '$count vols',
        style: GoogleFonts.bangers(
          fontSize: 12,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (isSeriesComplete) {
      return _buildCompleteButton();
    } else if (hasNextInReading) {
      return _buildReadingButton();
    } else if (hasNextInWishlist) {
      return _buildWishlistButton();
    } else {
      return _buildRequestButton();
    }
  }

  Widget _buildCompleteButton() {
    return GestureDetector(
      onTap: onResumeComplete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [ComicTheme.powerGreen, Color(0xFF00CC44)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              offset: Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              knownMaxVols != null ? '$count/$knownMaxVols' : '¡Completa!',
              style: GoogleFonts.bangers(
                fontSize: 11,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ComicTheme.primaryOrange, Color(0xFFFF8800)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_stories, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'Vol.$nextVol leyendo',
            style: GoogleFonts.bangers(
              fontSize: 11,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ComicTheme.secondaryBlue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ComicTheme.secondaryBlue,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.card_giftcard, size: 12, color: ComicTheme.secondaryBlue),
          const SizedBox(width: 4),
          Text(
            'Vol.$nextVol pedido',
            style: GoogleFonts.comicNeue(
              fontSize: 10,
              color: ComicTheme.secondaryBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.05),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        onTap: isLoading ? null : onRequestNext,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: isLoading
                ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                : const LinearGradient(
                    colors: [ComicTheme.heroRed, Color(0xFFFF4444)],
                  ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              if (!isLoading)
                BoxShadow(
                  color: ComicTheme.heroRed.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              const BoxShadow(
                color: Colors.black38,
                offset: Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.card_giftcard, size: 16, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                '¡VOL.$nextVol!',
                style: GoogleFonts.bangers(
                  fontSize: 12,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
