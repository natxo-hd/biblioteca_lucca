import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/book.dart';
import '../theme/comic_theme.dart';
import '../services/api/tebeosfera_client.dart';
import '../services/api/salvat_client.dart';

/// Pantalla robusta para buscar y añadir colecciones/series completas
/// Obtiene portadas verificadas directamente de las páginas de producto
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _tebeosferaClient = TebeosferaClient();
  final _salvatClient = SalvatClient();
  List<_VolumeResult> _results = [];
  bool _isSearching = false;
  bool _isAdding = false;
  String? _lastQuery;
  final Set<int> _selectedIndices = {};
  String _addingStatus = '';
  int _addingProgress = 0;
  int _addingTotal = 0;

  // Filtro de editorial
  String? _publisherFilter;
  List<String> _availablePublishers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;

    final trimmedQuery = query.trim();

    setState(() {
      _isSearching = true;
      _results = [];
      _selectedIndices.clear();
      _publisherFilter = null;
      _availablePublishers = [];
      _lastQuery = trimmedQuery;
    });

    final results = <_VolumeResult>[];

    // Buscar en múltiples fuentes
    await Future.wait([
      _searchSalvat(trimmedQuery, results),
      _searchTebeosfera(trimmedQuery, results),
      _searchTomosYGrapas(trimmedQuery, results),
      _searchGoogleBooks(trimmedQuery, results),
    ]);

    // Extraer editoriales disponibles
    final publishers = <String>{};
    for (final r in results) {
      if (r.publisher != null && r.publisher!.isNotEmpty) {
        publishers.add(r.publisher!);
      }
    }

    // Ordenar por número de volumen
    results.sort((a, b) {
      // Primero por serie
      final seriesCompare = (a.seriesName ?? '').compareTo(b.seriesName ?? '');
      if (seriesCompare != 0) return seriesCompare;
      // Luego por volumen
      if (a.volumeNumber != null && b.volumeNumber != null) {
        return a.volumeNumber!.compareTo(b.volumeNumber!);
      }
      if (a.volumeNumber != null) return -1;
      if (b.volumeNumber != null) return 1;
      return a.title.compareTo(b.title);
    });

    if (mounted) {
      setState(() {
        _results = results;
        _availablePublishers = publishers.toList()..sort();
        _isSearching = false;
      });
    }
  }

  Future<void> _searchSalvat(String query, List<_VolumeResult> results) async {
    try {
      debugPrint('Salvat: Buscando colección "$query"');
      final books = await _salvatClient.searchCollection(query);

      if (books.isNotEmpty) {
        debugPrint('Salvat: Encontrados ${books.length} volúmenes');

        // Convertir books a _VolumeResult para los volúmenes internos
        final volumeResults = books.map((book) => _VolumeResult(
          title: book.title,
          author: book.author,
          seriesName: book.seriesName,
          volumeNumber: book.volumeNumber,
          coverUrl: book.coverUrl,
          publisher: book.publisher,
          productUrl: book.sourceUrl,
          pageCount: book.totalPages,
          source: 'Salvat',
        )).toList();

        // Crear un solo resultado que representa toda la colección
        final firstBook = books.first;
        final collectionName = firstBook.seriesName ?? query;

        results.add(_VolumeResult(
          title: collectionName,
          author: 'Varios Autores',
          seriesName: collectionName,
          coverUrl: firstBook.coverUrl,
          publisher: 'Salvat',
          pageCount: firstBook.totalPages,
          source: 'Salvat',
          isCollection: true,
          volumes: volumeResults,
          volumeCount: books.length,
        ));
      }
    } catch (e) {
      debugPrint('Error buscando en Salvat: $e');
    }
  }

  Future<void> _searchTebeosfera(String query, List<_VolumeResult> results) async {
    try {
      debugPrint('Tebeosfera: Buscando colección "$query"');
      final books = await _tebeosferaClient.searchBooks(query);

      if (books.isNotEmpty) {
        debugPrint('Tebeosfera: Encontrados ${books.length} volúmenes');

        // Convertir books a _VolumeResult para los volúmenes internos
        final volumeResults = books.map((book) => _VolumeResult(
          title: book.title,
          author: book.author,
          seriesName: book.seriesName,
          volumeNumber: book.volumeNumber,
          coverUrl: book.coverUrl,
          publisher: book.publisher,
          pageCount: book.totalPages,
          source: 'Tebeosfera',
        )).toList();

        // Crear un solo resultado que representa toda la colección
        final firstBook = books.first;
        final collectionName = firstBook.seriesName ?? query;

        results.add(_VolumeResult(
          title: collectionName,
          author: firstBook.author,
          seriesName: collectionName,
          coverUrl: firstBook.coverUrl, // Primera portada como preview
          publisher: firstBook.publisher,
          pageCount: firstBook.totalPages,
          source: 'Tebeosfera',
          isCollection: true,
          volumes: volumeResults,
          volumeCount: books.length,
        ));
      }
    } catch (e) {
      debugPrint('Error buscando en Tebeosfera: $e');
    }
  }

  Future<void> _searchTomosYGrapas(String query, List<_VolumeResult> results) async {
    try {
      final seenUrls = <String>{};

      // Múltiples queries para obtener más resultados
      final queries = [query, '$query 01', '$query 1', '$query vol'];

      for (final q in queries) {
        try {
          final ajaxUrl = Uri.parse(
            'https://tienda.tomosygrapas.com/es/module/leoproductsearch/productsearch?ajax=1&q=${Uri.encodeComponent(q)}',
          );

          final response = await http.get(
            ajaxUrl,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
              'Accept': 'application/json',
              'X-Requested-With': 'XMLHttpRequest',
            },
          ).timeout(const Duration(seconds: 12));

          if (response.statusCode == 200) {
            final data = json.decode(response.body) as Map<String, dynamic>;
            final products = data['products'] as List<dynamic>?;

            if (products != null) {
              for (final product in products) {
                final productMap = product as Map<String, dynamic>;
                final name = productMap['name'] as String?;
                final productUrl = productMap['url'] as String? ?? productMap['link'] as String?;

                if (name == null || name.isEmpty) continue;
                if (productUrl != null && seenUrls.contains(productUrl)) continue;
                if (productUrl != null) seenUrls.add(productUrl);

                final publisher = productMap['manufacturer_name'] as String?;

                // Obtener cover del JSON de búsqueda
                String? coverUrl;
                if (productMap['cover'] != null) {
                  final cover = productMap['cover'] as Map<String, dynamic>;
                  if (cover['large'] != null) {
                    coverUrl = (cover['large'] as Map<String, dynamic>)['url'] as String?;
                  } else if (cover['bySize'] != null) {
                    final bySize = cover['bySize'] as Map<String, dynamic>;
                    coverUrl = (bySize['large_default'] as Map<String, dynamic>?)?['url'] as String?;
                    coverUrl ??= (bySize['medium_default'] as Map<String, dynamic>?)?['url'] as String?;
                  }
                }

                if (coverUrl != null) {
                  coverUrl = coverUrl.replaceAll('-home_default/', '-large_default/');
                  coverUrl = coverUrl.replaceAll('-medium_default/', '-large_default/');
                  coverUrl = coverUrl.replaceAll('-small_default/', '-large_default/');
                }

                final volInfo = _extractVolumeFromTitle(name);

                results.add(_VolumeResult(
                  title: name,
                  seriesName: volInfo['seriesName'] as String?,
                  volumeNumber: volInfo['volumeNumber'] as int?,
                  coverUrl: coverUrl,
                  publisher: publisher ?? 'Tomos y Grapas',
                  productUrl: productUrl,
                  source: 'T&G',
                ));
              }
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error T&G: $e');
    }
  }

  Future<void> _searchGoogleBooks(String query, List<_VolumeResult> results) async {
    try {
      final url = Uri.parse(
        'https://www.googleapis.com/books/v1/volumes?q=${Uri.encodeComponent(query)}&maxResults=20&langRestrict=es',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;

        if (items != null) {
          for (final item in items) {
            final volumeInfo = (item as Map<String, dynamic>)['volumeInfo'] as Map<String, dynamic>?;
            if (volumeInfo == null) continue;

            final title = volumeInfo['title'] as String?;
            if (title == null || title.isEmpty) continue;

            final authors = volumeInfo['authors'] as List<dynamic>?;
            final author = authors?.isNotEmpty == true ? authors!.first as String : null;
            final publisher = volumeInfo['publisher'] as String?;
            final pageCount = volumeInfo['pageCount'] as int?;

            String? coverUrl;
            final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
            if (imageLinks != null) {
              coverUrl = imageLinks['thumbnail'] as String?;
              if (coverUrl != null) {
                coverUrl = coverUrl.replaceAll('zoom=1', 'zoom=2');
                coverUrl = coverUrl.replaceAll('http://', 'https://');
              }
            }

            // Extraer ISBN
            String? isbn;
            final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>?;
            if (identifiers != null) {
              for (final id in identifiers) {
                final idMap = id as Map<String, dynamic>;
                if (idMap['type'] == 'ISBN_13') {
                  isbn = idMap['identifier'] as String?;
                  break;
                }
              }
            }

            final volInfo = _extractVolumeFromTitle(title);

            results.add(_VolumeResult(
              title: title,
              author: author,
              seriesName: volInfo['seriesName'] as String?,
              volumeNumber: volInfo['volumeNumber'] as int?,
              coverUrl: coverUrl,
              publisher: publisher ?? 'Google Books',
              isbn: isbn,
              pageCount: pageCount,
              source: 'GB',
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Error Google Books: $e');
    }
  }

  Map<String, dynamic> _extractVolumeFromTitle(String title) {
    String? seriesName;
    int? volumeNumber;

    // Patrones más robustos para detectar volúmenes
    final patterns = [
      // "SERIE 01 (DE 10)" o "SERIE 05 (de 20)"
      RegExp(r'^(.+?)\s+(\d{1,3})\s*\((?:DE|de|De)\s*\d+\)', caseSensitive: false),
      // "SERIE Nº 01" o "SERIE N° 5" o "SERIE nº5"
      RegExp(r'^(.+?)\s*[Nn][ºo°\.]\s*(\d+)', caseSensitive: false),
      // "SERIE Vol. 01" o "SERIE VOL 5" o "SERIE vol.5"
      RegExp(r'^(.+?)\s*[Vv][Oo][Ll]\.?\s*(\d+)', caseSensitive: false),
      // "SERIE Tomo 01" o "SERIE T. 5"
      RegExp(r'^(.+?)\s*[Tt](?:omo)?\.?\s*(\d+)', caseSensitive: false),
      // "SERIE #01" o "SERIE # 5"
      RegExp(r'^(.+?)\s*#\s*(\d+)', caseSensitive: false),
      // "SERIE 01: SUBTITULO" o "SERIE 5: algo"
      RegExp(r'^(.+?)\s+(\d{1,3})\s*:', caseSensitive: false),
      // "SERIE 01 - SUBTITULO"
      RegExp(r'^(.+?)\s+(\d{1,3})\s*[-–—]', caseSensitive: false),
      // "SERIE 01" al final (más genérico, último recurso)
      RegExp(r'^(.+?)\s+(\d{1,3})\s*$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(title);
      if (match != null) {
        seriesName = match.group(1)?.trim();
        volumeNumber = int.tryParse(match.group(2) ?? '');
        if (volumeNumber != null && volumeNumber > 0 && volumeNumber < 1000) {
          break;
        }
        volumeNumber = null; // Reset si el número no es válido
      }
    }

    // Limpiar nombre de serie
    if (seriesName != null) {
      seriesName = seriesName
          .replaceAll(RegExp(r'\s*[,:]$'), '')
          .trim();
    }

    return {
      'seriesName': seriesName ?? title,
      'volumeNumber': volumeNumber,
    };
  }

  List<_VolumeResult> get _filteredResults {
    if (_publisherFilter == null) return _results;
    return _results.where((r) => r.publisher == _publisherFilter).toList();
  }

  void _toggleAll() {
    setState(() {
      final filtered = _filteredResults;
      final filteredIndices = filtered.map((r) => _results.indexOf(r)).toSet();

      final allSelected = filteredIndices.every((i) => _selectedIndices.contains(i));
      if (allSelected) {
        _selectedIndices.removeAll(filteredIndices);
      } else {
        _selectedIndices.addAll(filteredIndices);
      }
    });
  }

  void _toggleItem(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  /// Obtiene la portada verificada desde la página de producto de T&G
  Future<String?> _fetchVerifiedCover(String productUrl) async {
    try {
      final response = await http.get(
        Uri.parse(productUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Accept': 'text/html',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final html = response.body;

        // Buscar en data-product JSON (más fiable)
        final dataProductMatch = RegExp(
          r'data-product="([^"]*)"',
          caseSensitive: false,
        ).firstMatch(html);

        if (dataProductMatch != null) {
          try {
            String jsonStr = dataProductMatch.group(1)!;
            jsonStr = jsonStr
                .replaceAll('&quot;', '"')
                .replaceAll('&amp;', '&')
                .replaceAll('&lt;', '<')
                .replaceAll('&gt;', '>')
                .replaceAll('&#039;', "'");

            final productData = json.decode(jsonStr) as Map<String, dynamic>;

            if (productData['cover'] != null) {
              final cover = productData['cover'] as Map<String, dynamic>;
              String? coverUrl;
              if (cover['large'] != null) {
                coverUrl = (cover['large'] as Map<String, dynamic>)['url'] as String?;
              }
              if (coverUrl == null && cover['bySize'] != null) {
                final bySize = cover['bySize'] as Map<String, dynamic>;
                if (bySize['large_default'] != null) {
                  coverUrl = (bySize['large_default'] as Map<String, dynamic>)['url'] as String?;
                }
              }
              if (coverUrl != null) {
                coverUrl = coverUrl.replaceAll('-home_default/', '-large_default/');
                coverUrl = coverUrl.replaceAll('-medium_default/', '-large_default/');
                return coverUrl;
              }
            }
          } catch (_) {}
        }

        // Fallback: og:image
        final ogImageMatch = RegExp(
          r'<meta\s+property="og:image"\s+content="([^"]+)"',
          caseSensitive: false,
        ).firstMatch(html);

        if (ogImageMatch != null) {
          var coverUrl = ogImageMatch.group(1)!;
          coverUrl = coverUrl.replaceAll('-home_default/', '-large_default/');
          coverUrl = coverUrl.replaceAll('-medium_default/', '-large_default/');
          return coverUrl;
        }
      }
    } catch (e) {
      debugPrint('Error fetching cover from $productUrl: $e');
    }
    return null;
  }

  Future<void> _addSelected({bool withCovers = true}) async {
    if (_selectedIndices.isEmpty) return;

    // Expandir colecciones a lista de resultados individuales
    final expandedResults = <_VolumeResult>[];
    for (final index in _selectedIndices) {
      final result = _results[index];
      if (result.isCollection && result.volumes != null) {
        // Es una colección, añadir todos sus volúmenes
        expandedResults.addAll(result.volumes!);
      } else {
        // Es un volumen individual
        expandedResults.add(result);
      }
    }

    setState(() {
      _isAdding = true;
      _addingProgress = 0;
      _addingTotal = expandedResults.length;
      _addingStatus = 'Preparando ${expandedResults.length} tomos...';
    });

    final books = <Book>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < expandedResults.length; i++) {
      final result = expandedResults[i];

      setState(() {
        _addingProgress = i + 1;
        _addingStatus = 'Procesando ${result.title}... (${i + 1}/${expandedResults.length})';
      });

      String? finalCoverUrl = result.coverUrl;

      // Si queremos portadas verificadas y tenemos URL de producto T&G
      if (withCovers && result.productUrl != null && result.source == 'T&G') {
        final verifiedCover = await _fetchVerifiedCover(result.productUrl!);
        if (verifiedCover != null) {
          finalCoverUrl = verifiedCover;
        }
      }

      books.add(Book(
        isbn: result.isbn ?? 'COL-$timestamp-${books.length}',
        title: result.title,
        author: result.author ?? 'Varios',
        coverUrl: withCovers ? finalCoverUrl : null,
        totalPages: result.pageCount ?? 0,
        seriesName: result.seriesName,
        volumeNumber: result.volumeNumber,
        publisher: result.publisher,
        apiSource: result.source == 'Tebeosfera' ? 'tebeosfera' : result.source == 'T&G' ? 'tomosygrapas' : 'googlebooks',
        sourceUrl: result.productUrl,
      ));
    }

    setState(() {
      _isAdding = false;
    });

    if (mounted) {
      Navigator.pop(context, books);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredResults = _filteredResults;
    final selectedInFiltered = filteredResults
        .where((r) => _selectedIndices.contains(_results.indexOf(r)))
        .length;

    return Scaffold(
      backgroundColor: ComicTheme.backgroundCream,
      appBar: AppBar(
        title: Text(
          'BUSCAR COLECCION',
          style: GoogleFonts.bangers(fontSize: 20, letterSpacing: 1),
        ),
        backgroundColor: ComicTheme.powerGreen,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Barra de búsqueda
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            style: GoogleFonts.comicNeue(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Nombre de colección o serie...',
                              hintStyle: GoogleFonts.comicNeue(
                                color: Colors.grey[400],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(Icons.search, color: ComicTheme.powerGreen),
                              filled: true,
                              fillColor: ComicTheme.backgroundCream,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: ComicTheme.powerGreen, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: _search,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSearching ? null : () => _search(_searchController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ComicTheme.powerGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                            ),
                          ),
                          child: const Icon(Icons.search),
                        ),
                      ],
                    ),
                    // Filtro de editorial
                    if (_availablePublishers.length > 1) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(null, 'Todas'),
                            ..._availablePublishers.map((p) => _buildFilterChip(p, p)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Info bar
              if (_results.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: ComicTheme.secondaryBlue.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Text(
                        '${filteredResults.length} encontrados',
                        style: GoogleFonts.comicNeue(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ComicTheme.comicBorder,
                        ),
                      ),
                      if (selectedInFiltered > 0) ...[
                        Text(
                          ' · $selectedInFiltered seleccionados',
                          style: GoogleFonts.comicNeue(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: ComicTheme.powerGreen,
                          ),
                        ),
                      ],
                      const Spacer(),
                      TextButton(
                        onPressed: _toggleAll,
                        style: TextButton.styleFrom(
                          foregroundColor: ComicTheme.secondaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          selectedInFiltered == filteredResults.length ? 'Ninguno' : 'Todos',
                          style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Resultados
              Expanded(
                child: _isSearching
                    ? _buildLoadingState()
                    : _results.isEmpty
                        ? _buildEmptyState()
                        : _buildResultsList(filteredResults),
              ),

              // Botones de añadir
              if (_selectedIndices.isNotEmpty) _buildAddButtons(),
            ],
          ),

          // Overlay de progreso
          if (_isAdding) _buildProgressOverlay(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String? value, String label) {
    final isSelected = _publisherFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label.length > 20 ? '${label.substring(0, 20)}...' : label,
          style: GoogleFonts.comicNeue(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : ComicTheme.comicBorder,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _publisherFilter = value),
        backgroundColor: Colors.white,
        selectedColor: ComicTheme.secondaryBlue,
        side: BorderSide(
          color: isSelected ? ComicTheme.secondaryBlue : Colors.grey[300]!,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: ComicTheme.powerGreen),
          const SizedBox(height: 16),
          Text(
            'Buscando en T&G y Google Books...',
            style: GoogleFonts.comicNeue(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _lastQuery == null ? Icons.library_books : Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _lastQuery == null
                  ? 'Busca una colección o serie'
                  : 'Sin resultados para "$_lastQuery"',
              style: GoogleFonts.comicNeue(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (_lastQuery == null) ...[
              const SizedBox(height: 12),
              Text(
                'Ejemplos:\n• Sandman\n• Fábulas\n• La Cosa del Pantano',
                style: GoogleFonts.comicNeue(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(List<_VolumeResult> results) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        final realIndex = _results.indexOf(result);
        return _buildResultCard(result, realIndex);
      },
    );
  }

  Widget _buildResultCard(_VolumeResult result, int index) {
    final isSelected = _selectedIndices.contains(index);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? ComicTheme.powerGreen : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected ? ComicTheme.powerGreen.withValues(alpha: 0.08) : Colors.white,
      elevation: 0,
      child: InkWell(
        onTap: () => _toggleItem(index),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 32,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleItem(index),
                  activeColor: ComicTheme.powerGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              // Portada más grande para ver bien
              Container(
                width: 50,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[400]!, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: result.coverUrl != null && result.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: result.coverUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.book, size: 24, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: GoogleFonts.comicNeue(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: ComicTheme.comicBorder,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        // Badge de colección (X volúmenes)
                        if (result.isCollection && result.volumeCount != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ComicTheme.powerGreen,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${result.volumeCount} TOMOS',
                              style: GoogleFonts.bangers(
                                fontSize: 11,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (result.volumeNumber != null && !result.isCollection) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: ComicTheme.secondaryBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Vol ${result.volumeNumber}',
                              style: GoogleFonts.comicNeue(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: ComicTheme.secondaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: result.source == 'Tebeosfera'
                                ? ComicTheme.powerGreen.withValues(alpha: 0.15)
                                : result.source == 'T&G'
                                    ? ComicTheme.primaryOrange.withValues(alpha: 0.15)
                                    : Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            result.source,
                            style: GoogleFonts.comicNeue(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: result.source == 'Tebeosfera'
                                  ? ComicTheme.powerGreen
                                  : result.source == 'T&G' ? ComicTheme.primaryOrange : Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (result.publisher != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        result.publisher!,
                        style: GoogleFonts.comicNeue(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón principal: con portadas verificadas
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _addSelected(withCovers: true),
                icon: const Icon(Icons.verified, size: 20),
                label: Text(
                  'AÑADIR ${_selectedIndices.length} CON PORTADAS',
                  style: GoogleFonts.bangers(fontSize: 15, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ComicTheme.powerGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Botón secundario: sin portadas (más rápido)
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () => _addSelected(withCovers: false),
                icon: const Icon(Icons.speed, size: 18),
                label: Text(
                  'RAPIDO SIN PORTADAS',
                  style: GoogleFonts.bangers(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[400]!, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ComicTheme.backgroundCream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ComicTheme.comicBorder, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: ComicTheme.powerGreen),
              const SizedBox(height: 20),
              Text(
                'Añadiendo $_addingProgress de $_addingTotal',
                style: GoogleFonts.bangers(
                  fontSize: 18,
                  color: ComicTheme.comicBorder,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _addingStatus,
                style: GoogleFonts.comicNeue(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _addingTotal > 0 ? _addingProgress / _addingTotal : 0,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation(ComicTheme.powerGreen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumeResult {
  final String title;
  final String? author;
  final String? seriesName;
  final int? volumeNumber;
  final String? coverUrl;
  final String? publisher;
  final String? productUrl;
  final String? isbn;
  final int? pageCount;
  final String source;

  // Para colecciones completas
  final bool isCollection;
  final List<_VolumeResult>? volumes;
  final int? volumeCount;

  _VolumeResult({
    required this.title,
    this.author,
    this.seriesName,
    this.volumeNumber,
    this.coverUrl,
    this.publisher,
    this.productUrl,
    this.isbn,
    this.pageCount,
    required this.source,
    this.isCollection = false,
    this.volumes,
    this.volumeCount,
  });
}
