import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/achievement.dart';
import '../services/book_provider.dart';
import '../theme/comic_theme.dart';
import '../widgets/achievements_grid.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final provider = context.read<BookProvider>();
    final stats = await provider.achievementsService.getAchievementStats();

    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MIS LOGROS',
          style: GoogleFonts.bangers(
            fontSize: 24,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: ComicTheme.secondaryBlue,
        foregroundColor: Colors.white,
      ),
      body: MangaBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadStats,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header con estadísticas
                      _buildHeader(),
                      const SizedBox(height: 24),

                      // Progreso general
                      _buildProgressSection(),
                      const SizedBox(height: 24),

                      // Grid de logros
                      AchievementsGrid(
                        unlockedAchievements: _stats!['unlockedAchievements'] as List<Achievement>,
                        onTapAchievement: _onTapAchievement,
                      ),

                      const SizedBox(height: 24),

                      // Sección de estadísticas detalladas
                      _buildDetailedStats(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final unlockedCount = _stats!['unlockedCount'] as int;
    final totalCount = _stats!['totalCount'] as int;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: ComicTheme.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ComicTheme.comicBorder, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events,
                color: ComicTheme.accentYellow,
                size: 40,
              ),
              const SizedBox(width: 12),
              Text(
                '$unlockedCount',
                style: GoogleFonts.bangers(
                  fontSize: 56,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Colors.black38,
                      offset: Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              Text(
                ' / $totalCount',
                style: GoogleFonts.bangers(
                  fontSize: 32,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'LOGROS DESBLOQUEADOS',
            style: GoogleFonts.bangers(
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    final unlockedCount = _stats!['unlockedCount'] as int;
    final totalCount = _stats!['totalCount'] as int;
    final progress = unlockedCount / totalCount;

    String message;
    IconData icon;
    Color color;

    if (progress == 1.0) {
      message = 'ERES UN HEROE DE LA LECTURA!';
      icon = Icons.military_tech;
      color = ComicTheme.accentYellow;
    } else if (progress >= 0.75) {
      message = 'CASI LO TIENES TODO!';
      icon = Icons.star;
      color = ComicTheme.powerGreen;
    } else if (progress >= 0.5) {
      message = 'VAS POR MUY BUEN CAMINO!';
      icon = Icons.trending_up;
      color = ComicTheme.primaryOrange;
    } else if (progress >= 0.25) {
      message = 'SIGUE ASI!';
      icon = Icons.bolt;
      color = ComicTheme.secondaryBlue;
    } else {
      message = 'TU AVENTURA ACABA DE EMPEZAR';
      icon = Icons.rocket_launch;
      color = ComicTheme.mangaPink;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ComicTheme.comicBorder, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.bangers(
                    fontSize: 18,
                    color: color,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.bangers(
                  fontSize: 24,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats() {
    final currentStreak = _stats!['currentStreak'] as int;
    final pagesReadToday = _stats!['pagesReadToday'] as int;
    final pagesReadWeek = _stats!['pagesReadWeek'] as int;
    final booksWeek = _stats!['booksCompletedWeek'] as int;
    final booksMonth = _stats!['booksCompletedMonth'] as int;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ComicTheme.comicBorder, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics,
                color: ComicTheme.secondaryBlue,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'TUS ESTADISTICAS',
                style: GoogleFonts.bangers(
                  fontSize: 18,
                  color: ComicTheme.comicBorder,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatRow(
            icon: Icons.local_fire_department,
            label: 'Racha actual',
            value: '$currentStreak dias',
            color: currentStreak >= 3 ? const Color(0xFFFF5722) : Colors.grey[600]!,
          ),
          const Divider(height: 16),
          _buildStatRow(
            icon: Icons.auto_stories,
            label: 'Paginas hoy',
            value: '$pagesReadToday',
            color: pagesReadToday >= 50 ? ComicTheme.powerGreen : Colors.grey[600]!,
          ),
          const Divider(height: 16),
          _buildStatRow(
            icon: Icons.date_range,
            label: 'Paginas esta semana',
            value: '$pagesReadWeek',
            color: ComicTheme.secondaryBlue,
          ),
          const Divider(height: 16),
          _buildStatRow(
            icon: Icons.menu_book,
            label: 'Libros esta semana',
            value: '$booksWeek',
            color: booksWeek >= 2 ? ComicTheme.powerGreen : Colors.grey[600]!,
          ),
          const Divider(height: 16),
          _buildStatRow(
            icon: Icons.calendar_month,
            label: 'Libros este mes',
            value: '$booksMonth',
            color: booksMonth >= 5 ? ComicTheme.powerGreen : Colors.grey[600]!,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.comicNeue(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: ComicTheme.comicBorder,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.bangers(
            fontSize: 18,
            color: color,
          ),
        ),
      ],
    );
  }

  void _onTapAchievement(AchievementDefinition definition, Achievement? achievement) {
    // El tooltip ya se muestra en el AchievementItem
  }
}
