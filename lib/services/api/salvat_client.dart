import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/book.dart';

/// Cliente para Editorial Salvat - Colecciones españolas de cómics
/// Especialmente útil para la colección Vertigo con portadas únicas
class SalvatClient {
  static const String _baseUrl = 'https://www.salvat.com';

  /// Headers comunes para las peticiones
  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'es-ES,es;q=0.9',
  };

  /// Busca la portada de un cómic en Salvat
  /// [title] - Título del cómic (ej: "La Cosa del Pantano Volumen 2")
  /// [volumeNumber] - Número de volumen opcional para refinar la búsqueda
  Future<String?> getCoverUrl(String title, {int? volumeNumber}) async {
    try {
      debugPrint('Salvat: Buscando portada para "$title" (vol: $volumeNumber)');

      // Construir query de búsqueda
      String searchQuery = _buildSearchQuery(title, volumeNumber);

      // Buscar productos
      final productUrl = await _searchProduct(searchQuery, volumeNumber: volumeNumber);
      if (productUrl == null) {
        // Intentar búsqueda más simple si la primera falla
        final simpleQuery = _simplifyTitle(title);
        if (simpleQuery != searchQuery) {
          final fallbackUrl = await _searchProduct(simpleQuery, volumeNumber: volumeNumber);
          if (fallbackUrl != null) {
            return await _extractCoverFromProductPage(fallbackUrl);
          }
        }
        debugPrint('Salvat: No se encontró producto');
        return null;
      }

      // Extraer portada de la página del producto
      return await _extractCoverFromProductPage(productUrl);
    } catch (e) {
      debugPrint('Salvat error: $e');
      return null;
    }
  }

  /// Construye la query de búsqueda optimizada
  String _buildSearchQuery(String title, int? volumeNumber) {
    String query = title.toLowerCase();

    // Limpiar el título de caracteres especiales
    query = query.replaceAll(RegExp(r'[^\w\sáéíóúñü]'), ' ');
    query = query.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Si tiene número de volumen y no está en el título, añadirlo
    if (volumeNumber != null && volumeNumber > 1) {
      if (!query.contains('volumen') && !query.contains('vol')) {
        query = '$query volumen $volumeNumber';
      }
    }

    return query;
  }

  /// Simplifica el título para búsqueda fallback
  String _simplifyTitle(String title) {
    String simple = title.toLowerCase();

    // Quitar palabras comunes que pueden interferir
    simple = simple.replaceAll(RegExp(r'\b(de|del|la|el|los|las|alan moore|vol\.?|volumen)\b'), ' ');
    simple = simple.replaceAll(RegExp(r'\d+'), ' '); // Quitar números
    simple = simple.replaceAll(RegExp(r'\s+'), ' ').trim();

    return simple;
  }

  /// Busca un producto en Salvat y devuelve la URL del producto
  Future<String?> _searchProduct(String query, {int? volumeNumber}) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final searchUrl = Uri.parse(
        '$_baseUrl/mod/iqitsearch/searchiqit?s=$encodedQuery',
      );

      debugPrint('Salvat: Buscando en $searchUrl');

      final response = await http.get(
        searchUrl,
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('Salvat: Error HTTP ${response.statusCode}');
        return null;
      }

      final html = response.body;

      // Buscar URLs de productos en los resultados
      // Patrón: href="https://www.salvat.com/coleccion-vertigo/nombre-id"
      final productUrlPattern = RegExp(
        r'href="(https://www\.salvat\.com/coleccion-vertigo/[^"]*-\d+)"',
        caseSensitive: false,
      );

      final matches = productUrlPattern.allMatches(html);
      final allUrls = matches.map((m) => m.group(1)).whereType<String>().toSet().toList();

      debugPrint('Salvat: Encontrados ${allUrls.length} productos de Vertigo');

      if (allUrls.isEmpty) return null;

      // Si buscamos un volumen específico, intentar encontrar coincidencia exacta
      if (volumeNumber != null) {
        // Para volumen 1, buscar URL sin "volumen" o con "volumen-1"
        if (volumeNumber == 1) {
          // Primero buscar explícitamente "volumen-1"
          for (final url in allUrls) {
            if (url.contains('volumen-1-') || url.endsWith('volumen-1')) {
              debugPrint('Salvat: Encontrado volumen 1 explícito: $url');
              return url;
            }
          }
          // Si no hay "volumen-1", buscar URL sin número de volumen (es el primero)
          for (final url in allUrls) {
            if (!RegExp(r'volumen-\d').hasMatch(url)) {
              debugPrint('Salvat: Encontrado volumen 1 (sin número): $url');
              return url;
            }
          }
        } else {
          // Para otros volúmenes, buscar "volumen-N" exacto
          final volumePattern = 'volumen-$volumeNumber';
          for (final url in allUrls) {
            // Verificar que sea exactamente ese volumen (no volumen-10 cuando buscamos 1)
            if (url.contains('$volumePattern-') || url.endsWith(volumePattern)) {
              debugPrint('Salvat: Encontrado volumen $volumeNumber exacto: $url');
              return url;
            }
          }
        }

        debugPrint('Salvat: No se encontró volumen $volumeNumber exacto');
      }

      // Fallback: usar el primer resultado relevante
      for (final url in allUrls) {
        if (_isRelevantProduct(url, query)) {
          debugPrint('Salvat: Usando resultado relevante: $url');
          return url;
        }
      }

      // Último fallback: primer resultado de Vertigo
      if (allUrls.isNotEmpty) {
        debugPrint('Salvat: Usando primer resultado: ${allUrls.first}');
        return allUrls.first;
      }

      return null;
    } catch (e) {
      debugPrint('Salvat search error: $e');
      return null;
    }
  }

  /// Verifica si la URL del producto es relevante para la búsqueda
  bool _isRelevantProduct(String url, String query) {
    final urlLower = url.toLowerCase();
    final queryWords = query.toLowerCase().split(' ')
        .where((w) => w.length > 2)
        .toList();

    // Verificar que al menos 2 palabras clave estén en la URL
    int matches = 0;
    for (final word in queryWords) {
      if (urlLower.contains(word)) {
        matches++;
      }
    }

    return matches >= 2 || (queryWords.length == 1 && matches == 1);
  }

  /// Extrae la URL de la portada de la página del producto
  Future<String?> _extractCoverFromProductPage(String productUrl) async {
    try {
      debugPrint('Salvat: Obteniendo portada de $productUrl');

      final response = await http.get(
        Uri.parse(productUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('Salvat: Error HTTP ${response.statusCode}');
        return null;
      }

      final html = response.body;

      // Buscar la imagen principal del producto
      // Patrón 1: og:image meta tag
      final ogImagePattern = RegExp(
        r'<meta\s+property="og:image"\s+content="([^"]+)"',
        caseSensitive: false,
      );
      var match = ogImagePattern.firstMatch(html);
      if (match != null) {
        final imageUrl = match.group(1);
        if (imageUrl != null && _isValidImageUrl(imageUrl)) {
          debugPrint('Salvat: Portada encontrada (og:image): $imageUrl');
          return _upgradeImageSize(imageUrl);
        }
      }

      // Patrón 2: data-image-large-src
      final dataImagePattern = RegExp(
        r'data-image-large-src="([^"]+)"',
        caseSensitive: false,
      );
      match = dataImagePattern.firstMatch(html);
      if (match != null) {
        final imageUrl = match.group(1);
        if (imageUrl != null && _isValidImageUrl(imageUrl)) {
          debugPrint('Salvat: Portada encontrada (data-image): $imageUrl');
          return _upgradeImageSize(imageUrl);
        }
      }

      // Patrón 3: Buscar imagen con patrón de Salvat (ID-size/nombre.jpg)
      final salvatImagePattern = RegExp(
        r'(https://www\.salvat\.com/\d+-[a-z_]+/[^"\s]+\.jpg)',
        caseSensitive: false,
      );
      final imageMatches = salvatImagePattern.allMatches(html);
      for (final imgMatch in imageMatches) {
        final imageUrl = imgMatch.group(1);
        if (imageUrl != null && !imageUrl.contains('category')) {
          debugPrint('Salvat: Portada encontrada (patrón): $imageUrl');
          return _upgradeImageSize(imageUrl);
        }
      }

      debugPrint('Salvat: No se encontró portada en la página');
      return null;
    } catch (e) {
      debugPrint('Salvat extract error: $e');
      return null;
    }
  }

  /// Verifica si es una URL de imagen válida
  bool _isValidImageUrl(String url) {
    return url.contains('.jpg') || url.contains('.png') || url.contains('.webp');
  }

  /// Convierte la URL de imagen al formato salvat_antigua (portada limpia sin marco)
  String _upgradeImageSize(String imageUrl) {
    // Usar salvat_antigua que tiene las portadas limpias sin marco blanco
    String upgraded = imageUrl
        .replaceAll('home_default', 'salvat_antigua')
        .replaceAll('small_default', 'salvat_antigua')
        .replaceAll('medium_default', 'salvat_antigua')
        .replaceAll('large_default', 'salvat_antigua')
        .replaceAll('thickbox_default', 'salvat_antigua')
        .replaceAll('cart_default', 'salvat_antigua');

    return upgraded;
  }

  /// Busca portadas de la colección Vertigo específicamente
  /// [seriesName] - Nombre de la serie (ej: "La Cosa del Pantano", "Sandman")
  /// [volumeNumber] - Número de volumen
  Future<String?> searchVertigoCover(String seriesName, int volumeNumber) async {
    // Construir búsqueda específica para Vertigo
    String query = seriesName;
    if (volumeNumber > 1) {
      query = '$seriesName volumen $volumeNumber';
    }

    return getCoverUrl(query, volumeNumber: volumeNumber);
  }

  /// Categorías conocidas de colecciones en Salvat
  static const Map<String, String> _knownCategories = {
    'dc': 'coleccion-novelas-graficas-dc-comics',
    'novelas graficas': 'coleccion-novelas-graficas-dc-comics',
    'vertigo': 'coleccion-vertigo',
    'marvel': 'coleccion-novelas-graficas-marvel',
    'pato donald': 'la-gran-dinastia-del-pato-donald',
    'batman': 'coleccion-novelas-graficas-dc-comics',
    'superman': 'coleccion-novelas-graficas-dc-comics',
  };

  /// Busca una colección completa en Salvat
  /// Devuelve lista de Books con todos los volúmenes
  Future<List<Book>> searchCollection(String query) async {
    debugPrint('Salvat: Buscando colección "$query"');
    final results = <Book>[];

    try {
      // Detectar categoría basándose en la query
      String? category;
      final queryLower = query.toLowerCase();
      for (final entry in _knownCategories.entries) {
        if (queryLower.contains(entry.key)) {
          category = entry.value;
          break;
        }
      }

      if (category == null) {
        debugPrint('Salvat: No se detectó categoría para "$query"');
        return results;
      }

      debugPrint('Salvat: Categoría detectada: $category');

      // Buscar con la API de Salvat
      final encodedQuery = Uri.encodeComponent(query);
      final searchUrl = Uri.parse(
        '$_baseUrl/mod/iqitsearch/searchiqit?s=$encodedQuery&comics-y-libros=$category',
      );

      debugPrint('Salvat: URL de búsqueda: $searchUrl');

      final response = await http.get(
        searchUrl,
        headers: {
          ..._headers,
          'Accept': 'application/json, text/html',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint('Salvat: Error HTTP ${response.statusCode}');
        return results;
      }

      // Intentar parsear como JSON primero
      try {
        final data = json.decode(response.body);
        if (data is Map && data['products'] != null) {
          return _parseJsonProducts(data['products'] as List, category);
        }
      } catch (e) {
        // No es JSON, parsear como HTML
        debugPrint('Salvat: Respuesta no es JSON, parseando HTML');
      }

      // Parsear HTML para encontrar productos
      return _parseHtmlProducts(response.body, category);
    } catch (e) {
      debugPrint('Salvat searchCollection error: $e');
      return results;
    }
  }

  /// Parsea productos desde respuesta JSON
  List<Book> _parseJsonProducts(List products, String category) {
    final results = <Book>[];
    final collectionName = _getCategoryDisplayName(category);

    for (final product in products) {
      try {
        final productMap = product as Map<String, dynamic>;
        final name = productMap['item_name'] as String? ?? productMap['name'] as String?;
        final reference = productMap['item_reference'] as String? ?? '';

        if (name == null) continue;

        // Extraer número de volumen de la referencia (ej: "Novelas gráficas DC Comics nº 45")
        int? volumeNumber;
        final volMatch = RegExp(r'n[ºo°]\s*(\d+)', caseSensitive: false).firstMatch(reference);
        if (volMatch != null) {
          volumeNumber = int.tryParse(volMatch.group(1) ?? '');
        }

        // Obtener URL de imagen
        String? coverUrl;
        if (productMap['cover'] != null) {
          final cover = productMap['cover'];
          if (cover is Map) {
            coverUrl = cover['large']?['url'] as String? ??
                      cover['medium']?['url'] as String? ??
                      cover['small']?['url'] as String?;
          }
        }
        if (coverUrl != null) {
          coverUrl = _upgradeImageSize(coverUrl);
        }

        // Obtener URL del producto
        String? productUrl = productMap['url'] as String? ?? productMap['link'] as String?;

        results.add(Book(
          isbn: '',
          title: volumeNumber != null ? '$collectionName $volumeNumber - $name' : name,
          author: 'Varios Autores',
          totalPages: 192,
          coverUrl: coverUrl ?? '',
          volumeNumber: volumeNumber,
          seriesName: collectionName,
          publisher: 'Salvat',
          apiSource: 'salvat',
          sourceUrl: productUrl,
        ));
      } catch (e) {
        debugPrint('Salvat: Error parseando producto: $e');
      }
    }

    results.sort((a, b) => (a.volumeNumber ?? 999).compareTo(b.volumeNumber ?? 999));
    debugPrint('Salvat: Encontrados ${results.length} volúmenes');
    return results;
  }

  /// Parsea productos desde HTML
  List<Book> _parseHtmlProducts(String html, String category) {
    final results = <Book>[];
    final collectionName = _getCategoryDisplayName(category);

    // Buscar productos en el HTML
    // Patrón: href="https://www.salvat.com/categoria/nombre-id"
    final productPattern = RegExp(
      r'href="(https://www\.salvat\.com/' + category + r'/([^"]+)-(\d+))"',
      caseSensitive: false,
    );

    final seenIds = <String>{};

    for (final match in productPattern.allMatches(html)) {
      final url = match.group(1);
      final slug = match.group(2);
      final id = match.group(3);

      if (url == null || id == null || seenIds.contains(id)) continue;
      seenIds.add(id);

      // Extraer nombre del slug
      final name = slug?.replaceAll('-', ' ').split(' ')
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
          .join(' ') ?? 'Volumen';

      // Intentar extraer número de volumen del nombre
      int? volumeNumber;
      final volMatch = RegExp(r'(?:vol(?:umen)?|n[ºo°]?)\s*(\d+)', caseSensitive: false).firstMatch(name);
      if (volMatch != null) {
        volumeNumber = int.tryParse(volMatch.group(1) ?? '');
      }

      results.add(Book(
        isbn: '',
        title: name,
        author: 'Varios Autores',
        totalPages: 192,
        coverUrl: '', // Se obtendrá al añadir
        volumeNumber: volumeNumber,
        seriesName: collectionName,
        publisher: 'Salvat',
        apiSource: 'salvat',
        sourceUrl: url,
      ));
    }

    results.sort((a, b) => (a.volumeNumber ?? 999).compareTo(b.volumeNumber ?? 999));
    debugPrint('Salvat: Encontrados ${results.length} volúmenes (HTML)');
    return results;
  }

  /// Obtiene el nombre para mostrar de una categoría
  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'coleccion-novelas-graficas-dc-comics':
        return 'DC Comics Novelas Gráficas';
      case 'coleccion-vertigo':
        return 'Colección Vertigo';
      case 'coleccion-novelas-graficas-marvel':
        return 'Marvel Novelas Gráficas';
      case 'la-gran-dinastia-del-pato-donald':
        return 'La Gran Dinastía del Pato Donald';
      default:
        return 'Colección Salvat';
    }
  }
}
