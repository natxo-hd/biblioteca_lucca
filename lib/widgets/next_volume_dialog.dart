import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/book.dart';
import '../theme/comic_theme.dart';
import '../services/email_service.dart';
import '../services/parent_settings_service.dart';

class NextVolumeDialog extends StatefulWidget {
  final Book finishedBook;
  final VoidCallback onHaveIt;
  final VoidCallback onClose;

  const NextVolumeDialog({
    super.key,
    required this.finishedBook,
    required this.onHaveIt,
    required this.onClose,
  });

  @override
  State<NextVolumeDialog> createState() => _NextVolumeDialogState();
}

class _NextVolumeDialogState extends State<NextVolumeDialog> {
  // Estados: 'ask' -> '¿Tienes el libro?', 'request' -> 'Enviar mail', 'sent' -> 'Enviado'
  String _currentView = 'ask';
  bool _sending = false;

  String get _nextVolumeTitle =>
      widget.finishedBook.nextVolumeTitle ??
      '${widget.finishedBook.seriesName} Vol. ${(widget.finishedBook.volumeNumber ?? 0) + 1}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
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
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final bool isSent = _currentView == 'sent';
    final bool isRequest = _currentView == 'request';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSent
            ? ComicTheme.powerGreen
            : isRequest
                ? ComicTheme.heroRed
                : ComicTheme.secondaryBlue,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Icon(
            isSent
                ? Icons.check_circle
                : isRequest
                    ? Icons.mail
                    : Icons.auto_stories,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            isSent
                ? '¡ENVIADO!'
                : isRequest
                    ? 'PEDIR LIBRO'
                    : '¡SIGUIENTE AVENTURA!',
            style: GoogleFonts.bangers(
              fontSize: 24,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentView) {
      case 'request':
        return _buildRequestView();
      case 'sent':
        return _buildSentView();
      default:
        return _buildAskView();
    }
  }

