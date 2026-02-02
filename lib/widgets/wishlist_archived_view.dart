import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../theme/comic_theme.dart';
import '../services/book_provider.dart';
import 'book_card.dart';
import 'alphabet_index.dart';

/// Vista combinada de libros solicitados (wishlist) y series archivadas.
///
/// Muestra primero los libros solicitados en grid 3 columnas,
/// y debajo las series archivadas agrupadas con headers colapsables
/// y filas horizontales de portadas (como en GroupedBookGrid).
/// Incluye AlphabetIndex para navegación rápida.
class WishlistAndArchivedView extends StatefulWidget {
  final List<Book> wishlistBooks;
  final List<Book> archivedBooks;

  const WishlistAndArchivedView({
    super.key,
    required this.wishlistBooks,
    required this.archivedBooks,
  });

  @override
  State<WishlistAndArchivedView> createState() =>
      _WishlistAndArchivedViewState();
}

class _WishlistAndArchivedViewState extends State<WishlistAndArchivedView> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _collapsedSeries = {};
  String? _currentLetter;
  bool _showLetterIndicator = false;

  /// Agrupar libros archivados por serie, ordenados alfabéticamente
  Map<String, List<Book>> get _archivedGrouped {
    final Map<String, List<Book>> grouped = {};
    for (final book in widget.archivedBooks) {
      final key = book.seriesName ?? book.title;
      grouped.putIfAbsent(key, () => []).add(book);
    }
    // Ordenar volúmenes dentro de cada serie
    for (final books in grouped.values) {
      books.sort((a, b) => (a.volumeNumber ?? 0).compareTo(b.volumeNumber ?? 0));
    }
    // Ordenar series alfabéticamente
    final sorted = Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())),
    );
    return sorted;
  }

  Set<String> get _availableLetters {
    final letters = <String>{};
    for (final series in _archivedGrouped.keys) {
      final letter = _getSeriesLetter(series);
      letters.add(letter);
    }
    return letters;
  }

  String _getSeriesLetter(String series) {
    final firstChar = series.trim().toUpperCase();
    if (firstChar.isEmpty) return '#';
    final char = firstChar[0];
    if (RegExp(r'[A-Z]').hasMatch(char)) return char;
    return '#';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSeries(String series) {
    setState(() {
      if (_collapsedSeries.contains(series)) {
        _collapsedSeries.remove(series);
      } else {
        _collapsedSeries.add(series);
      }
    });
  }

  void _scrollToLetter(String letter) {
    final grouped = _archivedGrouped;
    final sortedSeries = grouped.keys.toList();

    // Encontrar primera serie con esa letra
    int targetIndex = -1;
    for (int i = 0; i < sortedSeries.length; i++) {
      if (_getSeriesLetter(sortedSeries[i]) == letter) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex < 0) return;

    // Calcular offset: sección solicitados + series anteriores
    double offset = 0;

    // Altura de la sección de solicitados
    if (widget.wishlistBooks.isNotEmpty) {
      const sectionHeaderHeight = 60.0;
      final wishlistRows = (widget.wishlistBooks.length / 3).ceil();
      const rowHeight = 216.0;
      offset += sectionHeaderHeight + (wishlistRows * rowHeight) + 24;
    }

    // Altura del header de sección "ARCHIVADAS"
    offset += 60.0;

    // Sumar alturas de series anteriores
    for (int i = 0; i < targetIndex; i++) {
      final seriesName = sortedSeries[i];
      const seriesHeaderHeight = 68.0; // header con padding
      final isCollapsed = _collapsedSeries.contains(seriesName);
      if (isCollapsed) {
        offset += seriesHeaderHeight;
      } else {
        const booksRowHeight = 207.0; // 195 + spacing 12
        offset += seriesHeaderHeight + booksRowHeight;
      }
    }

    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );

    setState(() {
      _currentLetter = letter;
      _showLetterIndicator = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showLetterIndicator = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _archivedGrouped;
    final hasWishlist = widget.wishlistBooks.isNotEmpty;
    final hasArchived = grouped.isNotEmpty;
    final showAlphabetIndex = hasArchived && grouped.length >= 3;

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            // --- SOLICITADOS ---
            if (hasWishlist) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  'SOLICITADOS',
                  widget.wishlistBooks.length,
                  Icons.card_giftcard,
                  ComicTheme.secondaryBlue,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => BookCard(
                      book: widget.wishlistBooks[index],
                      showProgress: false,
                    ),
                    childCount: widget.wishlistBooks.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            // --- ARCHIVADAS ---
            if (hasArchived) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  'ARCHIVADAS',
                  grouped.length,
                  Icons.archive,
                  Colors.grey[600]!,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16, 0, showAlphabetIndex ? 40 : 16, 0,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = grouped.entries.elementAt(index);
                      final series = entry.key;
                      final books = entry.value;
                      final isCollapsed = _collapsedSeries.contains(series);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildArchivedSeriesHeader(series, books.length, isCollapsed),
                          if (!isCollapsed) _buildBooksRow(books),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                    childCount: grouped.length,
                  ),
                ),
              ),
            ],

            // Padding para FAB
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),

        // Alphabet index
        if (showAlphabetIndex)
          Positioned(
            right: 4,
            top: hasWishlist ? 16 : 76,
            bottom: 100,
            child: AlphabetIndex(
              availableLetters: _availableLetters,
              currentLetter: _currentLetter,
              onLetterSelected: _scrollToLetter,
            ),
          ),

        // Letter indicator
        if (_showLetterIndicator && _currentLetter != null)
          Center(child: LetterIndicator(letter: _currentLetter!)),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.bangers(
              fontSize: 20,
              color: ComicTheme.comicBorder,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.bangers(
                fontSize: 14,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedSeriesHeader(String series, int volCount, bool isCollapsed) {
    return GestureDetector(
      onTap: () => _toggleSeries(series),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[400]!.withValues(alpha: 0.2),
              Colors.grey[300]!.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[400]!,
            width: 2,
          ),
          boxShadow: [
            const BoxShadow(
              color: Colors.black12,
              offset: Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isCollapsed ? Icons.chevron_right : Icons.expand_more,
              color: Colors.grey[600],
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey[500],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                '$volCount vols',
                style: GoogleFonts.bangers(
                  fontSize: 12,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                context.read<BookProvider>().unarchiveSeries(series);
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$series restaurada!',
                      style:
                          GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: ComicTheme.powerGreen,
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              icon: const Icon(Icons.unarchive, size: 16, color: ComicTheme.secondaryBlue),
              label: Text(
                'RESTAURAR',
                style: GoogleFonts.bangers(
                  fontSize: 11,
                  color: ComicTheme.secondaryBlue,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBooksRow(List<Book> books) {
    return SizedBox(
      height: 195,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: books.length,
        itemBuilder: (context, index) {
          return Container(
            width: 110,
            margin: EdgeInsets.only(right: index < books.length - 1 ? 12 : 0),
            child: Opacity(
              opacity: 0.6,
              child: BookCard(
                key: ValueKey('archived_${books[index].isbn}'),
                book: books[index],
                showProgress: false,
              ),
            ),
          );
        },
      ),
    );
  }
}
