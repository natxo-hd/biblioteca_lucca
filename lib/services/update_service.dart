import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

/// Servicio para comprobar y descargar actualizaciones desde GitHub
class UpdateService {
  static const String _owner = 'natxo-hd';
  static const String _repo = 'biblioteca_lucca';
  static const String _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Información de una actualización disponible
  UpdateInfo? _cachedUpdate;
  DateTime? _lastCheck;

  /// Comprueba si hay una nueva versión disponible
  /// Devuelve null si no hay actualización o si hay error
  Future<UpdateInfo?> checkForUpdate({bool forceCheck = false}) async {
    // Cache de 1 hora para no saturar la API
    if (!forceCheck && _cachedUpdate != null && _lastCheck != null) {
      final elapsed = DateTime.now().difference(_lastCheck!);
      if (elapsed.inHours < 1) {
        return _cachedUpdate;
      }
    }

    try {
      debugPrint('UpdateService: Comprobando actualizaciones...');

      // Obtener versión actual de la app
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      debugPrint('UpdateService: Versión actual: $currentVersion');

      // Consultar última release en GitHub
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'BibliotecaLucca/$currentVersion',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('UpdateService: Error HTTP ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      // Obtener versión de la release (quitar 'v' del inicio si existe)
      String latestVersion = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
      debugPrint('UpdateService: Última versión en GitHub: $latestVersion');

      // Comparar versiones
      if (!_isNewerVersion(latestVersion, currentVersion)) {
        debugPrint('UpdateService: Ya tienes la última versión');
        _cachedUpdate = null;
        _lastCheck = DateTime.now();
        return null;
      }

      // Buscar el APK en los assets
      String? apkUrl;
      int? apkSize;
      final assets = data['assets'] as List<dynamic>? ?? [];

      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          apkSize = asset['size'] as int?;
          break;
        }
      }

      if (apkUrl == null) {
        debugPrint('UpdateService: No se encontró APK en la release');
        return null;
      }

      final updateInfo = UpdateInfo(
        currentVersion: currentVersion,
        newVersion: latestVersion,
        releaseNotes: data['body'] as String? ?? 'Nueva versión disponible',
        apkUrl: apkUrl,
        apkSize: apkSize ?? 0,
        publishedAt: DateTime.tryParse(data['published_at'] as String? ?? ''),
      );

      _cachedUpdate = updateInfo;
      _lastCheck = DateTime.now();

      debugPrint('UpdateService: Actualización disponible: $latestVersion');
      return updateInfo;
    } catch (e) {
      debugPrint('UpdateService: Error comprobando actualizaciones: $e');
      return null;
    }
  }

  /// Compara dos versiones semánticas (ej: "1.0.1" vs "1.0.0")
  /// Devuelve true si newVersion es mayor que currentVersion
  bool _isNewerVersion(String newVersion, String currentVersion) {
    try {
      final newParts = newVersion.split('.').map(int.parse).toList();
      final currentParts = currentVersion.split('.').map(int.parse).toList();

      // Asegurar que ambas tienen 3 partes
      while (newParts.length < 3) newParts.add(0);
      while (currentParts.length < 3) currentParts.add(0);

      // Comparar major.minor.patch
      for (int i = 0; i < 3; i++) {
        if (newParts[i] > currentParts[i]) return true;
        if (newParts[i] < currentParts[i]) return false;
      }

      return false; // Son iguales
    } catch (e) {
      debugPrint('UpdateService: Error comparando versiones: $e');
      return false;
    }
  }

  /// Descarga la APK y la abre para instalar
  /// Devuelve true si se inició la instalación correctamente
  Future<bool> downloadAndInstall(
    UpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      debugPrint('UpdateService: Descargando ${update.apkUrl}');

      // Crear cliente HTTP para descarga con progreso
      final request = http.Request('GET', Uri.parse(update.apkUrl));
      request.headers['User-Agent'] = 'BibliotecaLucca/${update.currentVersion}';

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        debugPrint('UpdateService: Error descargando APK: ${response.statusCode}');
        return false;
      }

      // Preparar archivo de destino
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/biblioteca_lucca_${update.newVersion}.apk');

      // Descargar con progreso
      final totalBytes = response.contentLength ?? update.apkSize;
      int downloadedBytes = 0;
      final sink = apkFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (totalBytes > 0) {
          final progress = downloadedBytes / totalBytes;
          onProgress?.call(progress);
        }
      }

      await sink.close();

      debugPrint('UpdateService: APK descargada: ${apkFile.path}');
      debugPrint('UpdateService: Tamaño: ${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)} MB');

      // Abrir el APK para instalar
      final result = await OpenFilex.open(apkFile.path);
      debugPrint('UpdateService: Resultado de abrir APK: ${result.type} - ${result.message}');

      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('UpdateService: Error descargando/instalando: $e');
      return false;
    }
  }
}

/// Información sobre una actualización disponible
class UpdateInfo {
  final String currentVersion;
  final String newVersion;
  final String releaseNotes;
  final String apkUrl;
  final int apkSize;
  final DateTime? publishedAt;

  UpdateInfo({
    required this.currentVersion,
    required this.newVersion,
    required this.releaseNotes,
    required this.apkUrl,
    required this.apkSize,
    this.publishedAt,
  });

  String get formattedSize {
    if (apkSize >= 1024 * 1024) {
      return '${(apkSize / 1024 / 1024).toStringAsFixed(1)} MB';
    } else if (apkSize >= 1024) {
      return '${(apkSize / 1024).toStringAsFixed(1)} KB';
    }
    return '$apkSize bytes';
  }
}
