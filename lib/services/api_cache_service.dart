/// Entrada de caché con valor y tiempo de expiración
class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  _CacheEntry(this.value, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Servicio de caché en memoria para respuestas de API
/// Evita búsquedas repetidas del mismo ISBN/título
class ApiCacheService {
  // Singleton
  static final ApiCacheService _instance = ApiCacheService._internal();
  factory ApiCacheService() => _instance;
  ApiCacheService._internal();

  /// Caché para búsquedas por ISBN
  final Map<String, _CacheEntry<dynamic>> _isbnCache = {};

  /// Caché para búsquedas por título
  final Map<String, _CacheEntry<dynamic>> _titleCache = {};

  /// Caché para URLs de portadas
  final Map<String, _CacheEntry<String?>> _coverCache = {};

  /// TTL por defecto: 30 minutos
  static const Duration defaultTtl = Duration(minutes: 30);

  /// TTL para portadas: 1 hora (cambian menos frecuentemente)
  static const Duration coverTtl = Duration(hours: 1);

  /// TTL para resultados no encontrados: 5 minutos
  static const Duration notFoundTtl = Duration(minutes: 5);

  /// Obtiene un valor del caché de ISBN
  T? getIsbn<T>(String isbn) {
    final entry = _isbnCache[isbn.toLowerCase()];
    if (entry == null || entry.isExpired) {
      _isbnCache.remove(isbn.toLowerCase());
      return null;
    }
    return entry.value as T?;
  }

  /// Guarda un valor en el caché de ISBN
  void setIsbn<T>(String isbn, T value, {Duration? ttl}) {
    final effectiveTtl = value == null ? notFoundTtl : (ttl ?? defaultTtl);
    _isbnCache[isbn.toLowerCase()] = _CacheEntry(
      value,
      DateTime.now().add(effectiveTtl),
    );
  }

  /// Obtiene resultados del caché de título
  T? getTitle<T>(String title) {
    final key = _normalizeKey(title);
    final entry = _titleCache[key];
    if (entry == null || entry.isExpired) {
      _titleCache.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  /// Guarda resultados en el caché de título
  void setTitle<T>(String title, T value, {Duration? ttl}) {
    final key = _normalizeKey(title);
    final effectiveTtl = (value is List && value.isEmpty)
        ? notFoundTtl
        : (ttl ?? defaultTtl);
    _titleCache[key] = _CacheEntry(
      value,
      DateTime.now().add(effectiveTtl),
    );
  }

  /// Obtiene una URL de portada del caché
  String? getCover(String key) {
    final normalizedKey = _normalizeKey(key);
    final entry = _coverCache[normalizedKey];
    if (entry == null || entry.isExpired) {
      _coverCache.remove(normalizedKey);
      return null;
    }
    return entry.value;
  }

  /// Guarda una URL de portada en el caché
  void setCover(String key, String? coverUrl, {Duration? ttl}) {
    final normalizedKey = _normalizeKey(key);
    final effectiveTtl = coverUrl == null ? notFoundTtl : (ttl ?? coverTtl);
    _coverCache[normalizedKey] = _CacheEntry(
      coverUrl,
      DateTime.now().add(effectiveTtl),
    );
  }

  /// Construye una clave de caché para portadas de volumen
  String buildCoverKey(String series, String author, {int? volumeNumber}) {
    final parts = [series, author];
    if (volumeNumber != null) {
      parts.add('v$volumeNumber');
    }
    return parts.join('_');
  }

  /// Normaliza una clave para el caché
  String _normalizeKey(String key) {
    return key.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Limpia entradas expiradas de todos los cachés
  void cleanExpired() {
    _isbnCache.removeWhere((_, entry) => entry.isExpired);
    _titleCache.removeWhere((_, entry) => entry.isExpired);
    _coverCache.removeWhere((_, entry) => entry.isExpired);
  }

  /// Limpia todo el caché
  void clearAll() {
    _isbnCache.clear();
    _titleCache.clear();
    _coverCache.clear();
  }

  /// Estadísticas del caché
  Map<String, int> get stats => {
    'isbn': _isbnCache.length,
    'title': _titleCache.length,
    'cover': _coverCache.length,
    'total': _isbnCache.length + _titleCache.length + _coverCache.length,
  };
}
