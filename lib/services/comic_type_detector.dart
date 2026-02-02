import '../models/book.dart';

/// Tipos de cómic soportados
enum ComicType {
  manga,    // Manga japonés
  marvel,   // Marvel Comics
  dc,       // DC Comics
  spanish,  // Editoriales españolas
  indie,    // Independientes/Otros
  unknown,  // Tipo desconocido
}

/// Detector de tipo de cómic basado en ISBN, título y otros metadatos
class ComicTypeDetector {
  // Keywords de Marvel
  static const List<String> _marvelKeywords = [
    'spider-man',
    'spiderman',
    'avengers',
    'vengadores',
    'x-men',
    'iron man',
    'thor',
    'hulk',
    'captain america',
    'capitán américa',
    'capitan america',
    'deadpool',
    'wolverine',
    'fantastic four',
    'cuatro fantásticos',
    'daredevil',
    'black panther',
    'pantera negra',
    'guardians of the galaxy',
    'guardianes de la galaxia',
    'doctor strange',
    'ant-man',
    'venom',
    'carnage',
    'marvel',
    'thanos',
    'loki',
    'black widow',
    'viuda negra',
    'hawkeye',
    'ojo de halcón',
    'scarlet witch',
    'bruja escarlata',
    'vision',
    'moon knight',
    'caballero luna',
    'ms. marvel',
    'captain marvel',
    'capitana marvel',
    'she-hulk',
  ];

  // Keywords de DC
  static const List<String> _dcKeywords = [
    'batman',
    'superman',
    'wonder woman',
    'mujer maravilla',
    'justice league',
    'liga de la justicia',
    'flash',
    'aquaman',
    'green lantern',
    'linterna verde',
    'green arrow',
    'flecha verde',
    'nightwing',
    'robin',
    'batgirl',
    'joker',
    'harley quinn',
    'catwoman',
    'supergirl',
    'teen titans',
    'jóvenes titanes',
    'cyborg',
    'shazam',
    'watchmen',
    'sandman',
    'constantine',
    'swamp thing',
    'cosa del pantano',
    'doom patrol',
    'suicide squad',
    'escuadrón suicida',
    // Vertigo
    'fables',
    'fábulas',
    'fabulas',
    'preacher',
    'predicador',
    'v for vendetta',
    'v de vendetta',
    'y the last man',
    'y, el último hombre',
    'y el último hombre',
    'el último hombre',
    'hellblazer',
    'transmetropolitan',
    'lucifer',
    '100 bullets',
    '100 balas',
    'dc comics',
    'dc',
    'gotham',
    'metropolis',
    'arkham',
    'dark knight',
    'caballero oscuro',
    'man of steel',
    'hombre de acero',
  ];

  // Keywords de manga
  static const List<String> _mangaKeywords = [
    'nº',
    'n°',
    'vol.',
    'volumen',
    'tomo',
    'manga',
    'shonen',
    'shounen',
    'shojo',
    'shoujo',
    'seinen',
    'josei',
    'one piece',
    'naruto',
    'dragon ball',
    'attack on titan',
    'shingeki no kyojin',
    'ataque a los titanes',
    'demon slayer',
    'kimetsu no yaiba',
    'guardianes de la noche', // Demon Slayer en español
    'my hero academia',
    'boku no hero',
    'mi héroe academia',
    'jujutsu kaisen',
    'death note',
    'bleach',
    'hunter x hunter',
    'cazador x cazador',
    'fullmetal alchemist',
    'tokyo ghoul',
    'chainsaw man',
    'spy x family',
    'one punch man',
    'sword art online',
    'fairy tail',
    'black clover',
    'haikyuu',
    'slam dunk',
    'vagabond',
    'berserk',
    'vinland saga',
    'dr. stone',
    'promised neverland',
    'yakusoku no neverland',
    'mob psycho',
    'jojo',
    'sailor moon',
    'cardcaptor sakura',
    'inuyasha',
    'detective conan',
    'case closed',
    'akira',
    'evangelion',
    'doraemon',
    'pokemon',
    'yokai watch',
    'captain tsubasa',
    'saint seiya',
    'caballeros del zodiaco',
  ];

  // Keywords de cómics independientes (Image, Dark Horse, etc.)
  static const List<String> _indieKeywords = [
    'radiant black',
    'massive-verse',
    'massiveverse',
    'spawn',
    'invincible',
    'savage dragon',
    'saga',
    'walking dead',
    'the walking dead',
    'witchblade',
    'darkness',
    'image comics',
    'hellboy',
    'sin city',
    'bone',
    'locke & key',
    'locke and key',
    'umbrella academy',
    'scott pilgrim',
    'paper girls',
    'east of west',
    'descender',
    'ascender',
    'lazarus',
    'deadly class',
    'monstress',
    'die',
    'wicked + divine',
    'wicked and divine',
    'rat queens',
    'black science',
    'low',
    'seven to eternity',
    'fire power',
    'department of truth',
    'ice cream man',
    'something is killing the children',
    'hay algo matando niños',
    'hay algo matando ninos',
    'nocterra',
    'dark horse',
    'boom studios',
    'boom! studios',
    'idw',
    'valiant',
    'bloodshot',
    'harbinger',
    'x-o manowar',
    'power rangers',
    'transformers',
    'sonic',
    'tmnt',
    'teenage mutant',
    'tortugas ninja',
  ];

