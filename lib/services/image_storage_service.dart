import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:image/image.dart' as img;

/// Servicio para descargar y almacenar portadas localmente
/// Las imágenes se guardan de forma permanente en el dispositivo
/// con compresión automática para ahorrar espacio
class ImageStorageService {
  static final ImageStorageService _instance = ImageStorageService._internal();
  factory ImageStorageService() => _instance;
  ImageStorageService._internal();

  /// Configuración de compresión
  static const int maxWidth = 400; // Ancho máximo en pixels
  static const int maxHeight = 600; // Alto máximo en pixels
  static const int jpegQuality = 85; // Calidad JPEG (0-100)

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

  /// Comprime una imagen a un tamaño y calidad óptimos
  /// Se ejecuta en un isolate para no bloquear el UI
  Future<Uint8List?> _compressImage(Uint8List bytes) async {
    try {
      return await compute(_compressInIsolate, bytes);
    } catch (e) {
      debugPrint('❌ Error comprimiendo imagen: $e');
      return null;
    }
  }

  /// Función que se ejecuta en isolate separado para compresión
  static Uint8List? _compressInIsolate(Uint8List bytes) {
    try {
      // Decodificar imagen
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Calcular nuevo tamaño manteniendo proporción
      int newWidth = image.width;
      int newHeight = image.height;

      if (image.width > maxWidth || image.height > maxHeight) {
        final aspectRatio = image.width / image.height;

        if (aspectRatio > maxWidth / maxHeight) {
          // Limitar por ancho
          newWidth = maxWidth;
          newHeight = (maxWidth / aspectRatio).round();
        } else {
          // Limitar por alto
          newHeight = maxHeight;
          newWidth = (maxHeight * aspectRatio).round();
        }
      }

      // Redimensionar si es necesario
      img.Image resized;
      if (newWidth != image.width || newHeight != image.height) {
        resized = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      } else {
        resized = image;
      }

      // Codificar como JPEG con compresión
      final compressed = img.encodeJpg(resized, quality: jpegQuality);
      return Uint8List.fromList(compressed);
    } catch (e) {
      return null;
    }
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

      // Comprimir imagen antes de guardar
      final compressedBytes = await _compressImage(response.bodyBytes);
      if (compressedBytes == null) {
        debugPrint('⚠️ No se pudo comprimir, guardando original');
        // Fallback: guardar original si falla la compresión
        final coversDir = await _coversDirectory;
        final fileName = _generateFileName(bookIsbn.isNotEmpty ? bookIsbn : imageUrl);
        final file = File('${coversDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }

      // Guardar imagen comprimida
      final coversDir = await _coversDirectory;
      final fileName = _generateFileName(bookIsbn.isNotEmpty ? bookIsbn : imageUrl);
      final file = File('${coversDir.path}/$fileName');

      await file.writeAsBytes(compressedBytes);

      final originalSize = response.bodyBytes.length;
      final compressedSize = compressedBytes.length;
      final savings = ((1 - compressedSize / originalSize) * 100).toStringAsFixed(0);
      debugPrint('✅ Portada guardada: ${file.path} (${formatSize(compressedSize)}, -$savings%)');
      return file.path;
    } catch (e) {
      debugPrint('❌ Error descargando portada: $e');
      return null;
    }
  }

  /// Guarda bytes de imagen directamente (útil para imágenes ya descargadas)
  /// Aplica compresión automáticamente
  Future<String?> saveBytes(Uint8List bytes, String bookIsbn) async {
    if (bytes.isEmpty) return null;

    try {
      // Comprimir imagen
      final compressedBytes = await _compressImage(bytes);
      final finalBytes = compressedBytes ?? bytes;

      final coversDir = await _coversDirectory;
      final fileName = _generateFileName(bookIsbn);
      final file = File('${coversDir.path}/$fileName');

      await file.writeAsBytes(finalBytes);

      if (compressedBytes != null) {
        final savings = ((1 - compressedBytes.length / bytes.length) * 100).toStringAsFixed(0);
        debugPrint('✅ Portada comprimida y guardada: ${file.path} (-$savings%)');
      } else {
        debugPrint('✅ Portada guardada desde bytes: ${file.path}');
      }
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
