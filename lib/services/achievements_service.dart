import 'package:flutter/foundation.dart';
import '../models/achievement.dart';
import '../models/book.dart';
import 'database_service.dart';
import 'reading_history_service.dart';

/// Servicio para gestionar el sistema de logros
class AchievementsService {
  final DatabaseService _dbService = DatabaseService();
  final ReadingHistoryService _historyService = ReadingHistoryService();

  /// Lista de logros pendientes de mostrar (recién desbloqueados)
  final List<Achievement> _pendingAchievements = [];
  List<Achievement> get pendingAchievements => List.unmodifiable(_pendingAchievements);

  /// Consume un logro pendiente (para mostrar celebración)
  Achievement? popPendingAchievement() {
    if (_pendingAchievements.isEmpty) return null;
    return _pendingAchievements.removeAt(0);
  }

  /// Verifica si hay logros pendientes
  bool get hasPendingAchievements => _pendingAchievements.isNotEmpty;

  /// Limpia los logros pendientes
  void clearPendingAchievements() {
    _pendingAchievements.clear();
  }

  /// Verifica y desbloquea logros después de actualizar progreso
  Future<List<Achievement>> checkAfterProgress() async {
    final unlocked = <Achievement>[];

    // Verificar racha
    final streakAchievement = await _checkStreakAchievements();
    if (streakAchievement != null) unlocked.add(streakAchievement);

    // Verificar velocidad (páginas hoy)
    final speedAchievement = await _checkSpeedAchievements();
    if (speedAchievement != null) unlocked.add(speedAchievement);

    // Añadir a pendientes para mostrar
    _pendingAchievements.addAll(unlocked);

    return unlocked;
  }

  /// Verifica y desbloquea logros después de completar un libro
  Future<List<Achievement>> checkAfterCompletion({
    required Book book,
    bool wasMarathon = false,
  }) async {
    final unlocked = <Achievement>[];

    // Verificar primer libro
    final firstBookAchievement = await _checkFirstBook();
    if (firstBookAchievement != null) unlocked.add(firstBookAchievement);

    // Verificar maratón
    if (wasMarathon) {
      final marathonAchievement = await _checkMarathon();
      if (marathonAchievement != null) unlocked.add(marathonAchievement);
    }

    // Verificar coleccionista (serie)
    if (book.seriesName != null) {
      final collectorAchievement = await _checkCollector(book.seriesName!);
      if (collectorAchievement != null) unlocked.add(collectorAchievement);
    }

    // Verificar productividad semanal
    final weeklyAchievement = await _checkWeeklyProductivity();
    if (weeklyAchievement != null) unlocked.add(weeklyAchievement);

    // Verificar productividad mensual
    final monthlyAchievement = await _checkMonthlyProductivity();
    if (monthlyAchievement != null) unlocked.add(monthlyAchievement);

    // Verificar racha
    final streakAchievement = await _checkStreakAchievements();
    if (streakAchievement != null) unlocked.add(streakAchievement);

    // Añadir a pendientes para mostrar
    _pendingAchievements.addAll(unlocked);

    return unlocked;
  }

  /// Verifica logros de racha
  Future<Achievement?> _checkStreakAchievements() async {
    final streak = await _historyService.getCurrentStreak();
    if (streak < 3) return null;

    // Encontrar el logro de racha más alto que aplique
    AchievementDefinition? toUnlock;

    if (streak >= 30 && !await isUnlocked('streak_30')) {
      toUnlock = AchievementDefinitions.streak30;
    } else if (streak >= 14 && !await isUnlocked('streak_14')) {
      toUnlock = AchievementDefinitions.streak14;
    } else if (streak >= 7 && !await isUnlocked('streak_7')) {
      toUnlock = AchievementDefinitions.streak7;
    } else if (streak >= 5 && !await isUnlocked('streak_5')) {
      toUnlock = AchievementDefinitions.streak5;
    } else if (streak >= 3 && !await isUnlocked('streak_3')) {
      toUnlock = AchievementDefinitions.streak3;
    }

    if (toUnlock != null) {
      return await _unlock(toUnlock.id, value: streak);
    }
    return null;
  }

