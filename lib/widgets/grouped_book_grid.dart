import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/book.dart';
import '../theme/comic_theme.dart';
import '../services/book_provider.dart';
import '../services/book_api_service.dart';
import '../services/parent_settings_service.dart';
import '../services/email_service.dart';
import 'book_card.dart';
import 'series_header.dart';
import 'alphabet_index.dart';

/// Widget que muestra libros agrupados por serie
class GroupedBookGrid extends StatefulWidget {
  final List<Book> books;
  final bool isReadingList;

  const GroupedBookGrid({
    super.key,
    required this.books,
    this.isReadingList = true,
  });

  @override
  State<GroupedBookGrid> createState() => _GroupedBookGridState();
}

class _GroupedBookGridState extends State<GroupedBookGrid> {
  final Set<String> _collapsedSeries = {};
  final Set<String> _loadingNextVolume = {};
  final Set<String> _completedSeries = {};
  final ParentSettingsService _settingsService = ParentSettingsService();
  final ScrollController _scrollController = ScrollController();
  String? _currentLetter;
  bool _showLetterIndicator = false;

  /// Series conocidas con su número total de volúmenes
  /// Esto evita ofrecer volúmenes que no existen
  static const Map<String, int> _knownSeriesVolumes = {
    // DC Vertigo
    'predicador': 13,
    'preacher': 13,
    'sandman': 10,
    'the sandman': 10,
    'fábulas': 22,
    'fabulas': 22,
    'fables': 22,
    'transmetropolitan': 10,
    'y el último hombre': 10,
    'y: the last man': 10,
    '100 balas': 13,
    '100 bullets': 13,
    'hellblazer': 27, // Original run
    'la cosa del pantano': 6, // Alan Moore run
    'swamp thing': 6,
    'lucifer': 11,
    'v de vendetta': 1,
    'v for vendetta': 1,
    'watchmen': 1,
    'desde el infierno': 1,
    'from hell': 1,

    // Marvel
    'ojo de halcón': 4, // Fraction/Aja
    'hawkeye': 4,
    'daredevil': 8, // Bendis run
    'inmortal hulk': 10,
    'immortal hulk': 10,

    // Manga populares (ediciones españolas típicas)
    'death note': 12,
    'fullmetal alchemist': 27,
    'dragon ball': 42,
    'dragon ball z': 26,
    'naruto': 72,
    'one punch man': 29, // Ongoing pero por ahora
    'attack on titan': 34,
    'ataque a los titanes': 34,
    'demon slayer': 23,
    'kimetsu no yaiba': 23,
    'jujutsu kaisen': 26, // Ongoing
    'chainsaw man': 16, // Ongoing
    'my hero academia': 39, // Ongoing
    'boku no hero academia': 39,
    'spy x family': 12, // Ongoing
    'tokyo revengers': 31,
    'haikyuu': 45,
    'hunter x hunter': 37, // Hiatus

    // One Piece ediciones
    'one piece': 109, // Ongoing
    'one piece 3 en 1': 36, // 109/3 rounded up
  };

  @override
  void initState() {
    super.initState();
    _loadCompletedSeries();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GroupedBookGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Forzar rebuild si los libros cambiaron (especialmente las portadas)
    if (widget.books != oldWidget.books) {
      debugPrint('📚 GroupedBookGrid: libros actualizados, forzando rebuild');
      setState(() {});
    }
  }

  Future<void> _loadCompletedSeries() async {
    final completed = await _settingsService.getCompletedSeries();
    if (mounted) {
      setState(() {
        _completedSeries.clear();
        _completedSeries.addAll(completed);
      });
    }
  }

  Future<void> _toggleSeriesComplete(String series) async {
    final isComplete = _completedSeries.contains(series.toLowerCase());

    if (isComplete) {
      await _settingsService.unmarkSeriesAsComplete(series);
      setState(() {
        _completedSeries.remove(series.toLowerCase());
      });
    } else {
      await _settingsService.markSeriesAsComplete(series);
      setState(() {
        _completedSeries.add(series.toLowerCase());
      });
    }
  }

  bool _isSeriesComplete(String series) {
    return _completedSeries.contains(series.toLowerCase());
  }

