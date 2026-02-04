import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book.dart';
import '../services/book_provider.dart';
import '../theme/comic_theme.dart';
import '../widgets/previous_volumes_dialog.dart';
import 'book_confirm_screen.dart';
import 'title_search_screen.dart';
import 'collection_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String? _lastScannedCode;
  late AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code == _lastScannedCode) return;

    if (code.length != 13 && code.length != 10) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    await _controller.stop();
    await _searchBook(code);
  }

  Future<void> _searchBook(String isbn) async {
    final provider = context.read<BookProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: ComicTheme.backgroundCream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ComicTheme.comicBorder, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: ComicTheme.primaryOrange,
                      strokeWidth: 4,
                    ),
                    Icon(
                      Icons.search,
                      color: ComicTheme.primaryOrange.withValues(alpha: 0.7),
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Buscando libro...',
                style: GoogleFonts.comicNeue(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ComicTheme.comicBorder,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ISBN: $isbn',
                style: GoogleFonts.comicNeue(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final book = await provider.searchBookByIsbn(isbn);

    if (!mounted) return;
    Navigator.pop(context);

    if (book != null) {
      final confirmedBook = await Navigator.push<Book>(
        context,
        MaterialPageRoute(
          builder: (context) => BookConfirmScreen(detectedBook: book),
        ),
      );

      if (confirmedBook != null && mounted) {
        await _addConfirmedBook(confirmedBook);
      } else {
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
        });
      }
    } else {
      _showNotFoundDialog(isbn);
    }
  }

  Future<void> _addConfirmedBook(Book book) async {
    final provider = context.read<BookProvider>();

    final status = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ComicTheme.backgroundCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
        ),
        title: Text(
          'DONDE LO AÑADO?',
          style: GoogleFonts.bangers(
            color: ComicTheme.comicBorder,
            fontSize: 22,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'reading'),
                icon: const Icon(Icons.auto_stories),
                label: Text(
                  'LEYENDO',
                  style: GoogleFonts.bangers(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ComicTheme.secondaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(
                        color: ComicTheme.comicBorder, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'finished'),
                icon: const Icon(Icons.done_all),
                label: Text(
                  'YA LEIDO',
                  style: GoogleFonts.bangers(fontSize: 18),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ComicTheme.powerGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(
                      color: ComicTheme.powerGreen, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (status == null) {
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
      return;
    }

    final bookToAdd = book.copyWith(
      status: status,
      currentPage: status == 'finished' ? book.totalPages : 0,
    );

    final success = await provider.addBook(bookToAdd);

    if (!mounted) return;

    if (success) {
      final volumeNumber = bookToAdd.volumeNumber;
      if (volumeNumber != null && volumeNumber > 1) {
        // Consultar qué volúmenes ya existen en la biblioteca
        final seriesName = bookToAdd.seriesName ?? bookToAdd.title;
        final existingVolumes = await provider.getExistingVolumeNumbers(seriesName);

        if (!mounted) return;

        final previousVolumes = await showPreviousVolumesDialog(
          context,
          book: bookToAdd,
          currentVolume: volumeNumber,
          existingVolumes: existingVolumes,
        );

        if (previousVolumes != null && previousVolumes.isNotEmpty && mounted) {
          final addedCount = await provider.addPreviousVolumesAsFinished(
            bookToAdd,
            previousVolumes,
          );

          if (mounted && addedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${bookToAdd.seriesName ?? bookToAdd.title} Vol. $volumeNumber + $addedCount anteriores!',
                  style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                ),
                backgroundColor: ComicTheme.powerGreen,
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${bookToAdd.title} añadido!',
                style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
              ),
              backgroundColor: ComicTheme.powerGreen,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${bookToAdd.title} añadido!',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.powerGreen,
          ),
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Este libro ya está en tu biblioteca',
            style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
          ),
          backgroundColor: ComicTheme.primaryOrange,
        ),
      );
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
    }
  }

  Future<void> _openTitleSearch() async {
    await _controller.stop();

    if (!mounted) return;

    final book = await Navigator.push<Book>(
      context,
      MaterialPageRoute(
        builder: (context) => const TitleSearchScreen(),
      ),
    );

    if (book != null && mounted) {
      // Abrir pantalla de confirmación con el libro encontrado
      final confirmedBook = await Navigator.push<Book>(
        context,
        MaterialPageRoute(
          builder: (context) => BookConfirmScreen(detectedBook: book),
        ),
      );

      if (confirmedBook != null && mounted) {
        await _addConfirmedBook(confirmedBook);
        return;
      }
    }

    // Si no se seleccionó nada, reactivar la cámara
    if (mounted) {
      await _controller.start();
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
    }
  }

  Future<void> _openCollections() async {
    await _controller.stop();

    if (!mounted) return;

    final books = await Navigator.push<List<Book>>(
      context,
      MaterialPageRoute(
        builder: (context) => const CollectionScreen(),
      ),
    );

    if (books != null && books.isNotEmpty && mounted) {
      await _addCollectionBooks(books);
    } else if (mounted) {
      await _controller.start();
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
    }
  }

  Future<void> _addCollectionBooks(List<Book> books) async {
    final provider = context.read<BookProvider>();

    // Preguntar estado para todos los libros
    final status = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ComicTheme.backgroundCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
        ),
        title: Text(
          'AÑADIR ${books.length} VOLUMENES',
          style: GoogleFonts.bangers(
            color: ComicTheme.comicBorder,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Como los quieres añadir?',
              style: GoogleFonts.comicNeue(
                fontWeight: FontWeight.bold,
                color: ComicTheme.comicBorder,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'reading'),
                icon: const Icon(Icons.auto_stories),
                label: Text(
                  'LEYENDO',
                  style: GoogleFonts.bangers(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ComicTheme.secondaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'finished'),
                icon: const Icon(Icons.done_all),
                label: Text(
                  'YA LEIDOS',
                  style: GoogleFonts.bangers(fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ComicTheme.powerGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: ComicTheme.powerGreen, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (status == null) {
      if (mounted) {
        await _controller.start();
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
        });
      }
      return;
    }

    // Mostrar progreso
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
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
                const CircularProgressIndicator(color: ComicTheme.primaryOrange),
                const SizedBox(height: 16),
                Text(
                  'Añadiendo ${books.length} volumenes...',
                  style: GoogleFonts.comicNeue(
                    fontWeight: FontWeight.bold,
                    color: ComicTheme.comicBorder,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    int addedCount = 0;
    for (final book in books) {
      final bookToAdd = book.copyWith(
        status: status,
        currentPage: status == 'finished' ? book.totalPages : 0,
      );
      final success = await provider.addBook(bookToAdd);
      if (success) addedCount++;
    }

    if (!mounted) return;
    Navigator.pop(context); // Cerrar diálogo de progreso

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$addedCount volumenes añadidos!',
          style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
        ),
        backgroundColor: ComicTheme.powerGreen,
        duration: const Duration(seconds: 3),
      ),
    );

    Navigator.pop(context); // Volver a home
  }

  void _showNotFoundDialog(String isbn) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ComicTheme.backgroundCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ComicTheme.heroRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.search_off,
                  color: ComicTheme.heroRed, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'NO ENCONTRADO',
                style: GoogleFonts.bangers(
                  color: ComicTheme.heroRed,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'No se encontró información para:\n$isbn\n\n¿Quieres añadirlo manualmente?',
          style: GoogleFonts.comicNeue(
            fontWeight: FontWeight.bold,
            color: ComicTheme.comicBorder,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isProcessing = false;
                _lastScannedCode = null;
              });
            },
            child: Text(
              'CANCELAR',
              style: GoogleFonts.bangers(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addManualBook(isbn);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.primaryOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'AÑADIR MANUAL',
              style: GoogleFonts.bangers(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addManualBook(String isbn) async {
    final emptyBook = Book(
      isbn: isbn,
      title: '',
      author: '',
      totalPages: 0,
    );

    final confirmedBook = await Navigator.push<Book>(
      context,
      MaterialPageRoute(
        builder: (context) => BookConfirmScreen(detectedBook: emptyBook),
      ),
    );

    if (confirmedBook != null && mounted) {
      await _addConfirmedBook(confirmedBook);
    } else {
      setState(() {
        _isProcessing = false;
        _lastScannedCode = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'AÑADIR LIBRO',
          style: GoogleFonts.bangers(
            letterSpacing: 2,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay oscuro con ventana de escaneo
          _buildScanOverlay(),
          // Marco de escaneo animado
          Center(
            child: _buildScanFrame(),
          ),
          // Instrucciones y botones inferiores
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Instrucción
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        color: ComicTheme.accentYellow,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Apunta al código de barras',
                        style: GoogleFonts.comicNeue(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Botones alternativos
                Row(
                  children: [
                    // Buscar por título
                    Expanded(
                      child: _buildBottomButton(
                        icon: Icons.search,
                        label: 'BUSCAR',
                        color: ComicTheme.secondaryBlue,
                        onPressed: _openTitleSearch,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Colecciones
                    Expanded(
                      child: _buildBottomButton(
                        icon: Icons.library_books,
                        label: 'COLECCIÓN',
                        color: ComicTheme.powerGreen,
                        onPressed: _openCollections,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.bangers(fontSize: 11, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    final screenWidth = MediaQuery.of(context).size.width;
    final scanWidth = screenWidth * 0.75; // 75% del ancho de pantalla
    final scanHeight = scanWidth * 0.57; // Ratio aspecto ~16:9

    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: 0.5),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              width: scanWidth,
              height: scanHeight,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanFrame() {
    final screenWidth = MediaQuery.of(context).size.width;
    final frameWidth = screenWidth * 0.78; // Ligeramente más grande que el overlay
    final frameHeight = frameWidth * 0.59;
    final scanLineTravel = frameHeight - 30; // Espacio para la línea de escaneo

    return SizedBox(
      width: frameWidth,
      height: frameHeight,
      child: Stack(
        children: [
          // Esquinas animadas
          ..._buildCorners(),
          // Línea de escaneo animada
          AnimatedBuilder(
            animation: _scanLineController,
            builder: (context, _) {
              return Positioned(
                top: 10 + _scanLineController.value * scanLineTravel,
                left: 10,
                right: 10,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        ComicTheme.accentYellow.withValues(alpha: 0.8),
                        ComicTheme.primaryOrange,
                        ComicTheme.accentYellow.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ComicTheme.accentYellow.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const cornerSize = 24.0;
    const cornerWidth = 3.0;
    const color = ComicTheme.accentYellow;

    return [
      // Top-left
      Positioned(
        top: 0,
        left: 0,
        child: _cornerWidget(
          border: const Border(
            top: BorderSide(color: color, width: cornerWidth),
            left: BorderSide(color: color, width: cornerWidth),
          ),
          radius: const BorderRadius.only(topLeft: Radius.circular(12)),
          size: cornerSize,
        ),
      ),
      // Top-right
      Positioned(
        top: 0,
        right: 0,
        child: _cornerWidget(
          border: const Border(
            top: BorderSide(color: color, width: cornerWidth),
            right: BorderSide(color: color, width: cornerWidth),
          ),
          radius: const BorderRadius.only(topRight: Radius.circular(12)),
          size: cornerSize,
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0,
        left: 0,
        child: _cornerWidget(
          border: const Border(
            bottom: BorderSide(color: color, width: cornerWidth),
            left: BorderSide(color: color, width: cornerWidth),
          ),
          radius: const BorderRadius.only(bottomLeft: Radius.circular(12)),
          size: cornerSize,
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 0,
        right: 0,
        child: _cornerWidget(
          border: const Border(
            bottom: BorderSide(color: color, width: cornerWidth),
            right: BorderSide(color: color, width: cornerWidth),
          ),
          radius: const BorderRadius.only(bottomRight: Radius.circular(12)),
          size: cornerSize,
        ),
      ),
    ];
  }

  Widget _cornerWidget({
    required Border border,
    required BorderRadius radius,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: border,
        borderRadius: radius,
      ),
    );
  }
}
