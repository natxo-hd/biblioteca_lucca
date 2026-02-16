import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book.dart';
import '../services/book_provider.dart';
import '../services/new_volume_checker_service.dart';
import '../widgets/book_grid.dart';
import '../widgets/grouped_book_grid.dart';
import '../widgets/new_volumes_alert_dialog.dart';
import '../widgets/wishlist_archived_view.dart';
import '../widgets/skeleton_book_card.dart';
import '../widgets/local_search_bar.dart';
import '../widgets/comic_refresh_indicator.dart';
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
  String _searchQuery = '';
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<BookProvider>();
      await provider.loadBooks();
      // Comprobar volúmenes nuevos en segundo plano (máximo 1 vez cada 24h)
      await provider.checkForNewVolumesOnStartup();
      if (mounted && provider.newVolumeAlerts.isNotEmpty) {
        _showNewVolumeSnackBar(provider.newVolumeAlerts);
        provider.clearNewVolumeAlerts();
      }
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
    setState(() {
      _currentIndex = index;
      _searchQuery = ''; // Limpiar búsqueda al cambiar de tab
    });
  }

  /// Refresca los datos al hacer pull-to-refresh
  Future<void> _onRefresh() async {
    final provider = context.read<BookProvider>();
    await provider.loadBooks();

    // Mostrar snackbar de confirmación
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Biblioteca actualizada',
            style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
          ),
          backgroundColor: ComicTheme.powerGreen,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
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
        child: Column(
          children: [
            // Barra de búsqueda local
            LocalSearchBar(
              hintText: _currentIndex == 0
                  ? 'Buscar en leyendo...'
                  : _currentIndex == 1
                      ? 'Buscar en terminados...'
                      : 'Buscar en lista...',
              onSearch: (query) {
                setState(() => _searchQuery = query);
              },
            ),
            // Contenido con lista de libros
            Expanded(
              child: Selector<BookProvider, ({bool isLoading, List<Book> reading, List<Book> finished, List<Book> wishlist, List<Book> archived})>(
                selector: (_, provider) => (
                  isLoading: provider.isLoading,
                  reading: provider.readingBooks,
                  finished: provider.finishedBooks,
                  wishlist: provider.wishlistBooks,
                  archived: provider.archivedBooks,
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
                      return previous.wishlist != next.wishlist || previous.archived != next.archived;
                    default:
                      return false;
                  }
                },
                builder: (context, data, child) {
                  if (data.isLoading) {
                    // Skeleton loading según la pestaña actual
                    return SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: _currentIndex == 0 || _currentIndex == 1
                          ? const SkeletonGroupedView(seriesCount: 3)
                          : const SkeletonBookGrid(itemCount: 6),
                    );
                  }

                  List<Book> books;
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

                  // Aplicar filtro de búsqueda
                  if (_searchQuery.isNotEmpty) {
                    books = books.where((book) {
                      return FuzzySearch.matches(book.title, _searchQuery) ||
                          FuzzySearch.matches(book.author, _searchQuery) ||
                          (book.seriesName != null && FuzzySearch.matches(book.seriesName!, _searchQuery));
                    }).toList();
                  }

                  // Para tab 2, comprobar tanto wishlist como archived
                  if (_currentIndex == 2) {
                    // Filtrar archived también
                    var filteredArchived = data.archived;
                    if (_searchQuery.isNotEmpty) {
                      filteredArchived = data.archived.where((book) {
                        return FuzzySearch.matches(book.title, _searchQuery) ||
                            FuzzySearch.matches(book.author, _searchQuery) ||
                            (book.seriesName != null && FuzzySearch.matches(book.seriesName!, _searchQuery));
                      }).toList();
                    }
                    if (books.isEmpty && filteredArchived.isEmpty) {
                      return _searchQuery.isEmpty ? _buildEmptyState() : _buildNoResultsState();
                    }
                    return ComicRefreshIndicator(
                      onRefresh: _onRefresh,
                      child: FadeTransition(
                        opacity: _tabFadeAnimation,
                        child: _buildContent(books, filteredArchived),
                      ),
                    );
                  } else if (books.isEmpty) {
                    return _searchQuery.isEmpty ? _buildEmptyState() : _buildNoResultsState();
                  }

                  return ComicRefreshIndicator(
                    onRefresh: _onRefresh,
                    child: FadeTransition(
                      opacity: _tabFadeAnimation,
                      child: _buildContent(books, data.archived),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showNewVolumeSnackBar(List<NewVolumeAlert> alerts) {
    final message = alerts.length == 1
        ? '${alerts.first.seriesName} Vol. ${alerts.first.newVolumeNumber} ya disponible!'
        : '${alerts.length} volúmenes nuevos disponibles!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.comicNeue(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: ComicTheme.secondaryBlue,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'VER',
          textColor: Colors.white,
          onPressed: () {
            showNewVolumesAlertDialog(
              context,
              alerts,
              _handleNewVolumeAction,
            );
          },
        ),
      ),
    );
  }

  void _handleNewVolumeAction(NewVolumeAlert alert, String action) {
    final provider = context.read<BookProvider>();
    final nextVolumeNumber = alert.newVolumeNumber;
    final seriesName = alert.seriesName;
    final isOmnibus =
        RegExp(r'\d+\s*[Ee][Nn]\s*1').hasMatch(seriesName);
    final nextTitle = isOmnibus
        ? '$seriesName $nextVolumeNumber'
        : '$seriesName Vol. $nextVolumeNumber';
    final syntheticIsbn =
        '${seriesName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}-vol-$nextVolumeNumber';

    final status = action == 'have_it' ? 'reading' : 'wishlist';

    final nextBook = Book(
      isbn: syntheticIsbn,
      title: nextTitle,
      author: alert.author,
      coverUrl: alert.coverUrl,
      status: status,
      currentPage: 0,
      totalPages: 0,
      seriesName: seriesName,
      volumeNumber: nextVolumeNumber,
    );

    provider.addBook(nextBook);

    final statusMsg = action == 'have_it' ? 'Leyendo' : 'Solicitados';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$nextTitle añadido a $statusMsg',
          style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
        ),
        backgroundColor: ComicTheme.powerGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildContent(List<Book> books, List<Book> archivedBooks) {
    // Generar key basada en hash de portadas para forzar reconstrucción
    final coversHash = books.fold<int>(0, (hash, b) => hash ^ (b.localCoverPath ?? b.coverUrl ?? '').hashCode);

    switch (_currentIndex) {
      case 0:
        return BookGrid(key: ValueKey('reading_$coversHash'), books: books, isReadingList: true);
      case 1:
        return GroupedBookGrid(key: ValueKey('finished_$coversHash'), books: books, isReadingList: false);
      case 2:
        final archivedHash = archivedBooks.fold<int>(0, (hash, b) => hash ^ (b.localCoverPath ?? b.coverUrl ?? '').hashCode);
        return WishlistAndArchivedView(
          key: ValueKey('wishlist_archived_${coversHash}_$archivedHash'),
          wishlistBooks: books,
          archivedBooks: archivedBooks,
        );
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
                icon: Icons.inventory_2_outlined,
                selectedIcon: Icons.inventory_2,
                label: 'MÁS',
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
                onTap: () async {
                  final result = await Navigator.push<String>(
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
                  // Navegar al tab correcto según el status del libro añadido
                  if (result != null && mounted) {
                    final targetIndex = result == 'reading' ? 0 : result == 'finished' ? 1 : _currentIndex;
                    if (targetIndex != _currentIndex) {
                      setState(() => _currentIndex = targetIndex);
                    }
                  }
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

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey[400]!,
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.search_off,
                size: 48,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'SIN RESULTADOS',
              style: GoogleFonts.bangers(
                fontSize: 24,
                color: Colors.grey[600],
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[400]!, width: 2),
              ),
              child: Text(
                'No hay libros que coincidan con "$_searchQuery"',
                style: GoogleFonts.comicNeue(
                  fontSize: 14,
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