  /// Verifica si el siguiente volumen existe según datos conocidos
  /// Devuelve null si no hay datos, true si existe, false si no existe
  bool? _nextVolumeExists(String series, int nextVol) {
    final seriesLower = series.toLowerCase().trim();

    // Buscar en la base de datos de series conocidas
    for (final entry in _knownSeriesVolumes.entries) {
      if (seriesLower.contains(entry.key) || entry.key.contains(seriesLower)) {
        // Si tenemos datos de esta serie, verificar si nextVol excede el máximo
        return nextVol <= entry.value;
      }
    }

    // No tenemos datos de esta serie
    return null;
  }

  /// Obtiene el número máximo de volúmenes conocido para una serie
  int? _getKnownMaxVolumes(String series) {
    final seriesLower = series.toLowerCase().trim();

    for (final entry in _knownSeriesVolumes.entries) {
      if (seriesLower.contains(entry.key) || entry.key.contains(seriesLower)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Muestra diálogo con opciones para el siguiente volumen
  void _showNextVolumeOptionsDialog(String series, List<Book> books, int nextVol) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ComicTheme.backgroundCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ComicTheme.comicBorder, width: 4),
        ),
        title: Column(
          children: [
            const Icon(Icons.menu_book, size: 40, color: ComicTheme.secondaryBlue),
            const SizedBox(height: 8),
            Text(
              '$series Vol. $nextVol',
              textAlign: TextAlign.center,
              style: GoogleFonts.bangers(
                color: ComicTheme.comicBorder,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Opción 1: Ya lo tengo
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _addNextVolumeAsReading(series, books, nextVol);
                },
                icon: const Icon(Icons.check_circle),
                label: Text(
                  '¡YA LO TENGO!',
                  style: GoogleFonts.bangers(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ComicTheme.powerGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Opción 2: Pedir a papá
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _requestNextVolume(series, books);
                },
                icon: const Icon(Icons.mail_outline),
                label: Text(
                  'PEDIR A PAPÁ',
                  style: GoogleFonts.bangers(fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ComicTheme.heroRed,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: ComicTheme.heroRed, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Separador
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('o', style: GoogleFonts.comicNeue(color: Colors.grey[400])),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),
            const SizedBox(height: 12),
            // Opción 3: Serie completa
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _toggleSeriesComplete(series);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '¡$series marcada como completa!',
                        style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: ComicTheme.powerGreen,
                    ),
                  );
                },
                icon: Icon(Icons.block, size: 18, color: Colors.grey[600]),
                label: Text(
                  'NO HAY MÁS VOLÚMENES',
                  style: GoogleFonts.bangers(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCELAR', style: GoogleFonts.bangers(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  /// Añade el siguiente volumen directamente a Leyendo
  Future<void> _addNextVolumeAsReading(String series, List<Book> books, int nextVol) async {
    setState(() {
      _loadingNextVolume.add(series);
    });

    try {
      final provider = context.read<BookProvider>();
      final lastBook = books.last;

      // Buscar portada
      String? coverUrl = await provider.searchCover(
        series,
        lastBook.author,
        volumeNumber: nextVol,
      );

      // Detectar si es omnibus
      final isOmnibus = RegExp(r'\d+\s*[Ee][Nn]\s*1').hasMatch(series);
      final nextTitle = isOmnibus ? '$series $nextVol' : '$series Vol. $nextVol';

      // Crear el siguiente volumen en Leyendo
      final nextBook = Book(
        isbn: '${series.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}-vol-$nextVol',
        title: nextTitle,
        author: lastBook.author,
        coverUrl: coverUrl,
        status: 'reading',
        currentPage: 0,
        totalPages: lastBook.totalPages,
        seriesName: series,
        volumeNumber: nextVol,
      );

      final added = await provider.addBook(nextBook);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added
                  ? '¡$nextTitle añadido a Leyendo!'
                  : 'Ya tienes este libro',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: added ? ComicTheme.powerGreen : ComicTheme.primaryOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold)),
            backgroundColor: ComicTheme.heroRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingNextVolume.remove(series);
        });
      }
    }
  }

