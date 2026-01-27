import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/book.dart';

/// Cliente para Tebeosfera - Base de datos de cómics españoles
/// Excelente fuente para colecciones españolas históricas
class TebeosferaClient {
  static const String _baseUrl = 'https://www.tebeosfera.com';

  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'es-ES,es;q=0.9',
  };

  /// Colecciones conocidas con sus URLs directas en Tebeosfera
  static const Map<String, String> _knownCollections = {
    // DC Comics Novelas Gráficas (Salvat) - 100 números + extras
    'dc comics': 'https://www.tebeosfera.com/colecciones/dc_comics_2016_salvat_-novelas_graficas-.html',
    'dc novelas': 'https://www.tebeosfera.com/colecciones/dc_comics_2016_salvat_-novelas_graficas-.html',
    'novelas graficas dc': 'https://www.tebeosfera.com/colecciones/dc_comics_2016_salvat_-novelas_graficas-.html',
    'novelas gráficas dc': 'https://www.tebeosfera.com/colecciones/dc_comics_2016_salvat_-novelas_graficas-.html',
    // Pato Donald - Carl Barks (Salvat)
    'pato donald': 'https://www.tebeosfera.com/colecciones/pato_donald_2018_salvat_-la_gran_dinastia-.html',
    'gran dinastía del pato donald': 'https://www.tebeosfera.com/colecciones/pato_donald_2018_salvat_-la_gran_dinastia-.html',
    'gran dinastia del pato donald': 'https://www.tebeosfera.com/colecciones/pato_donald_2018_salvat_-la_gran_dinastia-.html',
    'carl barks': 'https://www.tebeosfera.com/colecciones/pato_donald_2018_salvat_-la_gran_dinastia-.html',
    // Colección Vertigo (Salvat)
    'vertigo': 'https://www.tebeosfera.com/colecciones/vertigo_2015_salvat-.html',
    'coleccion vertigo': 'https://www.tebeosfera.com/colecciones/vertigo_2015_salvat-.html',
    'colección vertigo': 'https://www.tebeosfera.com/colecciones/vertigo_2015_salvat-.html',
    // Mortadelo y Filemón
    'mortadelo': 'https://www.tebeosfera.com/colecciones/mortadelo_y_filemon_2003_ediciones_b_-magos_del_humor-.html',
    'mortadelo y filemón': 'https://www.tebeosfera.com/colecciones/mortadelo_y_filemon_2003_ediciones_b_-magos_del_humor-.html',
    // Super Lopez
    'superlopez': 'https://www.tebeosfera.com/colecciones/super_lopez_2012_ediciones_b_-magos_del_humor-.html',
    'superlópez': 'https://www.tebeosfera.com/colecciones/super_lopez_2012_ediciones_b_-magos_del_humor-.html',
  };

  /// Busca la portada de un cómic en Tebeosfera
  /// [title] - Título del cómic
  /// [volumeNumber] - Número de volumen
  Future<String?> getCoverUrl(String title, {int? volumeNumber}) async {
    try {
      debugPrint('Tebeosfera: Buscando "$title" vol $volumeNumber');

      // Primero buscar en colecciones conocidas
      String? collectionUrl = _findKnownCollection(title);

      if (collectionUrl != null) {
        debugPrint('Tebeosfera: Colección conocida encontrada: $collectionUrl');
      } else {
        // Buscar la colección de forma genérica
        final searchQuery = _buildSearchQuery(title);
        collectionUrl = await _searchCollection(searchQuery);
        if (collectionUrl == null) {
          debugPrint('Tebeosfera: Colección no encontrada');
          return null;
        }
      }

      // Si tenemos número de volumen, buscar ese número específico
      if (volumeNumber != null) {
        final coverUrl = await _getVolumeCover(collectionUrl, volumeNumber);
        if (coverUrl != null) return coverUrl;
      }

      // Fallback: obtener la primera portada de la colección
      return await _getFirstCoverFromCollection(collectionUrl);
    } catch (e) {
      debugPrint('Tebeosfera error: $e');
      return null;
    }
  }

  /// Busca volúmenes de una colección en Tebeosfera
  /// Devuelve lista de Books con los volúmenes encontrados
  Future<List<Book>> searchBooks(String query) async {
    debugPrint('Tebeosfera: Buscando colección "$query"');
    final results = <Book>[];

    try {
      // Buscar en colecciones conocidas primero
      String? collectionUrl = _findKnownCollection(query);

      if (collectionUrl == null) {
        // Buscar en el buscador de Tebeosfera
        final searchQuery = _buildSearchQuery(query);
        collectionUrl = await _searchCollection(searchQuery);
      }

      if (collectionUrl == null) {
        debugPrint('Tebeosfera: No se encontró colección para "$query"');
        return results;
      }

      debugPrint('Tebeosfera: Parseando colección: $collectionUrl');

      // Obtener página de la colección
      final response = await http.get(
        Uri.parse(collectionUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint('Tebeosfera: Error HTTP ${response.statusCode}');
        return results;
      }

      final html = response.body;

      // Extraer nombre de la colección del título de la página
      String collectionName = query;
      final titleMatch = RegExp(r'<title>([^<]+)</title>', caseSensitive: false).firstMatch(html);
      if (titleMatch != null) {
        collectionName = titleMatch.group(1)?.replaceAll(' - Tebeosfera', '').trim() ?? query;
      }

      // Extraer base URL de la colección para construir URLs de imágenes
      // Ejemplo: pato_donald_2018_salvat_-la_gran_dinastia-
      final collectionBase = collectionUrl
          .replaceAll('$_baseUrl/colecciones/', '')
          .replaceAll('.html', '');

      // Buscar todos los números/volúmenes con sus imágenes
      // Patrón que captura imagen y enlace juntos
      final blockPattern = RegExp(
        r'<a[^>]+href="(/numeros/[^"]+_(\d+)\.html)"[^>]*>.*?<img[^>]+src="([^"]+)"',
        caseSensitive: false,
        dotAll: true,
      );

      final seenNumbers = <int>{};

      for (final match in blockPattern.allMatches(html)) {
        final path = match.group(1);
        final numStr = match.group(2);
        var imgUrl = match.group(3);

        if (path == null || numStr == null) continue;

        final volumeNumber = int.tryParse(numStr);
        if (volumeNumber == null || seenNumbers.contains(volumeNumber)) continue;
        seenNumbers.add(volumeNumber);

        // Procesar URL de imagen
        String? coverUrl;
        if (imgUrl != null && imgUrl.isNotEmpty) {
          if (!imgUrl.startsWith('http')) {
            imgUrl = '$_baseUrl$imgUrl';
          }
          // Quitar prefijo de miniatura (w-200_, etc)
          coverUrl = imgUrl.replaceAll(RegExp(r'w-\d+_'), '');
          debugPrint('Tebeosfera: Vol $volumeNumber -> $coverUrl');
        }

        String volumeTitle = '$collectionName $volumeNumber';

        results.add(Book(
          isbn: '',
          title: volumeTitle,
          author: 'Varios Autores',
          totalPages: 192,
          coverUrl: coverUrl ?? '',
          volumeNumber: volumeNumber,
          seriesName: collectionName,
          publisher: 'Salvat',
          apiSource: 'tebeosfera',
        ));
      }

      // Si no encontró con el patrón complejo, intentar patrón simple
      if (results.isEmpty) {
        debugPrint('Tebeosfera: Usando patrón simple...');
        final simplePattern = RegExp(
          r'href="(/numeros/[^"]+_(\d+)\.html)"',
          caseSensitive: false,
        );

        for (final match in simplePattern.allMatches(html)) {
          final path = match.group(1);
          final numStr = match.group(2);

          if (path == null || numStr == null) continue;

          final volumeNumber = int.tryParse(numStr);
          if (volumeNumber == null || seenNumbers.contains(volumeNumber)) continue;
          seenNumbers.add(volumeNumber);

          // Construir URL de imagen basada en el patrón conocido
          final coverUrl = '$_baseUrl/T3content/img/T3_numeros/${collectionBase}_$volumeNumber.jpg';

          results.add(Book(
            isbn: '',
            title: '$collectionName $volumeNumber',
            author: 'Varios Autores',
            totalPages: 192,
            coverUrl: coverUrl,
            volumeNumber: volumeNumber,
            seriesName: collectionName,
            publisher: 'Salvat',
            apiSource: 'tebeosfera',
          ));
        }
      }

      // Ordenar por número de volumen
      results.sort((a, b) => (a.volumeNumber ?? 0).compareTo(b.volumeNumber ?? 0));

      debugPrint('Tebeosfera: Encontrados ${results.length} volúmenes');
      return results;
    } catch (e) {
      debugPrint('Tebeosfera searchBooks error: $e');
      return results;
    }
  }

  /// Busca en las colecciones conocidas
  String? _findKnownCollection(String title) {
    final lowerTitle = title.toLowerCase();
    for (final entry in _knownCollections.entries) {
      if (lowerTitle.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  String _buildSearchQuery(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\sáéíóúñü]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Construye URLs candidatas para una colección basándose en el nombre
  List<String> _buildCandidateUrls(String query) {
    final candidates = <String>[];
    final normalized = query
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();

    // Detectar editorial y tipo de colección
    final hasSalvat = query.toLowerCase().contains('salvat');
    final hasDc = query.toLowerCase().contains('dc');
    final hasNovelas = query.toLowerCase().contains('novelas') ||
                       query.toLowerCase().contains('graficas');
    final hasPato = query.toLowerCase().contains('pato') ||
                    query.toLowerCase().contains('donald');
    final hasDinastia = query.toLowerCase().contains('dinast');

    // Años comunes para colecciones Salvat
    final years = ['2024', '2023', '2022', '2021', '2020', '2019', '2018', '2017', '2016', '2015'];

    // Patrones específicos para colecciones conocidas
    if (hasDc && hasNovelas) {
      for (final year in years) {
        candidates.add('$_baseUrl/colecciones/dc_comics_${year}_salvat_-novelas_graficas-.html');
      }
    }

    if (hasPato || hasDinastia) {
      for (final year in years) {
        candidates.add('$_baseUrl/colecciones/pato_donald_${year}_salvat_-la_gran_dinastia-.html');
      }
    }

    // Patrón genérico: nombre_año_salvat_-subtitulo-
    if (hasSalvat) {
      final baseName = normalized
          .replaceAll('_salvat', '')
          .replaceAll('_coleccion', '')
          .replaceAll('_de_', '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');

      for (final year in years) {
        candidates.add('$_baseUrl/colecciones/${baseName}_${year}_salvat-.html');
        candidates.add('$_baseUrl/colecciones/${baseName}_salvat_$year.html');
      }
    }

    // Patrón genérico simple
    for (final year in years) {
      candidates.add('$_baseUrl/colecciones/${normalized}_$year.html');
      candidates.add('$_baseUrl/colecciones/${normalized}_${year}_salvat.html');
    }

    // Sin año
    candidates.add('$_baseUrl/colecciones/$normalized.html');

    return candidates;
  }

  /// Busca una colección en Tebeosfera
  /// Intenta múltiples estrategias: URLs candidatas y buscador
  Future<String?> _searchCollection(String query) async {
    // Estrategia 1: Construir URLs candidatas basadas en el nombre
    final candidateUrls = _buildCandidateUrls(query);
    for (final url in candidateUrls) {
      debugPrint('Tebeosfera: Probando URL candidata: $url');
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: _headers,
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 && response.body.contains('/numeros/')) {
          debugPrint('Tebeosfera: URL válida encontrada: $url');
          return url;
        }
      } catch (e) {
        // Continuar con siguiente candidata
      }
    }

    // Estrategia 2: Usar el buscador de Tebeosfera
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final searchUrl = Uri.parse(
        '$_baseUrl/buscador.php?buscar=$encodedQuery&modo=colecciones',
      );

      debugPrint('Tebeosfera: Buscando en $searchUrl');

      final response = await http.get(
        searchUrl,
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('Tebeosfera: Error HTTP ${response.statusCode}');
        return null;
      }

      final html = response.body;

      // Buscar URLs de colecciones en los resultados
      // Patrón: /colecciones/nombre_coleccion.html
      final collectionPattern = RegExp(
        r'href="(/colecciones/[^"]+\.html)"',
        caseSensitive: false,
      );

      final matches = collectionPattern.allMatches(html);
      for (final match in matches) {
        final path = match.group(1);
        if (path != null && _isRelevantCollection(path, query)) {
          final fullUrl = '$_baseUrl$path';
          debugPrint('Tebeosfera: Colección encontrada: $fullUrl');
          return fullUrl;
        }
      }

      // Si no encontramos coincidencia exacta, usar la primera
      final firstMatch = collectionPattern.firstMatch(html);
      if (firstMatch != null) {
        final path = firstMatch.group(1);
        if (path != null) {
          return '$_baseUrl$path';
        }
      }

      return null;
    } catch (e) {
      debugPrint('Tebeosfera search error: $e');
      return null;
    }
  }

  bool _isRelevantCollection(String path, String query) {
    final pathLower = path.toLowerCase();
    final queryWords = query.split(' ').where((w) => w.length > 2).toList();

    int matches = 0;
    for (final word in queryWords) {
      if (pathLower.contains(word)) matches++;
    }

    return matches >= 2 || (queryWords.length == 1 && matches == 1);
  }

  /// Obtiene la portada de un volumen específico
  Future<String?> _getVolumeCover(String collectionUrl, int volumeNumber) async {
    try {
      final response = await http.get(
        Uri.parse(collectionUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final html = response.body;

      // Buscar enlace al número específico
      // Patrón: /numeros/nombre_numero.html
      final volumePattern = RegExp(
        r'href="(/numeros/[^"]*_$volumeNumber\.html)"',
        caseSensitive: false,
      );

      var match = volumePattern.firstMatch(html);

      // Si no encuentra con el patrón exacto, buscar cualquier número que termine en _N.html
      if (match == null) {
        final genericPattern = RegExp(
          r'href="(/numeros/[^"]+_(\d+)\.html)"',
          caseSensitive: false,
        );

        for (final m in genericPattern.allMatches(html)) {
          final numStr = m.group(2);
          if (numStr != null && int.tryParse(numStr) == volumeNumber) {
            match = m;
            break;
          }
        }
      }

      if (match == null) {
        debugPrint('Tebeosfera: Número $volumeNumber no encontrado en colección');
        return null;
      }

      final volumePath = match.group(1);
      if (volumePath == null) return null;

      final volumeUrl = '$_baseUrl$volumePath';
      debugPrint('Tebeosfera: Página del número: $volumeUrl');

      // Obtener portada de la página del número
      return await _extractCoverFromPage(volumeUrl);
    } catch (e) {
      debugPrint('Tebeosfera volume error: $e');
      return null;
    }
  }

  /// Obtiene la primera portada de una colección
  Future<String?> _getFirstCoverFromCollection(String collectionUrl) async {
    try {
      final response = await http.get(
        Uri.parse(collectionUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final html = response.body;

      // Buscar imágenes de portada directamente en la página de colección
      return _extractImageFromHtml(html);
    } catch (e) {
      debugPrint('Tebeosfera collection error: $e');
      return null;
    }
  }

  /// Extrae la URL de portada de una página de número
  Future<String?> _extractCoverFromPage(String pageUrl) async {
    try {
      final response = await http.get(
        Uri.parse(pageUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      return _extractImageFromHtml(response.body);
    } catch (e) {
      debugPrint('Tebeosfera extract error: $e');
      return null;
    }
  }

  /// Extrae URL de imagen de portada del HTML
  String? _extractImageFromHtml(String html) {
    // Patrón 1: og:image meta tag
    final ogImagePattern = RegExp(
      r'<meta\s+property="og:image"\s+content="([^"]+)"',
      caseSensitive: false,
    );
    var match = ogImagePattern.firstMatch(html);
    if (match != null) {
      final url = match.group(1);
      if (url != null && url.contains('tebeosfera')) {
        debugPrint('Tebeosfera: Portada (og:image): $url');
        return url;
      }
    }

    // Patrón 2: Imágenes en T3content/img/T3_numeros
    final imagePattern = RegExp(
      r'(https?://www\.tebeosfera\.com/T3content/img/T3_numeros/[^"\s>]+\.(?:jpg|png|gif))',
      caseSensitive: false,
    );
    match = imagePattern.firstMatch(html);
    if (match != null) {
      var url = match.group(1);
      if (url != null) {
        // Quitar prefijo de miniatura si existe
        url = url.replaceAll(RegExp(r'w-\d+_'), '');
        debugPrint('Tebeosfera: Portada (T3content): $url');
        return url;
      }
    }

    // Patrón 3: Cualquier imagen grande en el contenido
    final genericImagePattern = RegExp(
      r'src="([^"]+/img/[^"]+\.(?:jpg|png))"',
      caseSensitive: false,
    );
    match = genericImagePattern.firstMatch(html);
    if (match != null) {
      var url = match.group(1);
      if (url != null) {
        if (!url.startsWith('http')) {
          url = '$_baseUrl$url';
        }
        debugPrint('Tebeosfera: Portada (genérica): $url');
        return url;
      }
    }

    debugPrint('Tebeosfera: No se encontró portada');
    return null;
  }
}
