import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/comic_theme.dart';

/// Barra de búsqueda local con debounce para filtrar libros de la colección
class LocalSearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback? onClear;
  final String hintText;
  final Duration debounceDuration;

  const LocalSearchBar({
    super.key,
    required this.onSearch,
    this.onClear,
    this.hintText = 'Buscar en tu biblioteca...',
    this.debounceDuration = const Duration(milliseconds: 300),
  });

  @override
  State<LocalSearchBar> createState() => _LocalSearchBarState();
}

class _LocalSearchBarState extends State<LocalSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;
  bool _showClear = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _showClear = value.isNotEmpty;
    });

    // Cancelar timer anterior
    _debounceTimer?.cancel();

    // Crear nuevo timer con debounce
    _debounceTimer = Timer(widget.debounceDuration, () {
      widget.onSearch(value.trim().toLowerCase());
    });
  }

  void _onClear() {
    _controller.clear();
    setState(() {
      _showClear = false;
    });
    widget.onSearch('');
    widget.onClear?.call();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onChanged,
        style: GoogleFonts.comicNeue(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: ComicTheme.comicBorder,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.comicNeue(
            color: Colors.grey[400],
            fontWeight: FontWeight.bold,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: ComicTheme.secondaryBlue,
            size: 22,
          ),
          suffixIcon: _showClear
              ? IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: _onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

/// Utilidad para búsqueda fuzzy simple
class FuzzySearch {
  /// Normaliza un string para búsqueda (quita acentos, minúsculas)
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^\w\s]'), '') // Quitar puntuación
        .trim();
  }

  /// Comprueba si el texto contiene la query (fuzzy)
  static bool matches(String text, String query) {
    if (query.isEmpty) return true;

    final normalizedText = normalize(text);
    final normalizedQuery = normalize(query);

    // Búsqueda directa
    if (normalizedText.contains(normalizedQuery)) {
      return true;
    }

    // Búsqueda por palabras (todas las palabras de la query deben estar)
    final queryWords = normalizedQuery.split(RegExp(r'\s+'));
    return queryWords.every((word) => normalizedText.contains(word));
  }

  /// Calcula un score de relevancia (0-100)
  static int relevanceScore(String text, String query) {
    if (query.isEmpty) return 0;

    final normalizedText = normalize(text);
    final normalizedQuery = normalize(query);

    // Match exacto al inicio = 100
    if (normalizedText.startsWith(normalizedQuery)) {
      return 100;
    }

    // Match exacto = 80
    if (normalizedText.contains(normalizedQuery)) {
      return 80;
    }

    // Match por palabras
    final queryWords = normalizedQuery.split(RegExp(r'\s+'));
    final matchCount = queryWords.where((w) => normalizedText.contains(w)).length;

    if (matchCount == queryWords.length) {
      return 60;
    } else if (matchCount > 0) {
      return (matchCount / queryWords.length * 40).round();
    }

    return 0;
  }
}
