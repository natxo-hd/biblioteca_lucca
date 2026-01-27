/// Configuración centralizada para llamadas HTTP
/// Proporciona constantes de timeout consistentes para toda la aplicación
class HttpConfig {
  HttpConfig._();

  // ═══════════════════════════════════════════════════════════════════
  // TIMEOUTS
  // ═══════════════════════════════════════════════════════════════════

  /// Timeout para operaciones rápidas (test de conexión, validaciones)
  static const Duration quickTimeout = Duration(seconds: 5);

  /// Timeout estándar para la mayoría de operaciones
  static const Duration standardTimeout = Duration(seconds: 10);

  /// Timeout para operaciones que pueden tardar más (búsquedas complejas)
  static const Duration extendedTimeout = Duration(seconds: 15);

  /// Timeout para operaciones lentas (scraping de páginas grandes)
  static const Duration slowTimeout = Duration(seconds: 20);

  // ═══════════════════════════════════════════════════════════════════
  // DELAYS Y RATE LIMITING
  // ═══════════════════════════════════════════════════════════════════

  /// Delay entre peticiones consecutivas para evitar rate limiting
  static const Duration requestDelay = Duration(milliseconds: 100);

  /// Delay entre peticiones de búsqueda de portadas
  static const Duration coverSearchDelay = Duration(milliseconds: 500);

  /// Delay para retry después de un error
  static const Duration retryDelay = Duration(seconds: 1);

  // ═══════════════════════════════════════════════════════════════════
  // RETRY
  // ═══════════════════════════════════════════════════════════════════

  /// Número máximo de reintentos para operaciones fallidas
  static const int maxRetries = 3;

  /// Factor de backoff exponencial para reintentos
  static const double backoffMultiplier = 2.0;

  // ═══════════════════════════════════════════════════════════════════
  // HEADERS COMUNES
  // ═══════════════════════════════════════════════════════════════════

  /// User-Agent para peticiones HTTP (simula navegador móvil)
  static const String mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 10; Pixel 4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36';

  /// User-Agent para peticiones a APIs
  static const String apiUserAgent = 'BibliotecaLucca/1.0';

  /// Headers básicos para peticiones web
  static Map<String, String> get webHeaders => {
        'User-Agent': mobileUserAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
      };

  /// Headers para peticiones AJAX
  static Map<String, String> get ajaxHeaders => {
        'User-Agent': mobileUserAgent,
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'X-Requested-With': 'XMLHttpRequest',
      };

  /// Headers para APIs REST
  static Map<String, String> get apiHeaders => {
        'User-Agent': apiUserAgent,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
}
