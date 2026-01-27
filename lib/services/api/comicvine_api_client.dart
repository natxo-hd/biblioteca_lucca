import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/book.dart';
import '../../config/api_keys.dart';

/// Cliente para la API de Comic Vine
/// Usa clave incrustada en la app
/// Soporta Marvel, DC, Image, Dark Horse y muchos más
class ComicVineApiClient {
  static const String _baseUrl = 'https://comicvine.gamespot.com/api';

  ComicVineApiClient();

  /// Construye los parámetros base para las peticiones
  Map<String, String>? _buildBaseParams() {
    if (!ApiKeys.hasComicVineKey) {
      debugPrint('Comic Vine API: Clave no configurada');
      return null;
    }

    return {
      'api_key': ApiKeys.comicVineApiKey,
      'format': 'json',
    };
  }

  /// Busca issues (números) por título
  Future<List<Book>> searchIssues(String query) async {
    try {
      final baseParams = _buildBaseParams();
      if (baseParams == null) return [];

      final queryParams = {
        ...baseParams,
        'query': query,
        'resources': 'issue',
        'limit': '10',
      };

      final url = Uri.parse('$_baseUrl/search/').replace(queryParameters: queryParams);
      debugPrint('Comic Vine URL: $url');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'BibliotecaLucca/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final statusCode = data['status_code'] as int?;

        if (statusCode == 1) {
          final results = data['results'] as List? ?? [];
          return results.map((issue) => _parseIssue(issue)).toList();
        } else {
          debugPrint('Comic Vine API error: ${data['error']}');
        }
      } else if (response.statusCode == 401) {
        debugPrint('Comic Vine API: Error de autenticación (401)');
      } else if (response.statusCode == 420) {
        debugPrint('Comic Vine API: Rate limit excedido (420)');
      } else {
        debugPrint('Comic Vine API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Comic Vine API error: $e');
    }
    return [];
  }

