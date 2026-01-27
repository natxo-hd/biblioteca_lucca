import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/comic_theme.dart';
import '../services/book_api_service.dart';
import '../services/api/tomosygrapas_client.dart';

/// Diálogo para buscar y seleccionar portada manualmente
class CoverSearchDialog extends StatefulWidget {
  final String initialQuery;
  final String author;
  final int? volumeNumber;
  final String? currentCoverUrl;

  const CoverSearchDialog({
    super.key,
    required this.initialQuery,
    required this.author,
    this.volumeNumber,
    this.currentCoverUrl,
  });

  @override
  State<CoverSearchDialog> createState() => _CoverSearchDialogState();
}

class _CoverSearchDialogState extends State<CoverSearchDialog> {
  final _searchController = TextEditingController();
  final _apiService = BookApiService();
  final _tomosYGrapas = TomosYGrapasClient();

  List<String> _coverResults = [];
  bool _isSearching = false;
  String? _selectedCover;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    // Auto-buscar al abrir
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _coverResults = [];
      _selectedCover = null;
    });

    try {
      final results = <String>{};

      // 1. Buscar en Tomos y Grapas
      debugPrint('🔍 Buscando portadas en Tomos y Grapas: $query');
      final tomosResults = await _tomosYGrapas.searchCoversMultiple(query, limit: 6);
      results.addAll(tomosResults);

      // Actualizar UI con resultados parciales
      if (mounted && results.isNotEmpty) {
        setState(() => _coverResults = results.toList());
      }

      // 2. Buscar en Google Books
      debugPrint('🔍 Buscando portadas en Google Books: $query');
      final googleCover = await _apiService.searchCover(query, widget.author);
      if (googleCover != null && googleCover.isNotEmpty) {
        results.add(googleCover);
      }

      // 3. Buscar con variaciones
      if (widget.volumeNumber != null) {
        final volNum = widget.volumeNumber!;
        final variations = [
          '$query vol $volNum',
          '$query $volNum',
          if (volNum < 10) '$query 0$volNum',
        ];

        for (final variation in variations) {
          if (results.length >= 8) break;
          final cover = await _apiService.searchCover(variation, widget.author);
          if (cover != null && cover.isNotEmpty && !results.contains(cover)) {
            results.add(cover);
          }
        }
      }

      if (mounted) {
        setState(() {
          _coverResults = results.toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Error buscando portadas: $e');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ComicTheme.comicBorder, width: 4),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: ComicTheme.heroGradient),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image_search, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'BUSCAR PORTADA',
                      style: GoogleFonts.bangers(
                        fontSize: 22,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Campo de búsqueda
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar portada...',
                        hintStyle: GoogleFonts.comicNeue(),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSearching ? null : _performSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ComicTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                      ),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('BUSCAR', style: GoogleFonts.bangers(fontSize: 14)),
                  ),
                ],
              ),
            ),

            // Resultados
            Flexible(
              child: _isSearching && _coverResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: ComicTheme.primaryOrange),
                          const SizedBox(height: 16),
                          Text(
                            'Buscando portadas...',
                            style: GoogleFonts.comicNeue(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : _coverResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No se encontraron portadas',
                                style: GoogleFonts.comicNeue(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Prueba con otro término de búsqueda',
                                style: GoogleFonts.comicNeue(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shrinkWrap: true,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _coverResults.length,
                          itemBuilder: (context, index) {
                            final coverUrl = _coverResults[index];
                            final isSelected = _selectedCover == coverUrl;

                            return GestureDetector(
                              onTap: () => setState(() => _selectedCover = coverUrl),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? ComicTheme.powerGreen
                                        : ComicTheme.comicBorder,
                                    width: isSelected ? 4 : 2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: ComicTheme.powerGreen.withValues(alpha: 0.5),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [
                                          const BoxShadow(
                                            color: Colors.black26,
                                            offset: Offset(2, 2),
                                            blurRadius: 0,
                                          ),
                                        ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: coverUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.broken_image),
                                        ),
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: ComicTheme.powerGreen,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Botones de acción
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[400]!, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('CANCELAR', style: GoogleFonts.bangers(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _selectedCover != null
                          ? () => Navigator.pop(context, _selectedCover)
                          : null,
                      icon: const Icon(Icons.check, size: 20),
                      label: Text(
                        'SELECCIONAR',
                        style: GoogleFonts.bangers(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ComicTheme.powerGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Muestra el diálogo de búsqueda de portada
Future<String?> showCoverSearchDialog(
  BuildContext context, {
  required String initialQuery,
  required String author,
  int? volumeNumber,
  String? currentCoverUrl,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => CoverSearchDialog(
      initialQuery: initialQuery,
      author: author,
      volumeNumber: volumeNumber,
      currentCoverUrl: currentCoverUrl,
    ),
  );
}
