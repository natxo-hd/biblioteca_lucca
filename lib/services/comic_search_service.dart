import 'package:flutter/foundation.dart';
import '../models/book.dart';
import '../config/api_keys.dart';
import '../constants/translations.dart';
import '../utils/volume_extractor.dart';
import '../utils/query_generator.dart';
import 'comic_type_detector.dart';
import 'api_cache_service.dart';
import 'api/marvel_api_client.dart';
import 'api/comicvine_api_client.dart';
import 'api/superhero_api_client.dart';
import 'api/tomosygrapas_client.dart';
import 'api/salvat_client.dart';
import 'api/tebeosfera_client.dart';
import 'book_api_service.dart';

/// Fuentes de datos disponibles
enum ApiSource {
  marvel,
  comicVine,
  mangaDex,
  googleBooks,
  openLibrary,
  casaDelLibro,
  superHero,
}

/// Servicio orquestador para búsqueda de cómics
/// Coordina múltiples APIs y aplica fallback según el tipo de cómic
class ComicSearchService {
  final BookApiService _bookApiService;
  final TomosYGrapasClient _tomosYGrapasClient = TomosYGrapasClient();
  final SalvatClient _salvatClient = SalvatClient();
  final TebeosferaClient _tebeosferaClient = TebeosferaClient();
  final ApiCacheService _cache = ApiCacheService();

  /// Traduce un título español a inglés si existe traducción
  String? _translateToEnglish(String title) {
    if (ComicTranslations.hasTranslation(title)) {
      return ComicTranslations.getEnglishName(title);
    }
    return null;
  }

  late final MarvelApiClient _marvelClient;
  late final ComicVineApiClient _comicVineClient;
  late final SuperHeroApiClient _superHeroClient;

  ComicSearchService(this._bookApiService) {
    _marvelClient = MarvelApiClient();
    _comicVineClient = ComicVineApiClient();
    _superHeroClient = SuperHeroApiClient();
  }

  /// Busca un libro/cómic por ISBN con detección automática de tipo
  Future<Book?> searchByIsbn(String isbn) async {
    debugPrint('=== ComicSearchService: Buscando ISBN $isbn ===');

    // Detectar tipo de cómic por ISBN
    var comicType = ComicTypeDetector.detectFromIsbn(isbn);
    debugPrint('Tipo detectado por ISBN: ${ComicTypeDetector.getTypeName(comicType)}');

    // Obtener prioridad de fuentes según el tipo
    final sources = _getSourcePriority(comicType);
    debugPrint('Orden de búsqueda: ${sources.map((s) => s.name).join(' → ')}');

    Book? result;

    // Intentar cada fuente en orden
    for (final source in sources) {
      result = await _trySource(source, isbn, null);
      if (result != null) {
        debugPrint('Encontrado en: ${source.name}');
        break;
      }
    }

    // Si encontramos algo pero le faltan datos (volumen/páginas),
    // intentar enriquecer con Comic Vine usando el título
    if (result != null && _needsMoreData(result)) {
      debugPrint('Libro encontrado pero faltan datos, intentando enriquecer...');
      result = await _enrichWithComicVine(result);
    }

    if (result != null) {
      // Refinar tipo usando titulo/publisher del resultado encontrado.
      // Esto corrige ediciones espanolas de comics internacionales
      // (ej: Batman con ISBN 97884 -> dc en vez de spanish)
      final refinedType = ComicTypeDetector.refineType(
        comicType,
        result.title,
        result.publisher,
      );
      if (refinedType != comicType) {
        debugPrint('Tipo refinado: ${ComicTypeDetector.getTypeName(comicType)} -> ${ComicTypeDetector.getTypeName(refinedType)}');
        comicType = refinedType;
      }

      debugPrint('=== Antes de _enrichBook ===');
      debugPrint('seriesName: ${result.seriesName}');

      // Enriquecer con información adicional (publisher, universe)
      final enrichedResult = await _enrichBook(result);

      debugPrint('=== Después de _enrichBook ===');
      debugPrint('seriesName: ${enrichedResult.seriesName}');

      return enrichedResult;
    }

    debugPrint('No encontrado en ninguna fuente');
    return null;
  }

