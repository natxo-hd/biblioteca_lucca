import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/book.dart';
import '../utils/volume_extractor.dart';
import '../utils/query_generator.dart';
import 'api/tomosygrapas_client.dart';
import 'api/comicvine_api_client.dart';

class BookApiService {
  static const String _baseUrl = 'https://openlibrary.org';
  static const String _googleBooksUrl = 'https://www.googleapis.com/books/v1/volumes';

  final TomosYGrapasClient _tomosYGrapasClient = TomosYGrapasClient();
  final ComicVineApiClient _comicVineClient = ComicVineApiClient();

  Future<Book?> searchByIsbn(String isbn) async {
    // Limpiar ISBN (quitar guiones y espacios)
    final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '');
    debugPrint('=== BUSCANDO ISBN: $cleanIsbn ===');

    Book? book;

    // 1. PRIMERO: Tomos y Grapas (mejor fuente para manga/cómics españoles)
    // Tiene: volumen, páginas, portada, editorial, autor
    debugPrint('Buscando en Tomos y Grapas...');
    book = await _tomosYGrapasClient.searchByIsbn(cleanIsbn);

    if (book != null) {
      debugPrint('=== ENCONTRADO EN TOMOS Y GRAPAS: ${book.title} (Vol: ${book.volumeNumber}, Págs: ${book.totalPages}) ===');
      return book;
    }

    // 2. Si no encuentra, intentar con Open Library
    debugPrint('No encontrado en Tomos y Grapas, buscando en Open Library...');
    book = await _searchOpenLibrary(cleanIsbn);

    // 3. Si no encuentra, intentar con Google Books
    if (book == null) {
      debugPrint('No encontrado en Open Library, buscando en Google Books...');
      book = await _searchGoogleBooks(cleanIsbn);
    }

    // 4. Si no hay portada, buscar en diferentes fuentes
    if (book != null && (book.coverUrl == null || book.coverUrl!.isEmpty)) {
      // Para ISBN español: probar Casa del Libro PRIMERO (tiene portadas reales)
      // antes de buscar por título en T&G (que puede devolver figuras/merchandising)
      if (cleanIsbn.startsWith('97884')) {
        debugPrint('ISBN español sin portada, probando Casa del Libro...');
        final casaUrl = _buildCasaDelLibroCoverUrl(cleanIsbn);
        if (await _validateCoverUrl(casaUrl)) {
          book = book.copyWith(coverUrl: casaUrl);
          debugPrint('Portada encontrada en Casa del Libro: $casaUrl');
        }
      }

      // Si aún no hay portada, buscar en Tomos y Grapas
      if (book.coverUrl == null || book.coverUrl!.isEmpty) {
        // Si tenemos volumen, buscar con volume matching (evita devolver portada de otro vol)
        if (book.volumeNumber != null) {
          final seriesName = book.seriesName ?? book.title;
          debugPrint('Sin portada, buscando vol ${book.volumeNumber} de "$seriesName" en T&G...');
          final volumeCover = await _tomosYGrapasClient.searchCover(seriesName, book.volumeNumber!);
          if (volumeCover != null) {
            book = book.copyWith(coverUrl: volumeCover);
            debugPrint('Portada encontrada en T&G por serie+vol: $volumeCover');
          }
        }
        // Si aún no hay portada, buscar genérico por título
        if (book.coverUrl == null || book.coverUrl!.isEmpty) {
          debugPrint('Sin portada, buscando por título en Tomos y Grapas: ${book.title}');
          final titleCovers = await _tomosYGrapasClient.searchCoversMultiple(
            book.title,
            limit: 1,
          );
          if (titleCovers.isNotEmpty) {
            book = book.copyWith(coverUrl: titleCovers.first);
            debugPrint('Portada encontrada en T&G por título: ${titleCovers.first}');
          }
        }
      }
    }

    if (book != null) {
      debugPrint('=== LIBRO ENCONTRADO: ${book.title} (Vol: ${book.volumeNumber}) ===');
    } else {
      debugPrint('=== LIBRO NO ENCONTRADO ===');
    }

