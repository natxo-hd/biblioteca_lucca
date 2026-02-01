import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/http_config.dart';
import '../models/book.dart';
import '../utils/volume_extractor.dart';
import 'parent_settings_service.dart';

/// Cache de volumenes conocidos para una serie
class SeriesVolumeCache {
  final int maxKnownVolume;
  final DateTime lastChecked;

  const SeriesVolumeCache({
    required this.maxKnownVolume,
    required this.lastChecked,
  });

  bool get isStale =>
      DateTime.now().difference(lastChecked).inDays >= 7;

  Map<String, dynamic> toJson() => {
        'maxKnownVolume': maxKnownVolume,
        'lastChecked': lastChecked.toIso8601String(),
      };

  factory SeriesVolumeCache.fromJson(Map<String, dynamic> json) {
    return SeriesVolumeCache(
      maxKnownVolume: json['maxKnownVolume'] as int,
      lastChecked: DateTime.parse(json['lastChecked'] as String),
    );
  }
}

/// Alerta de volumen nuevo disponible
class NewVolumeAlert {
  final String seriesName;
  final int newVolumeNumber;
  final String? coverUrl;
  final String author;

  const NewVolumeAlert({
    required this.seriesName,
    required this.newVolumeNumber,
    this.coverUrl,
    required this.author,
  });
}

/// Info de una serie seguida por el usuario
class SeriesFollowInfo {
  final String seriesName;
  final int maxOwnedVolume;
  final String author;

  const SeriesFollowInfo({
    required this.seriesName,
    required this.maxOwnedVolume,
    required this.author,
  });
}

/// Servicio para verificar existencia de volumenes y detectar novedades.
///
/// Usa el endpoint AJAX ligero de TomosYGrapas (1 request, solo JSON)
/// y cachea resultados en SharedPreferences con TTL de 7 dias.
class NewVolumeCheckerService {
  static final NewVolumeCheckerService _instance =
      NewVolumeCheckerService._internal();
  factory NewVolumeCheckerService() => _instance;
  NewVolumeCheckerService._internal();

  static const String _baseUrl = 'https://tienda.tomosygrapas.com';
  static const String _cacheKey = 'series_volume_cache';

  final ParentSettingsService _settingsService = ParentSettingsService();

  /// Cache en memoria: clave normalizada → datos
  Map<String, SeriesVolumeCache> _cache = {};
  bool _initialized = false;

  /// Series conocidas con su numero total de volumenes (fallback estatico)
  static const Map<String, int> knownSeriesVolumes = {
    // DC Vertigo
    'predicador': 13,
    'preacher': 13,
    'sandman': 10,
    'the sandman': 10,
    'fábulas': 22,
    'fabulas': 22,
    'fables': 22,
    'transmetropolitan': 10,
    'y el último hombre': 10,
    'y: the last man': 10,
    '100 balas': 13,
    '100 bullets': 13,
    'hellblazer': 27,
    'la cosa del pantano': 6,
    'swamp thing': 6,
    'lucifer': 11,
    'v de vendetta': 1,
    'v for vendetta': 1,
    'watchmen': 1,
    'desde el infierno': 1,
    'from hell': 1,

    // Marvel
    'ojo de halcón': 4,
    'hawkeye': 4,
    'daredevil': 8,
    'inmortal hulk': 10,
    'immortal hulk': 10,

    // Manga populares
    'death note': 12,
    'fullmetal alchemist': 27,
    'dragon ball': 42,
    'dragon ball z': 26,
    'naruto': 72,
    'one punch man': 29,
    'attack on titan': 34,
    'ataque a los titanes': 34,
    'demon slayer': 23,
    'kimetsu no yaiba': 23,
    'jujutsu kaisen': 26,
    'chainsaw man': 16,
    'my hero academia': 39,
    'boku no hero academia': 39,
    'spy x family': 12,
    'tokyo revengers': 31,
    'haikyuu': 45,
    'hunter x hunter': 37,

    // One Piece ediciones
    'one piece': 109,
    'one piece 3 en 1': 36,
  };

