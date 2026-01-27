import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/comic_theme.dart';
import '../models/book.dart';

class PreviousVolumesDialog extends StatefulWidget {
  final Book book;
  final int currentVolume;

  const PreviousVolumesDialog({
    super.key,
    required this.book,
    required this.currentVolume,
  });

  @override
  State<PreviousVolumesDialog> createState() => _PreviousVolumesDialogState();
}

class _PreviousVolumesDialogState extends State<PreviousVolumesDialog> {
  late List<bool> _selectedVolumes;
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    // Inicialmente todos seleccionados
    _selectedVolumes = List.generate(widget.currentVolume - 1, (_) => true);
  }

  int get _selectedCount => _selectedVolumes.where((s) => s).length;

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      _selectedVolumes = List.generate(widget.currentVolume - 1, (_) => _selectAll);
    });
  }

  void _onConfirm() {
    final selectedVols = <int>[];
    for (int i = 0; i < _selectedVolumes.length; i++) {
      if (_selectedVolumes[i]) {
        selectedVols.add(i + 1);
      }
    }
    Navigator.pop(context, selectedVols);
  }

  @override
  Widget build(BuildContext context) {
    final seriesName = widget.book.seriesName ?? widget.book.title;
    final previousCount = widget.currentVolume - 1;
    final showList = previousCount > 3;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 350,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header compacto
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: ComicTheme.powerGradient,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.library_books, color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    '¿YA LEÍSTE LOS ANTERIORES?',
                    style: GoogleFonts.bangers(
                      fontSize: 18,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            // Contenido scrollable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Info del libro
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ComicTheme.accentYellow.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ComicTheme.accentYellow, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_stories, color: ComicTheme.primaryOrange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$seriesName Vol. ${widget.currentVolume}',
                              style: GoogleFonts.comicNeue(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: ComicTheme.comicBorder,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      previousCount == 1
                          ? '¿Ya leíste el volumen 1?'
                          : '¿Ya leíste los $previousCount volúmenes anteriores?',
                      style: GoogleFonts.comicNeue(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Los añadiremos como completados',
                      style: GoogleFonts.comicNeue(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),

                    // Lista de volúmenes si hay más de 3
                    if (showList) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_selectedCount de $previousCount seleccionados',
                            style: GoogleFonts.comicNeue(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          TextButton(
                            onPressed: _toggleSelectAll,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _selectAll ? 'Ninguno' : 'Todos',
                              style: GoogleFonts.comicNeue(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: previousCount,
                          itemBuilder: (context, index) {
                            final volumeNum = index + 1;
                            return CheckboxListTile(
                              value: _selectedVolumes[index],
                              onChanged: (value) {
                                setState(() {
                                  _selectedVolumes[index] = value ?? false;
                                  _selectAll = _selectedVolumes.every((s) => s);
                                });
                              },
                              title: Text(
                                'Volumen $volumeNum',
                                style: GoogleFonts.comicNeue(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              activeColor: ComicTheme.powerGreen,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Botones (siempre visibles abajo)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(17)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, <int>[]),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey[400]!, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'NO',
                        style: GoogleFonts.bangers(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _selectedCount > 0 ? _onConfirm : null,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        showList ? '¡AÑADIR $_selectedCount!' : '¡SÍ, TODOS!',
                        style: GoogleFonts.bangers(fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ComicTheme.powerGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(
                            color: ComicTheme.comicBorder,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Muestra el diálogo y retorna la lista de volúmenes a añadir como completados
Future<List<int>?> showPreviousVolumesDialog(
  BuildContext context, {
  required Book book,
  required int currentVolume,
}) async {
  // Solo mostrar si el volumen es mayor que 1
  if (currentVolume <= 1) return null;

  return showDialog<List<int>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PreviousVolumesDialog(
      book: book,
      currentVolume: currentVolume,
    ),
  );
}
