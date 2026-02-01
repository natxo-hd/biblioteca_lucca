/// Genera listas priorizadas de queries de busqueda para portadas de comics.
///
/// Consolida la logica de generacion de queries que estaba duplicada en
/// comic_search_service.dart, book_api_service.dart y tomosygrapas_client.dart.
class QueryGenerator {
  QueryGenerator._();

  /// Genera queries para busqueda de portadas, ordenadas por prioridad.
  ///
  /// [seriesName] - Nombre de la serie (puede incluir "3 EN 1" para omnibus)
  /// [volumeNumber] - Numero de volumen (null si desconocido)
  /// [englishTitle] - Titulo en ingles si hay traduccion disponible
  /// [isOmnibus] - Si es edicion omnibus
  /// [baseSeriesName] - Nombre base de la serie (sin "3 EN 1") para omnibus
  /// [author] - Autor para queries combinadas
  static List<String> forCover(
    String seriesName,
    int? volumeNumber, {
    String? englishTitle,
    bool isOmnibus = false,
    String? baseSeriesName,
    String? author,
  }) {
    final queries = <String>[];
    final seen = <String>{};

    void add(String query) {
      final normalized = query.trim().toLowerCase();
      if (normalized.isNotEmpty && seen.add(normalized)) {
        queries.add(query.trim());
      }
    }

    if (isOmnibus && baseSeriesName != null && volumeNumber != null) {
      // Queries especificas para omnibus
      final volPadded = volumeNumber.toString().padLeft(2, '0');
      final volStr = volumeNumber.toString();

      // Formatos exactos de editoriales espanolas (Planeta Comic)
      add('$baseSeriesName 3 en 1 nº $volPadded');
      add('$baseSeriesName 3 en 1 $volPadded');
      add('$baseSeriesName 3 en 1 $volStr');
      add('$seriesName $volStr');
      if (volumeNumber < 10) {
        add('$seriesName 0$volStr');
      }

      // Variaciones
      add('$baseSeriesName 3 en 1 vol $volStr');
      add('$baseSeriesName omnibus $volStr');

      // Traduccion inglesa + omnibus
      if (englishTitle != null) {
        add('$englishTitle 3 in 1 $volStr');
        add('$englishTitle omnibus $volStr');
        add('$englishTitle omnibus vol $volStr');
      }

      // Fallback generico
      add('$baseSeriesName 3 en 1');
      add(seriesName);
    } else if (volumeNumber != null) {
      // Queries normales con volumen
      final volPadded = volumeNumber.toString().padLeft(2, '0');
      final volStr = volumeNumber.toString();

      // Exacta con zero-padding (comun en editoriales espanolas)
      if (volumeNumber < 10) {
        add('$seriesName 0$volStr');
      }
      // Exacta sin padding
      add('$seriesName $volStr');

      // Variaciones con prefijo
      add('$seriesName vol $volStr');
      add('$seriesName nº $volPadded');
      add('$seriesName #$volStr');

      // Traduccion inglesa
      if (englishTitle != null) {
        add('$englishTitle vol $volStr');
        add('$englishTitle $volStr');
      }

      // Simplificada: primeras 2 palabras + vol
      final words = seriesName.split(RegExp(r'\s+'));
      if (words.length > 2) {
        add('${words.take(2).join(' ')} $volStr');
      }

      // Con autor (ultimo recurso)
      if (author != null && author.isNotEmpty) {
        add('$seriesName $volStr $author');
      }
    } else {
      // Sin volumen
      add(seriesName);
      if (englishTitle != null) {
        add(englishTitle);
      }
      if (author != null && author.isNotEmpty) {
        add('$seriesName $author');
      }
    }

    return queries;
  }

  /// Genera queries para busqueda por titulo en Google Books (con restriccion de idioma).
  ///
  /// Usadas en book_api_service.dart para buscar ISBNs y portadas via Google Books.
  static List<String> forGoogleBooks(
    String title,
    String author, {
    bool isOmnibus = false,
    String? baseSeriesName,
    int? volumeNumber,
  }) {
    final queries = <String>[];
    final seen = <String>{};

    void add(String query) {
      final normalized = query.trim().toLowerCase();
      if (normalized.isNotEmpty && seen.add(normalized)) {
        queries.add(query.trim());
      }
    }

    // Para omnibus, poner queries especificas primero
    if (isOmnibus && baseSeriesName != null && volumeNumber != null) {
      final volPadded = volumeNumber.toString().padLeft(2, '0');
      final volStr = volumeNumber.toString();

      add('$baseSeriesName 3 en 1 nº $volPadded');
      add('$baseSeriesName 3 en 1 $volPadded');
      add('$baseSeriesName 3 en 1 $volStr planeta');
      add('$baseSeriesName 3 en 1 vol $volStr');
      add('${baseSeriesName.toLowerCase()} omnibus vol $volStr');
    }

    // Queries genericas
    add(title);
    add('$title $author');
    add('$title planeta');
    add('$title manga planeta');

    return queries;
  }

  /// Genera queries para busqueda alternativa de volumen en Google Books.
  static List<String> forVolumeSearch(String title) {
    return [
      '$title 3 en 1',
      '$title nº',
      '$title vol',
    ];
  }
}
