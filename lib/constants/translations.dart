/// Traducciones de nombres de series/personajes español -> ingles
/// para mejorar busquedas de portadas en APIs internacionales
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
    'los vengadores': 'avengers',
    'cuatro fantásticos': 'fantastic four',
    'cuatro fantasticos': 'fantastic four',
    'hombre araña': 'spider-man',
    'la masa': 'hulk',
    'bruja escarlata': 'scarlet witch',
    'soldado de invierno': 'winter soldier',
    'guardianes de la galaxia': 'guardians of the galaxy',
    'patrulla x': 'x-men',
    'la patrulla x': 'x-men',
    'caballero luna': 'moon knight',
    'capitana marvel': 'captain marvel',
    'puño de hierro': 'iron fist',
    'puno de hierro': 'iron fist',
    'guerras secretas': 'secret wars',
    'guerra civil': 'civil war',
    'estela plateada': 'silver surfer',
    'nuevos mutantes': 'new mutants',
    'los nuevos mutantes': 'new mutants',

    // DC
    'linterna verde': 'green lantern',
    'mujer maravilla': 'wonder woman',
    'liga de la justicia': 'justice league',
    'la liga de la justicia': 'justice league',
    'caballero oscuro': 'dark knight',
    'escuadrón suicida': 'suicide squad',
    'escuadron suicida': 'suicide squad',
    'flecha verde': 'green arrow',
    'hombre de acero': 'man of steel',
    'jóvenes titanes': 'teen titans',
    'jovenes titanes': 'teen titans',
    'crisis en tierras infinitas': 'crisis on infinite earths',
    'reino de los supermanes': 'reign of the supermen',

    // Vertigo (coleccion Salvat)
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
    '100 balas': '100 bullets',
    'los invisibles': 'the invisibles',
    'dulces dientes': 'sweet tooth',

    // Manga
    'guardianes de la noche': 'demon slayer kimetsu no yaiba',
    'kimetsu no yaiba': 'demon slayer kimetsu no yaiba',
    'ataque a los titanes': 'attack on titan',
    'shingeki no kyojin': 'attack on titan',
    'mi héroe academia': 'my hero academia',
    'mi heroe academia': 'my hero academia',
    'boku no hero academia': 'my hero academia',
    'cazador x cazador': 'hunter x hunter',
    'bola de dragón': 'dragon ball',
    'bola de dragon': 'dragon ball',
    'caballeros del zodiaco': 'saint seiya',
    'caballeros del zodíaco': 'saint seiya',
    'los muertos vivientes': 'the walking dead',
    'tierra prometida': 'the promised neverland',
    'la tierra prometida': 'the promised neverland',
    'capitán tsubasa': 'captain tsubasa',
    'capitan tsubasa': 'captain tsubasa',
    'oliver y benji': 'captain tsubasa',
    'detective conan': 'case closed',
    'super campeones': 'captain tsubasa',

    // Indie / Image / Dark Horse
    'academia umbrella': 'umbrella academy',
    'la academia umbrella': 'umbrella academy',
    'chicas de papel': 'paper girls',

    // Series que no necesitan traduccion pero normalizan busqueda
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
    'slam dunk': 'slam dunk',
    'vagabond': 'vagabond',
    'berserk': 'berserk',
    'vinland saga': 'vinland saga',
    'black clover': 'black clover',
    'dr. stone': 'dr. stone',
    'mob psycho 100': 'mob psycho 100',
    'fairy tail': 'fairy tail',
    'haikyuu': 'haikyuu',
    'doraemon': 'doraemon',
    'inuyasha': 'inuyasha',
    'evangelion': 'neon genesis evangelion',
    'akira': 'akira',
  };

  /// Lookup inverso precalculado: ingles -> espanol
  static final Map<String, String> _englishToSpanish = _buildReverse();

  static Map<String, String> _buildReverse() {
    final reverse = <String, String>{};
    for (final entry in spanishToEnglish.entries) {
      // Solo guardar la primera traduccion espanola para cada titulo ingles
      // (evita sobreescribir con variantes sin tildes)
      if (!reverse.containsKey(entry.value)) {
        reverse[entry.value] = entry.key;
      }
    }
    return reverse;
  }

  /// Obtiene el nombre en ingles de una serie si existe traduccion
  static String getEnglishName(String seriesName) {
    final lower = seriesName.toLowerCase();
    for (final entry in spanishToEnglish.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return seriesName;
  }

  /// Obtiene el nombre en espanol de una serie si existe traduccion inversa
  static String? getSpanishName(String englishTitle) {
    final lower = englishTitle.toLowerCase();
    for (final entry in _englishToSpanish.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Verifica si hay traduccion disponible
  static bool hasTranslation(String seriesName) {
    final lower = seriesName.toLowerCase();
    return spanishToEnglish.keys.any((key) => lower.contains(key));
  }
}
