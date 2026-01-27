import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/book.dart';
import 'database_service.dart';

/// Servicio para crear y restaurar backups completos de la biblioteca
/// Incluye la base de datos y todas las portadas en un archivo ZIP
class BackupService {
  final _db = DatabaseService();

  /// Metadatos del backup
  static const String _metadataFileName = 'metadata.json';
  static const String _booksFileName = 'books.json';
  static const String _deletedFileName = 'deleted_books.json';
  static const String _coversFolderName = 'covers';

  /// Crea un backup completo de la biblioteca
  /// Devuelve la ruta del archivo ZIP creado
  Future<String> createBackup({
    void Function(String status, double progress)? onProgress,
  }) async {
    onProgress?.call('Preparando backup...', 0.0);

    // 1. Obtener todos los libros
    final books = await _db.getAllBooks();
    final deletedIsbns = await _db.getDeletedIsbns();

    onProgress?.call('Exportando datos...', 0.1);

    // 2. Crear archivo ZIP en memoria
    final archive = Archive();

    // 3. Añadir metadatos
    final metadata = {
      'version': 1,
      'appVersion': '1.0.0',
      'createdAt': DateTime.now().toIso8601String(),
      'bookCount': books.length,
      'deletedCount': deletedIsbns.length,
      'platform': Platform.operatingSystem,
    };
    archive.addFile(ArchiveFile(
      _metadataFileName,
      utf8.encode(jsonEncode(metadata)).length,
      utf8.encode(jsonEncode(metadata)),
    ));

    onProgress?.call('Exportando libros...', 0.2);

    // 4. Añadir libros en JSON
    final booksJson = books.map((b) => b.toMap()).toList();
    final booksData = utf8.encode(const JsonEncoder.withIndent('  ').convert(booksJson));
    archive.addFile(ArchiveFile(_booksFileName, booksData.length, booksData));

    // 5. Añadir ISBNs eliminados
    final deletedData = utf8.encode(jsonEncode(deletedIsbns));
    archive.addFile(ArchiveFile(_deletedFileName, deletedData.length, deletedData));

    onProgress?.call('Recopilando portadas...', 0.3);

    // 6. Añadir portadas
    final coversDir = await _getCoversDirectory();
    if (await coversDir.exists()) {
      final coverFiles = await coversDir.list().toList();
      final totalCovers = coverFiles.length;
      int processed = 0;

      for (final entity in coverFiles) {
        if (entity is File) {
          try {
            final bytes = await entity.readAsBytes();
            final fileName = entity.path.split('/').last;
            archive.addFile(ArchiveFile(
              '$_coversFolderName/$fileName',
              bytes.length,
              bytes,
            ));
          } catch (e) {
            debugPrint('Error añadiendo portada: $e');
          }
        }
        processed++;
        final progress = 0.3 + (0.5 * processed / totalCovers);
        onProgress?.call('Portadas: $processed/$totalCovers', progress);
      }
    }

    onProgress?.call('Comprimiendo...', 0.85);

    // 7. Comprimir el archivo
    final zipData = ZipEncoder().encode(archive);

    onProgress?.call('Guardando archivo...', 0.95);

    // 8. Guardar el archivo ZIP en el directorio de caché (accesible para compartir)
    final timestamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final fileName = 'biblioteca_lucca_backup_$timestamp.zip';

    // Usar directorio de caché que es accesible para compartir
    final cacheDir = await getTemporaryDirectory();
    final backupDir = Directory('${cacheDir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final filePath = '${backupDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(zipData);

    onProgress?.call('¡Completado!', 1.0);

    debugPrint('✅ Backup creado: $filePath (${_formatBytes(zipData.length)})');
    return filePath;
  }

  /// Comparte el backup usando el sistema de compartir nativo
  Future<bool> shareBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ Archivo no existe: $filePath');
        return false;
      }

      final xFile = XFile(filePath, mimeType: 'application/zip');
      final result = await Share.shareXFiles(
        [xFile],
        subject: 'Backup Biblioteca de Lucca',
      );

      debugPrint('📤 Share result: ${result.status}');
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('❌ Error compartiendo backup: $e');
      return false;
    }
  }

  /// Restaura un backup desde un archivo ZIP
  /// Devuelve un resumen de lo restaurado
  Future<BackupRestoreResult> restoreBackup({
    void Function(String status, double progress)? onProgress,
  }) async {
    onProgress?.call('Seleccionando archivo...', 0.0);

    // 1. Seleccionar archivo ZIP
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      throw BackupCancelledException();
    }

    final filePath = result.files.first.path;
    if (filePath == null) {
      throw Exception('No se pudo acceder al archivo');
    }

    onProgress?.call('Leyendo archivo...', 0.1);

    // 2. Leer y descomprimir el ZIP
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    onProgress?.call('Verificando backup...', 0.2);

    // 3. Verificar que es un backup válido
    final metadataFile = archive.findFile(_metadataFileName);
    if (metadataFile == null) {
      throw Exception('Archivo de backup inválido: falta metadata');
    }

    final metadata = jsonDecode(utf8.decode(metadataFile.content as List<int>));
    debugPrint('📦 Backup version: ${metadata['version']}, creado: ${metadata['createdAt']}');

    // 4. Leer libros
    final booksFile = archive.findFile(_booksFileName);
    if (booksFile == null) {
      throw Exception('Archivo de backup inválido: faltan libros');
    }

    onProgress?.call('Restaurando libros...', 0.3);

    final booksJson = jsonDecode(utf8.decode(booksFile.content as List<int>)) as List;
    final books = booksJson.map((json) => Book.fromMap(json as Map<String, dynamic>)).toList();

    // 5. Restaurar libros en la base de datos
    int booksRestored = 0;
    int booksSkipped = 0;

    for (int i = 0; i < books.length; i++) {
      final book = books[i];
      try {
        // Verificar si ya existe
        final existing = await _db.getBookByIsbn(book.isbn);
        if (existing == null) {
          await _db.insertBook(book);
          booksRestored++;
        } else {
          booksSkipped++;
        }
      } catch (e) {
        debugPrint('Error restaurando libro ${book.isbn}: $e');
        booksSkipped++;
      }

      final progress = 0.3 + (0.3 * i / books.length);
      onProgress?.call('Libros: ${i + 1}/${books.length}', progress);
    }

    // 6. Restaurar ISBNs eliminados
    final deletedFile = archive.findFile(_deletedFileName);
    if (deletedFile != null) {
      try {
        final deletedIsbns = (jsonDecode(utf8.decode(deletedFile.content as List<int>)) as List)
            .cast<String>();
        for (final isbn in deletedIsbns) {
          await _db.markAsDeleted(isbn);
        }
      } catch (e) {
        debugPrint('Error restaurando ISBNs eliminados: $e');
      }
    }

    onProgress?.call('Restaurando portadas...', 0.65);

    // 7. Restaurar portadas
    final coversDir = await _getCoversDirectory();
    int coversRestored = 0;

    final coverFiles = archive.files.where((f) => f.name.startsWith('$_coversFolderName/')).toList();
    for (int i = 0; i < coverFiles.length; i++) {
      final coverFile = coverFiles[i];
      try {
        final fileName = coverFile.name.split('/').last;
        if (fileName.isEmpty) continue;

        final targetFile = File('${coversDir.path}/$fileName');

        // Solo restaurar si no existe
        if (!await targetFile.exists()) {
          await targetFile.writeAsBytes(coverFile.content as List<int>);
          coversRestored++;
        }
      } catch (e) {
        debugPrint('Error restaurando portada: $e');
      }

      final progress = 0.65 + (0.3 * i / coverFiles.length);
      onProgress?.call('Portadas: ${i + 1}/${coverFiles.length}', progress);
    }

    onProgress?.call('¡Completado!', 1.0);

    return BackupRestoreResult(
      booksRestored: booksRestored,
      booksSkipped: booksSkipped,
      coversRestored: coversRestored,
      backupDate: DateTime.tryParse(metadata['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  /// Obtiene información del último backup (si existe)
  Future<BackupInfo?> getLastBackupInfo() async {
    try {
      // Buscar en Downloads
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final files = await downloadsDir
            .list()
            .where((f) => f.path.contains('biblioteca_lucca_backup') && f.path.endsWith('.zip'))
            .toList();

        if (files.isNotEmpty) {
          files.sort((a, b) => b.path.compareTo(a.path));
          final latestFile = files.first as File;
          final stat = await latestFile.stat();
          return BackupInfo(
            path: latestFile.path,
            size: stat.size,
            date: stat.modified,
          );
        }
      }
    } catch (e) {
      debugPrint('Error buscando último backup: $e');
    }
    return null;
  }

  /// Obtiene el directorio de portadas
  Future<Directory> _getCoversDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory('${appDir.path}/covers');
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    return coversDir;
  }

  /// Formatea bytes a formato legible
  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes bytes';
  }
}

/// Resultado de una restauración
class BackupRestoreResult {
  final int booksRestored;
  final int booksSkipped;
  final int coversRestored;
  final DateTime backupDate;

  BackupRestoreResult({
    required this.booksRestored,
    required this.booksSkipped,
    required this.coversRestored,
    required this.backupDate,
  });

  int get totalBooks => booksRestored + booksSkipped;
}

/// Información de un backup existente
class BackupInfo {
  final String path;
  final int size;
  final DateTime date;

  BackupInfo({
    required this.path,
    required this.size,
    required this.date,
  });

  String get formattedSize {
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '$size bytes';
  }

  String get formattedDate => DateFormat('dd/MM/yyyy HH:mm').format(date);
}

/// Excepción cuando el usuario cancela la selección
class BackupCancelledException implements Exception {
  @override
  String toString() => 'Selección cancelada';
}
