import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models/book.dart';

class ExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _fileNameFormat = DateFormat('yyyy-MM-dd_HHmm');

  /// Obtiene la carpeta de descargas
  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Solicitar permiso de almacenamiento en Android
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        final manageStatus = await Permission.manageExternalStorage.request();
        if (!manageStatus.isGranted) {
          throw Exception('Permiso de almacenamiento denegado');
        }
      }

      // Carpeta de descargas en Android
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        return downloadsDir;
      }
    }

    // Fallback: directorio de documentos de la app
    return await getApplicationDocumentsDirectory();
  }

  /// Exporta los libros a un archivo CSV
  Future<String> exportToCSV(List<Book> books) async {
    final dir = await _getDownloadsDirectory();
    final fileName = 'biblioteca_lucca_${_fileNameFormat.format(DateTime.now())}.csv';
    final filePath = '${dir.path}/$fileName';

    // Crear filas de datos
    final List<List<dynamic>> rows = [
      // Cabecera
      [
        'Título',
        'Autor',
        'ISBN',
        'Estado',
        'Serie',
        'Volumen',
        'Página Actual',
        'Total Páginas',
        'Progreso %',
        'Fecha Añadido',
        'Archivado',
      ],
      // Datos
      ...books.map((book) => [
        book.title,
        book.author,
        book.isbn,
        _getStatusName(book.status),
        book.seriesName ?? '',
        book.volumeNumber?.toString() ?? '',
        book.currentPage,
        book.totalPages,
        book.totalPages > 0
            ? '${(book.progress * 100).toStringAsFixed(1)}%'
            : '',
        _dateFormat.format(book.addedDate),
        book.isArchived ? 'Sí' : 'No',
      ]),
    ];

    // Convertir a CSV
    final csvData = const ListToCsvConverter().convert(rows);

    // Escribir archivo
    final file = File(filePath);
    await file.writeAsString(csvData);

    return filePath;
  }

  /// Exporta los libros a un archivo PDF
  Future<String> exportToPDF(List<Book> books, {String userName = 'Lucca'}) async {
    final dir = await _getDownloadsDirectory();
    final fileName = 'biblioteca_lucca_${_fileNameFormat.format(DateTime.now())}.pdf';
    final filePath = '${dir.path}/$fileName';

    final pdf = pw.Document();

    // Separar libros por estado
    final reading = books.where((b) => b.status == 'reading' && !b.isArchived).toList();
    final finished = books.where((b) => b.status == 'finished' && !b.isArchived).toList();
    final wishlist = books.where((b) => b.status == 'wishlist' && !b.isArchived).toList();
    final archived = books.where((b) => b.isArchived).toList();

    // Estadísticas
    final totalBooks = books.length;
    final totalPagesRead = books.fold<int>(0, (sum, b) => sum + b.currentPage);
    final totalPages = books.fold<int>(0, (sum, b) => sum + b.totalPages);
    final finishedCount = finished.length;

    // Colores del tema
    final primaryColor = PdfColor.fromHex('#FF6B35');
    final secondaryColor = PdfColor.fromHex('#4ECDC4');
    final accentColor = PdfColor.fromHex('#FFE66D');

    // Página de portada
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              begin: pw.Alignment.topLeft,
              end: pw.Alignment.bottomRight,
              colors: [primaryColor, secondaryColor],
            ),
          ),
          child: pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(20),
                    border: pw.Border.all(color: PdfColors.black, width: 4),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'BIBLIOTECA DE',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        userName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 48,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: pw.BoxDecoration(
                          color: accentColor,
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: pw.Text(
                          '$totalBooks LIBROS',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 40),
                pw.Text(
                  'Exportado el ${_dateFormat.format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Página de estadísticas
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('ESTADÍSTICAS', primaryColor),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('LIBROS', totalBooks.toString(), secondaryColor),
                _buildStatCard('LEYENDO', reading.length.toString(), primaryColor),
                _buildStatCard('TERMINADOS', finishedCount.toString(), PdfColors.green),
                _buildStatCard('SOLICITADOS', wishlist.length.toString(), PdfColors.blue),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PÁGINAS LEÍDAS',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        flex: totalPagesRead,
                        child: pw.Container(
                          height: 20,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.green,
                            borderRadius: const pw.BorderRadius.horizontal(
                              left: pw.Radius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (totalPages - totalPagesRead > 0)
                        pw.Expanded(
                          flex: totalPages - totalPagesRead,
                          child: pw.Container(
                            height: 20,
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey300,
                              borderRadius: const pw.BorderRadius.horizontal(
                                right: pw.Radius.circular(10),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '$totalPagesRead de $totalPages páginas',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            if (archived.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                '${archived.length} libros archivados',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // Páginas de libros por categoría
    if (reading.isNotEmpty) {
      _addBookListPages(pdf, 'LEYENDO AHORA', reading, primaryColor);
    }
    if (finished.isNotEmpty) {
      _addBookListPages(pdf, 'TERMINADOS', finished, PdfColors.green);
    }
    if (wishlist.isNotEmpty) {
      _addBookListPages(pdf, 'SOLICITADOS', wishlist, PdfColors.blue);
    }
    if (archived.isNotEmpty) {
      _addBookListPages(pdf, 'ARCHIVADOS', archived, PdfColors.grey);
    }

    // Guardar archivo
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  pw.Widget _buildSectionHeader(String title, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 20,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: color.shade(0.9),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: color, width: 2),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 32,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  void _addBookListPages(pw.Document pdf, String title, List<Book> books, PdfColor color) {
    const booksPerPage = 12;
    final pages = (books.length / booksPerPage).ceil();

    for (int page = 0; page < pages; page++) {
      final startIndex = page * booksPerPage;
      final endIndex = (startIndex + booksPerPage).clamp(0, books.length);
      final pageBooks = books.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                pages > 1 ? '$title (${page + 1}/$pages)' : title,
                color,
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: color.shade(0.9)),
                    children: [
                      _buildTableCell('Título', isHeader: true),
                      _buildTableCell('Autor', isHeader: true),
                      _buildTableCell('Vol.', isHeader: true),
                      _buildTableCell('Progreso', isHeader: true),
                    ],
                  ),
                  // Rows
                  ...pageBooks.map((book) => pw.TableRow(
                    children: [
                      _buildTableCell(book.title),
                      _buildTableCell(book.author),
                      _buildTableCell(book.volumeNumber?.toString() ?? '-'),
                      _buildTableCell(
                        book.totalPages > 0
                            ? '${(book.progress * 100).toInt()}%'
                            : '-',
                      ),
                    ],
                  )),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  String _getStatusName(String status) {
    switch (status) {
      case 'reading':
        return 'Leyendo';
      case 'finished':
        return 'Terminado';
      case 'wishlist':
        return 'Solicitado';
      default:
        return status;
    }
  }

  /// Convierte nombre de estado a código
  String _getStatusCode(String statusName) {
    switch (statusName.toLowerCase()) {
      case 'leyendo':
        return 'reading';
      case 'terminado':
        return 'finished';
      case 'solicitado':
        return 'wishlist';
      default:
        return 'reading';
    }
  }

  /// Importa libros desde un archivo CSV
  /// Devuelve la lista de libros importados
  Future<List<Book>?> importFromCSV() async {
    try {
      // Seleccionar archivo
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) {
        return null; // Usuario canceló
      }

      final file = File(result.files.single.path!);
      final csvString = await file.readAsString();

      // Parsear CSV
      final rows = const CsvToListConverter().convert(csvString);

      if (rows.length < 2) {
        throw Exception('El archivo CSV está vacío o no tiene datos');
      }

      // Saltar cabecera (primera fila)
      final dataRows = rows.skip(1);
      final books = <Book>[];

      for (final row in dataRows) {
        if (row.length < 4) continue; // Saltar filas incompletas

        // Parsear cada columna según el formato de exportación
        final title = row[0]?.toString() ?? '';
        final author = row[1]?.toString() ?? '';
        final isbn = row[2]?.toString() ?? '';
        final statusName = row[3]?.toString() ?? 'Leyendo';
        final seriesName = row.length > 4 ? row[4]?.toString() : null;
        final volumeStr = row.length > 5 ? row[5]?.toString() : null;
        final currentPageStr = row.length > 6 ? row[6]?.toString() : null;
        final totalPagesStr = row.length > 7 ? row[7]?.toString() : null;
        // Columna 8 es progreso (calculado, no se importa)
        final dateStr = row.length > 9 ? row[9]?.toString() : null;
        final archivedStr = row.length > 10 ? row[10]?.toString() : null;

        if (title.isEmpty || isbn.isEmpty) continue;

        final book = Book(
          isbn: isbn,
          title: title,
          author: author,
          status: _getStatusCode(statusName),
          seriesName: seriesName?.isNotEmpty == true ? seriesName : null,
          volumeNumber: volumeStr != null && volumeStr.isNotEmpty
              ? int.tryParse(volumeStr)
              : null,
          currentPage: int.tryParse(currentPageStr ?? '') ?? 0,
          totalPages: int.tryParse(totalPagesStr ?? '') ?? 0,
          addedDate: dateStr != null && dateStr.isNotEmpty
              ? (DateTime.tryParse(dateStr) ?? DateTime.now())
              : DateTime.now(),
          isArchived: archivedStr?.toLowerCase() == 'sí',
        );

        books.add(book);
      }

      return books;
    } catch (e) {
      throw Exception('Error al importar CSV: $e');
    }
  }
}
