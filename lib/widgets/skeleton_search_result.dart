import 'package:flutter/material.dart';
import '../theme/comic_theme.dart';

/// Skeleton para resultados de búsqueda mientras cargan
class SkeletonSearchResult extends StatefulWidget {
  const SkeletonSearchResult({super.key});

  @override
  State<SkeletonSearchResult> createState() => _SkeletonSearchResultState();
}

class _SkeletonSearchResultState extends State<SkeletonSearchResult>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // Portada skeleton
                Container(
                  width: 55,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300]!.withValues(alpha: _animation.value),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.auto_stories,
                      color: Colors.grey[400]!.withValues(alpha: _animation.value),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info skeleton
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300]!.withValues(alpha: _animation.value),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Título línea 2
                      Container(
                        height: 14,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[300]!.withValues(alpha: _animation.value * 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Autor
                      Container(
                        height: 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[300]!.withValues(alpha: _animation.value * 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge skeleton
                Container(
                  width: 30,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[300]!.withValues(alpha: _animation.value * 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Lista de skeletons para búsqueda
class SkeletonSearchResults extends StatelessWidget {
  final int itemCount;

  const SkeletonSearchResults({
    super.key,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonSearchResult(),
    );
  }
}

/// Widget de "Buscando..." con skeleton
class SearchingIndicator extends StatelessWidget {
  final String message;

  const SearchingIndicator({
    super.key,
    this.message = 'Buscando...',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Mensaje de búsqueda animado
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: ComicTheme.primaryOrange,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        // Skeleton results
        const Expanded(
          child: SkeletonSearchResults(itemCount: 5),
        ),
      ],
    );
  }
}