  // Keywords de editoriales españolas
  static const List<String> _spanishKeywords = [
    'mortadelo',
    'filemón',
    'superlopez',
    'superlópez',
    'ibáñez',
    'ibanez',
    'bruguera',
    'planeta cómic',
    'planeta comic',
    'norma editorial',
    'panini españa',
    'ecc ediciones',
    'zipi y zape',
    '13 rue del percebe',
    'rompetechos',
    'pepe gotera',
    'otilio',
    'anacleto',
    'carpanta',
    'botones sacarino',
    // Colecciones Salvat Disney/Barks
    'pato donald',
    'gran dinastía',
    'gran dinastia',
    'carl barks',
    'tío gilito',
    'tio gilito',
    'uncle scrooge',
    'patoaventuras',
  ];

  /// Detecta el tipo de cómic basándose en el ISBN
  static ComicType detectFromIsbn(String isbn) {
    final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '');

    // ISBN-13 japonés: 978-4-xxx
    if (cleanIsbn.startsWith('9784') || cleanIsbn.startsWith('4')) {
      return ComicType.manga;
    }

    // ISBN-13 español: 978-84-xxx
    if (cleanIsbn.startsWith('97884') || cleanIsbn.startsWith('84')) {
      return ComicType.spanish;
    }

    // ISBN-13 USA/UK: 978-0-xxx o 978-1-xxx
    if (cleanIsbn.startsWith('9780') ||
        cleanIsbn.startsWith('9781') ||
        cleanIsbn.startsWith('0') ||
        cleanIsbn.startsWith('1')) {
      // Podría ser Marvel, DC o indie - necesitamos más info
      return ComicType.unknown;
    }

