import 'package:flutter/material.dart';

/// Widget skeleton que simula la forma de una BookCard mientras carga
class SkeletonBookCard extends StatefulWidget {
  const SkeletonBookCard({super.key});

  @override
  State<SkeletonBookCard> createState() => _SkeletonBookCardState();
}

class _SkeletonBookCardState extends State<SkeletonBookCard>
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portada skeleton
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[300]!.withValues(alpha: _animation.value),
                  border: Border.all(
                    color: Colors.grey[400]!.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Shimmer effect
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey[200]!.withValues(alpha: _animation.value),
                                Colors.grey[300]!.withValues(alpha: _animation.value + 0.2),
                                Colors.grey[200]!.withValues(alpha: _animation.value),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Icono de libro tenue
                    Center(
                      child: Icon(
                        Icons.auto_stories,
                        size: 32,
                        color: Colors.grey[400]!.withValues(alpha: _animation.value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Título skeleton
            Container(
              height: 14,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[300]!.withValues(alpha: _animation.value),
              ),
            ),
            const SizedBox(height: 4),
            // Segunda línea de título
            Container(
              height: 14,
              width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[300]!.withValues(alpha: _animation.value * 0.7),
              ),
            ),
            const SizedBox(height: 6),
            // Barra de progreso skeleton
            Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: Colors.grey[300]!.withValues(alpha: _animation.value * 0.5),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Grid de skeletons para mostrar mientras cargan los libros
class SkeletonBookGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;

  const SkeletonBookGrid({
    super.key,
    this.itemCount = 9,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonBookCard(),
    );
  }
}

/// Skeleton para una fila horizontal de libros (series)
class SkeletonBookRow extends StatelessWidget {
  final int itemCount;

  const SkeletonBookRow({
    super.key,
    this.itemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 195,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Container(
            width: 110,
            margin: EdgeInsets.only(right: index < itemCount - 1 ? 12 : 0),
            child: const SkeletonBookCard(),
          );
        },
      ),
    );
  }
}

/// Skeleton para header de sección con serie
class SkeletonSeriesHeader extends StatefulWidget {
  const SkeletonSeriesHeader({super.key});

  @override
  State<SkeletonSeriesHeader> createState() => _SkeletonSeriesHeaderState();
}

class _SkeletonSeriesHeaderState extends State<SkeletonSeriesHeader>
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Icono skeleton
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[300]!.withValues(alpha: _animation.value),
                ),
              ),
              const SizedBox(width: 12),
              // Título skeleton
              Expanded(
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.grey[300]!.withValues(alpha: _animation.value),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Badge skeleton
              Container(
                width: 50,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[300]!.withValues(alpha: _animation.value * 0.7),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Skeleton completo para una vista de series agrupadas
class SkeletonGroupedView extends StatelessWidget {
  final int seriesCount;

  const SkeletonGroupedView({
    super.key,
    this.seriesCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: seriesCount,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonSeriesHeader(),
            SizedBox(height: 8),
            SkeletonBookRow(),
            SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
