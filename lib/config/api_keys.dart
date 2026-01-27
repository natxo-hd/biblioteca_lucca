/// Configuración de claves API
/// IMPORTANTE: No subir este archivo a repositorios públicos
class ApiKeys {
  // Marvel API - DESACTIVADA (el portal de desarrolladores ha cerrado)
  static const String marvelPublicKey = '';
  static const String marvelPrivateKey = '';

  // Comic Vine API - https://comicvine.gamespot.com/api/
  // Límite gratuito: 200 llamadas/hora
  // Soporta: Marvel, DC, Image, Dark Horse y más
  static const String comicVineApiKey = '54d75e582474d3e018d6255c0d1a0d6b5b9a3f00';

  // Verificar si las claves están configuradas
  static bool get hasMarvelKeys =>
      marvelPublicKey.isNotEmpty && marvelPrivateKey.isNotEmpty;

  static bool get hasComicVineKey => comicVineApiKey.isNotEmpty;
}