    return ComicType.unknown;
  }

  /// Detecta el tipo de cómic basándose en el título
  static ComicType detectFromTitle(String title) {
    final lowerTitle = title.toLowerCase();

    // Verificar Marvel
    for (final keyword in _marvelKeywords) {
      if (lowerTitle.contains(keyword)) {
        return ComicType.marvel;
      }
    }

    // Verificar DC
    for (final keyword in _dcKeywords) {
      if (lowerTitle.contains(keyword)) {
        return ComicType.dc;
      }
    }

    // Verificar Manga
    for (final keyword in _mangaKeywords) {
      if (lowerTitle.contains(keyword)) {
        return ComicType.manga;
      }
    }

    // Verificar Indie (Image, Dark Horse, etc.)
    for (final keyword in _indieKeywords) {
      if (lowerTitle.contains(keyword)) {
        return ComicType.indie;
      }
    }

    // Verificar Español
    for (final keyword in _spanishKeywords) {
      if (lowerTitle.contains(keyword)) {
        return ComicType.spanish;
      }
    }

    return ComicType.unknown;
  }

  /// Detecta el tipo de cómic basándose en el autor
  static ComicType detectFromAuthor(String author) {
    final lowerAuthor = author.toLowerCase();

    // Autores de Marvel conocidos
    final marvelAuthors = [
      'matt fraction',
      'fraction',
      'david aja',
      'aja',
      'ed brubaker',
      'brubaker',
      'jonathan hickman',
      'hickman',
      'brian michael bendis',
      'bendis',
      'jason aaron',
      'chris claremont',
      'stan lee',
      'jack kirby',
      'jim starlin',
      'dan slott',
      'nick spencer',
      'ta-nehisi coates',
      'donny cates',
      'chip zdarsky',
      'al ewing',
      'ryan stegman',
    ];

    for (final author in marvelAuthors) {
      if (lowerAuthor.contains(author)) {
        return ComicType.marvel;
      }
    }

    // Autores de DC conocidos
    final dcAuthors = [
      'scott snyder',
      'tom king',
      'geoff johns',
      'grant morrison',
      'frank miller',
      'alan moore',
      'neil gaiman',
      'brian azzarello',
      'greg rucka',
      'james tynion',
      'joshua williamson',
    ];

    for (final author in dcAuthors) {
      if (lowerAuthor.contains(author)) {
        return ComicType.dc;
      }
    }

    // Autores de manga conocidos
    final mangaAuthors = [
      'eiichiro oda',
      'akira toriyama',
      'masashi kishimoto',
      'hajime isayama',
      'koyoharu gotouge',
      'kohei horikoshi',
      'gege akutami',
      'tite kubo',
      'yoshihiro togashi',
      'hiromu arakawa',
      'sui ishida',
      'tatsuki fujimoto',
      'tatsuya endo',
      'one',
      'yusuke murata',
      'hiro mashima',
    ];

    for (final author in mangaAuthors) {
      if (lowerAuthor.contains(author)) {
        return ComicType.manga;
      }
    }

    // Autores españoles
    final spanishAuthors = [
      'francisco ibáñez',
      'francisco ibanez',
      'jan',
      'escobar',
      'vázquez',
      'vazquez',
    ];

    for (final author in spanishAuthors) {
      if (lowerAuthor.contains(author)) {
        return ComicType.spanish;
      }
    }

    return ComicType.unknown;
  }

  /// Detecta el tipo de cómic basándose en el publisher
  static ComicType detectFromPublisher(String? publisher) {
    if (publisher == null || publisher.isEmpty) {
      return ComicType.unknown;
    }

    final lowerPublisher = publisher.toLowerCase();

    // Publishers de Marvel
    if (lowerPublisher.contains('marvel') ||
        lowerPublisher.contains('panini') && lowerPublisher.contains('marvel')) {
      return ComicType.marvel;
    }

    // Publishers de DC
    if (lowerPublisher.contains('dc comics') ||
        lowerPublisher.contains('ecc') ||
        lowerPublisher.contains('vertigo')) {
      return ComicType.dc;
    }

    // Publishers de manga
    if (lowerPublisher.contains('shueisha') ||
        lowerPublisher.contains('kodansha') ||
        lowerPublisher.contains('shogakukan') ||
        lowerPublisher.contains('planeta') && lowerPublisher.contains('manga') ||
        lowerPublisher.contains('norma') ||
        lowerPublisher.contains('ivrea')) {
      return ComicType.manga;
    }

    // Publishers independientes
    if (lowerPublisher.contains('image comics') ||
        lowerPublisher.contains('image') && lowerPublisher.contains('comics') ||
        lowerPublisher.contains('dark horse') ||
        lowerPublisher.contains('boom! studios') ||
        lowerPublisher.contains('boom studios') ||
        lowerPublisher.contains('idw') ||
        lowerPublisher.contains('dynamite') ||
        lowerPublisher.contains('valiant') ||
        lowerPublisher.contains('aftershock') ||
        lowerPublisher.contains('oni press') ||
        lowerPublisher.contains('scout comics') ||
        lowerPublisher.contains('vault comics')) {
      return ComicType.indie;
    }

    // Publishers españoles
    if (lowerPublisher.contains('bruguera') ||
        lowerPublisher.contains('ediciones b')) {
      return ComicType.spanish;
    }

    return ComicType.unknown;
  }

  /// Detecta el tipo de cómic basándose en un Book completo
  /// Usa múltiples fuentes de información para mejor precisión
  static ComicType detectFromBook(Book book) {
    // Prioridad 1: Publisher (si está disponible)
    if (book.publisher != null) {
      final fromPublisher = detectFromPublisher(book.publisher);
      if (fromPublisher != ComicType.unknown) {
        return fromPublisher;
      }
    }

    // Prioridad 2: ISBN
    final fromIsbn = detectFromIsbn(book.isbn);
    if (fromIsbn != ComicType.unknown) {
      return fromIsbn;
    }

    // Prioridad 3: Título
    final fromTitle = detectFromTitle(book.title);
    if (fromTitle != ComicType.unknown) {
      return fromTitle;
    }

    // Prioridad 4: Serie (si está disponible)
    if (book.seriesName != null) {
      final fromSeries = detectFromTitle(book.seriesName!);
      if (fromSeries != ComicType.unknown) {
        return fromSeries;
      }
    }

    // Prioridad 5: Autor
    final fromAuthor = detectFromAuthor(book.author);
    if (fromAuthor != ComicType.unknown) {
      return fromAuthor;
    }

    return ComicType.unknown;
  }

  /// Refina el tipo detectado por ISBN usando titulo y publisher.
  ///
  /// Soluciona el problema de que ISBN 97884 (espanol) enruta incorrectamente
  /// ediciones espanolas de comics internacionales. Ejemplo:
  /// - ISBN 97884 + titulo "Batman" -> ComicType.dc (no spanish)
  /// - ISBN 97884 + publisher "Panini Marvel" -> ComicType.marvel (no spanish)
  static ComicType refineType(ComicType isbnType, String? title, String? publisher) {
    // Solo refinar si el ISBN dice "spanish"
    if (isbnType != ComicType.spanish) {
      return isbnType;
    }

    // Prioridad 1: Publisher (mas fiable)
    if (publisher != null && publisher.isNotEmpty) {
      final fromPublisher = detectFromPublisher(publisher);
      if (fromPublisher != ComicType.unknown && fromPublisher != ComicType.spanish) {
        return fromPublisher;
      }
    }

    // Prioridad 2: Titulo
    if (title != null && title.isNotEmpty) {
      final fromTitle = detectFromTitle(title);
      if (fromTitle != ComicType.unknown && fromTitle != ComicType.spanish) {
        return fromTitle;
      }
    }

    // Sin refinamiento posible, mantener spanish
    return isbnType;
  }

  /// Obtiene una descripción legible del tipo de cómic
  static String getTypeName(ComicType type) {
    switch (type) {
      case ComicType.manga:
        return 'Manga';
      case ComicType.marvel:
        return 'Marvel';
      case ComicType.dc:
        return 'DC Comics';
      case ComicType.spanish:
        return 'Cómic Español';
      case ComicType.indie:
        return 'Independiente';
      case ComicType.unknown:
        return 'Desconocido';
    }
  }
}
