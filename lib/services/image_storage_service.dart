import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Servicio para descargar y almacenar portadas localmente
/// Las imágenes se guardan de forma permanente en el dispositivo
class ImageStorageService {
  static final ImageStorageService _instance = ImageStorageService._internal();
  factory ImageStorageService() => _instance;
  ImageStorageService._internal();

  /// Directorio donde se guardan las portadas
  Future<Directory> get _coversDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory('${appDir.path}/covers');
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    return coversDir;
  }

  /// Genera un nombre de archivo único basado en el ISBN o URL
  String _generateFileName(String identifier) {
    final hash = md5.convert(utf8.encode(identifier)).toString();
    return 'cover_$hash.jpg';
  }

  /// Descarga y guarda una imagen localmente
  /// Devuelve la ruta local del archivo guardado, o null si falla
  Future<String?> downloadAndSave(String imageUrl, String bookIsbn) async {
    if (imageUrl.isEmpty) return null;

    try {
      debugPrint('📥 Descargando portada: $imageUrl');

      // Descargar la imagen
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Accept': 'image/*',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('❌ Error HTTP: ${response.statusCode}');
        return null;
      }

      // Verificar que es una imagen
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('image')) {
        debugPrint('❌ No es una imagen: $contentType');
        // Intentar de todas formas si tiene datos
        if (response.bodyBytes.isEmpty) return null;
      }

      // Guardar localmente
      final coversDir = await _coversDirectory;
      final fileName = _generateFileName(bookIsbn.isNotEmpty ? bookIsbn : imageUrl);
      final file = File('${coversDir.path}/$fileName');

      await file.writeAsBytes(response.bodyBytes);

      debugPrint('✅ Portada guardada: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('❌ Error descargando portada: $e');
      return null;
    }
  }

  /// Guarda bytes de imagen directamente (útil para imágenes ya descargadas)
  Future<String?> saveBytes(Uint8List bytes, String bookIsbn) async {
    if (bytes.isEmpty) return null;

    try {
      final coversDir = await _coversDirectory;
      final fileName = _generateFileName(bookIsbn);
      final file = File('${coversDir.path}/$fileName');

      await file.writeAsBytes(bytes);

      debugPrint('✅ Portada guardada desde bytes: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('❌ Error guardando bytes: $e');
      return null;
    }
  }

  /// Verifica si existe una portada local para un ISBN
  Future<String?> getLocalCover(String bookIsbn) async {
    if (bookIsbn.isEmpty) return null;

    try {
      final coversDir = await _coversDirectory;
      final fileName = _generateFileName(bookIsbn);
      final file = File('${coversDir.path}/$fileName');

      if (await file.exists()) {
        return file.path;
      }
    } catch (e) {
      debugPrint('Error buscando portada local: $e');
    }
    return null;
  }

  /// Elimina la portada local de un libro
  Future<void> deleteCover(String bookIsbn) async {
    if (bookIsbn.isEmpty) return;

    try {
      final coversDir = await _coversDirectory;
      final fileName = _generateFileName(bookIsbn);
      final file = File('${coversDir.path}/$fileName');

      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Portada eliminada: ${file.path}');
      }
    } catch (e) {
      debugPrint('Error eliminando portada: $e');
    }
  }

  /// Obtiene el tamaño total de las portadas guardadas
  Future<int> getTotalSize() async {
    try {
      final coversDir = await _coversDirectory;
      if (!await coversDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in coversDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Formatea el tamaño en MB/KB
  String formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes bytes';
  }

  /// Cuenta el número de portadas guardadas
  Future<int> getCoverCount() async {
    try {
      final coversDir = await _coversDirectory;
      if (!await coversDir.exists()) return 0;

      int count = 0;
      await for (final entity in coversDir.list()) {
        if (entity is File) count++;
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  /// Elimina todas las portadas (para liberar espacio)
  Future<void> clearAllCovers() async {
    try {
      final coversDir = await _coversDirectory;
      if (await coversDir.exists()) {
        await coversDir.delete(recursive: true);
        await coversDir.create();
        debugPrint('🗑️ Todas las portadas eliminadas');
      }
    } catch (e) {
      debugPrint('Error limpiando portadas: $e');
    }
  }
}