  /// Inicializar: cargar cache de SharedPreferences
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr != null) {
        final Map<String, dynamic> data = json.decode(jsonStr);
        _cache = data.map((key, value) => MapEntry(
              key,
              SeriesVolumeCache.fromJson(value as Map<String, dynamic>),
            ));
      }
    } catch (e) {
      debugPrint('NewVolumeChecker: Error cargando cache: $e');
      _cache = {};
    }
    _initialized = true;
  }

  /// Guardar cache en SharedPreferences
  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _cache.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString(_cacheKey, json.encode(data));
    } catch (e) {
      debugPrint('NewVolumeChecker: Error guardando cache: $e');
    }
  }

  /// Normalizar nombre de serie para uso como clave de cache
  String _normalize(String seriesName) {
    return seriesName.toLowerCase().trim();
  }

  /// Verificar si un volumen existe para una serie.
  ///
  /// Retorna:
  /// - `true` si el volumen existe
  /// - `false` si no existe
  /// - `null` si no se pudo determinar
  Future<bool?> doesVolumeExist(String seriesName, int volumeNumber) async {
    await init();
    final key = _normalize(seriesName);

    // 1. Comprobar cache dinamico (fresco)
    final cached = _cache[key];
    if (cached != null && !cached.isStale) {
      return volumeNumber <= cached.maxKnownVolume;
    }

    // 2. Comprobar mapa estatico
    final staticMax = _getStaticMax(seriesName);
    if (staticMax != null) {
      return volumeNumber <= staticMax;
    }

    // 3. Consultar TomosYGrapas AJAX (ligero)
    try {
      await _fetchSeriesDataLight(seriesName);
      final freshCached = _cache[key];
      if (freshCached != null) {
        return volumeNumber <= freshCached.maxKnownVolume;
      }
    } catch (e) {
      debugPrint('NewVolumeChecker: Error consultando TomosYGrapas: $e');
    }

    // 4. No se pudo determinar
    return null;
  }

  /// Resultado sincronico desde cache (para uso en build() sincronos)
  bool? getCachedResult(String seriesName, int volumeNumber) {
    final key = _normalize(seriesName);

    // Cache dinamico
    final cached = _cache[key];
    if (cached != null && !cached.isStale) {
      return volumeNumber <= cached.maxKnownVolume;
    }

    return null;
  }

  /// Buscar en el mapa estatico de series conocidas
  int? _getStaticMax(String seriesName) {
    final lower = seriesName.toLowerCase().trim();
    for (final entry in knownSeriesVolumes.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Consulta LIGERA al AJAX de TomosYGrapas.
  ///
  /// Solo hace 1 request HTTP, parsea el JSON de resultados,
  /// extrae volumeNumber de cada producto con VolumeExtractor,
  /// y guarda el maxKnownVolume en cache.
  /// NO visita paginas individuales (eso es lento).
  Future<void> _fetchSeriesDataLight(String seriesName) async {
    final key = _normalize(seriesName);

    // Limpiar nombre para busqueda
    final cleanName = VolumeExtractor.cleanSeriesName(seriesName);
    final query = cleanName.isNotEmpty ? cleanName : seriesName;

    final ajaxUrl = Uri.parse(
      '$_baseUrl/es/module/leoproductsearch/productsearch?ajax=1&q=${Uri.encodeComponent(query)}',
    );

    debugPrint('NewVolumeChecker: Consultando TomosYGrapas para "$query"');

    final response = await http
        .get(ajaxUrl, headers: HttpConfig.ajaxHeaders)
        .timeout(HttpConfig.standardTimeout);

    if (response.statusCode != 200) return;

    final data = json.decode(response.body) as Map<String, dynamic>;
    final products = data['products'] as List<dynamic>?;

    if (products == null || products.isEmpty) return;

    // Extraer palabras clave de la serie para filtrar resultados
    final seriesWords = query
        .toLowerCase()
        .split(' ')
        .where((w) => w.length > 2)
        .take(3)
        .toList();

    int maxVol = 0;

    for (final product in products) {
      final productMap = product as Map<String, dynamic>;
      final name = (productMap['name'] as String?)?.toLowerCase() ?? '';

      // Verificar que el producto es de la misma serie
      if (!seriesWords.every((word) => name.contains(word))) continue;

      // Extraer numero de volumen
      final volInfo =
          VolumeExtractor.extractFromTitle(productMap['name'] as String? ?? '');
      final vol = volInfo.volumeNumber;

      if (vol != null && vol > maxVol) {
        maxVol = vol;
      }
    }

    if (maxVol > 0) {
      _cache[key] = SeriesVolumeCache(
        maxKnownVolume: maxVol,
        lastChecked: DateTime.now(),
      );
      await _saveCache();
      debugPrint(
          'NewVolumeChecker: "$seriesName" → max volumen encontrado: $maxVol');
    }
  }

  /// Obtener series seguidas por el usuario.
  ///
  /// Una serie es "seguida" si:
  /// - Tiene al menos 1 libro activo (reading/finished, no archivado) con seriesName y volumeNumber
  /// - La serie NO esta marcada como completa
  Future<List<SeriesFollowInfo>> getFollowedSeries(
    List<Book> readingBooks,
    List<Book> finishedBooks,
  ) async {
    final allActive = [...readingBooks, ...finishedBooks];

    // Agrupar por serie
    final Map<String, List<Book>> seriesMap = {};
    for (final book in allActive) {
      if (book.seriesName == null || book.volumeNumber == null) continue;
      seriesMap.putIfAbsent(book.seriesName!, () => []).add(book);
    }

    // Filtrar series completas
    final completedSeries = await _settingsService.getCompletedSeries();

    final followed = <SeriesFollowInfo>[];
    for (final entry in seriesMap.entries) {
      if (completedSeries.contains(entry.key.toLowerCase())) continue;

      final maxVol =
          entry.value.map((b) => b.volumeNumber ?? 0).reduce(max);
      followed.add(SeriesFollowInfo(
        seriesName: entry.key,
        maxOwnedVolume: maxVol,
        author: entry.value.first.author,
      ));
    }

    return followed;
  }

  /// Comprobar todas las series seguidas para volumenes nuevos.
  ///
  /// Para cada serie seguida, verifica si el volumen maxOwnedVolume+1 existe.
  /// Retorna lista de alertas para las series con volumenes nuevos disponibles.
  Future<List<NewVolumeAlert>> checkForNewVolumes(
    List<Book> readingBooks,
    List<Book> finishedBooks,
  ) async {
    await init();
    final followed = await getFollowedSeries(readingBooks, finishedBooks);
    final alerts = <NewVolumeAlert>[];

    debugPrint(
        'NewVolumeChecker: Comprobando ${followed.length} series seguidas');

    for (final series in followed) {
      final nextVol = series.maxOwnedVolume + 1;

      try {
        final exists = await doesVolumeExist(series.seriesName, nextVol);

        if (exists == true) {
          alerts.add(NewVolumeAlert(
            seriesName: series.seriesName,
            newVolumeNumber: nextVol,
            coverUrl: null, // Se buscara portada al interactuar
            author: series.author,
          ));
          debugPrint(
              'NewVolumeChecker: Nuevo volumen disponible: ${series.seriesName} Vol. $nextVol');
        }
      } catch (e) {
        debugPrint(
            'NewVolumeChecker: Error comprobando ${series.seriesName}: $e');
      }

      // Rate-limit entre series
      await Future.delayed(HttpConfig.coverSearchDelay);
    }

    debugPrint('NewVolumeChecker: ${alerts.length} volumenes nuevos encontrados');
    return alerts;
  }

  /// Invalidar cache para una serie especifica (forzar re-comprobacion)
  Future<void> invalidateCache(String seriesName) async {
    final key = _normalize(seriesName);
    _cache.remove(key);
    await _saveCache();
  }

  /// Limpiar todo el cache
  Future<void> clearCache() async {
    _cache.clear();
    _initialized = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
