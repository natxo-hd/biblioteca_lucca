import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/comic_theme.dart';

/// Widget de índice alfabético lateral para navegación rápida
class AlphabetIndex extends StatefulWidget {
  /// Letras disponibles (con contenido)
  final Set<String> availableLetters;

  /// Callback cuando se selecciona una letra
  final void Function(String letter) onLetterSelected;

  /// Letra actualmente visible (opcional, para resaltar)
  final String? currentLetter;

  const AlphabetIndex({
    super.key,
    required this.availableLetters,
    required this.onLetterSelected,
    this.currentLetter,
  });

  @override
  State<AlphabetIndex> createState() => _AlphabetIndexState();
}

class _AlphabetIndexState extends State<AlphabetIndex> {
  String? _selectedLetter;
  bool _isDragging = false;

  static const List<String> _alphabet = [
    '#', // Números y símbolos primero
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  void _handleVerticalDrag(DragUpdateDetails details, BoxConstraints constraints) {
    final letterHeight = constraints.maxHeight / _alphabet.length;
    final index = (details.localPosition.dy / letterHeight).clamp(0, _alphabet.length - 1).floor();
    final letter = _alphabet[index];

    if (letter != _selectedLetter && widget.availableLetters.contains(letter)) {
      setState(() => _selectedLetter = letter);
      widget.onLetterSelected(letter);
    }
  }

  void _handleTap(String letter) {
    if (widget.availableLetters.contains(letter)) {
      setState(() => _selectedLetter = letter);
      widget.onLetterSelected(letter);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onVerticalDragStart: (_) => setState(() => _isDragging = true),
          onVerticalDragEnd: (_) => setState(() {
            _isDragging = false;
            _selectedLetter = null;
          }),
          onVerticalDragUpdate: (details) => _handleVerticalDrag(details, constraints),
          child: Container(
            width: 28,
            decoration: BoxDecoration(
              color: _isDragging
                  ? ComicTheme.secondaryBlue.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _alphabet.map((letter) {
                final isAvailable = widget.availableLetters.contains(letter);
                final isSelected = _selectedLetter == letter;
                final isCurrent = widget.currentLetter == letter;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _handleTap(letter),
                    child: Container(
                      width: 28,
                      alignment: Alignment.center,
                      decoration: isSelected
                          ? BoxDecoration(
                              color: ComicTheme.secondaryBlue,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Text(
                        letter,
                        style: GoogleFonts.bangers(
                          fontSize: 11,
                          color: isSelected
                              ? Colors.white
                              : isCurrent
                                  ? ComicTheme.secondaryBlue
                                  : isAvailable
                                      ? ComicTheme.comicBorder
                                      : Colors.grey.withValues(alpha: 0.3),
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// Widget indicador de letra actual (bubble flotante)
class LetterIndicator extends StatelessWidget {
  final String letter;

  const LetterIndicator({super.key, required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ComicTheme.secondaryBlue, Color(0xFF00D4FF)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: ComicTheme.secondaryBlue.withValues(alpha: 0.5),
            blurRadius: 12,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Colors.black38,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.bangers(
          fontSize: 32,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
