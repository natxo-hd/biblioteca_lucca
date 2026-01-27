import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/http_config.dart';

/// Errores que se pueden reintentar
bool _isRetryableError(dynamic error) {
  if (error is SocketException) return true;
  if (error is TimeoutException) return true;
  if (error is http.ClientException) return true;
  return false;
}

/// Códigos HTTP que se pueden reintentar
bool _isRetryableStatusCode(int statusCode) {
  return statusCode == 408 || // Request Timeout
      statusCode == 429 || // Too Many Requests
      statusCode == 500 || // Internal Server Error
      statusCode == 502 || // Bad Gateway
      statusCode == 503 || // Service Unavailable
      statusCode == 504; // Gateway Timeout
}

/// Ejecuta una operación HTTP con retry y backoff exponencial
///
/// Ejemplo de uso:
/// ```dart
/// final response = await httpRetry(
///   () => http.get(url).timeout(HttpConfig.standardTimeout),
/// );
/// ```
Future<http.Response> httpRetry(
  Future<http.Response> Function() request, {
  int maxRetries = HttpConfig.maxRetries,
  Duration initialDelay = const Duration(milliseconds: 500),
  double backoffMultiplier = HttpConfig.backoffMultiplier,
}) async {
  int attempt = 0;
  Duration delay = initialDelay;

  while (true) {
    try {
      attempt++;
      final response = await request();

      // Si el código es retryable y no hemos agotado los reintentos
      if (_isRetryableStatusCode(response.statusCode) && attempt < maxRetries) {
        debugPrint('HTTP retry: status ${response.statusCode}, attempt $attempt/$maxRetries');
        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * backoffMultiplier).round());
        continue;
      }

      return response;
    } catch (e) {
      if (_isRetryableError(e) && attempt < maxRetries) {
        debugPrint('HTTP retry: error $e, attempt $attempt/$maxRetries');
        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * backoffMultiplier).round());
        continue;
      }
      rethrow;
    }
  }
}

/// Ejecuta una operación genérica con retry y backoff exponencial
///
/// Útil para operaciones que no devuelven http.Response directamente.
///
/// Ejemplo de uso:
/// ```dart
/// final result = await retry(
///   () => apiClient.searchBook(isbn),
///   shouldRetry: (error) => error is TimeoutException,
/// );
/// ```
Future<T> retry<T>(
  Future<T> Function() operation, {
  int maxRetries = HttpConfig.maxRetries,
  Duration initialDelay = const Duration(milliseconds: 500),
  double backoffMultiplier = HttpConfig.backoffMultiplier,
  bool Function(dynamic error)? shouldRetry,
}) async {
  final retryCheck = shouldRetry ?? _isRetryableError;
  int attempt = 0;
  Duration delay = initialDelay;

  while (true) {
    try {
      attempt++;
      return await operation();
    } catch (e) {
      if (retryCheck(e) && attempt < maxRetries) {
        debugPrint('Retry: error $e, attempt $attempt/$maxRetries');
        await Future.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * backoffMultiplier).round());
        continue;
      }
      rethrow;
    }
  }
}

/// Ejecuta múltiples operaciones en paralelo con retry individual
///
/// Si una operación falla después de todos los reintentos, devuelve null
/// para esa operación en lugar de fallar toda la lista.
Future<List<T?>> retryAll<T>(
  List<Future<T> Function()> operations, {
  int maxRetries = HttpConfig.maxRetries,
}) async {
  return Future.wait(
    operations.map((op) async {
      try {
        return await retry(op, maxRetries: maxRetries);
      } catch (e) {
        debugPrint('retryAll: operación falló después de $maxRetries intentos: $e');
        return null;
      }
    }),
  );
}
