import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cliente para la SuperHero API
/// GRATIS - No requiere clave API
/// Útil para obtener imágenes de personajes de cómics
class SuperHeroApiClient {
  // La API es gratuita, usamos un token de acceso público
  static const String _baseUrl = 'https://superheroapi.com/api';
  // Token de acceso público (gratuito)
  static const String _accessToken = '10224313942148498';

  /// Busca un personaje por nombre
  Future<List<Map<String, dynamic>>> searchCharacter(String name) async {
    try {
      final url = Uri.parse('$_baseUrl/$_accessToken/search/$name');
      debugPrint('SuperHero API URL: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseType = data['response'] as String?;

        if (responseType == 'success') {
          final results = data['results'] as List? ?? [];
          return List<Map<String, dynamic>>.from(results);
        } else {
          debugPrint('SuperHero API: ${data['error']}');
        }
      }
    } catch (e) {
      debugPrint('SuperHero API error: $e');
    }
    return [];
  }

  /// Obtiene detalles de un personaje por ID
  Future<Map<String, dynamic>?> getCharacter(int characterId) async {
    try {
      final url = Uri.parse('$_baseUrl/$_accessToken/$characterId');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseType = data['response'] as String?;

        if (responseType == 'success') {
          return data;
        }
      }
    } catch (e) {
      debugPrint('SuperHero API character error: $e');
    }
    return null;
  }

  /// Obtiene la imagen de un personaje
  Future<String?> getCharacterImage(String characterName) async {
    try {
      final results = await searchCharacter(characterName);

      if (results.isNotEmpty) {
        // Buscar el personaje que mejor coincida
        for (final character in results) {
          final name = character['name'] as String? ?? '';
          if (name.toLowerCase() == characterName.toLowerCase()) {
            final image = character['image'] as Map<String, dynamic>?;
            return image?['url'] as String?;
          }
        }

        // Si no hay coincidencia exacta, devolver el primero
        final image = results.first['image'] as Map<String, dynamic>?;
        return image?['url'] as String?;
      }
    } catch (e) {
      debugPrint('SuperHero API image error: $e');
    }
    return null;
  }

  /// Obtiene información del publisher de un personaje
  Future<String?> getCharacterPublisher(String characterName) async {
    try {
      final results = await searchCharacter(characterName);

      if (results.isNotEmpty) {
        for (final character in results) {
          final name = character['name'] as String? ?? '';
          if (name.toLowerCase().contains(characterName.toLowerCase())) {
            final biography = character['biography'] as Map<String, dynamic>?;
            return biography?['publisher'] as String?;
          }
        }

        // Si no hay coincidencia, devolver el primero
        final biography = results.first['biography'] as Map<String, dynamic>?;
        return biography?['publisher'] as String?;
      }
    } catch (e) {
      debugPrint('SuperHero API publisher error: $e');
    }
    return null;
  }

  /// Verifica si la API está disponible
  Future<bool> testConnection() async {
    try {
      final results = await searchCharacter('batman');
      return results.isNotEmpty;
    } catch (e) {
      debugPrint('SuperHero API test error: $e');
      return false;
    }
  }

  /// Extrae el nombre del personaje principal de un título de cómic
  String? extractCharacterFromTitle(String title) {
    final lowerTitle = title.toLowerCase();

    // Lista de personajes conocidos
    final characters = [
      'spider-man',
      'spiderman',
      'batman',
      'superman',
      'wonder woman',
      'iron man',
      'captain america',
      'thor',
      'hulk',
      'wolverine',
      'deadpool',
      'flash',
      'aquaman',
      'green lantern',
      'daredevil',
      'black panther',
      'black widow',
      'hawkeye',
      'ant-man',
      'doctor strange',
      'scarlet witch',
      'vision',
      'nightwing',
      'robin',
      'batgirl',
      'supergirl',
      'harley quinn',
      'joker',
      'catwoman',
      'venom',
      'carnage',
      'thanos',
      'loki',
    ];

    for (final character in characters) {
      if (lowerTitle.contains(character)) {
        // Capitalizar correctamente
        return character.split('-').map((word) {
          return word[0].toUpperCase() + word.substring(1);
        }).join('-');
      }
    }

    return null;
  }

  /// Obtiene el universo (Marvel/DC) basándose en el personaje
  Future<String?> getUniverseFromCharacter(String characterName) async {
    final publisher = await getCharacterPublisher(characterName);

    if (publisher != null) {
      if (publisher.toLowerCase().contains('marvel')) {
        return 'Marvel Universe';
      } else if (publisher.toLowerCase().contains('dc')) {
        return 'DC Universe';
      }
    }

    return null;
  }
}