  /// Busca volúmenes (series) por nombre
  Future<List<Map<String, dynamic>>> searchVolumes(String query) async {
    try {
      final baseParams = _buildBaseParams();
      if (baseParams == null) return [];

      final queryParams = {
        ...baseParams,
        'query': query,
        'resources': 'volume',
        'limit': '10',
      };

      final url = Uri.parse('$_baseUrl/search/').replace(queryParameters: queryParams);

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'BibliotecaLucca/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status_code'] == 1) {
          return List<Map<String, dynamic>>.from(data['results'] ?? []);
        }
      }
    } catch (e) {
      debugPrint('Comic Vine volumes error: $e');
    }
    return [];
  }

  /// Obtiene los issues de un volumen específico
  Future<List<Book>> getVolumeIssues(int volumeId) async {
    try {
      final baseParams = _buildBaseParams();
      if (baseParams == null) return [];

      final queryParams = {
        ...baseParams,
        'filter': 'volume:$volumeId',
        'sort': 'issue_number:asc',
        'limit': '50',
      };

      final url = Uri.parse('$_baseUrl/issues/').replace(queryParameters: queryParams);

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'BibliotecaLucca/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status_code'] == 1) {
          final results = data['results'] as List? ?? [];
          return results.map((issue) => _parseIssue(issue)).toList();
        }
      }
    } catch (e) {
      debugPrint('Comic Vine volume issues error: $e');
    }
    return [];
  }

  /// Obtiene detalles de un issue específico por ID
  Future<Book?> getIssueDetails(int issueId) async {
    try {
      final baseParams = _buildBaseParams();
      if (baseParams == null) return null;

      final queryParams = {
        ...baseParams,
      };

      final url = Uri.parse('$_baseUrl/issue/4000-$issueId/').replace(queryParameters: queryParams);

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'BibliotecaLucca/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status_code'] == 1) {
          final results = data['results'];
          if (results != null) {
            return _parseIssue(results);
          }
        }
      }
    } catch (e) {
      debugPrint('Comic Vine issue details error: $e');
    }
    return null;
  }

  /// Obtiene la URL de portada para un cómic
  Future<String?> getCoverUrl(String title, int? issueNumber) async {
    try {
      final query = issueNumber != null ? '$title #$issueNumber' : title;
      final issues = await searchIssues(query);

      if (issues.isNotEmpty) {
        return issues.first.coverUrl;
      }
    } catch (e) {
      debugPrint('Comic Vine cover error: $e');
    }
    return null;
  }

  /// Verifica si la clave API es válida
  Future<bool> testConnection() async {
    try {
      final baseParams = _buildBaseParams();
      if (baseParams == null) return false;

      final queryParams = {
        ...baseParams,
        'query': 'batman',
        'resources': 'issue',
        'limit': '1',
      };

      final url = Uri.parse('$_baseUrl/search/').replace(queryParameters: queryParams);

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'BibliotecaLucca/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status_code'] == 1;
      }
      return false;
    } catch (e) {
      debugPrint('Comic Vine test error: $e');
      return false;
    }
  }

  /// Parsea los datos de un issue de Comic Vine a un Book
  Book _parseIssue(Map<String, dynamic> issue) {
    // Obtener nombre del issue
    final issueName = issue['name'] as String?;

    // Obtener número del issue
    final issueNumber = issue['issue_number'] as String?;
    final issueNum = issueNumber != null ? int.tryParse(issueNumber) : null;

    // Obtener volumen/serie
    final volume = issue['volume'] as Map<String, dynamic>?;
    final volumeName = volume?['name'] as String? ?? 'Serie desconocida';

    // Construir título
    String title;
    if (issueName != null && issueName.isNotEmpty) {
      title = issueNumber != null ? '$volumeName #$issueNumber - $issueName' : volumeName;
    } else {
      title = issueNumber != null ? '$volumeName #$issueNumber' : volumeName;
    }

    // Obtener portada
    final image = issue['image'] as Map<String, dynamic>?;
    final coverUrl = image?['medium_url'] as String? ??
        image?['small_url'] as String? ??
        image?['original_url'] as String?;

    // Obtener publisher
    final publisher = volume?['publisher'] as Map<String, dynamic>?;
    final publisherName = publisher?['name'] as String?;

    // Determinar universo basado en publisher
    String? comicUniverse;
    if (publisherName != null) {
      if (publisherName.toLowerCase().contains('marvel')) {
        comicUniverse = 'Marvel Universe';
      } else if (publisherName.toLowerCase().contains('dc')) {
        comicUniverse = 'DC Universe';
      }
    }

    return Book(
      isbn: issue['id']?.toString() ?? '',
      title: title,
      author: publisherName ?? 'Desconocido',
      coverUrl: coverUrl,
      totalPages: 0, // Comic Vine no proporciona páginas
      seriesName: volumeName,
      volumeNumber: issueNum,
      publisher: publisherName,
      comicUniverse: comicUniverse,
      apiSource: 'comicvine',
    );
  }

  /// Detecta el publisher/universo de un cómic basándose en su nombre
  String? detectPublisher(String title) {
    final lowerTitle = title.toLowerCase();

    // Marvel characters/titles
    final marvelKeywords = [
      'spider-man', 'avengers', 'x-men', 'iron man', 'thor', 'hulk',
      'captain america', 'deadpool', 'wolverine', 'fantastic four',
      'daredevil', 'black panther', 'guardians', 'venom', 'marvel',
    ];

    for (final keyword in marvelKeywords) {
      if (lowerTitle.contains(keyword)) {
        return 'Marvel';
      }
    }

    // DC characters/titles
    final dcKeywords = [
      'batman', 'superman', 'wonder woman', 'justice league', 'flash',
      'aquaman', 'green lantern', 'nightwing', 'robin', 'joker',
      'harley quinn', 'dc comics', 'gotham', 'metropolis',
    ];

    for (final keyword in dcKeywords) {
      if (lowerTitle.contains(keyword)) {
        return 'DC Comics';
      }
    }

    return null;
  }
}