  /// Verifica si al libro le faltan datos importantes
  bool _needsMoreData(Book book) {
    return book.volumeNumber == null || book.totalPages == 0;
  }

  /// Intenta enriquecer el libro con datos de Comic Vine usando el título
  Future<Book> _enrichWithComicVine(Book book) async {
    if (!ApiKeys.hasComicVineKey) return book;

    // Re-detectar tipo basándose en título y autor
    var comicType = ComicTypeDetector.detectFromTitle(book.title);
    if (comicType == ComicType.unknown) {
      comicType = ComicTypeDetector.detectFromAuthor(book.author);
    }
    debugPrint('Tipo detectado para enriquecer: ${ComicTypeDetector.getTypeName(comicType)}');

    // Solo intentar Comic Vine si parece Marvel o DC
    if (comicType != ComicType.marvel && comicType != ComicType.dc) {
      return book;
    }

    try {
      // Intentar varias búsquedas:
      // 1. Título original
      // 2. Serie si existe
      // 3. Autor + título simplificado
      final searchQueries = <String>[
        book.title,
        if (book.seriesName != null && book.seriesName != book.title) book.seriesName!,
        '${book.author.split(',').first} ${book.title.split(' ').take(2).join(' ')}',
      ];

      for (final query in searchQueries) {
        debugPrint('Buscando en Comic Vine: $query');
        final results = await _comicVineClient.searchIssues(query);

        if (results.isNotEmpty) {
          final cvBook = results.first;
          debugPrint('Comic Vine encontró: ${cvBook.title}, Vol: ${cvBook.volumeNumber}, Págs: ${cvBook.totalPages}');
          debugPrint('Comic Vine serie: ${cvBook.seriesName}');

          // Determinar el mejor seriesName:
          // - Preferir Comic Vine si el libro no tiene serie o si la serie = título
          String? bestSeriesName = book.seriesName;
          if (cvBook.seriesName != null && cvBook.seriesName!.isNotEmpty) {
            // Si no tiene serie, o la serie es igual al título (no detectada), usar Comic Vine
            if (book.seriesName == null ||
                book.seriesName!.isEmpty ||
                book.seriesName == book.title ||
                book.seriesName!.toLowerCase() == book.title.toLowerCase()) {
              bestSeriesName = cvBook.seriesName;
              debugPrint('Usando serie de Comic Vine: $bestSeriesName');
            }
          }

          // Combinar datos: mantener los originales y añadir los que faltan
          return book.copyWith(
            volumeNumber: book.volumeNumber ?? cvBook.volumeNumber,
            totalPages: book.totalPages > 0 ? book.totalPages : cvBook.totalPages,
            seriesName: bestSeriesName,
            publisher: book.publisher ?? cvBook.publisher,
            comicUniverse: book.comicUniverse ?? cvBook.comicUniverse,
          );
        }
      }
    } catch (e) {
      debugPrint('Error enriqueciendo con Comic Vine: $e');
    }

    return book;
  }

  /// Busca cómics por título
  Future<List<Book>> searchByTitle(String title) async {
    debugPrint('=== ComicSearchService: Buscando título "$title" ===');

    // Detectar tipo por título
    final comicType = ComicTypeDetector.detectFromTitle(title);
    debugPrint('Tipo detectado: ${ComicTypeDetector.getTypeName(comicType)}');

    final results = <Book>[];

    // Buscar en fuentes según el tipo
    switch (comicType) {
      case ComicType.marvel:
        if (ApiKeys.hasMarvelKeys) {
          results.addAll(await _marvelClient.searchByTitle(title));
        }
        if (results.isEmpty && ApiKeys.hasComicVineKey) {
          results.addAll(await _comicVineClient.searchIssues(title));
        }
        break;

      case ComicType.dc:
        if (ApiKeys.hasComicVineKey) {
          results.addAll(await _comicVineClient.searchIssues(title));
        }
        break;

      case ComicType.manga:
      case ComicType.indie:
      case ComicType.unknown:
        // Usar BookApiService existente para estos tipos
        results.addAll(await _bookApiService.searchByTitle(title));
        break;

      case ComicType.spanish:
        // Para cómics españoles, buscar primero en Tebeosfera
        debugPrint('Español: Buscando colección en Tebeosfera...');
        final tebeosferaResults = await _tebeosferaClient.searchBooks(title);
        if (tebeosferaResults.isNotEmpty) {
          debugPrint('Español: ${tebeosferaResults.length} volúmenes encontrados en Tebeosfera');
          results.addAll(tebeosferaResults);
        }
        // Fallback: BookApiService
        if (results.isEmpty) {
          results.addAll(await _bookApiService.searchByTitle(title));
        }
        break;
    }

    // Fallback a BookApiService si no hay resultados
    if (results.isEmpty) {
      results.addAll(await _bookApiService.searchByTitle(title));
    }

    return results;
  }

