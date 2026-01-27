import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book.dart';
import '../services/book_provider.dart';
import '../services/book_api_service.dart';
import '../services/parent_settings_service.dart';
import '../theme/comic_theme.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/next_volume_dialog.dart';
import '../widgets/cover_search_dialog.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late TextEditingController _pageController;
  late TextEditingController _totalPagesController;
  late Book _book;
  bool _searchingCover = false;
  bool _isSeriesComplete = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _pageController = TextEditingController(
      text: _book.currentPage.toString(),
    );
    _totalPagesController = TextEditingController(
      text: _book.totalPages > 0 ? _book.totalPages.toString() : '',
    );

    // Verificar si la serie está marcada como completa
    if (_book.isPartOfSeries) {
      _checkIfSeriesComplete();
    }
  }

  Future<void> _checkIfSeriesComplete() async {
    final parentSettings = ParentSettingsService();
    final seriesName = _book.seriesName ?? _book.title;
    final isComplete = await parentSettings.isSeriesComplete(seriesName);
    if (mounted) {
      setState(() => _isSeriesComplete = isComplete);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _totalPagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'DETALLES',
          style: GoogleFonts.bangers(letterSpacing: 2),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: ComicTheme.heroGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: MangaBackground(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Cabecera con portada
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ComicTheme.secondaryBlue.withValues(alpha: 0.2),
                    ComicTheme.backgroundCream,
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Portada estilo cómic (tap para cambiar)
                  GestureDetector(
                    onTap: _searchNewCover,
                    child: Stack(
                      children: [
                        // Sombra
                        Positioned(
                          left: 6,
                          top: 6,
                          child: Container(
                            height: 220,
                            width: 140,
                            decoration: BoxDecoration(
                              color: ComicTheme.comicBorder,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        Container(
                          height: 220,
                          width: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ComicTheme.comicBorder,
                              width: 4,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _searchingCover
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: ComicTheme.primaryOrange,
                                    ),
                                  )
                                : _book.coverUrl != null && _book.coverUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: _book.coverUrl!,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            _buildPlaceholder(),
                                      )
                                    : _buildPlaceholder(),
                          ),
                        ),
                        // Badge de serie
                        if (_book.isPartOfSeries && _book.volumeNumber != null)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ComicTheme.primaryOrange,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    offset: Offset(2, 2),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Text(
                                'VOL. ${_book.volumeNumber}',
                                style: GoogleFonts.bangers(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        // Icono de editar portada
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Título
                  Text(
                    _book.title,
                    style: GoogleFonts.bangers(
                      fontSize: 24,
                      color: ComicTheme.comicBorder,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  // Autor
                  Text(
                    _book.author,
                    style: GoogleFonts.comicNeue(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Serie
                  if (_book.isPartOfSeries) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ComicTheme.accentYellow.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ComicTheme.comicBorder,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'Serie: ${_book.seriesName}',
                        style: GoogleFonts.comicNeue(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: ComicTheme.comicBorder,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Contenido
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progreso (para libros en lectura)
                  if (_book.isReading) ...[
                    Text(
                      '¡TU PROGRESO!',
                      style: GoogleFonts.bangers(
                        fontSize: 20,
                        color: ComicTheme.comicBorder,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Barra de progreso estilo power-up (solo si hay páginas)
                    if (_book.totalPages > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ComicTheme.comicBorder,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              offset: Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: ComicTheme.comicBorder,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: _book.progress,
                                  child: Container(
                                    height: 20,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: ComicTheme.powerGradient,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: ComicTheme.comicBorder,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(_book.progress * 100).toInt()}% COMPLETADO',
                              style: GoogleFonts.bangers(
                                fontSize: 16,
                                color: ComicTheme.primaryOrange,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_book.totalPages > 0) const SizedBox(height: 20),
                    // Selector de páginas
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ComicTheme.comicBorder,
                          width: 3,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Páginas totales (editable)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _totalPagesController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.comicNeue(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: ComicTheme.comicBorder,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Páginas totales',
                                    labelStyle: GoogleFonts.comicNeue(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: const Icon(Icons.menu_book, size: 20),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _pageController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.comicNeue(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: ComicTheme.comicBorder,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Página actual',
                                    labelStyle: GoogleFonts.comicNeue(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: const Icon(Icons.bookmark, size: 20),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _updateProgress,
                              icon: const Icon(Icons.save, size: 18),
                              label: Text(
                                'GUARDAR PROGRESO',
                                style: GoogleFonts.bangers(
                                  letterSpacing: 1,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ComicTheme.secondaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Botón de acción principal
                  if (_book.isReading)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _markAsFinished,
                        icon: const Icon(Icons.emoji_events, size: 28),
                        label: Text(
                          '¡LIBRO COMPLETADO!',
                          style: GoogleFonts.bangers(
                            fontSize: 20,
                            letterSpacing: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ComicTheme.powerGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: ComicTheme.comicBorder,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (_book.isWishlist) ...[
                    // Para libros en solicitados, opción de empezar a leer
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _markAsReading,
                        icon: const Icon(Icons.play_arrow, size: 28),
                        label: Text(
                          '¡YA LO TENGO! EMPEZAR A LEER',
                          style: GoogleFonts.bangers(
                            fontSize: 18,
                            letterSpacing: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ComicTheme.powerGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: ComicTheme.comicBorder,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else if (_book.isFinished) ...[
                    // Para libros terminados de una serie
                    if (_book.isPartOfSeries && _book.volumeNumber != null) ...[
                      // Si la serie NO está completa, mostrar opciones
                      if (!_isSeriesComplete) ...[
                        // Botón para empezar siguiente
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showNextVolumeOptions,
                            icon: const Icon(Icons.skip_next, size: 28),
                            label: Text(
                              'EMPEZAR SIGUIENTE VOLUMEN',
                              style: GoogleFonts.bangers(
                                fontSize: 18,
                                letterSpacing: 1,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ComicTheme.powerGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: ComicTheme.comicBorder,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Botón para marcar serie como completa
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _markSeriesAsComplete,
                            icon: const Icon(Icons.check_circle, size: 24),
                            label: Text(
                              'NO HAY MÁS - SERIE COMPLETA',
                              style: GoogleFonts.bangers(
                                fontSize: 16,
                                letterSpacing: 1,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ComicTheme.primaryOrange,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(
                                color: ComicTheme.primaryOrange,
                                width: 3,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        // Serie marcada como completa
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ComicTheme.powerGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ComicTheme.powerGreen,
                              width: 3,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: ComicTheme.powerGreen),
                              const SizedBox(width: 8),
                              Text(
                                '¡SERIE COMPLETADA!',
                                style: GoogleFonts.bangers(
                                  fontSize: 18,
                                  color: ComicTheme.powerGreen,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                    // Botón de volver a leer (siempre disponible para libros terminados)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _markAsReading,
                        icon: const Icon(Icons.auto_stories, size: 24),
                        label: Text(
                          'VOLVER A LEER',
                          style: GoogleFonts.bangers(
                            fontSize: 18,
                            letterSpacing: 1,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ComicTheme.secondaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(
                            color: ComicTheme.secondaryBlue,
                            width: 3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Info adicional
                  Text(
                    'INFORMACIÓN',
                    style: GoogleFonts.bangers(
                      fontSize: 20,
                      color: ComicTheme.comicBorder,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ComicTheme.comicBorder,
                        width: 3,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.qr_code, 'ISBN', _book.isbn),
                        if (_book.totalPages > 0)
                          _buildInfoRow(
                            Icons.menu_book,
                            'Páginas',
                            _book.totalPages.toString(),
                          ),
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Añadido',
                          _formatDate(_book.addedDate),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ComicTheme.accentYellow.withValues(alpha: 0.5),
            ComicTheme.primaryOrange.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Icon(
        Icons.menu_book,
        size: 50,
        color: ComicTheme.primaryOrange.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ComicTheme.accentYellow.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: ComicTheme.primaryOrange),
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: GoogleFonts.comicNeue(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.comicNeue(
                fontWeight: FontWeight.bold,
                color: ComicTheme.comicBorder,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _updateProgress() {
    final page = int.tryParse(_pageController.text) ?? 0;
    final totalPages = int.tryParse(_totalPagesController.text) ?? 0;
    final validPage = totalPages > 0 ? page.clamp(0, totalPages) : page;

    final provider = context.read<BookProvider>();

    // Actualizar páginas totales si cambió
    if (totalPages != _book.totalPages && totalPages > 0) {
      provider.updateTotalPages(_book.id!, totalPages);
    }

    // Actualizar página actual
    provider.updateCurrentPage(_book.id!, validPage);

    setState(() {
      _book = _book.copyWith(
        currentPage: validPage,
        totalPages: totalPages > 0 ? totalPages : _book.totalPages,
      );
      _pageController.text = validPage.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Progreso guardado!',
          style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
        ),
        backgroundColor: ComicTheme.powerGreen,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _searchNewCover() async {
    // Mostrar opciones antes de buscar
    final option = await showModalBottomSheet<String>(
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'CAMBIAR PORTADA',
              style: GoogleFonts.bangers(
                fontSize: 22,
                color: ComicTheme.comicBorder,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 20),
            // Opción 1: Buscar automáticamente
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ComicTheme.primaryOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_fix_high, color: ComicTheme.primaryOrange),
              ),
              title: Text(
                'Buscar automáticamente',
                style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                'La app buscará la mejor portada',
                style: GoogleFonts.comicNeue(fontSize: 12, color: Colors.grey[600]),
              ),
              onTap: () => Navigator.pop(ctx, 'auto'),
            ),
            const SizedBox(height: 8),
            // Opción 2: Buscar manualmente
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ComicTheme.secondaryBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search, color: ComicTheme.secondaryBlue),
              ),
              title: Text(
                'Buscar manualmente',
                style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                'Escribe tu búsqueda y elige entre resultados',
                style: GoogleFonts.comicNeue(fontSize: 12, color: Colors.grey[600]),
              ),
              onTap: () => Navigator.pop(ctx, 'manual'),
            ),
            const SizedBox(height: 8),
            // Opción 3: Pegar URL
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ComicTheme.powerGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.link, color: ComicTheme.powerGreen),
              ),
              title: Text(
                'Pegar URL de imagen',
                style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                'Pega el enlace directo a la portada',
                style: GoogleFonts.comicNeue(fontSize: 12, color: Colors.grey[600]),
              ),
              onTap: () => Navigator.pop(ctx, 'paste'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (option == null || !mounted) return;

    if (option == 'paste') {
      // Mostrar diálogo para pegar URL
      _showPasteUrlDialog();
      return;
    }

    if (option == 'manual') {
      // Abrir diálogo de búsqueda manual
      final seriesName = _book.seriesName ?? _book.title;
      final selectedCover = await showCoverSearchDialog(
        context,
        initialQuery: seriesName,
        author: _book.author,
        volumeNumber: _book.volumeNumber,
        currentCoverUrl: _book.coverUrl,
      );

      if (selectedCover != null && selectedCover.isNotEmpty && mounted) {
        await context.read<BookProvider>().updateCoverUrl(_book.id!, selectedCover);
        setState(() => _book = _book.copyWith(coverUrl: selectedCover));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Portada actualizada!',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.powerGreen,
          ),
        );
      }
      return;
    }

    // Búsqueda automática (código existente)
    setState(() => _searchingCover = true);

    try {
      final provider = context.read<BookProvider>();

      // Para omnibus, extraer serie del título (ej: "ONE PIECE 3 EN 1 3" -> "ONE PIECE 3 EN 1")
      String seriesName;
      int? volumeNum = _book.volumeNumber;
      String? baseSeriesName;

      // Detectar omnibus en el TÍTULO (no en seriesName guardado)
      final omnibusMatch = RegExp(r'^(.+\d+\s*[Ee][Nn]\s*1)\s+(\d+)$').firstMatch(_book.title.trim());
      final isOmnibus = omnibusMatch != null;

      if (isOmnibus) {
        // Para omnibus: extraer serie completa incluyendo "3 EN 1"
        seriesName = omnibusMatch.group(1)!.trim();
        volumeNum = int.tryParse(omnibusMatch.group(2) ?? '') ?? _book.volumeNumber;
        // Base es sin el "3 EN 1" (ej: "ONE PIECE")
        final baseMatch = RegExp(r'^(.+?)\s*\d+\s*[Ee][Nn]\s*1').firstMatch(seriesName);
        baseSeriesName = baseMatch?.group(1)?.trim();
        debugPrint('📚 Omnibus detectado del título: serie="$seriesName", base="$baseSeriesName", vol=$volumeNum');
      } else {
        // No omnibus: usar seriesName guardado o título
        seriesName = _book.seriesName ?? _book.title;
      }

      String? newCover;

      // Usar el provider que tiene traducciones español -> inglés
      newCover = await provider.searchCover(
        seriesName,
        _book.author,
        volumeNumber: volumeNum,
      );

      // Fallback con queries adicionales
      if (newCover == null || newCover.isEmpty) {
        final apiService = BookApiService();
        final queries = <String>[];
        final authorFirst = _book.author.split(',').first.trim();

        if (volumeNum != null) {
          // Para OMNIBUS: queries específicas
          if (isOmnibus) {
            queries.addAll([
              // Título exacto (ej: "ONE PIECE 3 EN 1 5")
              _book.title,
              // Con cero delante si < 10
              if (volumeNum < 10) '$seriesName 0$volumeNum',
              // Base + 3 en 1 + vol
              if (baseSeriesName != null) '$baseSeriesName 3 en 1 $volumeNum',
              if (baseSeriesName != null && volumeNum < 10) '$baseSeriesName 3 en 1 0$volumeNum',
              // Solo base + volumen (puede encontrar versión no-omnibus)
              if (baseSeriesName != null) '$baseSeriesName $volumeNum',
              if (baseSeriesName != null) '$baseSeriesName vol $volumeNum',
            ]);
          }

          // Queries estándar
          queries.addAll([
            '$authorFirst $seriesName vol $volumeNum',
            '$authorFirst $seriesName $volumeNum',
            '$seriesName vol $volumeNum',
            '$seriesName $volumeNum',
            '${_book.title} ${_book.author}',
          ]);
        } else {
          queries.addAll([
            '$authorFirst ${_book.title}',
            '${_book.title} ${_book.author}',
            _book.title,
          ]);
        }

        for (final query in queries) {
          debugPrint('🔍 Buscando portada: "$query"');
          newCover = await apiService.searchCover(query, _book.author);
          if (newCover != null && newCover.isNotEmpty) {
            debugPrint('✅ Portada encontrada con query: $query');
            break;
          }
        }
      }

      if (mounted) {
        if (newCover != null && newCover.isNotEmpty) {
          // Actualizar en la base de datos
          await context.read<BookProvider>().updateCoverUrl(_book.id!, newCover);

          setState(() {
            _book = _book.copyWith(coverUrl: newCover);
            _searchingCover = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '¡Portada actualizada!',
                style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
              ),
              backgroundColor: ComicTheme.powerGreen,
            ),
          );
        } else {
          setState(() => _searchingCover = false);
          // Si no encuentra, ofrecer búsqueda manual
          final shouldSearchManually = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: ComicTheme.backgroundCream,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
              ),
              title: Text(
                'NO ENCONTRADA',
                style: GoogleFonts.bangers(color: ComicTheme.comicBorder),
              ),
              content: Text(
                '¿Quieres buscar manualmente?',
                style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('NO', style: GoogleFonts.bangers(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ComicTheme.secondaryBlue,
                  ),
                  child: Text('SÍ, BUSCAR', style: GoogleFonts.bangers(color: Colors.white)),
                ),
              ],
            ),
          );

          if (shouldSearchManually == true && mounted) {
            final selectedCover = await showCoverSearchDialog(
              context,
              initialQuery: _book.seriesName ?? _book.title,
              author: _book.author,
              volumeNumber: _book.volumeNumber,
            );

            if (selectedCover != null && selectedCover.isNotEmpty && mounted) {
              await context.read<BookProvider>().updateCoverUrl(_book.id!, selectedCover);
              setState(() => _book = _book.copyWith(coverUrl: selectedCover));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '¡Portada actualizada!',
                    style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: ComicTheme.powerGreen,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searchingCover = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error buscando portada',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.heroRed,
          ),
        );
      }
    }
  }

  /// Muestra diálogo para pegar URL de portada manualmente
  void _showPasteUrlDialog() {
    final urlController = TextEditingController(text: _book.coverUrl ?? '');

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
            const Icon(Icons.link, color: ComicTheme.powerGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'URL DE PORTADA',
                style: GoogleFonts.bangers(
                  color: ComicTheme.comicBorder,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pega la URL de la imagen:',
              style: GoogleFonts.comicNeue(
                fontWeight: FontWeight.bold,
                color: ComicTheme.comicBorder,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              maxLines: 3,
              style: GoogleFonts.comicNeue(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'https://ejemplo.com/portada.jpg',
                hintStyle: GoogleFonts.comicNeue(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: ComicTheme.comicBorder),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tip: Busca la imagen en Google, haz clic derecho y "Copiar dirección de imagen"',
              style: GoogleFonts.comicNeue(
                fontSize: 10,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.bangers(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final url = urlController.text.trim();
              Navigator.pop(ctx);
              if (url.isNotEmpty && _isValidImageUrl(url)) {
                // Guardar la nueva URL
                await context.read<BookProvider>().updateCoverUrl(_book.id!, url);
                setState(() {
                  _book = _book.copyWith(coverUrl: url);
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '¡Portada actualizada!',
                        style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: ComicTheme.powerGreen,
                    ),
                  );
                }
              } else if (url.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'URL no válida. Debe ser una imagen (jpg, png, webp...)',
                      style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: ComicTheme.heroRed,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: Text(
              'APLICAR',
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

  /// Valida que la URL sea de una imagen
  bool _isValidImageUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return false;
    }
    // Aceptar cualquier URL HTTPS (muchas CDNs no usan extensiones)
    return true;
  }

  Future<void> _markAsFinished() async {
    final provider = context.read<BookProvider>();
    final parentSettings = ParentSettingsService();

    // Mostrar celebración
    await showCelebration(context, _book.title);

    // Marcar como terminado
    await provider.markAsFinished(_book.id!);

    // Buscar info de serie si no la tiene
    Book bookWithSeries = _book;
    if (!_book.isPartOfSeries) {
      bookWithSeries = await provider.getSeriesInfo(_book);
    }

    if (!mounted) return;

    // Verificar si la serie está marcada como completa
    final seriesName = bookWithSeries.seriesName ?? bookWithSeries.title;
    final isSeriesComplete = await parentSettings.isSeriesComplete(seriesName);

    // Si tiene siguiente volumen Y la serie NO está completa, mostrar diálogo
    if (!isSeriesComplete && (bookWithSeries.hasNextVolume || bookWithSeries.isPartOfSeries)) {
      final result = await showNextVolumeDialog(context, bookWithSeries);

      if (result == 'have_it' && mounted) {
        // Añadir el siguiente libro directamente a Leyendo
        await _addNextVolume(bookWithSeries, status: 'reading');
        return;
      } else if (result == 'request' && mounted) {
        // Añadir el siguiente libro a Solicitados (wishlist)
        await _addNextVolume(bookWithSeries, status: 'wishlist');
        return;
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _addNextVolume(Book finishedBook, {String status = 'reading'}) async {
    final provider = context.read<BookProvider>();
    final nextVolumeNumber = (finishedBook.volumeNumber ?? 0) + 1;
    final seriesName = finishedBook.seriesName ?? finishedBook.title;

    // Detectar si es omnibus (ej: "ONE PIECE 3 EN 1")
    final isOmnibus = RegExp(r'\d+\s*[Ee][Nn]\s*1').hasMatch(seriesName);

    // Título: omnibus sin "Vol.", normal con "Vol."
    final nextTitle = finishedBook.nextVolumeTitle ??
        (isOmnibus ? '$seriesName $nextVolumeNumber' : '$seriesName Vol. $nextVolumeNumber');

    // Buscar portada si no la tenemos (usando provider que tiene traducciones)
    String? coverUrl = finishedBook.nextVolumeCover;
    if (coverUrl == null || coverUrl.isEmpty) {
      coverUrl = await provider.searchCover(
        seriesName,
        finishedBook.author,
        volumeNumber: nextVolumeNumber,
      );
    }

    // ISBN sintético ESTÁNDAR: basado en serie (igual que grouped_book_grid)
    // Esto evita duplicados cuando se solicita desde diferentes pantallas
    final syntheticIsbn = finishedBook.nextVolumeIsbn ??
        '${seriesName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}-vol-$nextVolumeNumber';

    // Crear el siguiente libro
    final nextBook = Book(
      isbn: syntheticIsbn,
      title: nextTitle,
      author: finishedBook.author,
      coverUrl: coverUrl,
      status: status,
      currentPage: 0,
      totalPages: finishedBook.totalPages,
      seriesName: seriesName,
      volumeNumber: nextVolumeNumber,
    );

    final added = await provider.addBook(nextBook);

    if (mounted) {
      if (added) {
        final isWishlist = status == 'wishlist';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isWishlist
                  ? '¡${nextBook.title} añadido a Solicitados!'
                  : '¡${nextBook.title} añadido a Leyendo!',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: isWishlist ? ComicTheme.secondaryBlue : ComicTheme.powerGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ya tienes este libro en tu biblioteca',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.primaryOrange,
          ),
        );
      }
      Navigator.pop(context);
    }
  }

  void _markAsReading() {
    context.read<BookProvider>().markAsReading(_book.id!);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_book.title} movido a Leyendo',
          style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
        ),
        backgroundColor: ComicTheme.secondaryBlue,
      ),
    );
  }

  /// Muestra el diálogo para empezar el siguiente volumen (¿lo tienes o lo solicitas?)
  Future<void> _showNextVolumeOptions() async {
    final provider = context.read<BookProvider>();
    final nextVolumeNumber = (_book.volumeNumber ?? 0) + 1;
    final seriesName = _book.seriesName ?? _book.title;

    // Buscar si ya tiene el siguiente volumen
    final syntheticIsbn = '${seriesName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}-vol-$nextVolumeNumber';
    Book? existingNextVolume;

    for (final book in [...provider.readingBooks, ...provider.finishedBooks, ...provider.wishlistBooks]) {
      if (book.isbn == syntheticIsbn ||
          (book.seriesName == seriesName && book.volumeNumber == nextVolumeNumber)) {
        existingNextVolume = book;
        break;
      }
    }

    if (existingNextVolume != null) {
      // Ya tiene el siguiente volumen
      if (existingNextVolume.isWishlist) {
        // Está en solicitados - preguntar si quiere empezarlo
        final startIt = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: ComicTheme.backgroundCream,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: ComicTheme.comicBorder, width: 4),
            ),
            title: Text(
              '¡YA LO TIENES SOLICITADO!',
              style: GoogleFonts.bangers(color: ComicTheme.secondaryBlue),
            ),
            content: Text(
              '${existingNextVolume!.title} está en Solicitados.\n\n¿Ya lo tienes y quieres empezar a leerlo?',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('NO', style: GoogleFonts.bangers(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: ComicTheme.powerGreen),
                child: Text('¡SÍ, EMPEZAR!', style: GoogleFonts.bangers(color: Colors.white)),
              ),
            ],
          ),
        );

        if (startIt == true && mounted) {
          await provider.markAsReading(existingNextVolume.id!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '¡${existingNextVolume.title} movido a Leyendo!',
                style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
              ),
              backgroundColor: ComicTheme.powerGreen,
            ),
          );
        }
      } else if (existingNextVolume.isReading) {
        // Ya lo está leyendo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Ya estás leyendo ${existingNextVolume.title}!',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.secondaryBlue,
          ),
        );
      } else {
        // Ya lo terminó
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Ya completaste ${existingNextVolume.title}!',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.powerGreen,
          ),
        );
      }
      return;
    }

    // No tiene el siguiente volumen - mostrar diálogo normal
    final result = await showNextVolumeDialog(context, _book);

    if (result == 'have_it' && mounted) {
      // Añadir el siguiente libro directamente a Leyendo
      await _addNextVolume(_book, status: 'reading');
    } else if (result == 'request' && mounted) {
      // Añadir el siguiente libro a Solicitados (wishlist)
      await _addNextVolume(_book, status: 'wishlist');
    }
  }

  /// Marca la serie como completa (no hay más volúmenes)
  Future<void> _markSeriesAsComplete() async {
    final parentSettings = ParentSettingsService();
    final seriesName = _book.seriesName ?? _book.title;

    await parentSettings.markSeriesAsComplete(seriesName);

    if (mounted) {
      setState(() => _isSeriesComplete = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡$seriesName marcada como completa!',
            style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
          ),
          backgroundColor: ComicTheme.powerGreen,
        ),
      );
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ComicTheme.backgroundCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ComicTheme.comicBorder, width: 4),
        ),
        title: Text(
          '¿ELIMINAR LIBRO?',
          style: GoogleFonts.bangers(
            color: ComicTheme.heroRed,
            letterSpacing: 1,
          ),
        ),
        content: Text(
          '¿Seguro que quieres eliminar "${_book.title}"?',
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
          ElevatedButton(
            onPressed: () {
              context.read<BookProvider>().deleteBook(_book.id!);
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Libro eliminado',
                    style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: ComicTheme.heroRed,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.heroRed,
            ),
            child: Text(
              'ELIMINAR',
              style: GoogleFonts.bangers(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