  Widget _buildAskView() {
    return Column(
      children: [
        // Portada
        _buildCover(),
        const SizedBox(height: 16),

        // Pregunta
        Text(
          '¿Tienes este libro?',
          style: GoogleFonts.comicNeue(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ComicTheme.comicBorder,
          ),
        ),
        const SizedBox(height: 8),

        // Título
        _buildTitleCard(),
        const SizedBox(height: 24),

        // Botón "¡Sí, lo tengo!"
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onHaveIt,
            icon: const Icon(Icons.check_circle),
            label: Text(
              '¡SÍ, LO TENGO!',
              style: GoogleFonts.bangers(fontSize: 18, letterSpacing: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.powerGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Botón "Pedir este libro"
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _currentView = 'request'),
            icon: const Icon(Icons.mail_outline),
            label: Text(
              'PEDIR ESTE LIBRO',
              style: GoogleFonts.bangers(fontSize: 18, letterSpacing: 1),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: ComicTheme.heroRed,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: ComicTheme.heroRed, width: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        const SizedBox(height: 8),
        // Separador
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'o',
                style: GoogleFonts.comicNeue(color: Colors.grey[400]),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
        const SizedBox(height: 8),
        // Botón "No hay más" (marcar serie como completa)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _markSeriesAsComplete,
            icon: const Icon(Icons.check_circle, size: 18),
            label: Text(
              'SERIE COMPLETA',
              style: GoogleFonts.bangers(fontSize: 16, letterSpacing: 1),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: ComicTheme.powerGreen,
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: ComicTheme.powerGreen, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Botón cerrar
        TextButton(
          onPressed: widget.onClose,
          child: Text(
            'Ahora no',
            style: GoogleFonts.comicNeue(fontSize: 14, color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }

  Future<void> _markSeriesAsComplete() async {
    final parentSettings = ParentSettingsService();
    final seriesName = widget.finishedBook.seriesName ?? widget.finishedBook.title;

    await parentSettings.markSeriesAsComplete(seriesName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡$seriesName marcada como completa!',
            style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
          ),
          backgroundColor: ComicTheme.powerGreen,
        ),
      );
      Navigator.of(context).pop('complete');
    }
  }

  Widget _buildRequestView() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final today = dateFormat.format(DateTime.now());

    return Column(
      children: [
        Text(
          'Enviar solicitud de:',
          style: GoogleFonts.comicNeue(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: ComicTheme.comicBorder,
          ),
        ),
        const SizedBox(height: 16),

        // Card del libro
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ComicTheme.accentYellow.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ComicTheme.primaryOrange, width: 3),
          ),
          child: Column(
            children: [
              const Icon(Icons.menu_book, size: 40, color: ComicTheme.primaryOrange),
              const SizedBox(height: 8),
              Text(
                _nextVolumeTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(fontSize: 20, color: ComicTheme.comicBorder),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Fecha: $today',
          style: GoogleFonts.comicNeue(
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),

        // Botones
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => _currentView = 'ask'),
                child: Text(
                  'VOLVER',
                  style: GoogleFonts.bangers(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _sending ? null : _sendRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ComicTheme.heroRed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'ENVIAR MAIL',
                        style: GoogleFonts.bangers(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSentView() {
    return Column(
      children: [
        const Icon(Icons.mark_email_read, size: 60, color: ComicTheme.powerGreen),
        const SizedBox(height: 16),

        Text(
          '¡Solicitud enviada!',
          style: GoogleFonts.comicNeue(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: ComicTheme.comicBorder,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ComicTheme.powerGreen.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ComicTheme.powerGreen, width: 3),
          ),
          child: Column(
            children: [
              const Icon(Icons.check, size: 40, color: ComicTheme.powerGreen),
              const SizedBox(height: 8),
              Text(
                _nextVolumeTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(fontSize: 20, color: ComicTheme.comicBorder),
              ),
              const SizedBox(height: 8),
              Text(
                '(Añadido a Solicitados)',
                style: GoogleFonts.comicNeue(
                  fontSize: 12,
                  color: ComicTheme.secondaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop('request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.powerGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
              ),
            ),
            child: Text(
              '¡GENIAL!',
              style: GoogleFonts.bangers(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCover() {
    if (widget.finishedBook.nextVolumeCover != null) {
      return Container(
        height: 160,
        width: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ComicTheme.comicBorder, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, offset: Offset(4, 4), blurRadius: 0),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: CachedNetworkImage(
            imageUrl: widget.finishedBook.nextVolumeCover!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.menu_book, size: 40),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 160,
      width: 110,
      decoration: BoxDecoration(
        color: ComicTheme.accentYellow.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ComicTheme.comicBorder, width: 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book, size: 50, color: ComicTheme.primaryOrange),
          const SizedBox(height: 8),
          Text(
            'Vol. ${(widget.finishedBook.volumeNumber ?? 0) + 1}',
            style: GoogleFonts.bangers(fontSize: 20, color: ComicTheme.comicBorder),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ComicTheme.comicBorder, width: 2),
      ),
      child: Text(
        _nextVolumeTitle,
        textAlign: TextAlign.center,
        style: GoogleFonts.comicNeue(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: ComicTheme.comicBorder,
        ),
      ),
    );
  }

  Future<void> _sendRequest() async {
    setState(() => _sending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final emailService = EmailService();

      if (user == null) {
        throw Exception('No hay usuario logueado');
      }

      final success = await emailService.sendBookRequest(
        childName: user.displayName ?? 'Lucca',
        bookTitle: _nextVolumeTitle,
        author: widget.finishedBook.author,
        coverUrl: widget.finishedBook.nextVolumeCover,
      );

      if (success && mounted) {
        setState(() {
          _sending = false;
          _currentView = 'sent';
        });
      } else {
        throw Exception('Error al enviar');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al enviar. Inténtalo de nuevo.',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.heroRed,
          ),
        );
      }
    }
  }
}

// Función helper para mostrar el diálogo
Future<String?> showNextVolumeDialog(BuildContext context, Book book) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => NextVolumeDialog(
      finishedBook: book,
      onHaveIt: () => Navigator.of(context).pop('have_it'),
      onClose: () => Navigator.of(context).pop('close'),
    ),
  );
}
