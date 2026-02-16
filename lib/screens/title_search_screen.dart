import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../theme/comic_theme.dart';
import '../widgets/skeleton_search_result.dart';

/// Pantalla de búsqueda por título para añadir libros sin código de barras
class TitleSearchScreen extends StatefulWidget {
  const TitleSearchScreen({super.key});

  @override
  State<TitleSearchScreen> createState() => _TitleSearchScreenState();
}

class _TitleSearchScreenState extends State<TitleSearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<_SearchResult> _results = [];
  bool _isSearching = false;
  String? _lastQuery;
  List<String> _searchHistory = [];
  static const _historyKey = 'search_history';
  static const _maxHistoryItems = 10;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    // Autofocus en el campo de búsqueda
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList(_historyKey) ?? [];
    });
  }

  Future<void> _saveToHistory(String query) async {
    if (query.trim().isEmpty) return;
    final trimmed = query.trim();

    // Quitar si ya existe y añadir al principio
    _searchHistory.remove(trimmed);
    _searchHistory.insert(0, trimmed);

    // Limitar a N elementos
    if (_searchHistory.length > _maxHistoryItems) {
      _searchHistory = _searchHistory.sublist(0, _maxHistoryItems);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, _searchHistory);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    setState(() {
      _searchHistory = [];
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty || query.trim() == _lastQuery) return;
    _lastQuery = query.trim();

    // Guardar en historial
    _saveToHistory(query.trim());

    setState(() {
      _isSearching = true;
      _results = [];
    });

    final results = <_SearchResult>[];

    // Buscar en paralelo en T&G y Google Books
    await Future.wait([
      _searchTomosYGrapas(query.trim(), results),
      _searchGoogleBooks(query.trim(), results),
    ]);

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _searchTomosYGrapas(String query, List<_SearchResult> results) async {
    try {
      final ajaxUrl = Uri.parse(
        'https://tienda.tomosygrapas.com/es/module/leoproductsearch/productsearch?ajax=1&q=${Uri.encodeComponent(query)}',
      );

      final response = await http.get(
        ajaxUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final products = data['products'] as List<dynamic>?;

        if (products != null) {
          for (final product in products) {
            if (results.length >= 20) break;
            final productMap = product as Map<String, dynamic>;
            final name = productMap['name'] as String?;
            final productUrl = productMap['url'] as String? ?? productMap['link'] as String?;
            final publisher = productMap['manufacturer_name'] as String?;

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

            if (name != null && name.isNotEmpty) {
              results.add(_SearchResult(
                title: name,
                author: '',
                coverUrl: coverUrl,
                publisher: publisher,
                source: 'Tomos y Grapas',
                productUrl: productUrl,
                totalPages: 0,
              ));
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _searchGoogleBooks(String query, List<_SearchResult> results) async {
    try {
      final url = Uri.parse(
        'https://www.googleapis.com/books/v1/volumes?q=${Uri.encodeComponent(query)}&maxResults=10&langRestrict=es',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;

        if (items != null) {
          for (final item in items) {
            if (results.length >= 20) break;
            final volumeInfo = (item as Map<String, dynamic>)['volumeInfo'] as Map<String, dynamic>?;
            if (volumeInfo == null) continue;

            final title = volumeInfo['title'] as String?;
            final authors = volumeInfo['authors'] as List<dynamic>?;
            final author = authors?.isNotEmpty == true ? authors!.first as String : '';
            final publisher = volumeInfo['publisher'] as String?;
            final pageCount = volumeInfo['pageCount'] as int?;
            final isbn13 = _extractIsbn13(volumeInfo);

            String? coverUrl;
            final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
            if (imageLinks != null) {
              coverUrl = imageLinks['thumbnail'] as String?;
              if (coverUrl != null) {
                coverUrl = coverUrl.replaceAll('zoom=1', 'zoom=2');
              }
            }

            if (title != null && title.isNotEmpty) {
              results.add(_SearchResult(
                title: title,
                author: author,
                coverUrl: coverUrl,
                publisher: publisher,
                source: 'Google Books',
                isbn: isbn13,
                totalPages: pageCount ?? 0,
              ));
            }
          }
        }
      }
    } catch (_) {}
  }

  String? _extractIsbn13(Map<String, dynamic> volumeInfo) {
    final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>?;
    if (identifiers == null) return null;
    for (final id in identifiers) {
      final idMap = id as Map<String, dynamic>;
      if (idMap['type'] == 'ISBN_13') return idMap['identifier'] as String?;
    }
    for (final id in identifiers) {
      final idMap = id as Map<String, dynamic>;
      if (idMap['type'] == 'ISBN_10') return idMap['identifier'] as String?;
    }
    return null;
  }

  void _selectResult(_SearchResult result) {
    // Extraer volumen del título
    final volInfo = _extractVolumeFromTitle(result.title);

    final book = Book(
      isbn: result.isbn ?? 'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
      title: result.title,
      author: result.author,
      coverUrl: result.coverUrl,
      totalPages: result.totalPages,
      seriesName: volInfo['seriesName'] as String?,
      volumeNumber: volInfo['volumeNumber'] as int?,
      publisher: result.publisher,
      apiSource: result.source == 'Tomos y Grapas' ? 'tomosygrapas' : 'googlebooks',
      sourceUrl: result.productUrl,
    );

    Navigator.pop(context, book);
  }

  void _createManual() {
    final book = Book(
      isbn: 'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
      title: _lastQuery ?? '',
      author: '',
      totalPages: 0,
    );

    Navigator.pop(context, book);
  }

  Widget _buildEmptyOrHistoryState() {
    // Si no hay búsqueda previa, mostrar historial o mensaje inicial
    if (_lastQuery == null) {
      return _searchHistory.isEmpty
          ? _buildInitialState()
          : _buildHistoryList();
    }

    // Si hay búsqueda sin resultados
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Sin resultados para "$_lastQuery"',
            style: GoogleFonts.comicNeue(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createManual,
            icon: const Icon(Icons.edit_note),
            label: Text(
              'CREAR MANUALMENTE',
              style: GoogleFonts.bangers(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Busca por nombre de serie o titulo',
            style: GoogleFonts.comicNeue(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(Icons.history, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'BUSQUEDAS RECIENTES',
                style: GoogleFonts.bangers(
                  fontSize: 14,
                  color: Colors.grey[600],
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearHistory,
                child: Text(
                  'BORRAR',
                  style: GoogleFonts.comicNeue(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[400],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Lista de historial
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _searchHistory.length,
            itemBuilder: (context, index) {
              final query = _searchHistory[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                child: ListTile(
                  leading: const Icon(Icons.history, color: Colors.grey),
                  title: Text(
                    query,
                    style: GoogleFonts.comicNeue(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(Icons.north_west, size: 18, color: Colors.grey),
                  onTap: () {
                    _searchController.text = query;
                    _search(query);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _extractVolumeFromTitle(String title) {
    String? seriesName;
    int? volumeNumber;

    final patterns = [
      RegExp(r'^(.+?)\s+(\d{1,3})\s*\((?:DE|de)\s*\d+\)', caseSensitive: false),
      RegExp(r'^(.+?)\s+(\d{1,3})[\s:]+[A-Z]', caseSensitive: false),
      RegExp(r'^(.+?)\s+(\d{1,3})\s*[-–—]', caseSensitive: false),
      RegExp(r'^(.+?)\s+(\d{1,3})\s*$'),
      RegExp(r'^(.+?)\s*[Nn][ºo°]\s*(\d+)', caseSensitive: false),
      RegExp(r'^(.+?)\s*[Vv]ol\.?\s*(\d+)'),
      RegExp(r'^(.+?)\s*#\s*(\d+)'),
      RegExp(r'^(.+?)\s*[Tt](?:omo)?\.?\s*(\d+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(title);
      if (match != null) {
        seriesName = match.group(1)?.trim();
        volumeNumber = int.tryParse(match.group(2) ?? '');
        if (volumeNumber != null) break;
      }
    }

    return {
      'seriesName': seriesName,
      'volumeNumber': volumeNumber,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ComicTheme.backgroundCream,
      appBar: AppBar(
        title: Text(
          'BUSCAR POR TITULO',
          style: GoogleFonts.bangers(fontSize: 22, letterSpacing: 2),
        ),
        backgroundColor: ComicTheme.secondaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    style: GoogleFonts.comicNeue(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ej: Sandman, V de Vendetta...',
                      hintStyle: GoogleFonts.comicNeue(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.bold,
                      ),
                      prefixIcon: const Icon(Icons.search, color: ComicTheme.secondaryBlue),
                      filled: true,
                      fillColor: ComicTheme.backgroundCream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: ComicTheme.secondaryBlue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSearching ? null : () => _search(_searchController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ComicTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                    ),
                  ),
                  child: Text(
                    'BUSCAR',
                    style: GoogleFonts.bangers(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),

          // Resultados
          Expanded(
            child: _isSearching
                ? const SearchingIndicator(message: 'Buscando en tiendas...')
                : _results.isEmpty
                    ? _buildEmptyOrHistoryState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _results.length,
                        itemBuilder: (context, index) => _buildResultCard(_results[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(_SearchResult result) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
      ),
      child: InkWell(
        onTap: () => _selectResult(result),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Portada
              Container(
                width: 55,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ComicTheme.comicBorder, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: result.coverUrl != null && result.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: result.coverUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.book,
                            color: Colors.grey,
                            size: 24,
                          ),
                        )
                      : const Icon(Icons.book, color: Colors.grey, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: GoogleFonts.comicNeue(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: ComicTheme.comicBorder,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.author.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        result.author,
                        style: GoogleFonts.comicNeue(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (result.publisher != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        result.publisher!,
                        style: GoogleFonts.comicNeue(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Fuente badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: result.source == 'Tomos y Grapas'
                      ? ComicTheme.primaryOrange.withValues(alpha: 0.15)
                      : ComicTheme.secondaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  result.source == 'Tomos y Grapas' ? 'T&G' : 'GB',
                  style: GoogleFonts.comicNeue(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: result.source == 'Tomos y Grapas'
                        ? ComicTheme.primaryOrange
                        : ComicTheme.secondaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResult {
  final String title;
  final String author;
  final String? coverUrl;
  final String? publisher;
  final String source;
  final String? productUrl;
  final String? isbn;
  final int totalPages;

  _SearchResult({
    required this.title,
    required this.author,
    this.coverUrl,
    this.publisher,
    required this.source,
    this.productUrl,
    this.isbn,
    required this.totalPages,
  });
}
