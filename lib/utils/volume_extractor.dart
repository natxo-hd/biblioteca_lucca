/// Resultado de la extraccion de volumen de un titulo
class VolumeInfo {
  final String seriesName;
  final int? volumeNumber;
  final bool isOmnibus;
  final String? baseSeriesName;

  const VolumeInfo({
    required this.seriesName,
    this.volumeNumber,
    this.isOmnibus = false,
    this.baseSeriesName,
  });

  Map<String, dynamic> toMap() => {
        'seriesName': seriesName,
        'volumeNumber': volumeNumber,
        'isOmnibus': isOmnibus,
        'baseSeriesName': baseSeriesName,
      };

  @override
  String toString() =>
      'VolumeInfo(series="$seriesName", vol=$volumeNumber, omnibus=$isOmnibus, base="$baseSeriesName")';
}

/// Extrae informacion de volumen y serie de titulos de comics/manga.
///
/// Consolida la logica duplicada que existia en book_api_service.dart,
/// tomosygrapas_client.dart y comic_search_service.dart.
class VolumeExtractor {
  VolumeExtractor._();

  /// Extrae nombre de serie, numero de volumen y detecta omnibus del titulo.
  static VolumeInfo extractFromTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return const VolumeInfo(seriesName: '');
    }

    // 1. Detectar patron omnibus "X en 1 Y" donde Y es el volumen
    // Ej: "ONE PIECE 3 EN 1 10" -> serie: "ONE PIECE 3 EN 1", volumen: 10
    final omnibusWithVol =
        RegExp(r'^(.+\d+\s*[Ee][Nn]\s*1)\s+(\d+)\s*$');
    final omnibusMatch = omnibusWithVol.firstMatch(trimmed);
    if (omnibusMatch != null) {
      final seriesName = omnibusMatch.group(1)!.trim();
      final vol = int.tryParse(omnibusMatch.group(2) ?? '');
      if (vol != null) {
        final baseMatch = RegExp(r'^(.+?)\s*\d+\s*[Ee][Nn]\s*1',
                caseSensitive: false)
            .firstMatch(seriesName);
        final baseName = baseMatch?.group(1)?.trim();
        return VolumeInfo(
          seriesName: seriesName,
          volumeNumber: vol,
          isOmnibus: true,
          baseSeriesName: baseName,
        );
      }
    }

    // 2. Detectar omnibus sin volumen despues
    // Ej: "ONE PIECE 3 EN 1" -> serie omnibus sin volumen
    // Debe chequearse ANTES de los patrones generales, ya que "number at end"
    // capturaría incorrectamente "1" de "3 EN 1" como volumen.
    final omnibusNoVol =
        RegExp(r'^(.+?)\s*(\d+)\s*[Ee][Nn]\s*1\s*$', caseSensitive: false);
    final omnibusNoVolMatch = omnibusNoVol.firstMatch(trimmed);
    if (omnibusNoVolMatch != null) {
      final baseName = omnibusNoVolMatch.group(1)?.trim();
      return VolumeInfo(
        seriesName: trimmed,
        isOmnibus: true,
        baseSeriesName: baseName,
      );
    }

    // Patrones ordenados por especificidad (mas especificos primero)
    final patterns = <_VolumePattern>[
      // "GREEN BLOOD 02 (DE 5)" o "SERIE 05 (DE 10)"
      _VolumePattern(
        RegExp(r'^(.+?)\s+(\d{1,3})\s*\((?:DE|de)\s*\d+\)',
            caseSensitive: false),
      ),
      // "RADIANT BLACK 02: TEAM-UP" (numero seguido de dos puntos y subtitulo)
      _VolumePattern(
        RegExp(r'^(.+?)\s+(\d{1,3})\s*:\s*[A-Za-zÀ-ÿ]',
            caseSensitive: false),
      ),
      // "SERIE 02 - SUBTITULO" (numero seguido de guion)
      _VolumePattern(
        RegExp(r'^(.+?)\s+(\d{1,3})\s*[-–—]\s*[A-Za-zÀ-ÿ]',
            caseSensitive: false),
      ),
      // "X en 1 nº Y" - omnibus con nº
      _VolumePattern(
        RegExp(r'^(.+?\d+\s*en\s*1)\s*[nN][ºo°]\s*(\d+)',
            caseSensitive: false),
        isOmnibus: true,
      ),
      // "NARUTO Nº 10" / "SERIE n° 5"
      _VolumePattern(
        RegExp(r'^(.+?)\s*[nN][ºo°]\s*(\d+)'),
      ),
      // "Vol. X" / "Volumen X" / "Volume X" / "vol X"
      _VolumePattern(
        RegExp(r'^(.+?)\s*[Vv]ol(?:umen?|\.?)?\s*(\d+)',
            caseSensitive: false),
      ),
      // "DRAGON BALL TOMO 10" / "SERIE T.10"
      _VolumePattern(
        RegExp(r'^(.+?)\s*[Tt](?:omo)?\.?\s*(\d+)',
            caseSensitive: false),
      ),
      // "TITULO: Libro 1" / "TITULO: Parte 1"
      _VolumePattern(
        RegExp(r'^(.+?):\s*[Ll]ibro\s*(\d+)', caseSensitive: false),
      ),
      _VolumePattern(
        RegExp(r'^(.+?):\s*[Pp]arte\s*(\d+)', caseSensitive: false),
      ),
      // "SERIE #10"
      _VolumePattern(
        RegExp(r'^(.+?)\s*#\s*(\d+)'),
      ),
      // "SERIE (10)" - numero entre parentesis
      _VolumePattern(
        RegExp(r'^(.+?)\s*\((\d+)\)\s*$'),
      ),
      // Numero al final: "ONE PIECE 10", "MASSIVE-VERSE: RADIANT BLACK 02"
      _VolumePattern(
        RegExp(r'^(.+?)\s+(\d{1,3})\s*$'),
      ),
    ];

    for (final p in patterns) {
      final match = p.regex.firstMatch(trimmed);
      if (match != null) {
        var seriesName = match.group(1)?.trim();
        final volStr = match.group(2);
        if (seriesName != null && volStr != null) {
          final vol = int.tryParse(volStr);
          if (vol != null && vol > 0 && vol < 10000) {
            seriesName = cleanSeriesName(seriesName);

            // Detectar si la serie es un omnibus
            final isOmni = p.isOmnibus ||
                RegExp(r'\d+\s*[Ee][Nn]\s*1', caseSensitive: false)
                    .hasMatch(seriesName);
            String? baseName;
            if (isOmni) {
              final baseMatch = RegExp(r'^(.+?)\s*\d+\s*[Ee][Nn]\s*1',
                      caseSensitive: false)
                  .firstMatch(seriesName);
              baseName = baseMatch?.group(1)?.trim();
            }

            return VolumeInfo(
              seriesName: seriesName,
              volumeNumber: vol,
              isOmnibus: isOmni,
              baseSeriesName: baseName,
            );
          }
        }
      }
    }

    return VolumeInfo(seriesName: trimmed);
  }

  /// Limpia prefijos/sufijos comunes del nombre de serie
  static String cleanSeriesName(String name) {
    var cleaned = name
        // Quitar prefijos comunes
        .replaceAll(
            RegExp(r'^MASSIVE-VERSE:\s*', caseSensitive: false), '')
        // Quitar "(DE X)" o "(de X)" al final
        .replaceAll(
            RegExp(r'\s*\((?:DE|de)\s*\d+\)\s*$',
                caseSensitive: false),
            '')
        .trim();

    // Si quedo vacio o es solo "3 en 1", devolver el original
    if (cleaned.isEmpty ||
        RegExp(r'^\d+\s*en\s*1$', caseSensitive: false)
            .hasMatch(cleaned)) {
      return name.trim();
    }

    return cleaned;
  }
}

class _VolumePattern {
  final RegExp regex;
  final bool isOmnibus;

  const _VolumePattern(this.regex, {this.isOmnibus = false});
}
