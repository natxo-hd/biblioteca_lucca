/// Traducciones de nombres de series/personajes español → inglés
/// para mejorar búsquedas de portadas en APIs internacionales
class ComicTranslations {
  ComicTranslations._();

  /// Diccionario principal de traducciones
  static const Map<String, String> spanishToEnglish = {
    // Marvel
    'ojo de halcón': 'hawkeye',
    'ojo de halcon': 'hawkeye',
    'hombre de hierro': 'iron man',
    'capitán américa': 'captain america',
    'capitan america': 'captain america',
    'viuda negra': 'black widow',
    'pantera negra': 'black panther',
    'vengadores': 'avengers',
    'cuatro fantásticos': 'fantastic four',
    'cuatro fantasticos': 'fantastic four',
    'hombre araña': 'spider-man',
    'la masa': 'hulk',
    'bruja escarlata': 'scarlet witch',
    'soldado de invierno': 'winter soldier',
    'guardianes de la galaxia': 'guardians of the galaxy',

    // DC
    'linterna verde': 'green lantern',
    'mujer maravilla': 'wonder woman',
    'liga de la justicia': 'justice league',
    'caballero oscuro': 'dark knight',
    'escuadrón suicida': 'suicide squad',
    'flecha verde': 'green arrow',
    'hombre de acero': 'man of steel',

    // Vertigo (colección Salvat)
    'la cosa del pantano': 'swamp thing',
    'cosa del pantano': 'swamp thing',
    'fábulas': 'fables',
    'fabulas': 'fables',
    'predicador': 'preacher',
    'y, el último hombre': 'y the last man',
    'y el último hombre': 'y the last man',
    'y, el ultimo hombre': 'y the last man',
    'y el ultimo hombre': 'y the last man',
    'el último hombre': 'y the last man',
    'el ultimo hombre': 'y the last man',
    'v de vendetta': 'v for vendetta',
    'los leones de bagdad': 'pride of baghdad',
    'leones de bagdad': 'pride of baghdad',

    // Manga
    'guardianes de la noche': 'demon slayer kimetsu no yaiba',
    'kimetsu no yaiba': 'demon slayer kimetsu no yaiba',
    'ataque a los titanes': 'attack on titan',
    'shingeki no kyojin': 'attack on titan',
    'mi héroe academia': 'my hero academia',
    'mi heroe academia': 'my hero academia',
    'boku no hero academia': 'my hero academia',
    'cazador x cazador': 'hunter x hunter',

    // Series que no necesitan traducción pero normalizan búsqueda
    'one punch man': 'one punch man',
    'hunter x hunter': 'hunter x hunter',
    'jujutsu kaisen': 'jujutsu kaisen',
    'chainsaw man': 'chainsaw man',
    'spy x family': 'spy x family',
    'dragon ball': 'dragon ball',
    'naruto': 'naruto',
    'one piece': 'one piece',
    'death note': 'death note',
    'fullmetal alchemist': 'fullmetal alchemist',
    'tokyo ghoul': 'tokyo ghoul',
    'bleach': 'bleach',
  };

  /// Obtiene el nombre en inglés de una serie si existe traducción
  static String getEnglishName(String seriesName) {
    final lower = seriesName.toLowerCase();
    for (final entry in spanishToEnglish.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return seriesName;
  }

  /// Verifica si hay traducción disponible
  static bool hasTranslation(String seriesName) {
    final lower = seriesName.toLowerCase();
    return spanishToEnglish.keys.any((key) => lower.contains(key));
  }
}