  /// Busca portada para un cómic
  Future<String?> searchCover(String title, String author, {int? volumeNumber}) async {
    // Verificar caché primero
    final cacheKey = _cache.buildCoverKey(title, author, volumeNumber: volumeNumber);
    final cachedCover = _cache.getCover(cacheKey);
    if (cachedCover != null) {
      debugPrint('Portada en caché para: $title (vol: $volumeNumber)');
      return cachedCover;
    }

    debugPrint('Buscando portada para: $title (vol: $volumeNumber)');

    // Detectar tipo y refinar (ediciones espanolas de comics internacionales)
    final rawType = ComicTypeDetector.detectFromTitle(title);
    final comicType = ComicTypeDetector.refineType(rawType, title, null);
    final englishTitle = _translateToEnglish(title);

    // Detectar si es edición omnibus usando VolumeExtractor
    final volInfo = VolumeExtractor.extractFromTitle(title);
    final isOmnibus = volInfo.isOmnibus;
    final baseSeriesName = volInfo.baseSeriesName;
    if (isOmnibus) {
      debugPrint('Omnibus detectado: base="$baseSeriesName"');
    }

    // Priorizar según tipo
    switch (comicType) {
      case ComicType.marvel:
        if (ApiKeys.hasMarvelKeys) {
          var cover = await _marvelClient.getCoverUrl(title, volumeNumber);
          if (cover != null) return cover;
          // Intentar con traducción inglés
          if (englishTitle != null) {
            cover = await _marvelClient.getCoverUrl(englishTitle, volumeNumber);
            if (cover != null) return cover;
          }
        }
        if (ApiKeys.hasComicVineKey) {
          var cover = await _comicVineClient.getCoverUrl(title, volumeNumber);
          if (cover != null) return cover;
          // Intentar con traducción inglés
          if (englishTitle != null) {
            cover = await _comicVineClient.getCoverUrl(englishTitle, volumeNumber);
            if (cover != null) return cover;
          }
        }
        break;

      case ComicType.dc:
        // Primero intentar Salvat (tiene las portadas de la colección Vertigo española)
        debugPrint('DC/Vertigo: Buscando primero en Salvat...');
        var salvatCover = await _salvatClient.getCoverUrl(title, volumeNumber: volumeNumber);
        if (salvatCover != null) {
          debugPrint('DC/Vertigo: Portada encontrada en Salvat');
          return salvatCover;
        }
        // Fallback: Comic Vine (portadas originales americanas)
        if (ApiKeys.hasComicVineKey) {
          var cover = await _comicVineClient.getCoverUrl(title, volumeNumber);
          if (cover != null) return cover;
          // Intentar con traducción inglés
          if (englishTitle != null) {
            cover = await _comicVineClient.getCoverUrl(englishTitle, volumeNumber);
            if (cover != null) return cover;
          }
        }
        break;

      case ComicType.manga:
        // Para OMNIBUS, NO usar la traducción inglesa genérica (pierde el "3 EN 1")
        // Dejar que caiga al código de omnibus más abajo
        if (isOmnibus) {
          debugPrint('Manga omnibus detectado, saltando búsqueda inglesa genérica');
          break;
        }
        // Para manga NO omnibus, intentar primero con nombre en inglés
        if (englishTitle != null) {
          debugPrint('Manga detectado, buscando con nombre inglés: $englishTitle vol $volumeNumber');
          final volumeQuery = volumeNumber != null ? '$englishTitle vol $volumeNumber' : englishTitle;
          var cover = await _bookApiService.searchCover(volumeQuery, author);
          if (cover != null && cover.isNotEmpty) return cover;
        }
        break;

      case ComicType.indie:
        // Para indie (Image Comics, Dark Horse, etc.), Tomos y Grapas primero
        if (volumeNumber != null) {
          final tomosCover = await _tomosYGrapasClient.searchCover(title, volumeNumber);
          if (tomosCover != null && tomosCover.isNotEmpty) return tomosCover;
        } else {
          final tomosCovers = await _tomosYGrapasClient.searchCoversMultiple(title, limit: 1);
          if (tomosCovers.isNotEmpty) return tomosCovers.first;
        }
        // Fallback: Comic Vine
        if (ApiKeys.hasComicVineKey) {
          var cover = await _comicVineClient.getCoverUrl(title, volumeNumber);
          if (cover != null) return cover;
        }
        break;

      case ComicType.spanish:
        // Para cómics españoles: Salvat, Tebeosfera, Tomos y Grapas
        debugPrint('Español: Buscando primero en Salvat...');
        var salvatCover = await _salvatClient.getCoverUrl(title, volumeNumber: volumeNumber);
        if (salvatCover != null) {
          debugPrint('Español: Portada encontrada en Salvat');
          return salvatCover;
        }
        // Fallback: Tebeosfera
        debugPrint('Español: Buscando en Tebeosfera...');
        var tebeosferaCover = await _tebeosferaClient.getCoverUrl(title, volumeNumber: volumeNumber);
        if (tebeosferaCover != null) {
          debugPrint('Español: Portada encontrada en Tebeosfera');
          return tebeosferaCover;
        }
        // Fallback: Tomos y Grapas
        debugPrint('Español: Buscando en Tomos y Grapas...');
        if (volumeNumber != null) {
          final tomosCover = await _tomosYGrapasClient.searchCover(title, volumeNumber);
          if (tomosCover != null && tomosCover.isNotEmpty) return tomosCover;
        } else {
          final tomosCovers = await _tomosYGrapasClient.searchCoversMultiple(title, limit: 1);
          if (tomosCovers.isNotEmpty) return tomosCovers.first;
        }
        break;

      default:
        break;
    }

    // OMNIBUS: Búsqueda directa en Tomos y Grapas con serie y volumen separados
    if (isOmnibus && volumeNumber != null && baseSeriesName != null) {
      debugPrint('🔍 Omnibus: Buscando directamente en TomosYGrapas');
      debugPrint('   Serie omnibus: "$baseSeriesName 3 EN 1"');
      debugPrint('   Volumen: $volumeNumber');

      // Llamar directamente a TomosYGrapas con el nombre de serie omnibus
      final omnibusSeriesName = '$baseSeriesName 3 EN 1';
      final tomosYGrapasCover = await _tomosYGrapasClient.searchCover(omnibusSeriesName, volumeNumber);
      if (tomosYGrapasCover != null && tomosYGrapasCover.isNotEmpty) {
        debugPrint('✅ Portada omnibus encontrada en TomosYGrapas: $tomosYGrapasCover');
        return tomosYGrapasCover;
      }

      // Fallback: queries generadas para otras fuentes
      final omnibusQueries = QueryGenerator.forCover(
        volInfo.seriesName,
        volumeNumber,
        englishTitle: englishTitle,
        isOmnibus: true,
        baseSeriesName: baseSeriesName,
      );

      for (final query in omnibusQueries) {
        debugPrint('Omnibus fallback query: $query');
        final cover = await _bookApiService.searchCover(query, author);
        if (cover != null && cover.isNotEmpty) {
          debugPrint('Portada omnibus encontrada con: $query');
          return cover;
        }
      }
    }

    // Fallback: Tomos y Grapas búsqueda directa por título (fuente principal)
    if (volumeNumber != null) {
      debugPrint('Fallback T&G searchCover: "$title" vol $volumeNumber');
      final tomosCover = await _tomosYGrapasClient.searchCover(title, volumeNumber);
      if (tomosCover != null && tomosCover.isNotEmpty) return tomosCover;
    } else {
      debugPrint('Fallback T&G searchCoversMultiple: "$title"');
      final tomosCovers = await _tomosYGrapasClient.searchCoversMultiple(title, limit: 1);
      if (tomosCovers.isNotEmpty) return tomosCovers.first;
    }

    // Fallback al servicio existente
    // Primero intentar con volumen si existe
    if (volumeNumber != null) {
      final queryWithVol = '$title vol $volumeNumber';
      debugPrint('Buscando portada con volumen: $queryWithVol');
      var cover = await _bookApiService.searchCover(queryWithVol, author);
      if (cover != null && cover.isNotEmpty) return cover;

      // Intentar con traducción inglés + volumen
      if (englishTitle != null) {
        final engQueryWithVol = '$englishTitle vol $volumeNumber';
        debugPrint('Buscando portada con inglés + volumen: $engQueryWithVol');
        cover = await _bookApiService.searchCover(engQueryWithVol, author);
        if (cover != null && cover.isNotEmpty) return cover;
      }
    }

    // Búsqueda general
    var cover = await _bookApiService.searchCover(title, author);
    if (cover != null && cover.isNotEmpty) return cover;

    // Último intento con inglés
    if (englishTitle != null) {
      cover = await _bookApiService.searchCover(englishTitle, author);
      if (cover != null && cover.isNotEmpty) {
        _cache.setCover(cacheKey, cover);
        return cover;
      }
    }

    // Guardar resultado negativo en caché (TTL corto)
    _cache.setCover(cacheKey, null);
    return null;
  }

