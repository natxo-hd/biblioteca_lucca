import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../theme/comic_theme.dart';
import '../services/api/tomosygrapas_client.dart';
import '../constants/translations.dart';

/// Diálogo para buscar y seleccionar portada manualmente
class CoverSearchDialog extends StatefulWidget {
  final String initialQuery;
  final String author;
  final int? volumeNumber;
  final String? currentCoverUrl;
  final String? isbn;

  const CoverSearchDialog({
    super.key,
    required this.initialQuery,
    required this.author,
    this.volumeNumber,
    this.currentCoverUrl,
    this.isbn,
  });

  @override
  State<CoverSearchDialog> createState() => _CoverSearchDialogState();
}

class _CoverSearchDialogState extends State<CoverSearchDialog> {
  final _searchController = TextEditingController();
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

  /// Extrae el nombre de serie sin número de volumen del query
  String _extractSeriesName(String query) {
    // Quitar sufijos tipo "03", "vol 3", "vol. 3", "volume 3"
    return query
        .replaceAll(RegExp(r'\s+(?:vol\.?\s*)?\d+\s*$', caseSensitive: false), '')
        .trim();
  }

  /// Detecta si una URL es de fuente española (Casa del Libro, Tomos y Grapas)
  bool _isSpanishSource(String url) {
    return url.contains('casadellibro.com') ||
        url.contains('tomosygrapas.com');
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _coverResults = [];
      _selectedCover = null;
    });

    // Dos grupos: español (prioridad) e internacional
    final spanishCovers = <String>[];
    final internationalCovers = <String>[];
    final seen = <String>{};
    final seriesName = _extractSeriesName(query);

    final englishName = ComicTranslations.hasTranslation(seriesName)
        ? ComicTranslations.getEnglishName(seriesName)
        : null;
    if (englishName != null) {
      debugPrint('🔍 Traducción: "$seriesName" → "$englishName"');
    }

    void addCovers(List<String> covers) {
      for (final cover in covers) {
        if (seen.contains(cover)) continue;
        seen.add(cover);
        if (_isSpanishSource(cover)) {
          spanishCovers.add(cover);
        } else {
          internationalCovers.add(cover);
        }
      }
      if (mounted && seen.isNotEmpty) {
        setState(() {
          _coverResults = [...spanishCovers, ...internationalCovers];
        });
      }
    }

    // Casa del Libro directo por ISBN (rápido, hacer primero)
    if (widget.isbn != null && widget.isbn!.startsWith('97884')) {
      final cdlUrl = _buildCasaDelLibroCoverUrl(widget.isbn!);
      try {
        final imgResp = await http.head(Uri.parse(cdlUrl))
            .timeout(const Duration(seconds: 3));
        if (imgResp.statusCode == 200) {
          addCovers([cdlUrl]);
        }
      } catch (_) {}
    }

    // Lanzar TODAS las búsquedas en PARALELO
    final searches = <Future<void>>[];

    // Tomos y Grapas (volumen exacto) - fuente española prioritaria
    if (widget.volumeNumber != null) {
      searches.add(() async {
        try {
          final cover = await _tomosYGrapas.searchCover(
            seriesName, widget.volumeNumber!,
          );
          if (cover != null && cover.isNotEmpty) addCovers([cover]);
        } catch (e) {
          debugPrint('T&G exact error: $e');
        }
      }());
    }

    // Tomos y Grapas (múltiples) - fuente española prioritaria
    searches.add(() async {
      try {
        final covers = await _tomosYGrapas.searchCoversMultiple(
          seriesName, limit: 6,
        );
        addCovers(covers);
      } catch (e) {
        debugPrint('T&G multi error: $e');
      }
    }());

    // Amazon (extrae ASINs→ISBN→Casa del Libro = portadas españolas)
    final amazonQuery = widget.volumeNumber != null
        ? '$seriesName ${widget.volumeNumber} comic'
        : '$seriesName comic';
    searches.add(() async {
      try {
        final covers = await _searchAmazonCovers(amazonQuery);
        addCovers(covers);
      } catch (e) {
        debugPrint('Amazon error: $e');
      }
    }());

    // Open Library (nombre inglés + volumen)
    if (englishName != null && widget.volumeNumber != null) {
      searches.add(() async {
        try {
          final covers = await _searchOpenLibraryCovers(
            englishName, volumeNumber: widget.volumeNumber,
          );
          addCovers(covers);
        } catch (e) {
          debugPrint('OpenLibrary EN error: $e');
        }
      }());
    }

    // Open Library (query directo, sin traducción)
    if (englishName == null) {
      searches.add(() async {
        try {
          final covers = await _searchOpenLibraryCovers(
            query, volumeNumber: widget.volumeNumber,
          );
          addCovers(covers);
        } catch (e) {
          debugPrint('OpenLibrary ES error: $e');
        }
      }());
    }

    // Google Books (inglés)
    if (englishName != null) {
      final engQuery = widget.volumeNumber != null
          ? '$englishName vol ${widget.volumeNumber}'
          : englishName;
      searches.add(() async {
        try {
          final covers = await _searchGoogleBooksCovers(engQuery);
          addCovers(covers);
        } catch (e) {
          debugPrint('GoogleBooks EN error: $e');
        }
      }());
    }

    // Google Books (query español directo → ISBNs españoles → CDL)
    searches.add(() async {
      try {
        final covers = await _searchGoogleBooksCovers(query);
        addCovers(covers);
      } catch (e) {
        debugPrint('GoogleBooks ES error: $e');
      }
    }());

    // Esperar a que terminen todas las búsquedas paralelas
    await Future.wait(searches);

    if (mounted) {
      setState(() {
        _coverResults = [...spanishCovers, ...internationalCovers];
        _isSearching = false;
      });
    }
  }

  /// Verifica que un título de Open Library sea relevante para la búsqueda
  bool _isTitleRelevant(String resultTitle, String searchQuery) {
    final resultLower = resultTitle.toLowerCase();
    final queryLower = searchQuery.toLowerCase();
    // Al menos las 2 primeras palabras significativas deben coincidir
    final queryWords = queryLower.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    if (queryWords.isEmpty) return true;
    final matchCount = queryWords.where((w) => resultLower.contains(w)).length;
    return matchCount >= (queryWords.length * 0.5).ceil();
  }

  /// Busca portadas en Open Library (excelente fuente para cómics)
  Future<List<String>> _searchOpenLibraryCovers(String query, {int? volumeNumber}) async {
    final covers = <String>[];
    try {
      // Búsqueda con volumen específico primero
      final searchQuery = volumeNumber != null ? '$query vol $volumeNumber' : query;
      debugPrint('🔍 Open Library: "$searchQuery"');
      final url = Uri.parse(
        'https://openlibrary.org/search.json?q=${Uri.encodeComponent(searchQuery)}&limit=10',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final docs = data['docs'] as List? ?? [];
        for (final doc in docs) {
          final title = (doc['title'] as String?) ?? '';
          // Filtrar resultados irrelevantes
          if (!_isTitleRelevant(title, query)) {
            debugPrint('📚 Open Library DESCARTADO (no relevante): $title');
            continue;
          }
          final coverId = doc['cover_i'];
          if (coverId != null) {
            final coverUrl = 'https://covers.openlibrary.org/b/id/$coverId-L.jpg';
            if (!covers.contains(coverUrl)) {
              covers.add(coverUrl);
              debugPrint('📚 Open Library cover: $title → $coverUrl');
            }
          }
          if (covers.length >= 6) break;
        }
      }

      // Si no encontramos suficientes con volumen, buscar sin volumen
      if (covers.length < 3 && volumeNumber != null) {
        debugPrint('🔍 Open Library (sin vol): "$query"');
        final url2 = Uri.parse(
          'https://openlibrary.org/search.json?q=${Uri.encodeComponent(query)}&limit=15',
        );
        final response2 = await http.get(url2).timeout(const Duration(seconds: 10));
        if (response2.statusCode == 200) {
          final data2 = json.decode(response2.body);
          final docs2 = data2['docs'] as List? ?? [];
          for (final doc in docs2) {
            final title = (doc['title'] as String?) ?? '';
            if (!_isTitleRelevant(title, query)) continue;
            final coverId = doc['cover_i'];
            if (coverId != null) {
              final coverUrl = 'https://covers.openlibrary.org/b/id/$coverId-L.jpg';
              if (!covers.contains(coverUrl)) {
                covers.add(coverUrl);
                debugPrint('📚 Open Library cover: $title → $coverUrl');
              }
            }
            if (covers.length >= 8) break;
          }
        }
      }
    } catch (e) {
      debugPrint('Open Library covers error: $e');
    }
    return covers;
  }

  /// Construye URL de portada de Casa del Libro a partir de ISBN
  String _buildCasaDelLibroCoverUrl(String isbn) {
    final last2 = isbn.length >= 2 ? isbn.substring(isbn.length - 2) : '00';
    return 'https://imagessl0.casadellibro.com/a/l/s7/$last2/$isbn.webp';
  }

  /// Calcula dígito de control ISBN-13
  String? _asinToIsbn13(String asin) {
    if (asin.length != 10 || !RegExp(r'^\d{9}[\dX]$').hasMatch(asin)) return null;
    final isbn12 = '978${asin.substring(0, 9)}';
    var total = 0;
    for (var i = 0; i < 12; i++) {
      total += int.parse(isbn12[i]) * (i.isEven ? 1 : 3);
    }
    final check = (10 - (total % 10)) % 10;
    return '$isbn12$check';
  }

  /// Busca portadas en Amazon España + extrae ISBNs para Casa del Libro
  Future<List<String>> _searchAmazonCovers(String query) async {
    final covers = <String>[];
    try {
      debugPrint('🔍 Amazon ES: "$query"');
      final url = Uri.parse(
        'https://www.amazon.es/s?k=${Uri.encodeComponent(query)}&i=stripbooks',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Accept': 'text/html',
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = response.body;

        // 1. Extraer ASINs → convertir a ISBN-13 → portada de Casa del Libro
        final asinPattern = RegExp(r'/dp/(\d{10})/');
        final asinMatches = asinPattern.allMatches(body);
        for (final match in asinMatches) {
          final asin = match.group(1)!;
          final isbn13 = _asinToIsbn13(asin);
          if (isbn13 != null && isbn13.startsWith('97884')) {
            final cdlUrl = _buildCasaDelLibroCoverUrl(isbn13);
            if (!covers.contains(cdlUrl)) {
              // Verificar que la imagen existe
              try {
                final imgResp = await http.head(Uri.parse(cdlUrl))
                    .timeout(const Duration(seconds: 5));
                if (imgResp.statusCode == 200) {
                  covers.add(cdlUrl);
                  debugPrint('🏠 Amazon ASIN $asin → CDL ISBN $isbn13 → $cdlUrl');
                }
              } catch (_) {}
            }
          }
          if (covers.length >= 3) break;
        }

        // 2. Extraer imágenes de productos Amazon directamente
        final imgPattern = RegExp(r'"(https://m\.media-amazon\.com/images/I/[^"]+\.jpg)"');
        final imgMatches = imgPattern.allMatches(body);
        for (final match in imgMatches) {
          var imgUrl = match.group(1)!;
          imgUrl = imgUrl.replaceAll(RegExp(r'\._[^.]+_\.'), '.');
          if (imgUrl.contains('_CB') || imgUrl.contains('gateway')) continue;
          if (!covers.contains(imgUrl)) {
            covers.add(imgUrl);
            debugPrint('🛒 Amazon cover: $imgUrl');
          }
          if (covers.length >= 6) break;
        }
      }
    } catch (e) {
      debugPrint('Amazon covers error: $e');
    }
    return covers;
  }

  /// Busca portadas en Google Books: extrae ISBNs españoles → CDL + thumbnails
  Future<List<String>> _searchGoogleBooksCovers(String query) async {
    final covers = <String>[];
    try {
      debugPrint('🔍 Google Books (intl): "$query"');
      final url = Uri.parse(
        'https://www.googleapis.com/books/v1/volumes?q=${Uri.encodeComponent(query)}&maxResults=10',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];

        // Primero: extraer ISBNs españoles → portada CDL (mayor calidad)
        final checkedIsbns = <String>{};
        for (final item in items) {
          final volumeInfo = item['volumeInfo'] as Map<String, dynamic>?;
          if (volumeInfo == null) continue;
          final identifiers = volumeInfo['industryIdentifiers'] as List? ?? [];
          for (final id in identifiers) {
            final isbn = id['identifier'] as String?;
            if (isbn != null && isbn.startsWith('97884') && !checkedIsbns.contains(isbn)) {
              checkedIsbns.add(isbn);
              final cdlUrl = _buildCasaDelLibroCoverUrl(isbn);
              try {
                final imgResp = await http.head(Uri.parse(cdlUrl))
                    .timeout(const Duration(seconds: 3));
                if (imgResp.statusCode == 200) {
                  covers.add(cdlUrl);
                  debugPrint('🏠 Google Books ISBN $isbn → CDL: $cdlUrl');
                }
              } catch (_) {}
            }
          }
          if (covers.length >= 3) break;
        }

        // Después: thumbnails de Google Books
        for (final item in items) {
          final volumeInfo = item['volumeInfo'] as Map<String, dynamic>?;
          if (volumeInfo == null) continue;
          final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
          if (imageLinks == null) continue;
          var imgUrl = imageLinks['thumbnail'] as String? ??
              imageLinks['smallThumbnail'] as String?;
          if (imgUrl != null) {
            imgUrl = imgUrl.replaceAll('http://', 'https://');
            imgUrl = imgUrl.replaceAll('zoom=1', 'zoom=3');
            if (!covers.contains(imgUrl)) {
              covers.add(imgUrl);
              debugPrint('📚 Google Books cover: $imgUrl');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Google Books covers error: $e');
    }
    return covers;
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
  String? isbn,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => CoverSearchDialog(
      initialQuery: initialQuery,
      author: author,
      volumeNumber: volumeNumber,
      currentCoverUrl: currentCoverUrl,
      isbn: isbn,
    ),
  );
}
