import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/reading_event.dart';
import '../models/book.dart';
import '../theme/comic_theme.dart';
import '../services/book_provider.dart';
import '../services/database_service.dart';

/// Widget que muestra el histórico completo de lectura
class ReadingHistoryWidget extends StatefulWidget {
  const ReadingHistoryWidget({super.key});

  @override
  State<ReadingHistoryWidget> createState() => _ReadingHistoryWidgetState();
}

class _ReadingHistoryWidgetState extends State<ReadingHistoryWidget> {
  List<ReadingEvent> _events = [];
  Map<int, Book> _booksCache = {};
  bool _isLoading = true;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    // Capturar el provider antes del await
    final provider = context.read<BookProvider>();
    final dbService = DatabaseService();

    // Obtener eventos de los últimos 60 días
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 60));
    final events = await dbService.getReadingEventsBetween(startDate, now);

    // Ordenar por fecha descendente (más recientes primero)
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Cargar info de libros
    final allBooks = [
      ...provider.readingBooks,
      ...provider.finishedBooks,
      ...provider.wishlistBooks,
      ...provider.archivedBooks,
    ];

    final booksMap = <int, Book>{};
    for (final book in allBooks) {
      if (book.id != null) {
        booksMap[book.id!] = book;
      }
    }

    if (mounted) {
      setState(() {
        _events = events;
        _booksCache = booksMap;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_events.isEmpty) {
      return _buildEmptyHistory();
    }

    // Agrupar eventos por día
    final groupedByDay = <String, List<ReadingEvent>>{};
    for (final event in _events) {
      final dayKey = _formatDayKey(event.timestamp);
      groupedByDay.putIfAbsent(dayKey, () => []).add(event);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        if (_isExpanded) ...[
          const SizedBox(height: 12),
          _buildStats(),
          const SizedBox(height: 16),
          ...groupedByDay.entries.take(7).map((entry) => _buildDaySection(entry.key, entry.value)),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ComicTheme.primaryOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ComicTheme.primaryOrange.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.history, color: ComicTheme.primaryOrange, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'HISTORIAL DE LECTURA',
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
                color: ComicTheme.primaryOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_events.length}',
                style: GoogleFonts.bangers(
                  fontSize: 14,
                  color: ComicTheme.primaryOrange,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    // Calcular estadísticas
    int totalPages = 0;
    int booksCompleted = 0;
    final Set<int> uniqueBooks = {};

    for (final event in _events) {
      totalPages += event.pagesRead;
      uniqueBooks.add(event.bookId);
      if (event.eventType == ReadingEventType.completed) {
        booksCompleted++;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ComicTheme.primaryOrange.withValues(alpha: 0.1),
              ComicTheme.accentYellow.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ComicTheme.primaryOrange.withValues(alpha: 0.3), width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.auto_stories,
              value: '$totalPages',
              label: 'PÁGINAS',
              color: ComicTheme.primaryOrange,
            ),
            Container(height: 40, width: 1, color: Colors.grey[300]),
            _buildStatItem(
              icon: Icons.menu_book,
              value: '${uniqueBooks.length}',
              label: 'LIBROS',
              color: ComicTheme.secondaryBlue,
            ),
            Container(height: 40, width: 1, color: Colors.grey[300]),
            _buildStatItem(
              icon: Icons.check_circle,
              value: '$booksCompleted',
              label: 'TERMINADOS',
              color: ComicTheme.powerGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.bangers(
            fontSize: 20,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.comicNeue(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDaySection(String dayKey, List<ReadingEvent> events) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del día
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              dayKey,
              style: GoogleFonts.bangers(
                fontSize: 14,
                color: ComicTheme.comicBorder,
                letterSpacing: 1,
              ),
            ),
          ),
          // Eventos del día
          ...events.map((event) => _buildEventItem(event)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildEventItem(ReadingEvent event) {
    final book = _booksCache[event.bookId];
    final bookTitle = book?.title ?? 'Libro #${event.bookId}';

    IconData icon;
    Color color;
    String description;

    switch (event.eventType) {
      case ReadingEventType.started:
        icon = Icons.play_circle_filled;
        color = ComicTheme.secondaryBlue;
        description = 'Empezado';
        break;
      case ReadingEventType.completed:
        icon = Icons.check_circle;
        color = ComicTheme.powerGreen;
        description = 'Completado';
        break;
      case ReadingEventType.progress:
        icon = Icons.auto_stories;
        color = ComicTheme.primaryOrange;
        description = '+${event.pagesRead} págs';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
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
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookTitle,
                  style: GoogleFonts.comicNeue(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ComicTheme.comicBorder,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      description,
                      style: GoogleFonts.comicNeue(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (event.eventType == ReadingEventType.progress) ...[
                      Text(
                        ' (pág ${event.newPage})',
                        style: GoogleFonts.comicNeue(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            _formatTime(event.timestamp),
            style: GoogleFonts.comicNeue(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 2),
        ),
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'SIN ACTIVIDAD',
              style: GoogleFonts.bangers(
                fontSize: 18,
                color: Colors.grey[500],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu historial de lectura aparecerá aquí',
              style: GoogleFonts.comicNeue(
                fontSize: 14,
                color: Colors.grey[500],
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDayKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(eventDay).inDays;

    if (diff == 0) return 'HOY';
    if (diff == 1) return 'AYER';
    if (diff < 7) return 'HACE $diff DÍAS';

    final weekday = _getWeekdayName(date.weekday);
    return '$weekday ${date.day}/${date.month}';
  }

  String _getWeekdayName(int weekday) {
    const names = ['', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
    return names[weekday];
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