    return book;
  }

  Future<Book?> _searchOpenLibrary(String cleanIsbn) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/api/books?bibkeys=ISBN:$cleanIsbn&format=json&jscmd=data',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.isEmpty) {
          return null;
        }

        final bookData = data['ISBN:$cleanIsbn'];
        if (bookData == null) {
          return null;
        }

        return await _parseBookData(cleanIsbn, bookData);
      }
      return null;
    } catch (e) {
      debugPrint('Error buscando en Open Library: $e');
      return null;
    }
  }

  Future<Book?> _searchGoogleBooks(String cleanIsbn) async {
    try {
      final url = Uri.parse(
        '$_googleBooksUrl?q=isbn:$cleanIsbn&maxResults=1',
      );
      debugPrint('URL Google Books: $url');

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
      );
      debugPrint('Google Books status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final items = data['items'] as List?;
        debugPrint('Google Books items: ${items?.length ?? 0}');

        if (items == null || items.isEmpty) {
          debugPrint('No items en Google Books');
          return null;
        }

        final volumeInfo = items.first['volumeInfo'] as Map<String, dynamic>?;
        if (volumeInfo == null) {
          return null;
        }

        // Obtener título y subtítulo
        String title = volumeInfo['title'] ?? 'Título desconocido';
        final subtitle = volumeInfo['subtitle'] as String?;

        // Obtener autor(es)
        final authors = volumeInfo['authors'] as List?;
        final author = authors?.join(', ') ?? 'Autor desconocido';

        // Intentar extraer número de volumen del título o subtítulo
        String? seriesName;
        int? volumeNumber;

        // 1. Primero intentar extraer de campos adicionales de Google Books
        volumeNumber = _extractVolumeFromGoogleBooksData(volumeInfo);
        if (volumeNumber != null) {
          debugPrint('Volumen detectado desde datos de Google Books: $volumeNumber');
          seriesName = title;
        }

        // 2. Si no, buscar patrones de volumen en título y subtítulo
        if (volumeNumber == null) {
          final fullTitle = subtitle != null ? '$title: $subtitle' : title;
          final volInfo = _extractVolumeFromTitle(fullTitle);
          if (volInfo['volumeNumber'] != null) {
            seriesName = volInfo['seriesName'] ?? title;
            volumeNumber = volInfo['volumeNumber'];
          } else {
            // Para manga, intentar extraer de patrones específicos
            final mangaVolInfo = _extractMangaVolume(title, subtitle);
            seriesName = mangaVolInfo['seriesName'];
            volumeNumber = mangaVolInfo['volumeNumber'];
          }
        }

        // Si no encontramos volumen, buscar en Google Books con título + variaciones
        if (volumeNumber == null && title.isNotEmpty) {
          debugPrint('Buscando volumen con búsqueda alternativa...');
          final altVolInfo = await _searchVolumeByIsbnAlternative(cleanIsbn, title);
          if (altVolInfo != null) {
            volumeNumber = altVolInfo['volumeNumber'];
            seriesName = altVolInfo['seriesName'] ?? seriesName;
            debugPrint('Volumen encontrado: $volumeNumber');
          }
        }

        // Obtener portada - primero intentar con fuentes españolas por ISBN
        String? coverUrl;

        // 1. Primero buscar en Casa del Libro (mejor para manga español)
        debugPrint('Buscando portada en Casa del Libro para ISBN: $cleanIsbn');
        coverUrl = await searchCoverByIsbn(cleanIsbn);

        // 2. Si no hay, usar la de Google Books
        if (coverUrl == null) {
          final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
          if (imageLinks != null) {
            // Preferir en orden: extraLarge, large, medium, small, thumbnail
            coverUrl = imageLinks['extraLarge'] as String? ??
                       imageLinks['large'] as String? ??
                       imageLinks['medium'] as String? ??
                       imageLinks['small'] as String? ??
                       imageLinks['thumbnail'] as String?;
            if (coverUrl != null) {
              coverUrl = coverUrl.replaceAll('http://', 'https://');
              // Aumentar zoom para mejor calidad
              coverUrl = coverUrl.replaceAll('zoom=1', 'zoom=3');
              coverUrl = coverUrl.replaceAll('zoom=2', 'zoom=3');
            }
          }
        }

        // 3. Si aún no hay portada, buscarla por título
        if (coverUrl == null || coverUrl.isEmpty) {
          debugPrint('Buscando portada por título: $title');
          coverUrl = await _searchCoverInGoogleBooks(title, author);
        }

        // Obtener páginas
        final pageCount = volumeInfo['pageCount'] as int? ?? 0;

        // Construir título final con volumen si lo tenemos
        String finalTitle = title;
        if (volumeNumber != null && !title.toLowerCase().contains('vol')) {
          finalTitle = '$title Vol. $volumeNumber';
        }

        return Book(
          isbn: cleanIsbn,
          title: finalTitle,
          author: author,
          coverUrl: coverUrl,
          totalPages: pageCount,
          status: 'reading',
          currentPage: 0,
          seriesName: seriesName,
          volumeNumber: volumeNumber,
        );
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('Error buscando en Google Books: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  // Extraer información de volumen (delegado a VolumeExtractor)
  // Acepta title y subtitle opcionales para compatibilidad con Google Books
  Map<String, dynamic> _extractMangaVolume(String title, String? subtitle) {
    final textToSearch = subtitle != null ? '$title $subtitle' : title;
    final info = VolumeExtractor.extractFromTitle(textToSearch);
    return {
      'seriesName': info.seriesName.isNotEmpty ? info.seriesName : title,
      'volumeNumber': info.volumeNumber,
    };
  }

  // Extraer volumen de campos adicionales de Google Books
  int? _extractVolumeFromGoogleBooksData(Map<String, dynamic> volumeInfo) {
    // 1. Revisar el campo "seriesInfo" si existe
    final seriesInfo = volumeInfo['seriesInfo'] as Map<String, dynamic>?;
    if (seriesInfo != null) {
      final volumePart = seriesInfo['bookDisplayNumber'];
      if (volumePart != null) {
        final vol = int.tryParse(volumePart.toString());
        if (vol != null) return vol;
      }
    }

    // 2. Revisar el título completo incluyendo subtítulo
    final title = volumeInfo['title'] as String? ?? '';
    final subtitle = volumeInfo['subtitle'] as String?;

    // Combinar título y subtítulo
    final fullTitle = subtitle != null ? '$title $subtitle' : title;

    // Patrones más agresivos para encontrar números
    final patterns = [
      // Patrones específicos de manga/cómic
      RegExp(r'(?:tomo|vol(?:umen|\.)?|n[ºo°]|#)\s*(\d+)', caseSensitive: false),
      // Número entre paréntesis
      RegExp(r'\((\d+)\)'),
      // Número al final del título
      RegExp(r'[\s,]\s*(\d{1,3})\s*$'),
      // "10" al final de títulos como "One Piece 10"
      RegExp(r'^[A-Za-z\s]+\s+(\d{1,3})$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(fullTitle);
      if (match != null && match.group(1) != null) {
        final vol = int.tryParse(match.group(1)!);
        if (vol != null && vol > 0 && vol < 1000) {
          debugPrint('Volumen extraído de título completo: $vol');
          return vol;
        }
      }
    }

    // 3. Revisar la descripción para patrones de volumen
    final description = volumeInfo['description'] as String?;
    if (description != null) {
      // Buscar patrones como "Volume 10" o "Tomo 10" en la descripción
      final descPatterns = [
        RegExp(r'(?:volume|vol\.?|tomo)\s*(\d+)', caseSensitive: false),
        RegExp(r'n[ºo°]\s*(\d+)', caseSensitive: false),
      ];

      for (final pattern in descPatterns) {
        final match = pattern.firstMatch(description);
        if (match != null && match.group(1) != null) {
          final vol = int.tryParse(match.group(1)!);
          if (vol != null && vol > 0 && vol < 1000) {
            debugPrint('Volumen extraído de descripción: $vol');
            return vol;
          }
        }
      }
    }

    return null;
  }

  // Buscar volumen de forma alternativa en Google Books
  // Busca el título de la serie + variaciones y compara ISBNs
  Future<Map<String, dynamic>?> _searchVolumeByIsbnAlternative(String isbn, String title) async {
    try {
      // Buscar con variaciones del título para manga español
      final searchQueries = [
        '$title 3 en 1',
        '$title nº',
        '$title vol',
      ];

      for (final query in searchQueries) {
        final url = Uri.parse(
          '$_googleBooksUrl?q=${Uri.encodeComponent(query)}&langRestrict=es&maxResults=20',
        );

        final response = await http.get(url).timeout(
          const Duration(seconds: 8),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final items = data['items'] as List? ?? [];

          for (final item in items) {
            final volumeInfo = item['volumeInfo'] as Map<String, dynamic>?;
            if (volumeInfo == null) continue;

            // Buscar si algún ISBN coincide
            final identifiers = volumeInfo['industryIdentifiers'] as List? ?? [];
            bool isbnMatch = false;
            for (final id in identifiers) {
              if (id['identifier'] == isbn) {
                isbnMatch = true;
                break;
              }
            }

            if (isbnMatch) {
              // Encontramos el libro, extraer volumen del título
              final foundTitle = volumeInfo['title'] as String? ?? '';
              final foundSubtitle = volumeInfo['subtitle'] as String?;
              final fullFoundTitle = foundSubtitle != null
                  ? '$foundTitle $foundSubtitle'
                  : foundTitle;

              debugPrint('Título alternativo encontrado: $fullFoundTitle');

              final volInfo = _extractMangaVolume(foundTitle, foundSubtitle);
              if (volInfo['volumeNumber'] != null) {
                return volInfo;
              }

              // Intentar extraer con patrones estándar también
              final stdVolInfo = _extractVolumeFromTitle(fullFoundTitle);
              if (stdVolInfo['volumeNumber'] != null) {
                return stdVolInfo;
              }
            }
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error en búsqueda alternativa de volumen: $e');
      return null;
    }
  }

  Future<Book> _parseBookData(String isbn, Map<String, dynamic> data) async {
    // Obtener título
    final title = data['title'] ?? 'Título desconocido';

    // Obtener autor(es)
    String author = 'Autor desconocido';
    if (data['authors'] != null && (data['authors'] as List).isNotEmpty) {
      author = (data['authors'] as List)
          .map((a) => a['name'] ?? '')
          .where((name) => name.isNotEmpty)
          .join(', ');
    }

    // Obtener URL de portada - primero Casa del Libro, luego Open Library
    String? coverUrl = await searchCoverByIsbn(isbn);

    if (coverUrl == null && data['cover'] != null) {
      coverUrl = data['cover']['large'] ??
                 data['cover']['medium'] ??
                 data['cover']['small'];
    }

    // Obtener número de páginas
    int totalPages = 0;
    if (data['number_of_pages'] != null) {
      totalPages = data['number_of_pages'] as int;
    }

    // Extraer info de volumen para manga
    final volInfo = _extractMangaVolume(title, null);

    return Book(
      isbn: isbn,
      title: title,
      author: author,
      coverUrl: coverUrl,
      totalPages: totalPages,
      status: 'reading',
      currentPage: 0,
      seriesName: volInfo['seriesName'],
      volumeNumber: volInfo['volumeNumber'],
    );
  }

  // Buscar información de serie para un libro
  Future<Book> getSeriesInfo(Book book) async {
    try {
      // Detectar número de volumen del título actual
      final volumeInfo = _extractVolumeFromTitle(book.title);
      String? seriesName = volumeInfo['seriesName'];
      int? volumeNumber = volumeInfo['volumeNumber'];

      // Si detectamos un volumen, buscar el siguiente
      if (volumeNumber != null && seriesName != null) {
        final nextVolume = volumeNumber + 1;
        final nextVolumeBook = await _searchNextVolume(seriesName, nextVolume, book.author);

        return book.copyWith(
          seriesName: seriesName,
          volumeNumber: volumeNumber,
          nextVolumeIsbn: nextVolumeBook?.isbn,
          nextVolumeTitle: nextVolumeBook?.title,
          nextVolumeCover: nextVolumeBook?.coverUrl,
        );
      }

      // Intentar buscar por patrones comunes de series
      final searchSeriesResult = await _searchForSeries(book.title, book.author);
      if (searchSeriesResult != null) {
        return book.copyWith(
          seriesName: searchSeriesResult['seriesName'],
          volumeNumber: searchSeriesResult['volumeNumber'],
          nextVolumeIsbn: searchSeriesResult['nextVolumeIsbn'],
          nextVolumeTitle: searchSeriesResult['nextVolumeTitle'],
          nextVolumeCover: searchSeriesResult['nextVolumeCover'],
        );
      }

      return book;
    } catch (e) {
      debugPrint('Error obteniendo info de serie: $e');
      return book;
    }
  }

  // Extraer nombre de serie y número de volumen del título (delegado a VolumeExtractor)
  Map<String, dynamic> _extractVolumeFromTitle(String title) {
    final info = VolumeExtractor.extractFromTitle(title);
    if (info.volumeNumber != null) {
      return {
        'seriesName': info.seriesName,
        'volumeNumber': info.volumeNumber,
      };
    }
    return {};
  }

  // Buscar el siguiente volumen de una serie
  Future<Book?> _searchNextVolume(String seriesName, int volumeNumber, String author) async {
    try {
      // Buscar con diferentes formatos
      final searchQueries = [
        '$seriesName Vol. $volumeNumber',
        '$seriesName Volume $volumeNumber',
        '$seriesName #$volumeNumber',
        '$seriesName Tomo $volumeNumber',
        '$seriesName $volumeNumber',
      ];

      for (final query in searchQueries) {
        final url = Uri.parse(
          '$_baseUrl/search.json?title=${Uri.encodeComponent(query)}&author=${Uri.encodeComponent(author)}&limit=3',
        );

        final response = await http.get(url).timeout(
          const Duration(seconds: 8),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final docs = data['docs'] as List? ?? [];

          for (final doc in docs) {
            final volInfo = _extractVolumeFromTitle(doc['title'] ?? '');

            // Verificar que es el volumen correcto
            if (volInfo['volumeNumber'] == volumeNumber) {
              final isbn = (doc['isbn'] as List?)?.first?.toString() ?? '';
              final coverId = doc['cover_i'];
              final bookTitle = doc['title'] ?? 'Vol. $volumeNumber';

              // Obtener portada de Open Library o Google Books
              String? coverUrl;
              if (coverId != null) {
                coverUrl = 'https://covers.openlibrary.org/b/id/$coverId-L.jpg';
              } else {
                // Buscar en Google Books si no hay portada
                coverUrl = await _searchCoverInGoogleBooks(bookTitle, author);
              }

              return Book(
                isbn: isbn,
                title: bookTitle,
                author: author,
                coverUrl: coverUrl,
                totalPages: doc['number_of_pages_median'] ?? 0,
              );
            }
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error buscando siguiente volumen: $e');
      return null;
    }
  }

  // Buscar si el libro pertenece a una serie
  Future<Map<String, dynamic>?> _searchForSeries(String title, String author) async {
    try {
      // Buscar el libro en Open Library para obtener info de work
      final url = Uri.parse(
        '$_baseUrl/search.json?title=${Uri.encodeComponent(title)}&author=${Uri.encodeComponent(author)}&limit=1',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final docs = data['docs'] as List? ?? [];

        if (docs.isNotEmpty) {
          final doc = docs.first;

          // Verificar si tiene info de serie en la API
          if (doc['series'] != null && (doc['series'] as List).isNotEmpty) {
            final seriesName = (doc['series'] as List).first.toString();
            return {
              'seriesName': seriesName,
              'volumeNumber': 1,
            };
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error buscando serie: $e');
      return null;
    }
  }

  // Buscar portada en Google Books como respaldo
  Future<String?> _searchCoverInGoogleBooks(String title, String author) async {
    // Intentar varias búsquedas
    final queries = [
      '$title $author',
      title,
      '$title comic',
      '$title vol',
    ];

    for (final queryText in queries) {
      try {
        final query = Uri.encodeComponent(queryText);
        final url = Uri.parse('$_googleBooksUrl?q=$query&maxResults=3');

        final response = await http.get(url).timeout(
          const Duration(seconds: 5),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final items = data['items'] as List?;

          if (items != null && items.isNotEmpty) {
            for (final item in items) {
              final volumeInfo = item['volumeInfo'] as Map<String, dynamic>?;
              if (volumeInfo != null) {
                final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
                if (imageLinks != null) {
                  String? cover = imageLinks['thumbnail'] as String?;
                  if (cover != null) {
                    cover = cover.replaceAll('http://', 'https://');
                    cover = cover.replaceAll('zoom=1', 'zoom=2');
                    return cover;
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error buscando portada en Google Books: $e');
      }
    }
    return null;
  }

  // Buscar portada pública - método accesible
  // Intenta encontrar la portada en múltiples fuentes
  Future<String?> searchCover(String title, String author) async {
    debugPrint('=== BookApiService.searchCover ===');
    debugPrint('TITLE RECIBIDO: "$title"');
    debugPrint('AUTHOR RECIBIDO: "$author"');

    // Extraer nombre de serie y volumen del título
    final volInfo = _extractVolumeFromTitle(title);
    debugPrint('volInfo resultado: $volInfo');
    final seriesName = volInfo['seriesName'] as String? ?? title;
    final volumeNumber = volInfo['volumeNumber'] as int?;
    debugPrint('seriesName final: "$seriesName", volumeNumber: $volumeNumber');

    // Detectar omnibus usando VolumeExtractor
    final titleVolInfo = VolumeExtractor.extractFromTitle(title);
    final isOmnibus = titleVolInfo.isOmnibus;
    final baseSeriesName = titleVolInfo.baseSeriesName;

    if (isOmnibus) {
      debugPrint('📚 Omnibus detectado: serie="$seriesName", base="$baseSeriesName", vol=$volumeNumber');
    }

    // 1. PRIMERO: Tomos y Grapas (mejor para manga/cómics españoles)
    if (volumeNumber != null) {
      final tomosYGrapasCover = await _tomosYGrapasClient.searchCover(seriesName, volumeNumber);
      if (tomosYGrapasCover != null) {
        debugPrint('Portada encontrada en Tomos y Grapas: $tomosYGrapasCover');
        return tomosYGrapasCover;
      }
    }

    // 2. Comic Vine (mejor para DC/Vertigo/Marvel americanos)
    // Intentar con varios formatos de búsqueda
    final comicVineQueries = <String>[
      if (volumeNumber != null) '$seriesName vol $volumeNumber',
      if (volumeNumber != null) '$seriesName volumen $volumeNumber',
      if (volumeNumber != null) '$seriesName #$volumeNumber',
      seriesName,
      title,
    ];

    for (final cvQuery in comicVineQueries) {
      try {
        debugPrint('🔍 Comic Vine query: "$cvQuery"');
        final comicVineCover = await _comicVineClient.getCoverUrl(
          cvQuery,
          volumeNumber,
        );
        if (comicVineCover != null && comicVineCover.isNotEmpty) {
          debugPrint('✅ Portada encontrada en Comic Vine: $comicVineCover');
          return comicVineCover;
        }
      } catch (e) {
        debugPrint('Error en Comic Vine: $e');
      }
    }

    // 3. Si tiene volumen, intentar MangaDex (mejor para manga japonés)
    if (volumeNumber != null) {
      final mangadexCover = await _searchMangaDexCover(seriesName, volumeNumber);
      if (mangadexCover != null) {
        debugPrint('Portada encontrada en MangaDex: $mangadexCover');
        return mangadexCover;
      }
    }

    // 3. Intentar encontrar el ISBN en Google Books para usar Casa del Libro
    final searchQueries = QueryGenerator.forGoogleBooks(
      title,
      author,
      isOmnibus: isOmnibus,
      baseSeriesName: baseSeriesName,
      volumeNumber: volumeNumber,
    );

    for (final query in searchQueries) {
      try {
        debugPrint('🔍 Google Books query: "$query"');
        final url = Uri.parse(
          '$_googleBooksUrl?q=${Uri.encodeComponent(query)}&langRestrict=es&maxResults=5',
        );

        final response = await http.get(url).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final items = data['items'] as List? ?? [];

          for (final item in items) {
            final volumeInfo = item['volumeInfo'] as Map<String, dynamic>?;
            if (volumeInfo == null) continue;

            // Verificar que el título coincida razonablemente
            final bookTitle = (volumeInfo['title'] as String?)?.toLowerCase() ?? '';

            // Para omnibus, verificar que contenga el número de volumen
            if (isOmnibus && volumeNumber != null) {
              final volStr = volumeNumber.toString();
              final volPadded = volStr.padLeft(2, '0');
              // El título debe contener el número de volumen
              if (!bookTitle.contains(volStr) && !bookTitle.contains(volPadded)) {
                continue; // Saltar este resultado, no es el volumen correcto
              }
            }

            // Buscar ISBN-13
            final identifiers = volumeInfo['industryIdentifiers'] as List? ?? [];
            for (final id in identifiers) {
              if (id['type'] == 'ISBN_13') {
                final isbn = id['identifier'] as String?;
                if (isbn != null && isbn.startsWith('978')) {
                  // Solo usar Casa del Libro para ISBN españoles (97884)
                  if (isbn.startsWith('97884')) {
                    final coverUrl = _buildCasaDelLibroCoverUrl(isbn);
                    debugPrint('✅ ISBN español -> Casa del Libro: $isbn -> $coverUrl');
                    return coverUrl;
                  }
                  // Para otros ISBNs, intentar imagen de Google Books directamente
                  final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
                  if (imageLinks != null) {
                    var imgUrl = imageLinks['thumbnail'] as String? ??
                        imageLinks['smallThumbnail'] as String?;
                    if (imgUrl != null) {
                      imgUrl = imgUrl.replaceAll('http://', 'https://');
                      imgUrl = imgUrl.replaceAll('zoom=1', 'zoom=3');
                      debugPrint('✅ Google Books imagen directa: $imgUrl');
                      return imgUrl;
                    }
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error buscando ISBN: $e');
      }
    }

    // 4. Intentar búsqueda directa en Casa del Libro por título
    if (volumeNumber != null) {
      final casaCover = await _searchCasaDelLibroCover(seriesName, volumeNumber, baseSeriesName);
      if (casaCover != null) {
        debugPrint('✅ Portada encontrada en Casa del Libro: $casaCover');
        return casaCover;
      }
    }

    // 5. Intentar Amazon España
    if (volumeNumber != null) {
      final amazonCover = await _searchAmazonCover(seriesName, volumeNumber, baseSeriesName);
      if (amazonCover != null) {
        debugPrint('✅ Portada encontrada en Amazon: $amazonCover');
        return amazonCover;
      }
    }

    // 6. Intentar Open Library
    if (volumeNumber != null) {
      final openLibCover = await _searchOpenLibraryCover(seriesName, volumeNumber, baseSeriesName);
      if (openLibCover != null) {
        debugPrint('✅ Portada encontrada en Open Library: $openLibCover');
        return openLibCover;
      }
    }

    // 7. Fallback: buscar imagen directamente en Google Books
    return _searchCoverInGoogleBooks(title, author);
  }

  /// Busca portada en Open Library
  Future<String?> _searchOpenLibraryCover(String seriesName, int volumeNumber, String? baseSeriesName) async {
    final queries = <String>[
      '$seriesName $volumeNumber',
      if (baseSeriesName != null) '$baseSeriesName omnibus $volumeNumber',
      if (baseSeriesName != null) '$baseSeriesName 3 in 1 $volumeNumber',
    ];

    for (final query in queries) {
      try {
        debugPrint('🔍 Open Library búsqueda: "$query"');
        final searchUrl = Uri.parse(
          'https://openlibrary.org/search.json?q=${Uri.encodeComponent(query)}&limit=5',
        );

        final response = await http.get(searchUrl).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final docs = data['docs'] as List? ?? [];

          for (final doc in docs) {
            final coverId = doc['cover_i'];
            if (coverId != null) {
              final coverUrl = 'https://covers.openlibrary.org/b/id/$coverId-L.jpg';
              debugPrint('✅ Open Library cover: $coverUrl');
              return coverUrl;
            }

            // Si no hay cover_i, intentar con ISBN
            final isbns = doc['isbn'] as List?;
            if (isbns != null && isbns.isNotEmpty) {
              for (final isbn in isbns) {
                if (isbn.toString().startsWith('978')) {
                  final coverUrl = _buildCasaDelLibroCoverUrl(isbn.toString());
                  debugPrint('✅ Open Library ISBN -> Casa del Libro: $coverUrl');
                  return coverUrl;
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Open Library error: $e');
      }
    }
    return null;
  }

  /// Busca portada en Amazon España
  Future<String?> _searchAmazonCover(String seriesName, int volumeNumber, String? baseSeriesName) async {
    final queries = <String>[
      '$seriesName $volumeNumber',
      if (volumeNumber < 10) '$seriesName 0$volumeNumber',
      if (baseSeriesName != null) '$baseSeriesName 3 en 1 $volumeNumber planeta comic',
    ];

    for (final query in queries) {
      try {
        debugPrint('🔍 Amazon búsqueda: "$query"');
        final searchUrl = Uri.parse(
          'https://www.amazon.es/s?k=${Uri.encodeComponent(query)}&i=stripbooks',
        );

        final response = await http.get(
          searchUrl,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'es-ES,es;q=0.9',
          },
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final html = response.body;

          // Buscar imagen de portada en los resultados
          // Amazon usa: src="https://m.media-amazon.com/images/I/XXXXX._AC_UL320_.jpg"
          final imgMatches = RegExp(
            r'src="(https://m\.media-amazon\.com/images/I/[^"]+\.jpg)"',
          ).allMatches(html);

          for (final match in imgMatches) {
            var imgUrl = match.group(1);
            if (imgUrl != null && !imgUrl.contains('sprite') && !imgUrl.contains('icon')) {
              // Obtener versión de alta calidad
              imgUrl = imgUrl.replaceAll(RegExp(r'\._[^.]+_\.'), '.');
              debugPrint('✅ Amazon imagen: $imgUrl');
              return imgUrl;
            }
          }
        }
      } catch (e) {
        debugPrint('Amazon error: $e');
      }
    }
    return null;
  }

  /// Busca portada directamente en Casa del Libro por título
  Future<String?> _searchCasaDelLibroCover(String seriesName, int volumeNumber, String? baseSeriesName) async {
    final queries = <String>[
      '$seriesName $volumeNumber',
      if (volumeNumber < 10) '$seriesName 0$volumeNumber',
      if (baseSeriesName != null) '$baseSeriesName 3 en 1 $volumeNumber',
      if (baseSeriesName != null && volumeNumber < 10) '$baseSeriesName 3 en 1 0$volumeNumber',
    ];

    for (final query in queries) {
      try {
        debugPrint('🔍 Casa del Libro búsqueda: "$query"');
        final searchUrl = Uri.parse(
          'https://www.casadellibro.com/busqueda-generica?busqueda=${Uri.encodeComponent(query)}',
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

          // Buscar ISBN en los resultados
          // Patrón: data-isbn="9788411610773" o href que contenga ISBN
          final isbnMatch = RegExp(
            r'(?:data-isbn|isbn)[="\s:]+(\d{13})',
            caseSensitive: false,
          ).firstMatch(html);

          if (isbnMatch != null) {
            final isbn = isbnMatch.group(1);
            if (isbn != null && isbn.startsWith('978')) {
              debugPrint('✅ Casa del Libro ISBN encontrado: $isbn');
              return _buildCasaDelLibroCoverUrl(isbn);
            }
          }

          // Alternativa: buscar URL de imagen directamente
          final imgMatch = RegExp(
            r'<img[^>]+src="(https://[^"]*casadellibro[^"]*\.(?:jpg|webp|png))"',
            caseSensitive: false,
          ).firstMatch(html);

          if (imgMatch != null) {
            var imgUrl = imgMatch.group(1);
            if (imgUrl != null && !imgUrl.contains('logo') && !imgUrl.contains('icon')) {
              // Intentar obtener versión grande
              imgUrl = imgUrl.replaceAll('/t0/', '/l/').replaceAll('/s0/', '/l/');
              debugPrint('✅ Casa del Libro imagen directa: $imgUrl');
              return imgUrl;
            }
          }
        }
      } catch (e) {
        debugPrint('Casa del Libro error: $e');
      }
    }
    return null;
  }

  // Buscar portada en MangaDex por nombre de serie y volumen
  Future<String?> _searchMangaDexCover(String seriesName, int volumeNumber) async {
    // Para omnibus (ej: "ONE PIECE 3 EN 1"), extraer nombre base y calcular volumen real
    String searchName = seriesName;
    int searchVolume = volumeNumber;

    final omnibusMatch = RegExp(r'^(.+?)\s*(\d+)\s*[Ee][Nn]\s*1', caseSensitive: false).firstMatch(seriesName);
    if (omnibusMatch != null) {
      searchName = omnibusMatch.group(1)?.trim() ?? seriesName;
      final volumesPerOmnibus = int.tryParse(omnibusMatch.group(2) ?? '3') ?? 3;
      // Calcular el primer volumen original del omnibus
      // Ej: "ONE PIECE 3 EN 1 5" contiene volúmenes 13, 14, 15 (5-1)*3+1 = 13
      searchVolume = (volumeNumber - 1) * volumesPerOmnibus + 1;
      debugPrint('📚 Omnibus: buscando "$searchName" vol $searchVolume (original de omnibus $volumeNumber)');
    }

    try {
      // 1. Buscar el manga por título
      final searchUrl = Uri.parse(
        'https://api.mangadex.org/manga?title=${Uri.encodeComponent(searchName)}&limit=5',
      );

      final searchResponse = await http.get(searchUrl).timeout(
        const Duration(seconds: 10),
      );

      if (searchResponse.statusCode != 200) return null;

      final searchData = json.decode(searchResponse.body);
      final mangas = searchData['data'] as List? ?? [];

      if (mangas.isEmpty) return null;

      // Buscar el manga que mejor coincida
      String? mangaId;
      for (final manga in mangas) {
        final attrs = manga['attributes'] as Map<String, dynamic>?;
        if (attrs == null) continue;

        final titles = attrs['title'] as Map<String, dynamic>? ?? {};
        final altTitles = attrs['altTitles'] as List? ?? [];

        // Verificar si el título coincide
        final allTitles = <String>[
          ...titles.values.map((t) => t.toString().toLowerCase()),
          ...altTitles.expand((t) => (t as Map).values.map((v) => v.toString().toLowerCase())),
        ];

        final searchLower = seriesName.toLowerCase();
        if (allTitles.any((t) => t.contains(searchLower) || searchLower.contains(t))) {
          mangaId = manga['id'];
          break;
        }
      }

      // Si no encontró coincidencia exacta, usar el primero
      mangaId ??= mangas.first['id'];

      debugPrint('MangaDex manga ID: $mangaId');

      // 2. Buscar la portada del volumen específico
      final coverUrl = Uri.parse(
        'https://api.mangadex.org/cover?manga[]=$mangaId&limit=100',
      );

      final coverResponse = await http.get(coverUrl).timeout(
        const Duration(seconds: 10),
      );

      if (coverResponse.statusCode != 200) return null;

      final coverData = json.decode(coverResponse.body);
      final covers = coverData['data'] as List? ?? [];

      // Buscar la portada del volumen específico
      for (final cover in covers) {
        final attrs = cover['attributes'] as Map<String, dynamic>?;
        if (attrs == null) continue;

        final vol = attrs['volume']?.toString();
        if (vol == searchVolume.toString()) {
          final fileName = attrs['fileName'] as String?;
          if (fileName != null) {
            // Construir URL de portada (usar .512.jpg para tamaño medio)
            debugPrint('✅ MangaDex: portada encontrada para vol $searchVolume');
            return 'https://uploads.mangadex.org/covers/$mangaId/$fileName.512.jpg';
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error buscando en MangaDex: $e');
      return null;
    }
  }

  // Construir URL de portada de Casa del Libro por ISBN
  // Patrón: https://imagessl1.casadellibro.com/a/l/s5/{last2digits}/{isbn}.webp
  String _buildCasaDelLibroCoverUrl(String isbn) {
    final last2Digits = isbn.length >= 2 ? isbn.substring(isbn.length - 2) : '00';
    return 'https://imagessl1.casadellibro.com/a/l/s5/$last2Digits/$isbn.webp';
  }

  // Buscar portada por ISBN - devuelve URL de Casa del Libro (más fiable para España)
  Future<String?> searchCoverByIsbn(String isbn) async {
    final casaDelLibroUrl = _buildCasaDelLibroCoverUrl(isbn);
    debugPrint('URL portada Casa del Libro: $casaDelLibroUrl');

    // Validar que la URL devuelve una imagen real (evita imagenes rotas)
    if (await _validateCoverUrl(casaDelLibroUrl)) {
      return casaDelLibroUrl;
    }

    debugPrint('Casa del Libro: URL no valida, descartando');
    return null;
  }

  /// Valida que una URL de portada devuelve una imagen real.
  /// Hace un HEAD request y verifica status 200 + content-length > 1000.
  Future<bool> _validateCoverUrl(String url) async {
    try {
      final response = await http.head(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint('Cover validation: status ${response.statusCode} for $url');
        return false;
      }

      // Verificar que tiene contenido suficiente (imagenes placeholder son muy pequenas)
      final contentLength = int.tryParse(
        response.headers['content-length'] ?? '',
      );
      if (contentLength != null && contentLength < 1000) {
        debugPrint('Cover validation: content too small ($contentLength bytes) for $url');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Cover validation error for $url: $e');
      return false;
    }
  }

  // Buscar por título (alternativa si no se encuentra por ISBN)
  Future<List<Book>> searchByTitle(String title) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/search.json?title=${Uri.encodeComponent(title)}&limit=5',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final docs = data['docs'] as List? ?? [];

        return docs.map((doc) {
          final isbn = (doc['isbn'] as List?)?.first ?? '';
          final authorList = doc['author_name'] as List? ?? [];
          final coverId = doc['cover_i'];

          return Book(
            isbn: isbn.toString(),
            title: doc['title'] ?? 'Sin título',
            author: authorList.isNotEmpty ? authorList.first : 'Autor desconocido',
            coverUrl: coverId != null
                ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg'
                : null,
            totalPages: doc['number_of_pages_median'] ?? 0,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error buscando por título: $e');
      return [];
    }
  }
}