  /// Obtiene la prioridad de fuentes según el tipo de cómic
  List<ApiSource> _getSourcePriority(ComicType type) {
    switch (type) {
      case ComicType.manga:
        return [
          ApiSource.mangaDex,
          ApiSource.casaDelLibro,
          ApiSource.googleBooks,
          ApiSource.openLibrary,
        ];

      case ComicType.marvel:
        return [
          ApiSource.marvel,
          ApiSource.comicVine,
          ApiSource.googleBooks,
          ApiSource.openLibrary,
        ];

      case ComicType.dc:
        return [
          ApiSource.comicVine,
          ApiSource.googleBooks,
          ApiSource.openLibrary,
        ];

      case ComicType.spanish:
        // Incluir Comic Vine porque muchos Marvel/DC se publican en España con ISBN español
        return [
          ApiSource.casaDelLibro,
          ApiSource.comicVine,
          ApiSource.googleBooks,
          ApiSource.openLibrary,
        ];

      case ComicType.indie:
        return [
          ApiSource.comicVine,
          ApiSource.googleBooks,
          ApiSource.openLibrary,
        ];

      case ComicType.unknown:
        return [
          ApiSource.googleBooks,
          ApiSource.openLibrary,
          ApiSource.comicVine,
          ApiSource.marvel,
        ];
    }
  }

