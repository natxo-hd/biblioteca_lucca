import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book.dart';
import '../services/book_provider.dart';
import '../widgets/book_grid.dart';
import '../widgets/grouped_book_grid.dart';
import '../theme/comic_theme.dart';
import 'scanner_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  late AnimationController _tabController;
  late Animation<double> _tabFadeAnimation;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fabAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
    );

    _tabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _tabFadeAnimation = CurvedAnimation(
      parent: _tabController,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    _tabController.forward(from: 0.0);
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: ComicTheme.powerGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: ComicTheme.primaryOrange.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_stories, size: 24),
                ),
                const SizedBox(width: 10),
                Text(
                  'BIBLIOTECA DE LUCCA',
                  style: GoogleFonts.bangers(
                    fontSize: 22,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              if (_currentIndex == 1)
                Consumer<BookProvider>(
                  builder: (context, provider, _) {
                    final archivedCount = provider.archivedBooks.length;
                    return IconButton(
                      icon: Badge(
                        isLabelVisible: archivedCount > 0,
                        label: Text(
                          archivedCount.toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        child: const Icon(Icons.archive),
                      ),
                      tooltip: 'Series archivadas',
                      onPressed: () => _showArchivedDialog(context, provider),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: MangaBackground(
        child: Selector<BookProvider, ({bool isLoading, List<Book> reading, List<Book> finished, List<Book> wishlist})>(
          selector: (_, provider) => (
            isLoading: provider.isLoading,
            reading: provider.readingBooks,
            finished: provider.finishedBooks,
            wishlist: provider.wishlistBooks,
          ),
          shouldRebuild: (previous, next) {
            // Solo rebuild si cambia isLoading o la lista del tab actual
            if (previous.isLoading != next.isLoading) return true;
            switch (_currentIndex) {
              case 0:
                return previous.reading != next.reading;
              case 1:
                return previous.finished != next.finished;
              case 2:
                return previous.wishlist != next.wishlist;
              default:
                return false;
            }
          },
          builder: (context, data, child) {
            if (data.isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLoadingIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      'Cargando libros...',
                      style: GoogleFonts.comicNeue(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ComicTheme.comicBorder,
                      ),
                    ),
                  ],
                ),
              );
            }

            final List<Book> books;
            switch (_currentIndex) {
              case 0:
                books = data.reading;
                break;
              case 1:
                books = data.finished;
                break;
              case 2:
                books = data.wishlist;
                break;
              default:
                books = [];
            }

            if (books.isEmpty) {
              return _buildEmptyState();
            }

            return FadeTransition(
              opacity: _tabFadeAnimation,
              child: _buildContent(books),
            );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: ComicTheme.primaryOrange,
              strokeWidth: 4,
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: ComicTheme.powerGradient,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ComicTheme.primaryOrange.withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_stories,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<Book> books) {
    // Generar key basada en hash de portadas para forzar reconstrucción
    final coversHash = books.fold<int>(0, (hash, b) => hash ^ (b.localCoverPath ?? b.coverUrl ?? '').hashCode);

    switch (_currentIndex) {
      case 0:
        return BookGrid(key: ValueKey('reading_$coversHash'), books: books, isReadingList: true);
      case 1:
        return GroupedBookGrid(key: ValueKey('finished_$coversHash'), books: books, isReadingList: false);
      case 2:
        return BookGrid(key: ValueKey('wishlist_$coversHash'), books: books, isReadingList: false);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.auto_stories_outlined,
                selectedIcon: Icons.auto_stories,
                label: 'LEYENDO',
                color: ComicTheme.primaryOrange,
                gradient: ComicTheme.powerGradient,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.emoji_events_outlined,
                selectedIcon: Icons.emoji_events,
                label: 'COMPLETADOS',
                color: ComicTheme.powerGreen,
                gradient: [ComicTheme.powerGreen, const Color(0xFF27AE60)],
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.card_giftcard_outlined,
                selectedIcon: Icons.card_giftcard,
                label: 'SOLICITADOS',
                color: ComicTheme.secondaryBlue,
                gradient: ComicTheme.heroGradient,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return MouseRegion(
      onEnter: (_) => _fabController.forward(),
      onExit: (_) => _fabController.reverse(),
      child: GestureDetector(
        onTapDown: (_) => _fabController.forward(),
        onTapUp: (_) => _fabController.reverse(),
        onTapCancel: () => _fabController.reverse(),
        child: AnimatedBuilder(
          animation: _fabAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _fabAnimation.value,
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF5C6BC0), // Índigo suave
                  Color(0xFF7E57C2), // Púrpura elegante
                ],
              ),
              border: Border.all(
                color: ComicTheme.comicBorder,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5C6BC0).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
                const BoxShadow(
                  color: Colors.black26,
                  offset: Offset(2, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(19),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const ScannerScreen(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        return ScaleTransition(
                          scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.elasticOut,
                            ),
                          ),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 28,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            blurRadius: 4,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AÑADIR',
                        style: GoogleFonts.bangers(
                          fontSize: 20,
                          letterSpacing: 1.5,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 4,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    IconData icon;
    List<Color> gradientColors;
    String title;
    String subtitle;

    switch (_currentIndex) {
      case 0:
        icon = Icons.menu_book;
        gradientColors = ComicTheme.powerGradient;
        title = 'HORA DE LEER';
        subtitle = 'Añade un libro para empezar tu aventura';
        break;
      case 1:
        icon = Icons.emoji_events;
        gradientColors = [ComicTheme.powerGreen, const Color(0xFF27AE60)];
        title = 'A POR TU PRIMER LIBRO';
        subtitle = 'Termina tu primer libro y aparecerá aquí';
        break;
      case 2:
        icon = Icons.card_giftcard;
        gradientColors = [ComicTheme.secondaryBlue, const Color(0xFF2980B9)];
        title = 'LISTA VACIA';
        subtitle = 'Pide el siguiente volumen de tus series en Completados';
        break;
      default:
        icon = Icons.menu_book;
        gradientColors = ComicTheme.powerGradient;
        title = '';
        subtitle = '';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ComicTheme.comicBorder,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors.first.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                        const BoxShadow(
                          color: Colors.black26,
                          offset: Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: GoogleFonts.bangers(
                fontSize: 30,
                color: ComicTheme.comicBorder,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: ComicTheme.comicBorder,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                subtitle,
                style: GoogleFonts.comicNeue(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showArchivedDialog(BuildContext context, BookProvider provider) {
    final archivedGroups = provider.getArchivedSeriesGrouped();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: ComicTheme.backgroundCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: ComicTheme.comicBorder, width: 3),
            left: BorderSide(color: ComicTheme.comicBorder, width: 3),
            right: BorderSide(color: ComicTheme.comicBorder, width: 3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: ComicTheme.powerGradient,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.archive,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SERIES ARCHIVADAS',
                    style: GoogleFonts.bangers(
                      fontSize: 20,
                      color: ComicTheme.comicBorder,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: archivedGroups.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.archive_outlined,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No hay series archivadas',
                            style: GoogleFonts.comicNeue(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Mantén pulsado en una serie para archivarla',
                            style: GoogleFonts.comicNeue(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: archivedGroups.length,
                      itemBuilder: (context, index) {
                        final entry =
                            archivedGroups.entries.elementAt(index);
                        final series = entry.key;
                        final books = entry.value;
                        return _buildArchivedSeriesTile(
                            series, books, provider);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivedSeriesTile(
      String series, List<Book> books, BookProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ComicTheme.comicBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ComicTheme.primaryOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.archive,
                color: ComicTheme.primaryOrange, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  series,
                  style: GoogleFonts.bangers(
                    fontSize: 16,
                    color: ComicTheme.comicBorder,
                  ),
                ),
                Text(
                  '${books.length} volúmenes',
                  style: GoogleFonts.comicNeue(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              provider.unarchiveSeries(series);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$series restaurada!',
                    style:
                        GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: ComicTheme.powerGreen,
                ),
              );
            },
            icon: const Icon(Icons.unarchive, size: 18),
            label: Text(
              'RESTAURAR',
              style: GoogleFonts.bangers(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.secondaryBlue,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required Color color,
    required List<Color> gradient,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _switchTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 18 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.05),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: color.withValues(alpha: 0.5), width: 2)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Icon(
                isSelected ? selectedIcon : icon,
                size: 26,
                color: isSelected ? color : Colors.grey[500],
                shadows: isSelected
                    ? [
                        Shadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.bangers(
                fontSize: isSelected ? 12 : 10,
                color: isSelected ? color : Colors.grey[500],
                letterSpacing: 0.5,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