  /// Verifica logros de velocidad
  Future<Achievement?> _checkSpeedAchievements() async {
    final pagesReadToday = await _historyService.getPagesReadToday();
    if (pagesReadToday < 50) return null;

    AchievementDefinition? toUnlock;

    if (pagesReadToday >= 200 && !await isUnlocked('speed_200')) {
      toUnlock = AchievementDefinitions.speed200;
    } else if (pagesReadToday >= 100 && !await isUnlocked('speed_100')) {
      toUnlock = AchievementDefinitions.speed100;
    } else if (pagesReadToday >= 50 && !await isUnlocked('speed_50')) {
      toUnlock = AchievementDefinitions.speed50;
    }

    if (toUnlock != null) {
      return await _unlock(toUnlock.id, value: pagesReadToday);
    }
    return null;
  }

  /// Verifica logro de primer libro
  Future<Achievement?> _checkFirstBook() async {
    if (await isUnlocked('first_book')) return null;

    // El primer libro ya se completó si estamos aquí
    return await _unlock('first_book');
  }

  /// Verifica logro de maratón
  Future<Achievement?> _checkMarathon() async {
    if (await isUnlocked('marathon')) return null;
    return await _unlock('marathon');
  }

  /// Verifica logros de coleccionista
  Future<Achievement?> _checkCollector(String seriesName) async {
    final count = await _dbService.countCompletedVolumesInSeries(seriesName);

    AchievementDefinition? toUnlock;

    if (count >= 10 && !await isUnlocked('collector_10')) {
      toUnlock = AchievementDefinitions.collector10;
    } else if (count >= 5 && !await isUnlocked('collector_5')) {
      toUnlock = AchievementDefinitions.collector5;
    } else if (count >= 3 && !await isUnlocked('collector_3')) {
      toUnlock = AchievementDefinitions.collector3;
    }

    if (toUnlock != null) {
      return await _unlock(toUnlock.id, value: count);
    }
    return null;
  }

  /// Verifica logro de productividad semanal
  Future<Achievement?> _checkWeeklyProductivity() async {
    if (await isUnlocked('weekly_2')) return null;

    final booksThisWeek = await _historyService.getBooksCompletedThisWeek();
    if (booksThisWeek >= 2) {
      return await _unlock('weekly_2', value: booksThisWeek);
    }
    return null;
  }

  /// Verifica logro de productividad mensual
  Future<Achievement?> _checkMonthlyProductivity() async {
    if (await isUnlocked('monthly_5')) return null;

    final booksThisMonth = await _historyService.getBooksCompletedThisMonth();
    if (booksThisMonth >= 5) {
      return await _unlock('monthly_5', value: booksThisMonth);
    }
    return null;
  }

  /// Desbloquea un logro
  Future<Achievement> _unlock(String achievementId, {int? value}) async {
    final achievement = Achievement(
      id: achievementId,
      value: value,
    );

    await _dbService.unlockAchievement(achievement);
    debugPrint('AchievementsService: Desbloqueado ${achievement.definition.title}!');

    return achievement;
  }

  /// Verifica si un logro está desbloqueado
  Future<bool> isUnlocked(String achievementId) async {
    return await _dbService.isAchievementUnlocked(achievementId);
  }

  /// Obtiene todos los logros desbloqueados
  Future<List<Achievement>> getUnlockedAchievements() async {
    return await _dbService.getUnlockedAchievements();
  }

  /// Obtiene el conteo de logros desbloqueados
  Future<int> getUnlockedCount() async {
    final unlocked = await getUnlockedAchievements();
    return unlocked.length;
  }

  /// Obtiene el total de logros disponibles
  int get totalAchievements => AchievementDefinitions.all.length;

  /// Obtiene la racha actual
  Future<int> getCurrentStreak() async {
    return await _historyService.getCurrentStreak();
  }

  /// Obtiene las páginas leídas hoy
  Future<int> getPagesReadToday() async {
    return await _historyService.getPagesReadToday();
  }

  /// Obtiene estadísticas para la pantalla de logros
  Future<Map<String, dynamic>> getAchievementStats() async {
    final unlocked = await getUnlockedAchievements();
    final streak = await getCurrentStreak();
    final pagesReadToday = await getPagesReadToday();
    final pagesReadWeek = await _historyService.getPagesReadThisWeek();
    final booksWeek = await _historyService.getBooksCompletedThisWeek();
    final booksMonth = await _historyService.getBooksCompletedThisMonth();

    return {
      'unlockedCount': unlocked.length,
      'totalCount': totalAchievements,
      'currentStreak': streak,
      'pagesReadToday': pagesReadToday,
      'pagesReadWeek': pagesReadWeek,
      'booksCompletedWeek': booksWeek,
      'booksCompletedMonth': booksMonth,
      'unlockedAchievements': unlocked,
    };
  }
}
