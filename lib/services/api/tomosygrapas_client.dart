import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/book.dart';
import '../../config/http_config.dart';
import '../../utils/volume_extractor.dart';
import '../../utils/query_generator.dart';

/// Cliente para Tomos y Grapas - Tienda española de cómics/manga
/// Excelente fuente para manga español con datos completos:
/// - Número de volumen
/// - Páginas totales
/// - Portadas de alta calidad
/// - ISBN, editorial, autor
class TomosYGrapasClient {
  static const String _baseUrl = 'https://tienda.tomosygrapas.com';

  /// Busca un producto por ISBN
  Future<Book?> searchByIsbn(String isbn) async {
    try {
      final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '');
      debugPrint('TomosYGrapas: Buscando ISBN $cleanIsbn');

      // MÉTODO PRINCIPAL: Endpoint AJAX leoproductsearch (funciona con ISBN)
      var book = await _searchAjax(cleanIsbn);
      if (book != null) return book;

      // FALLBACK: Búsqueda HTML tradicional
      book = await _searchHtml(cleanIsbn);
      if (book != null) return book;

      debugPrint('TomosYGrapas: No encontrado');
      return null;
    } catch (e) {
      debugPrint('TomosYGrapas error: $e');
    }
    return null;
  }

  /// Búsqueda usando el endpoint AJAX leoproductsearch (EL QUE FUNCIONA)
  Future<Book?> _searchAjax(String isbn) async {
    try {
      // Este es el endpoint correcto que devuelve JSON con productos
      final ajaxUrl = Uri.parse(
        '$_baseUrl/es/module/leoproductsearch/productsearch?ajax=1&q=$isbn',
      );

      debugPrint('TomosYGrapas AJAX: $ajaxUrl');

      final response = await http.get(
        ajaxUrl,
        headers: HttpConfig.ajaxHeaders,
      ).timeout(HttpConfig.standardTimeout);

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;

          // El array de productos está en data['products']
          final products = data['products'] as List<dynamic>?;

          if (products != null && products.isNotEmpty) {
            final product = products.first as Map<String, dynamic>;

            debugPrint('TomosYGrapas AJAX: Producto encontrado: ${product['name']}');

            // Extraer datos directamente del JSON de búsqueda
            final title = product['name'] as String?;
            final productUrl = product['url'] as String? ?? product['link'] as String?;
            final publisher = product['manufacturer_name'] as String?;

            // Extraer cover URL
            String? coverUrl;
            if (product['cover'] != null) {
              final cover = product['cover'] as Map<String, dynamic>;
              if (cover['large'] != null) {
                coverUrl = (cover['large'] as Map<String, dynamic>)['url'] as String?;
              } else if (cover['bySize'] != null) {
                final bySize = cover['bySize'] as Map<String, dynamic>;
                if (bySize['large_default'] != null) {
                  coverUrl = (bySize['large_default'] as Map<String, dynamic>)['url'] as String?;
                }
              }
            }

            // Si tenemos URL del producto, obtener detalles completos (páginas, autor)
            if (productUrl != null) {
              final detailedBook = await _fetchProductDetails(productUrl, isbn);
              if (detailedBook != null) {
                // Combinar datos: usar publisher del JSON si no lo tenemos
                return detailedBook.copyWith(
                  publisher: detailedBook.publisher ?? publisher,
                  coverUrl: detailedBook.coverUrl ?? coverUrl,
                );
              }
            }

            // Si no pudimos obtener detalles, crear libro con datos básicos
            if (title != null) {
              final volInfo = _extractVolumeFromTitle(title);
              return Book(
                isbn: isbn,
                title: title,
                author: 'Desconocido',
                coverUrl: coverUrl,
                totalPages: 0,
                seriesName: volInfo['seriesName'],
                volumeNumber: volInfo['volumeNumber'],
                publisher: publisher,
                apiSource: 'tomosygrapas',
                sourceUrl: productUrl,
              );
            }
          }
        } catch (e) {
          debugPrint('TomosYGrapas AJAX JSON error: $e');
        }
      }
    } catch (e) {
      debugPrint('TomosYGrapas AJAX error: $e');
    }
    return null;
  }

  /// Búsqueda en la página HTML tradicional
  Future<Book?> _searchHtml(String isbn) async {
    try {
      final searchUrl = Uri.parse('$_baseUrl/es/buscar?controller=search&s=$isbn');

      final response = await http.get(
        searchUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'es-ES,es;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final html = response.body;

        // Buscar el enlace al producto en los resultados
        // Patrón 1: URL que contiene parte del ISBN
        final isbnSuffix = isbn.length >= 4 ? isbn.substring(isbn.length - 4) : isbn;
        var productLinkMatch = RegExp(
          r'href="(https://tienda\.tomosygrapas\.com/es/[^"]+' + isbnSuffix + r'[^"]*\.html)"',
        ).firstMatch(html);

        // Patrón 2: Cualquier URL de producto
        productLinkMatch ??= RegExp(
          r'href="(https://tienda\.tomosygrapas\.com/es/(?:manga|comic-americano|comic-europeo)/\d+-[^"]+\.html)"',
        ).firstMatch(html);

        // Patrón 3: data-id-product seguido de URL
        if (productLinkMatch == null) {
          final dataProductMatch = RegExp(
            r'data-id-product="(\d+)"[^>]*>[\s\S]*?href="([^"]+\.html)"',
          ).firstMatch(html);
          if (dataProductMatch != null) {
            final url = dataProductMatch.group(2);
            if (url != null && url.contains('tomosygrapas.com')) {
              debugPrint('TomosYGrapas HTML data-id: $url');
              return await _fetchProductDetails(url, isbn);
            }
          }
        }

        if (productLinkMatch != null) {
          final productUrl = productLinkMatch.group(1)!;
          debugPrint('TomosYGrapas HTML: Producto encontrado: $productUrl');
          return await _fetchProductDetails(productUrl, isbn);
        }

        // Intentar extraer datos directamente de la página
        return _parseSearchResults(html, isbn);
      }
    } catch (e) {
      debugPrint('TomosYGrapas HTML error: $e');
    }
    return null;
  }

  /// Obtiene los detalles de un producto desde su página
  Future<Book?> _fetchProductDetails(String productUrl, String isbn) async {
    try {
      final response = await http.get(
        Uri.parse(productUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'es-ES,es;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return _parseProductPage(response.body, isbn, sourceUrl: productUrl);
      }
    } catch (e) {
      debugPrint('TomosYGrapas product fetch error: $e');
    }
    return null;
  }

  /// Parsea la página de un producto
  Book? _parseProductPage(String html, String isbn, {String? sourceUrl}) {
    try {
      debugPrint('TomosYGrapas: Parseando página de producto...');

      String? title;
      String? coverUrl;
      String author = 'Desconocido';
      int totalPages = 0;
      String? publisher;

      // MÉTODO PRINCIPAL: Extraer del JSON en data-product (más fiable)
      final dataProductMatch = RegExp(
        r'data-product="([^"]*)"',
        caseSensitive: false,
      ).firstMatch(html);

      if (dataProductMatch != null) {
        try {
          // Decodificar HTML entities (&quot; -> ")
          String jsonStr = dataProductMatch.group(1)!;
          jsonStr = jsonStr
              .replaceAll('&quot;', '"')
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&#039;', "'")
              .replaceAll('&apos;', "'");

          final productData = json.decode(jsonStr) as Map<String, dynamic>;

          // Título
          title = productData['name'] as String?;
          debugPrint('TomosYGrapas JSON: Título = $title');

          // Portada desde cover.large.url
          if (productData['cover'] != null) {
            final cover = productData['cover'] as Map<String, dynamic>;
            if (cover['large'] != null) {
              coverUrl = (cover['large'] as Map<String, dynamic>)['url'] as String?;
            }
            // Alternativa: bySize.large_default
            if (coverUrl == null && cover['bySize'] != null) {
              final bySize = cover['bySize'] as Map<String, dynamic>;
              if (bySize['large_default'] != null) {
                coverUrl = (bySize['large_default'] as Map<String, dynamic>)['url'] as String?;
              }
            }
          }
          debugPrint('TomosYGrapas JSON: Cover = $coverUrl');

          // Features: Autor, Páginas, etc.
          if (productData['features'] != null) {
            final features = productData['features'] as List<dynamic>;
            for (final feature in features) {
              final featureMap = feature as Map<String, dynamic>;
              final name = (featureMap['name'] as String?)?.toLowerCase() ?? '';
              final value = featureMap['value'] as String?;

              if (name.contains('autor') || name.contains('guionista')) {
                author = value ?? author;
                debugPrint('TomosYGrapas JSON: Autor = $author');
              } else if (name.contains('página') || name.contains('pagina')) {
                totalPages = int.tryParse(value ?? '') ?? 0;
                debugPrint('TomosYGrapas JSON: Páginas = $totalPages');
              } else if (name.contains('editorial')) {
                publisher = value;
                debugPrint('TomosYGrapas JSON: Editorial = $publisher');
              }
            }
          }

        } catch (e) {
          debugPrint('TomosYGrapas: Error parseando data-product JSON: $e');
        }
      }

      // FALLBACK: Si no tenemos título, intentar otros métodos
      if (title == null || title.isEmpty) {
        // og:title
        final ogTitleMatch = RegExp(
          r'<meta\s+property="og:title"\s+content="([^"]+)"',
          caseSensitive: false,
        ).firstMatch(html);
        title = ogTitleMatch?.group(1)?.trim();

        // h1
        if (title == null) {
          final h1Match = RegExp(r'<h1[^>]*>([^<]+)</h1>').firstMatch(html);
          title = h1Match?.group(1)?.trim();
        }
      }

      if (title == null || title.isEmpty) {
        debugPrint('TomosYGrapas: No se encontró título');
        return null;
      }

      // FALLBACK: Portada desde og:image si no la tenemos
      if (coverUrl == null) {
        final ogImageMatch = RegExp(
          r'<meta\s+property="og:image"\s+content="([^"]+)"',
          caseSensitive: false,
        ).firstMatch(html);
        coverUrl = ogImageMatch?.group(1);
      }

      // Asegurar versión large de la imagen
      if (coverUrl != null) {
        coverUrl = coverUrl.replaceAll('-home_default/', '-large_default/');
        coverUrl = coverUrl.replaceAll('-medium_default/', '-large_default/');
        coverUrl = coverUrl.replaceAll('-small_default/', '-large_default/');
      }

      // Extraer número de volumen del título
      final volInfo = _extractVolumeFromTitle(title);

      debugPrint('TomosYGrapas FINAL: $title | Autor: $author | Vol: ${volInfo['volumeNumber']} | Páginas: $totalPages');

      return Book(
        isbn: isbn,
        title: title,
        author: author,
        coverUrl: coverUrl,
        totalPages: totalPages,
        seriesName: volInfo['seriesName'],
        volumeNumber: volInfo['volumeNumber'],
        publisher: publisher,
        apiSource: 'tomosygrapas',
        sourceUrl: sourceUrl,
      );
    } catch (e) {
      debugPrint('TomosYGrapas parse error: $e');
    }
    return null;
  }

  /// Intenta parsear resultados directamente de la página de búsqueda
  Book? _parseSearchResults(String html, String isbn) {
    try {
      // Buscar título del producto
      final titleMatch = RegExp(
        r'<a[^>]+class="[^"]*product-title[^"]*"[^>]*>([^<]+)</a>',
        caseSensitive: false,
      ).firstMatch(html);

      if (titleMatch == null) return null;

      final title = titleMatch.group(1)?.trim();
      if (title == null || title.isEmpty) return null;

      // Buscar imagen
      String? coverUrl;
      final imgMatch = RegExp(
        r'<img[^>]+src="(https://tienda\.tomosygrapas\.com/\d+-[^"]+\.jpg)"',
      ).firstMatch(html);
      coverUrl = imgMatch?.group(1);

      // Usar versión large si es posible
      if (coverUrl != null) {
        coverUrl = coverUrl.replaceAll('-home_default/', '-large_default/');
        coverUrl = coverUrl.replaceAll('-medium_default/', '-large_default/');
        coverUrl = coverUrl.replaceAll('-small_default/', '-large_default/');
      }

      final volInfo = _extractVolumeFromTitle(title);

      return Book(
        isbn: isbn,
        title: title,
        author: 'Desconocido',
        coverUrl: coverUrl,
        totalPages: 0,
        seriesName: volInfo['seriesName'],
        volumeNumber: volInfo['volumeNumber'],
        apiSource: 'tomosygrapas',
      );
    } catch (e) {
      debugPrint('TomosYGrapas search parse error: $e');
    }
    return null;
  }

  /// Extrae el número de volumen del título (delegado a VolumeExtractor)
  Map<String, dynamic> _extractVolumeFromTitle(String title) {
    final info = VolumeExtractor.extractFromTitle(title);
    if (info.volumeNumber != null) {
      debugPrint('TomosYGrapas: Volumen extraído: ${info.volumeNumber} de "$title"');
    }
    return {
      'seriesName': info.seriesName,
      'volumeNumber': info.volumeNumber,
    };
  }

  /// Busca portada por título y volumen
  Future<String?> searchCover(String seriesName, int volumeNumber) async {
    debugPrint('=== TomosYGrapas searchCover V3 ===');
    debugPrint('ENTRADA: seriesName="$seriesName", volumeNumber=$volumeNumber');

    // Detectar si es omnibus (ej: "ONE PIECE 3 EN 1")
    final volInfo = VolumeExtractor.extractFromTitle(seriesName);
    final isOmnibus = volInfo.isOmnibus || RegExp(r'\d+\s*[Ee][Nn]\s*1').hasMatch(seriesName);
    final baseSeriesName = volInfo.baseSeriesName;
    debugPrint('isOmnibus=$isOmnibus');

    // Generar queries usando QueryGenerator
    final queries = QueryGenerator.forCover(
      seriesName,
      volumeNumber,
      isOmnibus: isOmnibus,
      baseSeriesName: baseSeriesName,
    );

    // MÉTODO ESPECIAL: Para ONE PIECE 3 EN 1, intentar construir URL directamente
    if (isOmnibus && seriesName.toLowerCase().contains('one piece')) {
      final directCover = await _tryDirectOnePieceOmnibusUrl(volumeNumber);
      if (directCover != null) {
        debugPrint('TomosYGrapas: URL directa encontrada para One Piece 3en1 vol $volumeNumber');
        return directCover;
      }
    }

    final volStr = volumeNumber.toString();
    final volPadded = volStr.padLeft(2, '0');

    // Recopilar URLs de productos de la misma serie (para fallback de volúmenes relacionados)
    final sameSeriesProductUrls = <String>[];

    for (final query in queries) {
      // MÉTODO 1: Usar el endpoint AJAX
      try {
        debugPrint('TomosYGrapas AJAX search: "$query"');
        final ajaxUrl = Uri.parse(
          '$_baseUrl/es/module/leoproductsearch/productsearch?ajax=1&q=${Uri.encodeComponent(query)}',
        );

        final ajaxResponse = await http.get(
          ajaxUrl,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
            'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ).timeout(const Duration(seconds: 10));

        if (ajaxResponse.statusCode == 200) {
          try {
            final data = json.decode(ajaxResponse.body) as Map<String, dynamic>;
            final products = data['products'] as List<dynamic>?;

            if (products != null && products.isNotEmpty) {
              for (final product in products) {
                final productMap = product as Map<String, dynamic>;
                final name = (productMap['name'] as String?)?.toLowerCase() ?? '';
                final productUrl = productMap['url'] as String? ?? productMap['link'] as String?;

                debugPrint('TomosYGrapas AJAX: Analizando: "$name"');

                if (isOmnibus) {
                  final hasOmnibusPattern = RegExp(r'3\s*en\s*1', caseSensitive: false).hasMatch(name);
                  if (!hasOmnibusPattern) continue;
                }

                // Verificar que es de la misma serie
                final seriesBase = seriesName.toLowerCase()
                    .replaceAll(RegExp(r'\s*\d+\s*en\s*1\s*', caseSensitive: false), ' ')
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .trim();

                final nameBase = name
                    .replaceAll(RegExp(r'\s*\d+\s*en\s*1\s*', caseSensitive: false), ' ')
                    .replaceAll(RegExp(r'\s*\d+\s*$'), '')
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .trim();

                bool isSameSeries = nameBase.contains(seriesBase) || seriesBase.contains(nameBase);
                if (!isSameSeries) {
                  final mainName = seriesBase.split(' ').take(2).join(' ');
                  isSameSeries = nameBase.startsWith(mainName);
                }
                if (!isSameSeries) continue;

                // Verificar volumen
                bool hasCorrectVol = false;
                if (isOmnibus) {
                  final omnibusVolPatterns = [
                    RegExp(r'en\s*1\s+' + volStr + r'\s*$', caseSensitive: false),
                    RegExp(r'en\s*1\s+' + volPadded + r'\s*$', caseSensitive: false),
                    RegExp(r'en\s*1\s+' + volStr + r'[^\d]', caseSensitive: false),
                    RegExp(r'en\s*1\s+' + volPadded + r'[^\d]', caseSensitive: false),
                  ];
                  hasCorrectVol = omnibusVolPatterns.any((pattern) => pattern.hasMatch(name));
                } else {
                  final normalVolPatterns = [
                    RegExp(r'\s' + volStr + r'\s*$', caseSensitive: false),
                    RegExp(r'\s' + volPadded + r'\s*$', caseSensitive: false),
                    RegExp(r'(?:nº|n\.|vol\.?|#)\s*' + volStr + r'(?:[^\d]|$)', caseSensitive: false),
                    RegExp(r'(?:nº|n\.|vol\.?|#)\s*' + volPadded + r'(?:[^\d]|$)', caseSensitive: false),
                    RegExp(r'\s' + volStr + r'\s*:', caseSensitive: false),
                    RegExp(r'\s' + volPadded + r'\s*:', caseSensitive: false),
                    RegExp(r'\s' + volStr + r'\s*-', caseSensitive: false),
                    RegExp(r'\s' + volPadded + r'\s*-', caseSensitive: false),
                  ];
                  hasCorrectVol = normalVolPatterns.any((pattern) => pattern.hasMatch(name));
                }

                // Verificacion omnibus adicional
                final queryLower = query.toLowerCase();
                final seriesLower = seriesName.toLowerCase();
                final searchingOmnibus = RegExp(r'\d+\s*en\s*1', caseSensitive: false).hasMatch(queryLower) ||
                                         RegExp(r'\d+\s*en\s*1', caseSensitive: false).hasMatch(seriesLower);
                final productHasOmnibus = RegExp(r'\d+\s*en\s*1', caseSensitive: false).hasMatch(name);

                if (searchingOmnibus && !productHasOmnibus) continue;

                if (hasCorrectVol) {
                  // Extraer URL de portada
                  String? coverUrl;
                  if (productMap['cover'] != null) {
                    final cover = productMap['cover'] as Map<String, dynamic>;
                    if (cover['large'] != null) {
                      coverUrl = (cover['large'] as Map<String, dynamic>)['url'] as String?;
                    } else if (cover['bySize'] != null) {
                      final bySize = cover['bySize'] as Map<String, dynamic>;
                      coverUrl = (bySize['large_default'] as Map<String, dynamic>?)?['url'] as String?;
                      coverUrl ??= (bySize['medium_default'] as Map<String, dynamic>?)?['url'] as String?;
                      coverUrl ??= (bySize['home_default'] as Map<String, dynamic>?)?['url'] as String?;
                    }
                  }

                  if (coverUrl != null && isOmnibus) {
                    final coverUrlLower = coverUrl.toLowerCase();
                    final hasOmnibusInUrl = coverUrlLower.contains('3-en-1') ||
                        coverUrlLower.contains('3en1') ||
                        coverUrlLower.contains('3_en_1');
                    if (!hasOmnibusInUrl) continue;
                  }

                  if (coverUrl != null) {
                    coverUrl = coverUrl.replaceAll('-home_default/', '-large_default/');
                    coverUrl = coverUrl.replaceAll('-medium_default/', '-large_default/');
                    coverUrl = coverUrl.replaceAll('-small_default/', '-large_default/');
                    debugPrint('TomosYGrapas AJAX: Portada vol $volumeNumber: $coverUrl');
                    return coverUrl;
                  }
                } else if (productUrl != null && isSameSeries && sameSeriesProductUrls.length < 3) {
                  // No es el volumen que buscamos, pero es de la misma serie
                  // Guardar URL para intentar descubrir el volumen via página de producto
                  if (!sameSeriesProductUrls.contains(productUrl)) {
                    sameSeriesProductUrls.add(productUrl);
                    debugPrint('TomosYGrapas: Guardando URL de la misma serie: $productUrl');
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('TomosYGrapas AJAX JSON parse error: $e');
          }
        }
      } catch (e) {
        debugPrint('TomosYGrapas AJAX error: $e');
      }

      // MÉTODO 2: Fallback a búsqueda HTML
      try {
        debugPrint('TomosYGrapas HTML search: "$query"');
        final searchUrl = Uri.parse(
          '$_baseUrl/es/buscar?controller=search&s=${Uri.encodeComponent(query)}',
        );

        final response = await http.get(
          searchUrl,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
            'Accept': 'text/html',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final html = response.body;

          final imgPatterns = [
            RegExp(r'<img[^>]+src="(https://tienda\.tomosygrapas\.com/(\d+)-[^"]+\.jpg)"', caseSensitive: false),
            RegExp(r'data-src="(https://tienda\.tomosygrapas\.com/(\d+)-[^"]+\.jpg)"', caseSensitive: false),
            RegExp(r'src="(https://[^"]*tomosygrapas[^"]+/(\d+)-[^"]+\.(?:jpg|webp|png))"', caseSensitive: false),
          ];

          for (final pattern in imgPatterns) {
            final matches = pattern.allMatches(html);
            for (final match in matches) {
              var imgUrl = match.group(1);
              if (imgUrl == null) continue;
              if (imgUrl.contains('logo') || imgUrl.contains('banner') || imgUrl.contains('icon')) continue;

              final imgUrlLower = imgUrl.toLowerCase();

              if (isOmnibus) {
                final hasOmnibusInUrl = imgUrlLower.contains('3-en-1') ||
                    imgUrlLower.contains('3en1') ||
                    imgUrlLower.contains('3_en_1');
                if (!hasOmnibusInUrl) continue;
              }

              final urlVolPatterns = [
                RegExp(r'[-_]' + volStr + r'[-_\.]', caseSensitive: false),
                RegExp(r'[-_]' + volPadded + r'[-_\.]', caseSensitive: false),
                RegExp(r'[-_]' + volStr + r'$', caseSensitive: false),
              ];

              final hasVolInUrl = urlVolPatterns.any((p) => p.hasMatch(imgUrlLower.replaceAll('.jpg', '').replaceAll('.webp', '').replaceAll('.png', '')));

              if (hasVolInUrl) {
                imgUrl = imgUrl.replaceAll('-home_default/', '-large_default/');
                imgUrl = imgUrl.replaceAll('-medium_default/', '-large_default/');
                imgUrl = imgUrl.replaceAll('-small_default/', '-large_default/');
                debugPrint('TomosYGrapas HTML: Portada vol $volumeNumber: $imgUrl');
                return imgUrl;
              }
            }
          }

          // Recopilar URLs de productos de la misma serie desde HTML
          if (sameSeriesProductUrls.length < 3) {
            final seriesSlug = seriesName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
            final productLinkPattern = RegExp(
              r'href="(https://tienda\.tomosygrapas\.com/es/[^"]*' + RegExp.escape(seriesSlug.split('-').first) + r'[^"]*\.html)"',
              caseSensitive: false,
            );
            final linkMatches = productLinkPattern.allMatches(html);
            for (final linkMatch in linkMatches) {
              final url = linkMatch.group(1);
              if (url != null && !sameSeriesProductUrls.contains(url)) {
                sameSeriesProductUrls.add(url);
                if (sameSeriesProductUrls.length >= 3) break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('TomosYGrapas HTML error: $e');
      }
    }

    // MÉTODO 3: Si encontramos productos de la misma serie pero no el volumen exacto,
    // intentar descubrir el volumen via la página de producto (productos relacionados)
    if (sameSeriesProductUrls.isNotEmpty) {
      debugPrint('TomosYGrapas: Intentando descubrir vol $volumeNumber via ${sameSeriesProductUrls.length} URLs de la misma serie');
      for (final productUrl in sameSeriesProductUrls) {
        final cover = await _discoverVolumeFromProductPage(productUrl, seriesName, volumeNumber);
        if (cover != null) {
          debugPrint('TomosYGrapas: Portada descubierta via producto relacionado: $cover');
          return cover;
        }
      }
    }

    debugPrint('TomosYGrapas: No se encontro portada para vol $volumeNumber');
    return null;
  }

  /// Intenta descubrir la portada de un volumen específico visitando la página de otro volumen
  /// de la misma serie y buscando enlaces/imágenes del volumen objetivo
  Future<String?> _discoverVolumeFromProductPage(String productUrl, String seriesName, int targetVolume) async {
    try {
      debugPrint('TomosYGrapas: Visitando $productUrl para descubrir vol $targetVolume');

      final response = await http.get(
        Uri.parse(productUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'es-ES,es;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final html = response.body;
      final volStr = targetVolume.toString();
      final volPadded = volStr.padLeft(2, '0');

      // Estrategia 1: Buscar enlace al producto del volumen objetivo en la misma página
      // T&G suele tener "productos relacionados" o "accesorios" en la página
      final seriesSlug = seriesName.toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      final mainWords = seriesSlug.split('-').where((w) => w.length > 2).take(2).toList();

      // Buscar URLs de productos que contengan el nombre de la serie Y el volumen
      final targetUrlPatterns = [
        // URL con volumen zero-padded: radiant-black-01
        RegExp(
          r'href="(https://tienda\.tomosygrapas\.com/es/[^"]*' +
          mainWords.join('[^"]*') +
          r'[^"]*[-/]' + volPadded + r'[^"]*\.html)"',
          caseSensitive: false,
        ),
        // URL con volumen sin padding: radiant-black-1
        if (targetVolume < 10) RegExp(
          r'href="(https://tienda\.tomosygrapas\.com/es/[^"]*' +
          mainWords.join('[^"]*') +
          r'[^"]*[-/]' + volStr + r'[-/][^"]*\.html)"',
          caseSensitive: false,
        ),
      ];

      for (final pattern in targetUrlPatterns) {
        final match = pattern.firstMatch(html);
        if (match != null) {
          final targetUrl = match.group(1)!;
          debugPrint('TomosYGrapas: Encontrado enlace al vol $targetVolume: $targetUrl');

          // Visitar esa página y extraer la portada
          final book = await _fetchProductDetails(targetUrl, '');
          if (book?.coverUrl != null && book!.coverUrl!.isNotEmpty) {
            return book.coverUrl;
          }
        }
      }

      // Estrategia 2: Buscar en el data-product JSON de productos relacionados
      final accessoryPattern = RegExp(
        r'var\s+(?:productAccessories|accessories|relatedProducts)\s*=\s*(\[[\s\S]*?\]);',
        caseSensitive: false,
      );
      final accessoryMatch = accessoryPattern.firstMatch(html);
      if (accessoryMatch != null) {
        try {
          final jsonStr = accessoryMatch.group(1)!;
          final products = json.decode(jsonStr) as List<dynamic>;
          for (final product in products) {
            final productMap = product as Map<String, dynamic>;
            final name = (productMap['name'] as String?)?.toLowerCase() ?? '';

            // Verificar que es de la misma serie y tiene el volumen correcto
            final hasSeriesWords = mainWords.every((word) => name.contains(word));
            if (!hasSeriesWords) continue;

            final volPatterns = [
              RegExp(r'\s' + volStr + r'(?:\s|$|:|-)', caseSensitive: false),
              RegExp(r'\s' + volPadded + r'(?:\s|$|:|-)', caseSensitive: false),
            ];
            final hasVol = volPatterns.any((p) => p.hasMatch(name));
            if (!hasVol) continue;

            // Extraer cover
            String? coverUrl;
            if (productMap['cover'] != null) {
              final cover = productMap['cover'] as Map<String, dynamic>;
              if (cover['large'] != null) {
                coverUrl = (cover['large'] as Map<String, dynamic>)['url'] as String?;
              } else if (cover['bySize'] != null) {
                final bySize = cover['bySize'] as Map<String, dynamic>;
                coverUrl = (bySize['large_default'] as Map<String, dynamic>?)?['url'] as String?;
              }
            }

            if (coverUrl != null) {
              coverUrl = coverUrl.replaceAll('-home_default/', '-large_default/');
              coverUrl = coverUrl.replaceAll('-medium_default/', '-large_default/');
              debugPrint('TomosYGrapas: Portada descubierta en accesorios: $coverUrl');
              return coverUrl;
            }
          }
        } catch (e) {
          debugPrint('TomosYGrapas: Error parseando accesorios JSON: $e');
        }
      }

      // Estrategia 3: Derivar la URL del producto objetivo a partir de la URL del producto conocido
      // Ejemplo: si tenemos ".../25011-radiant-black-04-..."
      // intentar ".../25008-radiant-black-01-..." (asumiendo IDs consecutivos)
      final urlIdMatch = RegExp(r'/(\d+)-([^/]+)\.html$').firstMatch(productUrl);
      if (urlIdMatch != null) {
        final knownId = int.tryParse(urlIdMatch.group(1) ?? '');
        final knownSlug = urlIdMatch.group(2) ?? '';

        // Extraer el volumen del producto conocido
        final knownVolMatch = RegExp(r'[-](\d{2})[-]').firstMatch(knownSlug);
        if (knownId != null && knownVolMatch != null) {
          final knownVol = int.tryParse(knownVolMatch.group(1) ?? '');
          if (knownVol != null && knownVol != targetVolume) {
            // Calcular diferencia de IDs (asumiendo productos consecutivos)
            final idDiff = knownVol - targetVolume;
            final targetId = knownId - idDiff;

            // Construir slug del volumen objetivo
            final targetSlug = knownSlug.replaceFirst(
              RegExp(r'(\d{2})'),
              volPadded,
            );

            // Intentar la URL construida
            final basePath = productUrl.substring(0, productUrl.lastIndexOf('/'));
            final guessedUrl = '$basePath/$targetId-$targetSlug.html';
            debugPrint('TomosYGrapas: Intentando URL derivada: $guessedUrl');

            try {
              final guessResponse = await http.get(
                Uri.parse(guessedUrl),
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
                  'Accept': 'text/html',
                },
              ).timeout(const Duration(seconds: 10));

              if (guessResponse.statusCode == 200) {
                final book = _parseProductPage(guessResponse.body, '', sourceUrl: guessedUrl);
                if (book?.coverUrl != null && book!.coverUrl!.isNotEmpty) {
                  debugPrint('TomosYGrapas: Portada encontrada via URL derivada: ${book.coverUrl}');
                  return book.coverUrl;
                }
              }
            } catch (e) {
              debugPrint('TomosYGrapas: URL derivada falló: $e');
            }

            // Intentar variaciones del ID (+/- 1, 2, 3)
            for (final offset in [0, -1, 1, -2, 2, -3, 3]) {
              if (offset == 0) continue;
              final altId = targetId + offset;
              final altUrl = '$basePath/$altId-$targetSlug.html';
              try {
                final altResponse = await http.get(
                  Uri.parse(altUrl),
                  headers: {
                    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
                    'Accept': 'text/html',
                  },
                ).timeout(const Duration(seconds: 5));

                if (altResponse.statusCode == 200 &&
                    altResponse.body.contains(seriesName.split(' ').first)) {
                  final book = _parseProductPage(altResponse.body, '', sourceUrl: altUrl);
                  if (book?.coverUrl != null && book!.coverUrl!.isNotEmpty) {
                    debugPrint('TomosYGrapas: Portada encontrada via URL derivada (offset $offset): ${book.coverUrl}');
                    return book.coverUrl;
                  }
                }
              } catch (_) {}
            }
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('TomosYGrapas: Error descubriendo vol $targetVolume: $e');
      return null;
    }
  }

  /// Intenta obtener la portada de One Piece 3en1 directamente por ISBN
  /// Tomos y Grapas tiene un bug donde algunos volúmenes no aparecen en búsqueda
  Future<String?> _tryDirectOnePieceOmnibusUrl(int volumeNumber) async {
    // ISBNs conocidos de ONE PIECE 3 EN 1 (Planeta España)
    // Verificados en Amazon, Universal Comics, Casa del Libro
    final knownIsbns = {
      1: '9788411406710',
      2: '9788411406727',
      3: '9788411406734',
      4: '9788411406741',
      5: '9788411610773',
      6: '9788411611206',
      7: '9788411611831',
      8: '9788411612401',
      9: '9788411612845',
      10: '9788411613460',
      11: '9788411618892',
      12: '9788410492653',
    };

    final isbn = knownIsbns[volumeNumber];
    if (isbn == null) {
      debugPrint('TomosYGrapas: No tengo ISBN para One Piece 3en1 vol $volumeNumber');
      return null;
    }

    debugPrint('TomosYGrapas: Buscando One Piece 3en1 vol $volumeNumber por ISBN: $isbn');

    try {
      // Buscar por ISBN en la API
      final ajaxUrl = Uri.parse(
        '$_baseUrl/es/module/leoproductsearch/productsearch?ajax=1&q=$isbn',
      );

      final response = await http.get(
        ajaxUrl,
        headers: HttpConfig.ajaxHeaders,
      ).timeout(HttpConfig.standardTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final products = data['products'] as List<dynamic>?;

        if (products != null && products.isNotEmpty) {
          final product = products.first as Map<String, dynamic>;
          final name = (product['name'] as String?)?.toLowerCase() ?? '';

          // Verificar que es el producto correcto
          if (name.contains('one piece') && name.contains('3 en 1')) {
            String? coverUrl;
            if (product['cover'] != null) {
              final cover = product['cover'] as Map<String, dynamic>;
              if (cover['large'] != null) {
                coverUrl = (cover['large'] as Map<String, dynamic>)['url'] as String?;
              } else if (cover['bySize'] != null) {
                final bySize = cover['bySize'] as Map<String, dynamic>;
                coverUrl = (bySize['large_default'] as Map<String, dynamic>?)?['url'] as String?;
              }
            }

            if (coverUrl != null) {
              coverUrl = coverUrl.replaceAll('-home_default/', '-large_default/');
              coverUrl = coverUrl.replaceAll('-medium_default/', '-large_default/');
              debugPrint('TomosYGrapas: ✅ Portada por ISBN: $coverUrl');
              return coverUrl;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('TomosYGrapas: Error buscando por ISBN: $e');
    }

    return null;
  }

  /// Busca múltiples portadas para un query (para selección manual)
  Future<List<String>> searchCoversMultiple(String query, {int limit = 8}) async {
    final results = <String>[];

    try {
      debugPrint('TomosYGrapas: Buscando múltiples portadas para: $query');

      // Usar endpoint AJAX
      final ajaxUrl = Uri.parse(
        '$_baseUrl/es/module/leoproductsearch/productsearch?ajax=1&q=${Uri.encodeComponent(query)}',
      );

      final response = await http.get(
        ajaxUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final products = data['products'] as List<dynamic>?;

        if (products != null) {
          for (final product in products) {
            if (results.length >= limit) break;

            final productMap = product as Map<String, dynamic>;
            String? coverUrl;

            if (productMap['cover'] != null) {
              final cover = productMap['cover'] as Map<String, dynamic>;
              if (cover['large'] != null) {
                coverUrl = (cover['large'] as Map<String, dynamic>)['url'] as String?;
              } else if (cover['bySize'] != null) {
                final bySize = cover['bySize'] as Map<String, dynamic>;
                coverUrl = (bySize['large_default'] as Map<String, dynamic>?)?['url'] as String?;
                coverUrl ??= (bySize['medium_default'] as Map<String, dynamic>?)?['url'] as String?;
              }
            }

            if (coverUrl != null && coverUrl.isNotEmpty) {
              // Asegurar versión large
              coverUrl = coverUrl.replaceAll('-home_default/', '-large_default/');
              coverUrl = coverUrl.replaceAll('-medium_default/', '-large_default/');
              coverUrl = coverUrl.replaceAll('-small_default/', '-large_default/');

              if (!results.contains(coverUrl)) {
                results.add(coverUrl);
                debugPrint('TomosYGrapas: Portada encontrada: $coverUrl');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('TomosYGrapas searchCoversMultiple error: $e');
    }

    debugPrint('TomosYGrapas: ${results.length} portadas encontradas');
    return results;
  }

  /// Extrae volúmenes relacionados de una página de producto
  /// Devuelve un Map de volumeNumber -> {coverUrl, productUrl, isbn}
  Future<Map<int, Map<String, String>>> getRelatedVolumes(String productUrl) async {
    final relatedVolumes = <int, Map<String, String>>{};

    try {
      debugPrint('TomosYGrapas: Buscando volúmenes relacionados en: $productUrl');

      final response = await http.get(
        Uri.parse(productUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'es-ES,es;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return relatedVolumes;

      final html = response.body;

      // Buscar el bloque de productos relacionados (accessory-block o similar)
      // También buscar en el carrusel de productos
      final relatedPatterns = [
        // Patrón para enlaces de productos relacionados con imagen
        RegExp(
          r'<a[^>]+href="(https://tienda\.tomosygrapas\.com/es/[^"]+\.html)"[^>]*>[\s\S]*?<img[^>]+src="([^"]+)"',
          caseSensitive: false,
        ),
        // Patrón alternativo: imagen primero, luego enlace
        RegExp(
          r'<img[^>]+src="([^"]+)"[^>]*>[\s\S]*?<a[^>]+href="(https://tienda\.tomosygrapas\.com/es/[^"]+\.html)"',
          caseSensitive: false,
        ),
      ];

      // Obtener el título actual para identificar la serie
      String? currentTitle;
      final titleMatch = RegExp(r'<h1[^>]*>([^<]+)</h1>').firstMatch(html);
      currentTitle = titleMatch?.group(1)?.toLowerCase().trim();

      // Extraer nombre base de la serie del producto actual
      String? seriesBase;
      if (currentTitle != null) {
        // Quitar número de volumen del final
        seriesBase = currentTitle
            .replaceAll(RegExp(r'\s*\d+\s*$'), '')
            .replaceAll(RegExp(r'\s*\(de\s*\d+\)\s*$', caseSensitive: false), '')
            .trim();
        debugPrint('TomosYGrapas: Serie base detectada: $seriesBase');
      }

      // Buscar todos los productos en la página
      for (final pattern in relatedPatterns) {
        final matches = pattern.allMatches(html);
        for (final match in matches) {
          String? url, imgUrl;

          // El orden de captura depende del patrón
          if (pattern.pattern.contains('<a[^>]+href')) {
            url = match.group(1);
            imgUrl = match.group(2);
          } else {
            imgUrl = match.group(1);
            url = match.group(2);
          }

          if (url == null || imgUrl == null) continue;
          if (imgUrl.contains('logo') || imgUrl.contains('banner')) continue;

          // Extraer el nombre del producto de la URL
          // Formato: tienda.tomosygrapas.com/es/manga/12345-nombre-producto.html
          final urlName = url.split('/').last.replaceAll('.html', '');
          final nameParts = urlName.split('-');
          if (nameParts.length < 2) continue;

          // Quitar el ID del producto del inicio
          nameParts.removeAt(0);
          final productName = nameParts.join('-').toLowerCase();

          // Verificar que es de la misma serie
          if (seriesBase != null) {
            final seriesWords = seriesBase.split(' ').where((w) => w.length > 2).take(2);
            final matchesSeries = seriesWords.every((word) => productName.contains(word));
            if (!matchesSeries) continue;
          }

          // Extraer número de volumen
          final volInfo = _extractVolumeFromTitle(productName.replaceAll('-', ' '));
          final volumeNumber = volInfo['volumeNumber'] as int?;

          if (volumeNumber != null) {
            // Asegurar versión large de la imagen
            var coverUrl = imgUrl.replaceAll('-home_default/', '-large_default/');
            coverUrl = coverUrl.replaceAll('-medium_default/', '-large_default/');
            coverUrl = coverUrl.replaceAll('-small_default/', '-large_default/');

            relatedVolumes[volumeNumber] = {
              'coverUrl': coverUrl,
              'productUrl': url,
            };
            debugPrint('TomosYGrapas: Volumen relacionado $volumeNumber: $coverUrl');
          }
        }
      }

      // Método adicional: buscar en el JSON de productos relacionados si existe
      final jsonDataMatch = RegExp(
        r'var\s+productAccessories\s*=\s*(\[[\s\S]*?\]);',
        caseSensitive: false,
      ).firstMatch(html);

      if (jsonDataMatch != null) {
        try {
          final jsonStr = jsonDataMatch.group(1)!;
          final products = json.decode(jsonStr) as List<dynamic>;

          for (final product in products) {
            final productMap = product as Map<String, dynamic>;
            final name = (productMap['name'] as String?)?.toLowerCase() ?? '';
            final productUrl = productMap['url'] as String? ?? productMap['link'] as String?;

            // Verificar que es de la misma serie
            if (seriesBase != null) {
              final matchesSeries = seriesBase.split(' ').where((w) => w.length > 2).take(2).every((word) => name.contains(word));
              if (!matchesSeries) continue;
            }

            final volInfo = _extractVolumeFromTitle(name);
            final volumeNumber = volInfo['volumeNumber'] as int?;

            if (volumeNumber != null) {
              String? coverUrl;
              if (productMap['cover'] != null) {
                final cover = productMap['cover'] as Map<String, dynamic>;
                if (cover['large'] != null) {
                  coverUrl = (cover['large'] as Map<String, dynamic>)['url'] as String?;
                }
              }

              if (coverUrl != null && productUrl != null) {
                relatedVolumes[volumeNumber] = {
                  'coverUrl': coverUrl,
                  'productUrl': productUrl,
                };
              }
            }
          }
        } catch (e) {
          debugPrint('TomosYGrapas: Error parseando JSON de relacionados: $e');
        }
      }

      debugPrint('TomosYGrapas: Encontrados ${relatedVolumes.length} volúmenes relacionados');
    } catch (e) {
      debugPrint('TomosYGrapas: Error obteniendo relacionados: $e');
    }

    return relatedVolumes;
  }

  /// Busca la portada de un volumen específico usando la URL de otro volumen de la misma serie
  Future<String?> getCoverFromRelatedVolume(String sourceUrl, int targetVolume) async {
    final related = await getRelatedVolumes(sourceUrl);
    final volumeData = related[targetVolume];
    return volumeData?['coverUrl'];
  }

  /// Busca todos los volúmenes de una serie por nombre
  /// Devuelve un Map de volumeNumber -> {isbn, title, coverUrl, productUrl}
  /// Esto permite obtener los ISBNs reales de cada volumen
  Future<Map<int, Map<String, String>>> searchSeriesVolumes(String seriesName) async {
    final volumes = <int, Map<String, String>>{};

    debugPrint('╔════════════════════════════════════════╗');
    debugPrint('║ BUSCANDO VOLÚMENES DE SERIE EN T&G     ║');
    debugPrint('╠════════════════════════════════════════╣');
    debugPrint('║ Serie: $seriesName');
    debugPrint('╚════════════════════════════════════════╝');

    // Detectar si es omnibus
    final isOmnibus = RegExp(r'\d+\s*[Ee][Nn]\s*1', caseSensitive: false).hasMatch(seriesName);

    // Generar queries de búsqueda
    final queries = <String>[
      seriesName,
      // Si es omnibus, buscar también con formato estándar
      if (isOmnibus) seriesName.replaceAll(RegExp(r'\s*\d+\s*[Ee][Nn]\s*1', caseSensitive: false), '').trim() + ' 3 en 1',
    ];

    // Conjunto para evitar URLs duplicadas
    final visitedUrls = <String>{};

    for (final query in queries) {
      try {
        debugPrint('TomosYGrapas: Buscando serie con query: "$query"');

        final ajaxUrl = Uri.parse(
          '$_baseUrl/es/module/leoproductsearch/productsearch?ajax=1&q=${Uri.encodeComponent(query)}',
        );

        final response = await http.get(
          ajaxUrl,
          headers: HttpConfig.ajaxHeaders,
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) continue;

        final data = json.decode(response.body) as Map<String, dynamic>;
        final products = data['products'] as List<dynamic>?;

        if (products == null || products.isEmpty) continue;

        // Extraer nombre base de la serie para comparar
        final seriesBase = seriesName.toLowerCase()
            .replaceAll(RegExp(r'\s*\d+\s*en\s*1\s*', caseSensitive: false), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final seriesWords = seriesBase.split(' ').where((w) => w.length > 2).take(3).toList();

        for (final product in products) {
          final productMap = product as Map<String, dynamic>;
          final name = (productMap['name'] as String?)?.toLowerCase() ?? '';
          final productUrl = productMap['url'] as String? ?? productMap['link'] as String?;

          // Verificar que es de la misma serie
          final matchesSeries = seriesWords.every((word) => name.contains(word));
          if (!matchesSeries) continue;

          // Verificar omnibus si es necesario
          if (isOmnibus) {
            final productHasOmnibus = RegExp(r'\d+\s*en\s*1', caseSensitive: false).hasMatch(name);
            if (!productHasOmnibus) continue;
          }

          // Extraer número de volumen
          final volInfo = _extractVolumeFromTitle(productMap['name'] as String? ?? '');
          final volumeNumber = volInfo['volumeNumber'] as int?;

          if (volumeNumber == null) continue;
          if (volumes.containsKey(volumeNumber)) continue; // Ya tenemos este volumen

          // Extraer cover URL
          String? coverUrl;
          if (productMap['cover'] != null) {
            final cover = productMap['cover'] as Map<String, dynamic>;
            if (cover['large'] != null) {
              coverUrl = (cover['large'] as Map<String, dynamic>)['url'] as String?;
            } else if (cover['bySize'] != null) {
              final bySize = cover['bySize'] as Map<String, dynamic>;
              coverUrl = (bySize['large_default'] as Map<String, dynamic>?)?['url'] as String?;
            }
          }

          if (coverUrl != null) {
            coverUrl = coverUrl.replaceAll('-home_default/', '-large_default/');
            coverUrl = coverUrl.replaceAll('-medium_default/', '-large_default/');
          }

          // Si tenemos URL del producto, obtener ISBN de la página
          if (productUrl != null && !visitedUrls.contains(productUrl)) {
            visitedUrls.add(productUrl);
            final isbn = await _fetchIsbnFromProductPage(productUrl);

            if (isbn != null && isbn.isNotEmpty) {
              volumes[volumeNumber] = {
                'isbn': isbn,
                'title': productMap['name'] as String? ?? '',
                'coverUrl': coverUrl ?? '',
                'productUrl': productUrl,
              };
              debugPrint('✅ Vol.$volumeNumber: ISBN=$isbn, Cover=${coverUrl != null ? "✓" : "✗"}');
            }
          }

          // Pausa para no saturar el servidor
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } catch (e) {
        debugPrint('TomosYGrapas searchSeriesVolumes error: $e');
      }
    }

    debugPrint('📚 Total volúmenes encontrados con ISBN real: ${volumes.length}');
    return volumes;
  }

  /// Obtiene el ISBN de una página de producto
  Future<String?> _fetchIsbnFromProductPage(String productUrl) async {
    try {
      final response = await http.get(
        Uri.parse(productUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'es-ES,es;q=0.9',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final html = response.body;

      // Buscar ISBN en el data-product JSON
      final dataProductMatch = RegExp(
        r'data-product="([^"]*)"',
        caseSensitive: false,
      ).firstMatch(html);

      if (dataProductMatch != null) {
        try {
          String jsonStr = dataProductMatch.group(1)!;
          jsonStr = jsonStr
              .replaceAll('&quot;', '"')
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&#039;', "'")
              .replaceAll('&apos;', "'");

          final productData = json.decode(jsonStr) as Map<String, dynamic>;

          // Buscar ISBN/EAN en features
          if (productData['features'] != null) {
            final features = productData['features'] as List<dynamic>;
            for (final feature in features) {
              final featureMap = feature as Map<String, dynamic>;
              final name = (featureMap['name'] as String?)?.toLowerCase() ?? '';
              final value = featureMap['value'] as String?;

              if ((name.contains('isbn') || name.contains('ean')) && value != null) {
                // Limpiar el ISBN
                final cleanIsbn = value.replaceAll(RegExp(r'[^0-9X]'), '');
                if (cleanIsbn.length >= 10) {
                  return cleanIsbn;
                }
              }
            }
          }

          // Buscar en reference o ean del producto
          if (productData['ean13'] != null) {
            final ean = productData['ean13'] as String?;
            if (ean != null && ean.length >= 10) return ean;
          }
          if (productData['reference'] != null) {
            final ref = productData['reference'] as String?;
            if (ref != null && ref.length >= 10) return ref;
          }
        } catch (e) {
          debugPrint('Error parseando JSON para ISBN: $e');
        }
      }

      // Fallback: buscar ISBN en el HTML con patrones
      final isbnPatterns = [
        RegExp(r'ISBN[:\s]*(\d{10,13})', caseSensitive: false),
        RegExp(r'EAN[:\s]*(\d{13})', caseSensitive: false),
        RegExp(r'978[-\s]?\d[-\s]?\d{2,5}[-\s]?\d{2,7}[-\s]?\d'),
        RegExp(r'978\d{10}'),
      ];

      for (final pattern in isbnPatterns) {
        final match = pattern.firstMatch(html);
        if (match != null) {
          final isbn = match.group(0)?.replaceAll(RegExp(r'[^0-9X]'), '') ??
                       match.group(1)?.replaceAll(RegExp(r'[^0-9X]'), '');
          if (isbn != null && isbn.length >= 10) {
            return isbn;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error obteniendo ISBN de $productUrl: $e');
      return null;
    }
  }

  /// Verifica si el servicio está disponible
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
