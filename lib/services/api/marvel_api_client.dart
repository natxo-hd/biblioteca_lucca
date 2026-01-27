import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/book.dart';
import '../../config/api_keys.dart';

/// Cliente para la API de Marvel Comics
/// Usa claves incrustadas en la app
class MarvelApiClient {
  static const String _baseUrl = 'https://gateway.marvel.com/v1/public';

  MarvelApiClient();

  /// Genera el hash MD5 requerido por Marvel API
  /// hash = md5(timestamp + privateKey + publicKey)
  String _generateHash(String timestamp, String privateKey, String publicKey) {
    final input = '$timestamp$privateKey$publicKey';
    final bytes = utf8.encode(input);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Construye los parámetros de autenticación
  Map<String, String>? _buildAuthParams() {
    if (!ApiKeys.hasMarvelKeys) {
      debugPrint('Marvel API: Claves no configuradas');
      return null;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final hash = _generateHash(
      timestamp,
      ApiKeys.marvelPrivateKey,
      ApiKeys.marvelPublicKey,
    );

    return {
      'ts': timestamp,
      'apikey': ApiKeys.marvelPublicKey,
      'hash': hash,
    };
  }

  /// Busca cómics por título
  Future<List<Book>> searchByTitle(String title) async {
    try {
      final authParams = _buildAuthParams();
      if (authParams == null) return [];

      final queryParams = {
        ...authParams,
        'titleStartsWith': title,
        'limit': '10',
        'orderBy': '-focDate',
      };

      final url = Uri.parse('$_baseUrl/comics').replace(queryParameters: queryParams);
      debugPrint('Marvel API URL: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['data']?['results'] as List? ?? [];

        return results.map((comic) => _parseComic(comic)).toList();
      } else if (response.statusCode == 401) {
        debugPrint('Marvel API: Error de autenticación (401)');
      } else if (response.statusCode == 429) {
        debugPrint('Marvel API: Rate limit excedido (429)');
      } else {
        debugPrint('Marvel API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Marvel API error: $e');
    }
    return [];
  }

  /// Busca un cómic específico por UPC (código de barras)
  Future<Book?> searchByUpc(String upc) async {
    try {
      final authParams = _buildAuthParams();
      if (authParams == null) return null;

      final queryParams = {
        ...authParams,
        'upc': upc,
      };

      final url = Uri.parse('$_baseUrl/comics').replace(queryParameters: queryParams);
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['data']?['results'] as List? ?? [];

        if (results.isNotEmpty) {
          return _parseComic(results.first);
        }
      }
    } catch (e) {
      debugPrint('Marvel API UPC error: $e');
    }
    return null;
  }

  /// Busca cómics de una serie específica
  Future<List<Book>> searchBySeries(String seriesName) async {
    try {
      final authParams = _buildAuthParams();
      if (authParams == null) return [];

      // Primero buscar la serie
      final seriesParams = {
        ...authParams,
        'titleStartsWith': seriesName,
        'limit': '5',
      };

      final seriesUrl = Uri.parse('$_baseUrl/series').replace(queryParameters: seriesParams);
      final seriesResponse = await http.get(seriesUrl).timeout(const Duration(seconds: 15));

      if (seriesResponse.statusCode == 200) {
        final seriesData = json.decode(seriesResponse.body);
        final series = seriesData['data']?['results'] as List? ?? [];

        if (series.isNotEmpty) {
          final seriesId = series.first['id'];

          // Obtener cómics de la serie
          final comicsParams = {
            ...authParams,
            'series': seriesId.toString(),
            'limit': '20',
            'orderBy': 'issueNumber',
          };

          final comicsUrl = Uri.parse('$_baseUrl/comics').replace(queryParameters: comicsParams);
          final comicsResponse = await http.get(comicsUrl).timeout(const Duration(seconds: 15));

          if (comicsResponse.statusCode == 200) {
            final comicsData = json.decode(comicsResponse.body);
            final comics = comicsData['data']?['results'] as List? ?? [];

            return comics.map((comic) => _parseComic(comic)).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Marvel API series error: $e');
    }
    return [];
  }

  /// Obtiene la URL de portada de un cómic
  Future<String?> getCoverUrl(String title, int? issueNumber) async {
    try {
      final authParams = _buildAuthParams();
      if (authParams == null) return null;

      final queryParams = {
        ...authParams,
        'titleStartsWith': title,
        if (issueNumber != null) 'issueNumber': issueNumber.toString(),
        'limit': '1',
      };

      final url = Uri.parse('$_baseUrl/comics').replace(queryParameters: queryParams);
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['data']?['results'] as List? ?? [];

        if (results.isNotEmpty) {
          final thumbnail = results.first['thumbnail'];
          if (thumbnail != null) {
            final path = thumbnail['path'] as String?;
            final extension = thumbnail['extension'] as String?;
            if (path != null && extension != null && !path.contains('image_not_available')) {
              return '$path/portrait_xlarge.$extension';
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Marvel API cover error: $e');
    }
    return null;
  }

  /// Verifica si las claves API son válidas
  Future<bool> testConnection() async {
    try {
      final authParams = _buildAuthParams();
      if (authParams == null) return false;

      final queryParams = {
        ...authParams,
        'limit': '1',
      };

      final url = Uri.parse('$_baseUrl/comics').replace(queryParameters: queryParams);
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Marvel API test error: $e');
      return false;
    }
  }

  /// Parsea los datos de un cómic de Marvel a un Book
  Book _parseComic(Map<String, dynamic> comic) {
    // Obtener título
    final title = comic['title'] as String? ?? 'Sin título';

    // Obtener número de issue
    final issueNumber = comic['issueNumber'] as num?;

    // Obtener serie
    final series = comic['series'] as Map<String, dynamic>?;
    final seriesName = series?['name'] as String?;

    // Obtener portada
    String? coverUrl;
    final thumbnail = comic['thumbnail'] as Map<String, dynamic>?;
    if (thumbnail != null) {
      final path = thumbnail['path'] as String?;
      final extension = thumbnail['extension'] as String?;
      if (path != null && extension != null && !path.contains('image_not_available')) {
        coverUrl = '$path/portrait_xlarge.$extension';
      }
    }

    // Obtener páginas
    final pageCount = comic['pageCount'] as int? ?? 0;

    // Obtener ISBN/UPC
    final isbn = comic['upc'] as String? ?? comic['isbn'] as String? ?? '';

    // Obtener creadores (escritor/artista)
    String author = 'Marvel Comics';
    final creators = comic['creators'] as Map<String, dynamic>?;
    final creatorItems = creators?['items'] as List? ?? [];
    for (final creator in creatorItems) {
      final role = creator['role'] as String? ?? '';
      if (role.toLowerCase() == 'writer') {
        author = creator['name'] as String? ?? author;
        break;
      }
    }

    return Book(
      isbn: isbn,
      title: title,
      author: author,
      coverUrl: coverUrl,
      totalPages: pageCount,
      seriesName: seriesName,
      volumeNumber: issueNumber?.toInt(),
      publisher: 'Marvel',
      comicUniverse: 'Marvel Universe',
      apiSource: 'marvel',
    );
  }
}
