import 'package:flutter/foundation.dart';
import '../models/reading_event.dart';
import 'database_service.dart';

/// Servicio para gestionar el histórico de lectura
class ReadingHistoryService {
  final DatabaseService _dbService = DatabaseService();

  /// Registra un progreso de lectura
  Future<void> recordProgress({
    required int bookId,
    required int previousPage,
    required int newPage,
  }) async {
    // Solo registrar si hay progreso positivo
    if (newPage <= previousPage) return;

    final event = ReadingEvent.progress(
      bookId: bookId,
      previousPage: previousPage,
      newPage: newPage,
    );

    await _dbService.insertReadingEvent(event);

    // Actualizar estadísticas diarias
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _dbService.updateDailyStats(today, addPages: event.pagesRead);

    debugPrint('ReadingHistory: +${event.pagesRead} páginas (libro $bookId)');
  }

  /// Registra el inicio de lectura de un libro
  Future<void> recordStarted({required int bookId}) async {
    final event = ReadingEvent.started(bookId: bookId);
    await _dbService.insertReadingEvent(event);
    debugPrint('ReadingHistory: Iniciado libro $bookId');
  }

  /// Registra la finalización de un libro
  Future<void> recordCompletion({
    required int bookId,
    required int totalPages,
    int? previousPage,
  }) async {
    final event = ReadingEvent.completed(
      bookId: bookId,
      totalPages: totalPages,
      previousPage: previousPage,
    );

    await _dbService.insertReadingEvent(event);

    // Actualizar estadísticas diarias
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (event.pagesRead > 0) {
      await _dbService.updateDailyStats(today, addPages: event.pagesRead);
    }
    await _dbService.updateDailyStats(today, addBooksCompleted: 1);

    debugPrint('ReadingHistory: Completado libro $bookId (+${event.pagesRead} páginas)');
  }

  /// Obtiene las páginas leídas hoy
  Future<int> getPagesReadToday() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return await _dbService.getPagesReadOnDate(today);
  }

  /// Obtiene las páginas leídas en una fecha específica
  Future<int> getPagesReadOnDate(DateTime date) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    return await _dbService.getPagesReadOnDate(dateStr);
  }

  /// Obtiene el histórico de lectura de un libro
  Future<List<ReadingEvent>> getBookHistory(int bookId) async {
    return await _dbService.getReadingHistory(bookId);
  }

  /// Obtiene los eventos de lectura de hoy
  Future<List<ReadingEvent>> getTodayEvents() async {
    return await _dbService.getReadingEventsForDate(DateTime.now());
  }

  /// Obtiene las estadísticas de los últimos N días
  Future<List<Map<String, dynamic>>> getRecentStats({int days = 7}) async {
    return await _dbService.getDailyStatsRange(days);
  }

  /// Obtiene la racha actual de lectura (días consecutivos)
  Future<int> getCurrentStreak() async {
    final dates = await _dbService.getDatesWithReadingActivity(limit: 60);
    if (dates.isEmpty) return 0;

    // Verificar si hay actividad hoy o ayer
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final yesterdayStr = today.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);

    // Si no hay actividad hoy ni ayer, la racha es 0
    if (dates.first != todayStr && dates.first != yesterdayStr) {
      return 0;
    }

    // Contar días consecutivos
    int streak = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      final current = DateTime.parse(dates[i]);
      final previous = DateTime.parse(dates[i + 1]);
      final diff = current.difference(previous).inDays;

      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  /// Verifica si un libro se empezó y terminó el mismo día (maratón)
  Future<bool> wasCompletedSameDay(int bookId) async {
    final history = await getBookHistory(bookId);

    ReadingEvent? startEvent;
    ReadingEvent? completeEvent;

    for (final event in history) {
      if (event.eventType == ReadingEventType.started) {
        startEvent = event;
      } else if (event.eventType == ReadingEventType.completed) {
        completeEvent = event;
      }
    }

    if (startEvent == null || completeEvent == null) return false;

    // Comparar fechas (solo día)
    final startDate = startEvent.timestamp.toIso8601String().substring(0, 10);
    final completeDate = completeEvent.timestamp.toIso8601String().substring(0, 10);

    return startDate == completeDate;
  }

  /// Obtiene el total de páginas leídas en la última semana
  Future<int> getPagesReadThisWeek() async {
    final stats = await getRecentStats(days: 7);
    int total = 0;
    for (final day in stats) {
      total += (day['pagesRead'] as int? ?? 0);
    }
    return total;
  }

  /// Obtiene el total de libros completados en la última semana
  Future<int> getBooksCompletedThisWeek() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return await _dbService.countCompletedBooksInPeriod(weekAgo, now);
  }

  /// Obtiene el total de libros completados en el último mes
  Future<int> getBooksCompletedThisMonth() async {
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));
    return await _dbService.countCompletedBooksInPeriod(monthAgo, now);
  }
}