  /// Intenta buscar en una fuente específica
  Future<Book?> _trySource(ApiSource source, String isbn, String? title) async {
    try {
      switch (source) {
        case ApiSource.marvel:
          if (!ApiKeys.hasMarvelKeys) {
            debugPrint('Marvel API: Sin claves configuradas, saltando...');
            return null;
          }
          // Marvel usa UPC en lugar de ISBN
          return await _marvelClient.searchByUpc(isbn);

        case ApiSource.comicVine:
          if (!ApiKeys.hasComicVineKey) {
            debugPrint('Comic Vine API: Sin clave configurada, saltando...');
            return null;
          }
          final results = await _comicVineClient.searchIssues(title ?? isbn);
          return results.isNotEmpty ? results.first : null;

        case ApiSource.mangaDex:
        case ApiSource.googleBooks:
        case ApiSource.openLibrary:
        case ApiSource.casaDelLibro:
          // Delegar al BookApiService existente
          return await _bookApiService.searchByIsbn(isbn);

        case ApiSource.superHero:
          // SuperHero API no busca por ISBN, es solo para personajes
          return null;
      }
    } catch (e) {
      debugPrint('Error en ${source.name}: $e');
      return null;
    }
  }

  /// Enriquece un libro con información adicional
  Future<Book> _enrichBook(Book book) async {
    // Si ya tiene publisher y universe, no enriquecer
    if (book.publisher != null && book.comicUniverse != null) {
      return book;
    }

    // Detectar tipo de cómic
    final comicType = ComicTypeDetector.detectFromBook(book);

    String? publisher = book.publisher;
    String? comicUniverse = book.comicUniverse;

    // Asignar publisher y universo según tipo detectado
    switch (comicType) {
      case ComicType.marvel:
        publisher ??= 'Marvel';
        comicUniverse ??= 'Marvel Universe';
        break;
      case ComicType.dc:
        publisher ??= 'DC Comics';
        comicUniverse ??= 'DC Universe';
        break;
      case ComicType.manga:
        // Intentar detectar editorial de manga
        publisher ??= _detectMangaPublisher(book.title);
        break;
      case ComicType.spanish:
        publisher ??= _detectSpanishPublisher(book.title);
        break;
      default:
        break;
    }

    // Intentar obtener información del personaje principal
    if (comicUniverse == null) {
      final character = _superHeroClient.extractCharacterFromTitle(book.title);
      if (character != null) {
        final universe = await _superHeroClient.getUniverseFromCharacter(character);
        comicUniverse ??= universe;
      }
    }

    return book.copyWith(
      publisher: publisher,
      comicUniverse: comicUniverse,
    );
  }

