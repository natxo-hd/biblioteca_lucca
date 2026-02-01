import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/comic_theme.dart';
import '../services/new_volume_checker_service.dart';

/// Diálogo que muestra los volúmenes nuevos disponibles para series seguidas.
///
/// Se muestra al abrir la app cuando se detectan novedades.
/// Cada volumen tiene opciones "YA LO TENGO" y "PEDIR A PAPÁ".
class NewVolumesAlertDialog extends StatelessWidget {
  final List<NewVolumeAlert> alerts;
  final void Function(NewVolumeAlert alert, String action) onAction;

  const NewVolumesAlertDialog({
    super.key,
    required this.alerts,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 500),
        decoration: BoxDecoration(
          color: ComicTheme.backgroundCream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ComicTheme.comicBorder,
            width: 4,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              offset: Offset(6, 6),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: alerts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildAlertCard(context, alerts[index]),
              ),
            ),
            _buildCloseButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: ComicTheme.powerGradient,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.new_releases,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            alerts.length == 1
                ? 'NUEVO VOLUMEN DISPONIBLE'
                : '${alerts.length} VOLUMENES NUEVOS',
            style: GoogleFonts.bangers(
              fontSize: 20,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, NewVolumeAlert alert) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ComicTheme.comicBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: ComicTheme.heroGradient,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.seriesName,
                      style: GoogleFonts.bangers(
                        fontSize: 16,
                        color: ComicTheme.comicBorder,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Vol. ${alert.newVolumeNumber}',
                      style: GoogleFonts.comicNeue(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: ComicTheme.secondaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context: context,
                  label: 'YA LO TENGO',
                  icon: Icons.check_circle,
                  color: ComicTheme.powerGreen,
                  onTap: () => onAction(alert, 'have_it'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  context: context,
                  label: 'PEDIR',
                  icon: Icons.card_giftcard,
                  color: ComicTheme.secondaryBlue,
                  onTap: () => onAction(alert, 'request'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.bangers(
                    fontSize: 12,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'CERRAR',
            style: GoogleFonts.bangers(
              fontSize: 14,
              color: Colors.grey[600],
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Muestra el diálogo de volúmenes nuevos disponibles
Future<void> showNewVolumesAlertDialog(
  BuildContext context,
  List<NewVolumeAlert> alerts,
  void Function(NewVolumeAlert alert, String action) onAction,
) {
  return showDialog(
    context: context,
    builder: (context) => NewVolumesAlertDialog(
      alerts: alerts,
      onAction: (alert, action) {
        Navigator.of(context).pop();
        onAction(alert, action);
      },
    ),
  );
}
