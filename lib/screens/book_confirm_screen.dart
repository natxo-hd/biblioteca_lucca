import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../models/book.dart';
import '../theme/comic_theme.dart';
import '../services/api/tomosygrapas_client.dart';
import '../utils/volume_extractor.dart';
import '../widgets/cover_search_dialog.dart';

class BookConfirmScreen extends StatefulWidget {
  final Book detectedBook;

  const BookConfirmScreen({
    super.key,
    required this.detectedBook,
  });

  @override
  State<BookConfirmScreen> createState() => _BookConfirmScreenState();
}

class _BookConfirmScreenState extends State<BookConfirmScreen> {
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _seriesController;
  late TextEditingController _volumeController;
  late TextEditingController _pagesController;
  String? _coverUrl;
  bool _searchingCover = false;

  @override
  void initState() {
    super.initState();
    debugPrint('=== BookConfirmScreen.initState ===');
    debugPrint('Libro recibido:');
    debugPrint('  título: ${widget.detectedBook.title}');
    debugPrint('  seriesName: ${widget.detectedBook.seriesName}');
    debugPrint('  volumeNumber: ${widget.detectedBook.volumeNumber}');

    _titleController = TextEditingController(text: widget.detectedBook.title);
    _authorController = TextEditingController(text: widget.detectedBook.author);

    // Auto-detectar serie y volumen del título si la API no los devolvió
    String? seriesName = widget.detectedBook.seriesName;
    int? volumeNumber = widget.detectedBook.volumeNumber;

    if (volumeNumber == null) {
      final volInfo = VolumeExtractor.extractFromTitle(widget.detectedBook.title);
      if (volInfo.volumeNumber != null) {
        volumeNumber = volInfo.volumeNumber;
        seriesName ??= volInfo.seriesName;
        debugPrint('  Auto-detectado del título: serie="${volInfo.seriesName}" vol=$volumeNumber');
      }
    }

    _seriesController = TextEditingController(
      text: seriesName ?? widget.detectedBook.title,
    );
    _volumeController = TextEditingController(
      text: volumeNumber?.toString() ?? '',
    );
    _pagesController = TextEditingController(
      text: widget.detectedBook.totalPages > 0
          ? widget.detectedBook.totalPages.toString()
          : '',
    );
    _coverUrl = widget.detectedBook.coverUrl;

    // Auto-buscar portada si no tiene
    if (_coverUrl == null || _coverUrl!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSearchCover();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _seriesController.dispose();
    _volumeController.dispose();
    _pagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ComicTheme.backgroundCream,
      appBar: AppBar(
        title: Text(
          'VERIFICAR LIBRO',
          style: GoogleFonts.bangers(fontSize: 22, letterSpacing: 2),
        ),
        backgroundColor: ComicTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Portada
            _buildCoverSection(),
            const SizedBox(height: 24),

            // Campos editables
            _buildTextField(
              controller: _titleController,
              label: 'TITULO',
              icon: Icons.book,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _authorController,
              label: 'AUTOR',
              icon: Icons.person,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _seriesController,
              label: 'SERIE',
              icon: Icons.collections_bookmark,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _volumeController,
                    label: 'VOLUMEN',
                    icon: Icons.format_list_numbered,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _pagesController,
                    label: 'PAGINAS',
                    icon: Icons.menu_book,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ISBN (solo lectura) - ocultar para entradas manuales
            if (!widget.detectedBook.isbn.startsWith('MANUAL-'))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Text(
                      'ISBN: ${widget.detectedBook.isbn}',
                      style: GoogleFonts.comicNeue(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[400]!, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'CANCELAR',
                      style: GoogleFonts.bangers(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _confirmBook,
                    icon: const Icon(Icons.check),
                    label: Text(
                      'AÑADIR',
                      style: GoogleFonts.bangers(fontSize: 18),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverSection() {
    return Column(
      children: [
        // Portada
        GestureDetector(
          onTap: _searchNewCover,
          onLongPress: _showPasteUrlDialog,
          child: Container(
            height: 200,
            width: 140,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ComicTheme.comicBorder, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: _searchingCover
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: ComicTheme.primaryOrange,
                      ),
                    )
                  : _coverUrl != null && _coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _coverUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => _buildNoCover(),
                        )
                      : _buildNoCover(),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Botones de portada
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Buscar automáticamente
            TextButton.icon(
              onPressed: _searchingCover ? null : _searchNewCover,
              icon: const Icon(Icons.image_search, size: 18),
              label: Text(
                'BUSCAR',
                style: GoogleFonts.bangers(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: ComicTheme.secondaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            Container(
              width: 1,
              height: 20,
              color: Colors.grey[300],
            ),
            // Pegar URL manualmente
            TextButton.icon(
              onPressed: _showPasteUrlDialog,
              icon: const Icon(Icons.link, size: 18),
              label: Text(
                'PEGAR URL',
                style: GoogleFonts.bangers(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: ComicTheme.primaryOrange,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),

        // Hint
        Text(
          'Mantén pulsada la portada para pegar URL',
          style: GoogleFonts.comicNeue(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  /// Muestra diálogo para pegar URL de portada manualmente
  void _showPasteUrlDialog() {
    final urlController = TextEditingController(text: _coverUrl ?? '');

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
            const Icon(Icons.link, color: ComicTheme.primaryOrange),
            const SizedBox(width: 8),
            Text(
              'URL DE PORTADA',
              style: GoogleFonts.bangers(
                color: ComicTheme.comicBorder,
                fontSize: 18,
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
            onPressed: () {
              final url = urlController.text.trim();
              Navigator.pop(ctx);
              if (url.isNotEmpty && _isValidImageUrl(url)) {
                setState(() {
                  _coverUrl = url;
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

    final lowerUrl = url.toLowerCase();
    // Verificar extensiones comunes de imagen
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'];
    for (final ext in imageExtensions) {
      if (lowerUrl.contains(ext)) return true;
    }

    // También aceptar URLs que contengan patrones comunes de imágenes
    final imagePatterns = ['image', 'img', 'cover', 'portada', 'foto', 'picture'];
    for (final pattern in imagePatterns) {
      if (lowerUrl.contains(pattern)) return true;
    }

    // Si no tiene extensión pero parece una URL válida, aceptarla
    // (muchas CDNs no usan extensiones)
    return true;
  }

  Widget _buildNoCover() {
    return Container(
      color: ComicTheme.accentYellow.withOpacity(0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_photo_alternate,
            size: 50,
            color: ComicTheme.primaryOrange,
          ),
          const SizedBox(height: 8),
          Text(
            'Toca para buscar',
            style: GoogleFonts.comicNeue(
              fontSize: 12,
              color: ComicTheme.comicBorder,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.bangers(
            fontSize: 14,
            color: ComicTheme.comicBorder,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.comicNeue(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: ComicTheme.secondaryBlue),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: ComicTheme.comicBorder,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: ComicTheme.comicBorder,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: ComicTheme.secondaryBlue,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Construye URL de portada de Casa del Libro a partir de ISBN
  String _buildCdlCoverUrl(String isbn) {
    final last2 = isbn.substring(isbn.length - 2);
    return 'https://imagessl0.casadellibro.com/a/l/s7/$last2/$isbn.webp';
  }

  /// Búsqueda automática en background (se lanza al abrir si no hay portada)
  /// Solo hace requests ligeros: HEAD a CDL, GET a Google Books, GET a T&G.
  Future<void> _autoSearchCover() async {
    if (!mounted) return;
    setState(() => _searchingCover = true);

    try {
      final title = _titleController.text.trim();
      final volume = _volumeController.text.trim();
      final isbn = widget.detectedBook.isbn;
      String? foundCover;

      final searches = <Future<String?>>[];

      // 1. CDL directo por ISBN (1 HEAD request, ~1s)
      if (isbn.isNotEmpty && isbn.startsWith('97884')) {
        searches.add(() async {
          try {
            final cdlUrl = _buildCdlCoverUrl(isbn);
            final resp = await http.head(Uri.parse(cdlUrl))
                .timeout(const Duration(seconds: 4));
            if (resp.statusCode == 200) return cdlUrl;
          } catch (_) {}
          return null;
        }());
      }

      // 2. Google Books → ISBN español → CDL (~3s)
      final gbQuery = volume.isNotEmpty ? '$title $volume' : title;
      searches.add(() async {
        try {
          final url = Uri.parse(
            'https://www.googleapis.com/books/v1/volumes'
            '?q=${Uri.encodeComponent(gbQuery)}&maxResults=5',
          );
          final resp = await http.get(url).timeout(const Duration(seconds: 6));
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body);
            final items = data['items'] as List? ?? [];
            for (final item in items) {
              final vi = item['volumeInfo'] as Map<String, dynamic>?;
              if (vi == null) continue;
              final ids = vi['industryIdentifiers'] as List? ?? [];
              for (final id in ids) {
                final bookIsbn = id['identifier'] as String?;
                if (bookIsbn != null && bookIsbn.startsWith('97884')) {
                  final cdlUrl = _buildCdlCoverUrl(bookIsbn);
                  final headResp = await http.head(Uri.parse(cdlUrl))
                      .timeout(const Duration(seconds: 3));
                  if (headResp.statusCode == 200) return cdlUrl;
                }
              }
            }
            // Fallback: thumbnail de Google Books
            for (final item in items) {
              final vi = item['volumeInfo'] as Map<String, dynamic>?;
              final img = vi?['imageLinks'] as Map<String, dynamic>?;
              var thumb = img?['thumbnail'] as String?;
              if (thumb != null) {
                return thumb.replaceAll('http://', 'https://').replaceAll('zoom=1', 'zoom=3');
              }
            }
          }
        } catch (_) {}
        return null;
      }());

      // 3. Tomos y Grapas (1 AJAX request, ~3s)
      final seriesName = _seriesController.text.trim().isNotEmpty
          ? _seriesController.text.trim()
          : title;
      final volNum = int.tryParse(volume);
      if (volNum != null) {
        searches.add(() async {
          try {
            final tomosYGrapas = TomosYGrapasClient();
            return await tomosYGrapas.searchCover(seriesName, volNum);
          } catch (_) {}
          return null;
        }());
      }

      // Esperar a todas en paralelo, usar la primera que encuentre
      final results = await Future.wait(searches);
      for (final result in results) {
        if (result != null && result.isNotEmpty) {
          foundCover = result;
          break;
        }
      }

      if (mounted) {
        setState(() {
          if (foundCover != null) _coverUrl = foundCover;
          _searchingCover = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searchingCover = false);
      }
    }
  }

  /// Búsqueda manual: abre el diálogo con múltiples resultados para elegir
  Future<void> _searchNewCover() async {
    final seriesName = _seriesController.text.trim().isNotEmpty
        ? _seriesController.text.trim()
        : _titleController.text.trim();
    final volNum = int.tryParse(_volumeController.text.trim());
    final searchQuery = volNum != null
        ? '$seriesName ${volNum.toString().padLeft(2, '0')}'
        : seriesName;

    final selectedCover = await showCoverSearchDialog(
      context,
      initialQuery: searchQuery,
      author: _authorController.text.trim(),
      volumeNumber: volNum,
      currentCoverUrl: _coverUrl,
      isbn: widget.detectedBook.isbn,
    );

    if (selectedCover != null && selectedCover.isNotEmpty && mounted) {
      setState(() => _coverUrl = selectedCover);
    }
  }

  void _confirmBook() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El título es obligatorio',
            style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
          ),
          backgroundColor: ComicTheme.heroRed,
        ),
      );
      return;
    }

    final volumeNumber = int.tryParse(_volumeController.text.trim());
    final totalPages = int.tryParse(_pagesController.text.trim()) ?? 0;

    // Usar la serie del campo de texto (pre-poblado con la detectada)
    final seriesName = _seriesController.text.trim().isNotEmpty
        ? _seriesController.text.trim()
        : title;

    final confirmedBook = widget.detectedBook.copyWith(
      title: title,
      author: _authorController.text.trim(),
      coverUrl: _coverUrl,
      totalPages: totalPages,
      volumeNumber: volumeNumber,
      seriesName: seriesName,
    );

    // DEBUG: Imprimir el libro confirmado
    print('╔════════════════════════════════════════╗');
    print('║ LIBRO CONFIRMADO                       ║');
    print('╠════════════════════════════════════════╣');
    print('║ Título: ${confirmedBook.title}');
    print('║ Serie: ${confirmedBook.seriesName}');
    print('║ Vol: ${confirmedBook.volumeNumber}');
    print('╚════════════════════════════════════════╝');

    Navigator.pop(context, confirmedBook);
  }
}