  /// Detecta la editorial de manga basándose en el título
  String? _detectMangaPublisher(String title) {
    final lowerTitle = title.toLowerCase();

    // Editoriales comunes de manga en España
    if (lowerTitle.contains('planeta') || lowerTitle.contains('3 en 1')) {
      return 'Planeta Cómic';
    }
    if (lowerTitle.contains('norma')) {
      return 'Norma Editorial';
    }
    if (lowerTitle.contains('ivrea')) {
      return 'Editorial Ivrea';
    }
    if (lowerTitle.contains('panini')) {
      return 'Panini Manga';
    }

    return null;
  }

  /// Detecta la editorial española basándose en el título
  String? _detectSpanishPublisher(String title) {
    final lowerTitle = title.toLowerCase();

    if (lowerTitle.contains('mortadelo') || lowerTitle.contains('ibáñez')) {
      return 'Bruguera / Ediciones B';
    }
    if (lowerTitle.contains('superlopez') || lowerTitle.contains('superlópez')) {
      return 'Bruguera / Ediciones B';
    }

    return null;
  }

  /// Verifica el estado de todas las conexiones API
  Future<Map<String, bool>> testAllConnections() async {
    final results = <String, bool>{};

    // Marvel API
    if (ApiKeys.hasMarvelKeys) {
      results['marvel'] = await _marvelClient.testConnection();
    } else {
      results['marvel'] = false;
    }

    // Comic Vine API
    if (ApiKeys.hasComicVineKey) {
      results['comicVine'] = await _comicVineClient.testConnection();
    } else {
      results['comicVine'] = false;
    }

    // SuperHero API (siempre disponible)
    results['superHero'] = await _superHeroClient.testConnection();

    return results;
  }

  /// Obtiene información sobre las APIs configuradas
  Future<Map<String, dynamic>> getApiStatus() async {
    final hasMarvel = ApiKeys.hasMarvelKeys;
    final hasComicVine = ApiKeys.hasComicVineKey;

    return {
      'marvel': {
        'configured': hasMarvel,
        'name': 'Marvel API',
        'description': 'Cómics de Marvel oficiales',
      },
      'comicVine': {
        'configured': hasComicVine,
        'name': 'Comic Vine API',
        'description': 'Marvel, DC, Image y más',
      },
      'superHero': {
        'configured': true,
        'name': 'SuperHero API',
        'description': 'Imágenes de personajes (gratis)',
      },
      'mangaDex': {
        'configured': true,
        'name': 'MangaDex',
        'description': 'Manga japonés (gratis)',
      },
      'googleBooks': {
        'configured': true,
        'name': 'Google Books',
        'description': 'Libros generales (gratis)',
      },
    };
  }
}
