import 'package:flutter/foundation.dart';

/// Circuit breaker simple para evitar llamadas repetidas a APIs caídas.
///
/// Si un servicio falla [_failureThreshold] veces en [_failureWindow],
/// el circuito se abre y las llamadas se saltan durante [_resetTimeout].
class CircuitBreaker {
  static final CircuitBreaker _instance = CircuitBreaker._internal();
  factory CircuitBreaker() => _instance;
  CircuitBreaker._internal();

  final Map<String, List<DateTime>> _failures = {};
  final Map<String, DateTime> _openUntil = {};

  static const int _failureThreshold = 3;
  static const Duration _failureWindow = Duration(minutes: 5);
  static const Duration _resetTimeout = Duration(minutes: 2);

  /// Verifica si el circuito está abierto (API no disponible)
  bool isOpen(String service) {
    final openUntil = _openUntil[service];
    if (openUntil == null) return false;
    if (DateTime.now().isAfter(openUntil)) {
      _openUntil.remove(service);
      _failures.remove(service);
      debugPrint('CircuitBreaker: $service reabierto');
      return false;
    }
    return true;
  }

  /// Registra un fallo en el servicio
  void recordFailure(String service) {
    final now = DateTime.now();
    _failures.putIfAbsent(service, () => []);
    _failures[service]!.removeWhere((t) => now.difference(t) > _failureWindow);
    _failures[service]!.add(now);
    if (_failures[service]!.length >= _failureThreshold) {
      _openUntil[service] = now.add(_resetTimeout);
      debugPrint('CircuitBreaker: $service abierto (${_failures[service]!.length} fallos en $_failureWindow)');
    }
  }

  /// Registra un éxito, reseteando los fallos
  void recordSuccess(String service) {
    _failures.remove(service);
    _openUntil.remove(service);
  }

  /// Ejecuta una operación con protección de circuit breaker.
  /// Devuelve null si el circuito está abierto o si la operación falla.
  Future<T?> execute<T>(String service, Future<T?> Function() operation) async {
    if (isOpen(service)) {
      debugPrint('CircuitBreaker: $service saltado (circuito abierto)');
      return null;
    }
    try {
      final result = await operation();
      if (result != null) {
        recordSuccess(service);
      }
      return result;
    } catch (e) {
      recordFailure(service);
      debugPrint('CircuitBreaker: Error en $service: $e');
      return null;
    }
  }
}
