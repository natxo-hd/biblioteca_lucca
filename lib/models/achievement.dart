import 'package:flutter/material.dart';
import '../theme/comic_theme.dart';

/// Categorías de logros
enum AchievementCategory {
  streak,       // Rachas de lectura
  speed,        // Velocidad de lectura
  productivity, // Libros completados
  special,      // Logros especiales
}

/// Definición estática de un logro (no varía)
class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final AchievementCategory category;
  final int threshold;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    required this.threshold,
  });
}

/// Modelo para un logro desbloqueado (guardado en BD)
class Achievement {
  final String id;
  final DateTime unlockedAt;
  final int? value; // Valor al desbloquear (ej: días de racha, páginas)

  Achievement({
    required this.id,
    DateTime? unlockedAt,
    this.value,
  }) : unlockedAt = unlockedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'unlockedAt': unlockedAt.toIso8601String(),
      'value': value,
    };
  }

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] as String,
      unlockedAt: DateTime.parse(map['unlockedAt'] as String),
      value: map['value'] as int?,
    );
  }

  /// Obtiene la definición del logro
  AchievementDefinition get definition {
    return AchievementDefinitions.all.firstWhere(
      (d) => d.id == id,
      orElse: () => AchievementDefinition(
        id: id,
        title: 'LOGRO',
        description: 'Logro desconocido',
        icon: Icons.star,
        color: ComicTheme.accentYellow,
        category: AchievementCategory.special,
        threshold: 0,
      ),
    );
  }

  Achievement copyWith({
    String? id,
    DateTime? unlockedAt,
    int? value,
  }) {
    return Achievement(
      id: id ?? this.id,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      value: value ?? this.value,
    );
  }

  @override
  String toString() {
    return 'Achievement(id: $id, unlockedAt: $unlockedAt, value: $value)';
  }
}

/// Definiciones de todos los logros disponibles
class AchievementDefinitions {
  AchievementDefinitions._();

  // ============ RACHAS ============
  static const streak3 = AchievementDefinition(
    id: 'streak_3',
    title: 'CALENTANDO',
    description: '3 dias seguidos leyendo',
    icon: Icons.local_fire_department,
    color: Color(0xFFFF9800),
    category: AchievementCategory.streak,
    threshold: 3,
  );

  static const streak5 = AchievementDefinition(
    id: 'streak_5',
    title: 'EN LLAMAS',
    description: '5 dias seguidos leyendo',
    icon: Icons.whatshot,
    color: Color(0xFFFF5722),
    category: AchievementCategory.streak,
    threshold: 5,
  );

  static const streak7 = AchievementDefinition(
    id: 'streak_7',
    title: 'SEMANA PERFECTA',
    description: '7 dias seguidos leyendo',
    icon: Icons.calendar_today,
    color: Color(0xFFE91E63),
    category: AchievementCategory.streak,
    threshold: 7,
  );

  static const streak14 = AchievementDefinition(
    id: 'streak_14',
    title: 'IMPARABLE',
    description: '14 dias seguidos leyendo',
    icon: Icons.bolt,
    color: Color(0xFF9C27B0),
    category: AchievementCategory.streak,
    threshold: 14,
  );

  static const streak30 = AchievementDefinition(
    id: 'streak_30',
    title: 'LEYENDA',
    description: '30 dias seguidos leyendo',
    icon: Icons.military_tech,
    color: Color(0xFFFFD700),
    category: AchievementCategory.streak,
    threshold: 30,
  );

  // ============ VELOCIDAD ============
  static const speed50 = AchievementDefinition(
    id: 'speed_50',
    title: 'LECTOR RAPIDO',
    description: '50 paginas en un dia',
    icon: Icons.speed,
    color: Color(0xFF2196F3),
    category: AchievementCategory.speed,
    threshold: 50,
  );

  static const speed100 = AchievementDefinition(
    id: 'speed_100',
    title: 'SUPERSONICO',
    description: '100 paginas en un dia',
    icon: Icons.flash_on,
    color: Color(0xFF00BCD4),
    category: AchievementCategory.speed,
    threshold: 100,
  );

  static const speed200 = AchievementDefinition(
    id: 'speed_200',
    title: 'ULTRA INSTINTO',
    description: '200 paginas en un dia',
    icon: Icons.auto_awesome,
    color: Color(0xFF7C4DFF),
    category: AchievementCategory.speed,
    threshold: 200,
  );

  // ============ PRODUCTIVIDAD ============
  static const weekly2 = AchievementDefinition(
    id: 'weekly_2',
    title: 'DEVORADOR',
    description: '2 libros en una semana',
    icon: Icons.menu_book,
    color: Color(0xFF4CAF50),
    category: AchievementCategory.productivity,
    threshold: 2,
  );

  static const monthly5 = AchievementDefinition(
    id: 'monthly_5',
    title: 'INSACIABLE',
    description: '5 libros en un mes',
    icon: Icons.library_books,
    color: Color(0xFF8BC34A),
    category: AchievementCategory.productivity,
    threshold: 5,
  );

  // ============ ESPECIALES ============
  static const marathon = AchievementDefinition(
    id: 'marathon',
    title: 'MARATON',
    description: 'Terminar un libro en un dia',
    icon: Icons.emoji_events,
    color: Color(0xFFFFC107),
    category: AchievementCategory.special,
    threshold: 1,
  );

  static const firstBook = AchievementDefinition(
    id: 'first_book',
    title: 'PRIMER PASO',
    description: 'Completar tu primer libro',
    icon: Icons.celebration,
    color: Color(0xFFE91E63),
    category: AchievementCategory.special,
    threshold: 1,
  );

  static const collector3 = AchievementDefinition(
    id: 'collector_3',
    title: 'FAN',
    description: '3 volumenes de una serie',
    icon: Icons.collections_bookmark,
    color: Color(0xFF3F51B5),
    category: AchievementCategory.special,
    threshold: 3,
  );

  static const collector5 = AchievementDefinition(
    id: 'collector_5',
    title: 'SUPERFAN',
    description: '5 volumenes de una serie',
    icon: Icons.star,
    color: Color(0xFF673AB7),
    category: AchievementCategory.special,
    threshold: 5,
  );

  static const collector10 = AchievementDefinition(
    id: 'collector_10',
    title: 'COLECCIONISTA',
    description: '10 volumenes de una serie',
    icon: Icons.workspace_premium,
    color: Color(0xFFFFD700),
    category: AchievementCategory.special,
    threshold: 10,
  );

  /// Lista de todos los logros
  static const List<AchievementDefinition> all = [
    // Rachas
    streak3,
    streak5,
    streak7,
    streak14,
    streak30,
    // Velocidad
    speed50,
    speed100,
    speed200,
    // Productividad
    weekly2,
    monthly5,
    // Especiales
    marathon,
    firstBook,
    collector3,
    collector5,
    collector10,
  ];

  /// Logros por categoría
  static List<AchievementDefinition> byCategory(AchievementCategory category) {
    return all.where((a) => a.category == category).toList();
  }

  /// Obtiene una definición por ID
  static AchievementDefinition? byId(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