  /// Muestra menú de opciones para una serie
  void _showSeriesMenuDialog(String series, List<Book> books) {
    final totalPages = books.fold<int>(0, (sum, b) => sum + b.totalPages);
    final readPages = books.fold<int>(0, (sum, b) => sum + b.currentPage);

    showModalBottomSheet(
      context: context,
      backgroundColor: ComicTheme.backgroundCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Título
            Text(
              series.toUpperCase(),
              style: GoogleFonts.bangers(
                fontSize: 20,
                color: ComicTheme.comicBorder,
              ),
            ),
            const SizedBox(height: 8),
            // Estadísticas
            Text(
              '${books.length} volúmenes • $readPages/$totalPages páginas',
              style: GoogleFonts.comicNeue(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Opciones
            ListTile(
              leading: const Icon(Icons.archive, color: ComicTheme.primaryOrange),
              title: Text(
                'Archivar serie',
                style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Ocultar de las listas principales',
                style: GoogleFonts.comicNeue(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showArchiveSeriesDialog(series);
              },
            ),
            if (!_isSeriesComplete(series))
              ListTile(
                leading: const Icon(Icons.check_circle, color: ComicTheme.powerGreen),
                title: Text(
                  'Marcar serie completa',
                  style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'No hay más volúmenes disponibles',
                  style: GoogleFonts.comicNeue(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleSeriesComplete(series);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '¡$series marcada como completa!',
                        style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: ComicTheme.powerGreen,
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: ComicTheme.heroRed),
              title: Text(
                'Borrar serie',
                style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Eliminar todos los volúmenes',
                style: GoogleFonts.comicNeue(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteSeriesDialog(series, books.length);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// Muestra diálogo para archivar una serie
  void _showArchiveSeriesDialog(String series) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ComicTheme.backgroundCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
        ),
        title: Row(
          children: [
            const Icon(Icons.archive, color: ComicTheme.primaryOrange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ARCHIVAR SERIE',
                style: GoogleFonts.bangers(
                  color: ComicTheme.comicBorder,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Quieres archivar "$series"?\n\nLos libros archivados no aparecerán en las listas principales. Podrás verlos en Ajustes.',
          style: GoogleFonts.comicNeue(
            fontWeight: FontWeight.bold,
            color: ComicTheme.comicBorder,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCELAR', style: GoogleFonts.bangers(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<BookProvider>().archiveSeries(series);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '¡$series archivada!',
                    style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: ComicTheme.primaryOrange,
                  action: SnackBarAction(
                    label: 'DESHACER',
                    textColor: Colors.white,
                    onPressed: () {
                      context.read<BookProvider>().unarchiveSeries(series);
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.archive, size: 18),
            label: Text(
              'ARCHIVAR',
              style: GoogleFonts.bangers(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  /// Muestra diálogo para borrar una serie completa
  void _showDeleteSeriesDialog(String series, int volumeCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ComicTheme.backgroundCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: ComicTheme.heroRed),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'BORRAR SERIE',
                style: GoogleFonts.bangers(
                  color: ComicTheme.comicBorder,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Quieres borrar "$series"?\n\nSe eliminarán los $volumeCount volúmenes de forma permanente.',
          style: GoogleFonts.comicNeue(
            fontWeight: FontWeight.bold,
            color: ComicTheme.comicBorder,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCELAR', style: GoogleFonts.bangers(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final deletedCount = await context.read<BookProvider>().deleteSeries(series);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '¡$series eliminada! ($deletedCount volúmenes)',
                      style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: ComicTheme.heroRed,
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_forever, size: 18),
            label: Text(
              'BORRAR',
              style: GoogleFonts.bangers(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.heroRed,
            ),
          ),
        ],
      ),
    );
  }

  /// Muestra diálogo para reanudar una serie marcada como completa
  void _showResumeSeriesDialog(String series, int nextVol) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ComicTheme.backgroundCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: ComicTheme.powerGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'SERIE COMPLETA',
                style: GoogleFonts.bangers(
                  color: ComicTheme.comicBorder,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '¡$series está marcada como completa!\n\n¿Han sacado más volúmenes?',
          style: GoogleFonts.comicNeue(
            fontWeight: FontWeight.bold,
            color: ComicTheme.comicBorder,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CERRAR', style: GoogleFonts.bangers(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _toggleSeriesComplete(series);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '¡$series reactivada! Ahora puedes pedir Vol.$nextVol',
                    style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: ComicTheme.secondaryBlue,
                ),
              );
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(
              'REANUDAR SERIE',
              style: GoogleFonts.bangers(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.secondaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  void _showSeriesCompleteDialog(String series) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ComicTheme.backgroundCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
        ),
        title: Text(
          '¿SERIE COMPLETA?',
          style: GoogleFonts.bangers(
            color: ComicTheme.comicBorder,
            fontSize: 20,
          ),
        ),
        content: Text(
          '¿"$series" ya no tiene más volúmenes?\n\nSi la marcas como completa, no aparecerá el botón de pedir más.',
          style: GoogleFonts.comicNeue(
            fontWeight: FontWeight.bold,
            color: ComicTheme.comicBorder,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.bangers(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _toggleSeriesComplete(series);
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    '¡$series marcada como completa!',
                    style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: ComicTheme.powerGreen,
                ),
              );
            },
            icon: const Icon(Icons.check_circle, size: 18),
            label: Text(
              'SÍ, COMPLETA',
              style: GoogleFonts.bangers(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.powerGreen,
            ),
          ),
        ],
      ),
    );
  }

  /// Agrupa los libros por serie y los ordena
  Map<String, List<Book>> _groupBooksBySeries() {
    final Map<String, List<Book>> grouped = {};

    for (final book in widget.books) {
      // Usar seriesName si existe, sino el título
      final seriesKey = book.seriesName ?? book.title;

      if (!grouped.containsKey(seriesKey)) {
        grouped[seriesKey] = [];
      }
      grouped[seriesKey]!.add(book);
    }

    // Ordenar libros dentro de cada serie por número de volumen
    for (final series in grouped.keys) {
      grouped[series]!.sort((a, b) {
        final volA = a.volumeNumber ?? 0;
        final volB = b.volumeNumber ?? 0;
        return volA.compareTo(volB);
      });
    }

    // Ordenar las series alfabéticamente
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return {for (final key in sortedKeys) key: grouped[key]!};
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

  /// Obtiene el siguiente número de volumen de una serie
  int _getNextVolumeNumber(List<Book> books) {
    int maxVol = 0;
    for (final book in books) {
      if (book.volumeNumber != null && book.volumeNumber! > maxVol) {
        maxVol = book.volumeNumber!;
      }
    }
    return maxVol + 1;
  }

  /// Verifica si el siguiente volumen ya está en la lista de lectura
  bool _isNextVolumeInReading(String series, int nextVol) {
    final provider = context.read<BookProvider>();
    return provider.readingBooks.any((book) =>
        (book.seriesName == series || book.title == series) &&
        book.volumeNumber == nextVol);
  }

  /// Verifica si el siguiente volumen ya está en la lista de deseos
  bool _isNextVolumeInWishlist(String series, int nextVol) {
    final provider = context.read<BookProvider>();
    return provider.wishlistBooks.any((book) =>
        (book.seriesName == series || book.title == series) &&
        book.volumeNumber == nextVol);
  }

  /// Añade el siguiente volumen a la lista de deseos (solicitar a papá)
  Future<void> _requestNextVolume(String series, List<Book> books) async {
    if (_loadingNextVolume.contains(series)) return;

    setState(() {
      _loadingNextVolume.add(series);
    });

    try {
      final provider = context.read<BookProvider>();
      final apiService = BookApiService();
      final parentSettings = ParentSettingsService();
      final lastBook = books.last;
      final nextVol = _getNextVolumeNumber(books);

      // Verificar si hay email configurado
      final hasEmail = await parentSettings.hasParentEmail();
      if (!hasEmail && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Configura el email de papá/mamá en Ajustes',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.heroRed,
            action: SnackBarAction(
              label: 'IR',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ),
        );
        setState(() {
          _loadingNextVolume.remove(series);
        });
        return;
      }

      // Buscar portada para el siguiente volumen usando el provider (tiene traducciones)
      String? coverUrl = await provider.searchCover(
        series,
        lastBook.author,
        volumeNumber: nextVol,
      );

      // Fallback con queries adicionales si no encuentra
      if (coverUrl == null || coverUrl.isEmpty) {
        final authorFirst = lastBook.author.split(',').first.trim();
        final searchQueries = [
          '$authorFirst $series vol $nextVol',
          '$series vol $nextVol',
          '$series $nextVol',
        ];

        for (final query in searchQueries) {
          coverUrl = await apiService.searchCover(query, lastBook.author);
          if (coverUrl != null && coverUrl.isNotEmpty) break;
        }
      }

      // Detectar si es omnibus (ej: "ONE PIECE 3 EN 1")
      final isOmnibus = RegExp(r'\d+\s*[Ee][Nn]\s*1').hasMatch(series);

      // Título: omnibus sin "Vol.", normal con "Vol."
      final nextTitle = isOmnibus ? '$series $nextVol' : '$series Vol. $nextVol';

      // Crear el siguiente volumen en wishlist
      final nextBook = Book(
        isbn: '${series.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}-vol-$nextVol',
        title: nextTitle,
        author: lastBook.author,
        coverUrl: coverUrl,
        status: 'wishlist',
        currentPage: 0,
        totalPages: lastBook.totalPages,
        seriesName: series,
        volumeNumber: nextVol,
      );

      await provider.addBook(nextBook);

      // Enviar email a papá/mamá usando EmailService (Firebase)
      final emailService = EmailService();
      final user = FirebaseAuth.instance.currentUser;
      final emailSent = await emailService.sendBookRequest(
        childName: user?.displayName ?? 'Lucca',
        bookTitle: nextBook.title,
        author: lastBook.author,
        coverUrl: coverUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              emailSent
                  ? '¡$series Vol. $nextVol solicitado a papá! 📧'
                  : '¡$series Vol. $nextVol añadido a Solicitados!',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.secondaryBlue,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al solicitar volumen: $e',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.heroRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingNextVolume.remove(series);
        });
      }
    }
  }

  /// Obtiene la letra inicial de una serie (normalizada)
  String _getSeriesLetter(String series) {
    final firstChar = series.trim().toUpperCase();
    if (firstChar.isEmpty) return '#';
    final char = firstChar[0];
    if (RegExp(r'[A-Z]').hasMatch(char)) {
      return char;
    }
    return '#'; // Para números y símbolos
  }

  /// Obtiene el conjunto de letras disponibles en las series
  Set<String> _getAvailableLetters(Map<String, List<Book>> groupedBooks) {
    final letters = <String>{};
    for (final series in groupedBooks.keys) {
      letters.add(_getSeriesLetter(series));
    }
    return letters;
  }

  /// Calcula la posición de scroll para una letra específica
  void _scrollToLetter(String letter, Map<String, List<Book>> groupedBooks) {
    final sortedSeries = groupedBooks.keys.toList();

    // Encontrar el primer índice que empiece con esa letra
    int targetIndex = -1;
    for (int i = 0; i < sortedSeries.length; i++) {
      if (_getSeriesLetter(sortedSeries[i]) == letter) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex >= 0) {
      // Estimar la posición: cada serie ocupa aproximadamente 250px
      // (header ~80px + fila de libros 170px)
      const estimatedItemHeight = 250.0;
      final targetOffset = targetIndex * estimatedItemHeight;

      _scrollController.animateTo(
        targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );

      // Mostrar indicador de letra
      setState(() {
        _currentLetter = letter;
        _showLetterIndicator = true;
      });

      // Ocultar después de un momento
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _showLetterIndicator = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedBooks = _groupBooksBySeries();

    if (groupedBooks.isEmpty) {
      return const SizedBox.shrink();
    }

    final availableLetters = _getAvailableLetters(groupedBooks);
    final showAlphabetIndex = !widget.isReadingList && groupedBooks.length >= 5;

    return Stack(
      children: [
        // Lista principal
        ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(16, 16, showAlphabetIndex ? 40 : 16, 100),
          itemCount: groupedBooks.length,
          itemBuilder: (context, index) {
        final series = groupedBooks.keys.elementAt(index);
        final books = groupedBooks[series]!;
        final isCollapsed = _collapsedSeries.contains(series);
        final isSingleBook =
            books.length == 1 && books.first.volumeNumber == null;
        final nextVol = _getNextVolumeNumber(books);
        final hasNextInReading = _isNextVolumeInReading(series, nextVol);
        final hasNextInWishlist = _isNextVolumeInWishlist(series, nextVol);
        final isLoading = _loadingNextVolume.contains(series);
        final isSeriesComplete = _isSeriesComplete(series);

        // Verificar si el siguiente volumen existe según datos conocidos
        final nextVolumeExists = _nextVolumeExists(series, nextVol);
        final knownMaxVols = _getKnownMaxVolumes(series);
        // Si sabemos que no existe más, marcarlo como completo automáticamente
        final effectivelyComplete = isSeriesComplete || (nextVolumeExists == false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de la serie
            if (!isSingleBook)
              SeriesHeader(
                series: series,
                count: books.length,
                isCollapsed: isCollapsed,
                nextVol: nextVol,
                hasNextInReading: hasNextInReading,
                hasNextInWishlist: hasNextInWishlist,
                isLoading: isLoading,
                isSeriesComplete: effectivelyComplete,
                books: books,
                knownMaxVols: knownMaxVols,
                onToggle: () => _toggleSeries(series),
                onLongPress: () => _showSeriesMenuDialog(series, books),
                onResumeComplete: () => _showResumeSeriesDialog(series, nextVol),
                onRequestNext: () => _showNextVolumeOptionsDialog(series, books, nextVol),
              ),

            // Lista horizontal de libros de esta serie
            if (!isCollapsed) _buildBooksRow(books, isSingleBook),

            const SizedBox(height: 20),
          ],
        );
      },
    ),

        // Índice alfabético (solo en completados con suficientes series)
        if (showAlphabetIndex)
          Positioned(
            right: 4,
            top: 16,
            bottom: 100,
            child: AlphabetIndex(
              availableLetters: availableLetters,
              currentLetter: _currentLetter,
              onLetterSelected: (letter) => _scrollToLetter(letter, groupedBooks),
            ),
          ),

        // Indicador de letra grande
        if (_showLetterIndicator && _currentLetter != null)
          Center(
            child: LetterIndicator(letter: _currentLetter!),
          ),
      ],
    );
  }

  // Método _buildSeriesHeader movido a widgets/series_header.dart

  Widget _deprecatedBuildSeriesHeader(
    String series,
    int count,
    bool isCollapsed,
    int nextVol,
    bool hasNextInReading,
    bool hasNextInWishlist,
    bool isLoading,
    bool isSeriesComplete,
    List<Book> books,
    int? knownMaxVols,
  ) {
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
          // Botón expandir/colapsar
          GestureDetector(
            onTap: () => _toggleSeries(series),
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
          ),
          // Nombre de la serie (tap para expandir, long press para menú)
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleSeries(series),
              onLongPress: () => _showSeriesMenuDialog(series, books),
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
          ),
          // Contador de volúmenes - estilo cómic
          Container(
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
          ),
          const SizedBox(width: 8),
          // Botón solicitar siguiente volumen a papá (o marcar como completa)
          if (isSeriesComplete)
            // Serie marcada como completa - tap para reanudar
            GestureDetector(
              onTap: () => _showResumeSeriesDialog(series, nextVol),
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
                      knownMaxVols != null ? '${count}/${knownMaxVols}' : '¡Completa!',
                      style: GoogleFonts.bangers(
                        fontSize: 11,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (hasNextInReading)
            // Ya está en Leyendo - botón visible con buen contraste
            Container(
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
            )
          else if (hasNextInWishlist)
            // Ya está solicitado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ComicTheme.secondaryBlue.withValues(alpha:0.2),
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
            )
          else
            // Botón para solicitar - estilo superhéroe pulsante
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 1.05),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: GestureDetector(
                onTap: isLoading ? null : () => _showNextVolumeOptionsDialog(series, books, nextVol),
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
            ),
        ],
      ),
    );
  }

  Widget _buildBooksRow(List<Book> books, bool isSingleBook) {
    return SizedBox(
      height: 195, // Altura suficiente para portada + título + autor
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: books.length,
        itemBuilder: (context, index) {
          return Container(
            width: 110,
            margin: EdgeInsets.only(right: index < books.length - 1 ? 12 : 0),
            child: BookCard(
              key: ValueKey('${books[index].id}_${books[index].localCoverPath ?? books[index].coverUrl}'),
              book: books[index],
              showProgress: widget.isReadingList,
            ),
          );
        },
      ),
    );
  }
}
