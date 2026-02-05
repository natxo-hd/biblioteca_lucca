import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/translations.dart';
import '../models/book.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'biblioteca_lucca.db');
    return await openDatabase(
      path,
      version: 10,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        isbn TEXT NOT NULL,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        coverUrl TEXT,
        localCoverPath TEXT,
        status TEXT NOT NULL DEFAULT 'reading',
        currentPage INTEGER NOT NULL DEFAULT 0,
        totalPages INTEGER NOT NULL DEFAULT 0,
        addedDate TEXT NOT NULL,
        seriesName TEXT,
        volumeNumber INTEGER,
        nextVolumeIsbn TEXT,
        nextVolumeTitle TEXT,
        nextVolumeCover TEXT,
        pendingSync INTEGER NOT NULL DEFAULT 0,
        isArchived INTEGER NOT NULL DEFAULT 0,
        publisher TEXT,
        comicUniverse TEXT,
        apiSource TEXT,
        sourceUrl TEXT
      )
    ''');

    // Tabla para rastrear libros eliminados (evitar re-sync)
    await db.execute('''
      CREATE TABLE deleted_books(
        isbn TEXT PRIMARY KEY,
        deletedAt TEXT NOT NULL
      )
    ''');

    // Índices para mejorar rendimiento de consultas
    await db.execute('CREATE UNIQUE INDEX idx_books_isbn ON books(isbn)');
    await db.execute('CREATE INDEX idx_books_status ON books(status)');
    await db.execute('CREATE INDEX idx_books_series ON books(seriesName)');
    await db.execute('CREATE INDEX idx_books_archived ON books(isArchived)');
    await db.execute('CREATE INDEX idx_books_pending_sync ON books(pendingSync)');
    await db.execute('CREATE INDEX idx_books_active_status ON books(isArchived, status)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Obtener columnas existentes para evitar errores de duplicado
    final existingColumns = await _getExistingColumns(db, 'books');

    if (oldVersion < 2) {
      // Añadir campos de serie
      await _addColumnIfNotExists(db, 'books', 'seriesName', 'TEXT', existingColumns);
      await _addColumnIfNotExists(db, 'books', 'volumeNumber', 'INTEGER', existingColumns);
      await _addColumnIfNotExists(db, 'books', 'nextVolumeIsbn', 'TEXT', existingColumns);
      await _addColumnIfNotExists(db, 'books', 'nextVolumeTitle', 'TEXT', existingColumns);
      await _addColumnIfNotExists(db, 'books', 'nextVolumeCover', 'TEXT', existingColumns);
    }
    if (oldVersion < 3) {
      // Añadir campo de sincronización
      await _addColumnIfNotExists(db, 'books', 'pendingSync', 'INTEGER NOT NULL DEFAULT 0', existingColumns);
    }
    if (oldVersion < 4) {
      // Añadir campos de información de cómics
      await _addColumnIfNotExists(db, 'books', 'publisher', 'TEXT', existingColumns);
      await _addColumnIfNotExists(db, 'books', 'comicUniverse', 'TEXT', existingColumns);
      await _addColumnIfNotExists(db, 'books', 'apiSource', 'TEXT', existingColumns);
    }
    if (oldVersion < 5) {
      // Añadir URL del producto para buscar volúmenes relacionados
      await _addColumnIfNotExists(db, 'books', 'sourceUrl', 'TEXT', existingColumns);
    }
    if (oldVersion < 6) {
      // Tabla para rastrear libros eliminados (evitar re-sync desde nube)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS deleted_books(
          isbn TEXT PRIMARY KEY,
          deletedAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      // Eliminar duplicados por ISBN antes de crear índice único
      await _removeDuplicateBooks(db);
      // Crear índice único en ISBN para prevenir duplicados futuros
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_books_isbn ON books(isbn)');
    }
    if (oldVersion < 8) {
      // Añadir campo de archivado
      await _addColumnIfNotExists(db, 'books', 'isArchived', 'INTEGER NOT NULL DEFAULT 0', existingColumns);
    }
    if (oldVersion < 9) {
      // Añadir campo de ruta local de portada
      await _addColumnIfNotExists(db, 'books', 'localCoverPath', 'TEXT', existingColumns);
    }
    if (oldVersion < 10) {
      // Añadir índices para mejorar rendimiento de consultas frecuentes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_books_status ON books(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_books_series ON books(seriesName)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_books_archived ON books(isArchived)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_books_pending_sync ON books(pendingSync)');
      // Índice compuesto para consultas de libros activos por estado
      await db.execute('CREATE INDEX IF NOT EXISTS idx_books_active_status ON books(isArchived, status)');
    }
  }

  /// Obtiene las columnas existentes de una tabla
  Future<Set<String>> _getExistingColumns(Database db, String table) async {
    final result = await db.rawQuery('PRAGMA table_info($table)');
    return result.map((row) => row['name'] as String).toSet();
  }

  /// Añade una columna solo si no existe
  Future<void> _addColumnIfNotExists(
    Database db,
    String table,
    String column,
    String type,
    Set<String> existingColumns,
  ) async {
    if (!existingColumns.contains(column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  /// Ejecuta limpieza de duplicados lógicos (llamar después de inicializar)
  Future<int> runLogicalDuplicatesCleanup() async {
    final removed = await cleanupLogicalDuplicates();
    if (removed > 0) {
      print('🧹 Eliminados $removed duplicados lógicos');
    }
    return removed;
  }

  /// Elimina libros duplicados, manteniendo el que tiene más información
  Future<void> _removeDuplicateBooks(Database db) async {
    // Encontrar ISBNs duplicados
    final duplicates = await db.rawQuery('''
      SELECT isbn, COUNT(*) as count
      FROM books
      GROUP BY isbn
      HAVING count > 1
    ''');

    for (final dup in duplicates) {
      final isbn = dup['isbn'] as String;

      // Obtener todos los libros con este ISBN
      final books = await db.query(
        'books',
        where: 'isbn = ?',
        whereArgs: [isbn],
        orderBy: 'id ASC', // Mantener el más antiguo
      );

      if (books.length > 1) {
        // Mantener el primero (más antiguo), eliminar el resto
        final keepId = books.first['id'] as int;
        await db.delete(
          'books',
          where: 'isbn = ? AND id != ?',
          whereArgs: [isbn, keepId],
        );
      }
    }
  }

  Future<int> insertBook(Book book) async {
    final db = await database;
    // Usar IGNORE para evitar error si el ISBN ya existe (por el UNIQUE index)
    return await db.insert(
      'books',
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Inserta un libro solo si no existe (devuelve el ID existente si ya está)
  Future<int> insertBookIfNotExists(Book book) async {
    // Verificar si ya existe
    final existing = await getBookByIsbn(book.isbn);
    if (existing != null) {
      return existing.id!;
    }
    return await insertBook(book);
  }

  Future<List<Book>> getBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      orderBy: 'addedDate DESC',
    );
    return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
  }

  Future<List<Book>> getBooksByStatus(String status) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'addedDate DESC',
    );
    return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
  }

  Future<Book?> getBookByIsbn(String isbn) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'isbn = ?',
      whereArgs: [isbn],
    );
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  /// Busca un libro por serie y número de volumen (normalizado)
  /// Usa traducciones español↔inglés para detectar la misma serie con nombre diferente
  Future<Book?> getBookBySeriesAndVolume(String seriesName, int volumeNumber) async {
    final db = await database;

    // Buscar todos los libros con ese volumen
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'volumeNumber = ?',
      whereArgs: [volumeNumber],
    );

    // Comparar series usando matching robusto (traducciones + normalización)
    for (final map in maps) {
      final bookSeries = map['seriesName'] as String?;
      if (bookSeries != null && _seriesMatch(bookSeries, seriesName)) {
        return Book.fromMap(map);
      }
      // También verificar el título por si no tiene seriesName
      final title = map['title'] as String;
      if (_seriesMatch(title, seriesName)) {
        return Book.fromMap(map);
      }
    }

    return null;
  }

  /// Devuelve los números de volumen que ya existen en la biblioteca para una serie
  Future<Set<int>> getExistingVolumeNumbers(String seriesName) async {
    final db = await database;
    final normalizedSeries = _normalizeSeriesName(seriesName);

    debugPrint('🔍 getExistingVolumeNumbers: "$seriesName" → normalized: "$normalizedSeries"');

    // Solo libros activos (no archivados)
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      columns: ['volumeNumber', 'seriesName', 'title', 'isbn'],
      where: 'volumeNumber IS NOT NULL AND isArchived = 0',
    );

    final existing = <int>{};
    for (final map in maps) {
      final bookSeries = map['seriesName'] as String?;
      final title = map['title'] as String;
      final volNum = map['volumeNumber'] as int;
      final isbn = map['isbn'] as String?;

      if (bookSeries != null && _seriesMatch(bookSeries, seriesName)) {
        existing.add(volNum);
        debugPrint('  ✅ Vol.$volNum encontrado (por serie): "$bookSeries" isbn=$isbn');
      } else if (_seriesMatch(title, seriesName)) {
        existing.add(volNum);
        debugPrint('  ✅ Vol.$volNum encontrado (por título): "$title" isbn=$isbn');
      }
    }

    debugPrint('📊 Volúmenes existentes para "$seriesName": $existing');
    return existing;
  }

  /// Normaliza el nombre de serie para comparación
  String _normalizeSeriesName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s*(vol\.?|volume)\s*\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\d+\s*$'), '') // Quitar número al final
        .replaceAll(RegExp(r'\s*\(de\s*\d+\)\s*', caseSensitive: false), '') // Quitar "(de X)"
        .replaceAll(RegExp(r'\s*\d+\s*en\s*1\s*', caseSensitive: false), '') // Quitar "3 en 1"
        .replaceAll(RegExp(r'[^\w\s]'), '') // Quitar puntuación
        .replaceAll(RegExp(r'\s+'), ' ') // Normalizar espacios
        .trim();
  }

  /// Comprueba si dos nombres de serie se refieren a la misma serie,
  /// considerando traducciones español↔inglés y contenimiento
  bool _seriesMatch(String a, String b) {
    final normA = _normalizeSeriesName(a);
    final normB = _normalizeSeriesName(b);

    // Match exacto
    if (normA == normB) return true;
    if (normA.isEmpty || normB.isEmpty) return false;

    // Contenimiento (para variantes con subtítulos)
    if (normA.length > 5 && normB.length > 5) {
      if (normA.contains(normB) || normB.contains(normA)) return true;
    }

    // Traducciones español↔inglés
    final englishA = ComicTranslations.getEnglishName(a);
    if (_normalizeSeriesName(englishA) == normB) return true;

    final englishB = ComicTranslations.getEnglishName(b);
    if (_normalizeSeriesName(englishB) == normA) return true;

    // También comparar traducciones entre sí
    if (_normalizeSeriesName(englishA) == _normalizeSeriesName(englishB) &&
        englishA.toLowerCase() != a.toLowerCase()) return true;

    final spanishA = ComicTranslations.getSpanishName(a);
    if (spanishA != null && _normalizeSeriesName(spanishA) == normB) return true;

    final spanishB = ComicTranslations.getSpanishName(b);
    if (spanishB != null && _normalizeSeriesName(spanishB) == normA) return true;

    return false;
  }

  /// Encuentra duplicados lógicos (mismo contenido, diferente registro)
  Future<List<List<Book>>> findLogicalDuplicates() async {
    final db = await database;
    final allBooks = await getAllBooks();
    final duplicateGroups = <String, List<Book>>{};

    for (final book in allBooks) {
      if (book.volumeNumber == null) continue;

      // Crear clave única normalizada: serie + volumen
      final seriesKey = book.seriesName ?? book.title;
      final normalizedKey = '${_normalizeSeriesName(seriesKey)}_${book.volumeNumber}';

      if (!duplicateGroups.containsKey(normalizedKey)) {
        duplicateGroups[normalizedKey] = [];
      }
      duplicateGroups[normalizedKey]!.add(book);
    }

    // Devolver solo los grupos con más de un libro
    return duplicateGroups.values.where((group) => group.length > 1).toList();
  }

  /// Limpia duplicados lógicos (mantiene el que tiene más progreso)
  Future<int> cleanupLogicalDuplicates() async {
    final duplicateGroups = await findLogicalDuplicates();
    int removed = 0;

    for (final group in duplicateGroups) {
      // Ordenar: el que tiene más progreso primero, luego el más antiguo
      group.sort((a, b) {
        // Primero por progreso (mayor primero)
        final progressCompare = b.currentPage.compareTo(a.currentPage);
        if (progressCompare != 0) return progressCompare;
        // Luego por fecha (más antiguo primero)
        return a.addedDate.compareTo(b.addedDate);
      });

      // Mantener el primero, eliminar el resto
      final toKeep = group.first;
      for (int i = 1; i < group.length; i++) {
        await deleteBook(group[i].id!);
        removed++;
      }
    }

    return removed;
  }

  Future<int> updateBook(Book book) async {
    final db = await database;
    return await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<int> updateCurrentPage(int id, int page) async {
    final db = await database;
    return await db.update(
      'books',
      {'currentPage': page},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      'books',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateTotalPages(int id, int totalPages) async {
    final db = await database;
    return await db.update(
      'books',
      {'totalPages': totalPages},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateCoverUrl(int id, String coverUrl) async {
    final db = await database;
    return await db.update(
      'books',
      {'coverUrl': coverUrl},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateLocalCoverPath(int id, String localPath) async {
    final db = await database;
    return await db.update(
      'books',
      {'localCoverPath': localPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSeriesInfo(int id, Book book) async {
    final db = await database;
    await db.update(
      'books',
      {
        'seriesName': book.seriesName,
        'volumeNumber': book.volumeNumber,
        'nextVolumeIsbn': book.nextVolumeIsbn,
        'nextVolumeTitle': book.nextVolumeTitle,
        'nextVolumeCover': book.nextVolumeCover,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteBook(int id) async {
    final db = await database;
    return await db.delete(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Métodos para sincronización

  Future<List<Book>> getAllBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      orderBy: 'addedDate DESC',
    );
    return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
  }

  Future<List<Book>> getPendingSyncBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'pendingSync = ?',
      whereArgs: [1],
    );
    return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
  }

  Future<void> markAsSynced(int id) async {
    final db = await database;
    await db.update(
      'books',
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllAsPendingSync() async {
    final db = await database;
    await db.update('books', {'pendingSync': 1});
  }

  /// Busca libros de la misma serie que tengan sourceUrl
  /// Búsqueda case-insensitive y con variaciones en título
  Future<Book?> getBookWithSourceUrlBySeries(String seriesName) async {
    final db = await database;
    // Búsqueda case-insensitive: primero por seriesName exacto, luego por título
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT * FROM books
      WHERE (LOWER(seriesName) = LOWER(?) OR LOWER(title) LIKE LOWER(?))
      AND sourceUrl IS NOT NULL AND sourceUrl != ""
      ORDER BY id DESC
      LIMIT 1
      ''',
      [seriesName, '%$seriesName%'],
    );
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  /// Actualiza la sourceUrl de un libro
  Future<int> updateSourceUrl(int id, String sourceUrl) async {
    final db = await database;
    return await db.update(
      'books',
      {'sourceUrl': sourceUrl},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Métodos para rastrear libros eliminados

  /// Marca un ISBN como eliminado para evitar re-sync
  Future<void> markAsDeleted(String isbn) async {
    final db = await database;
    await db.insert(
      'deleted_books',
      {
        'isbn': isbn,
        'deletedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Verifica si un ISBN fue eliminado localmente
  Future<bool> wasDeleted(String isbn) async {
    final db = await database;
    final result = await db.query(
      'deleted_books',
      where: 'isbn = ?',
      whereArgs: [isbn],
    );
    return result.isNotEmpty;
  }

  /// Elimina un ISBN de la lista de eliminados (si el usuario lo vuelve a añadir)
  Future<void> unmarkAsDeleted(String isbn) async {
    final db = await database;
    await db.delete(
      'deleted_books',
      where: 'isbn = ?',
      whereArgs: [isbn],
    );
  }

  /// Purga entradas antiguas de deleted_books (más de 90 días)
  Future<int> purgeOldDeletedBooks() async {
    final db = await database;
    final cutoff = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
    return await db.delete(
      'deleted_books',
      where: 'deletedAt < ?',
      whereArgs: [cutoff],
    );
  }

  /// Obtiene todos los ISBNs eliminados
  Future<List<String>> getDeletedIsbns() async {
    final db = await database;
    final result = await db.query('deleted_books');
    return result.map((row) => row['isbn'] as String).toList();
  }

  /// Limpia libros duplicados manualmente (mantiene el más antiguo)
  /// Devuelve el número de duplicados eliminados
  Future<int> cleanupDuplicates() async {
    final db = await database;

    // Contar duplicados antes
    final duplicatesBefore = await db.rawQuery('''
      SELECT SUM(count - 1) as total FROM (
        SELECT isbn, COUNT(*) as count
        FROM books
        GROUP BY isbn
        HAVING count > 1
      )
    ''');

    final totalBefore = (duplicatesBefore.first['total'] as int?) ?? 0;

    if (totalBefore > 0) {
      await _removeDuplicateBooks(db);
    }

    return totalBefore;
  }

  /// Cuenta cuántos libros duplicados hay
  Future<int> countDuplicates() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(count - 1) as total FROM (
        SELECT isbn, COUNT(*) as count
        FROM books
        GROUP BY isbn
        HAVING count > 1
      )
    ''');
    return (result.first['total'] as int?) ?? 0;
  }

  // Métodos para archivar series

  /// Archiva o desarchiva un libro
  Future<void> setArchived(int id, bool archived) async {
    final db = await database;
    await db.update(
      'books',
      {'isArchived': archived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Archiva todos los libros de una serie
  Future<void> archiveSeries(String seriesName) async {
    final db = await database;
    await db.update(
      'books',
      {'isArchived': 1},
      where: 'seriesName = ?',
      whereArgs: [seriesName],
    );
  }

  /// Desarchiva todos los libros de una serie
  Future<void> unarchiveSeries(String seriesName) async {
    final db = await database;
    await db.update(
      'books',
      {'isArchived': 0},
      where: 'seriesName = ?',
      whereArgs: [seriesName],
    );
  }

  /// Obtiene libros archivados
  Future<List<Book>> getArchivedBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'isArchived = ?',
      whereArgs: [1],
      orderBy: 'seriesName ASC, volumeNumber ASC',
    );
    return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
  }

  /// Obtiene libros NO archivados por estado
  Future<List<Book>> getActiveBooksByStatus(String status) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'status = ? AND isArchived = 0',
      whereArgs: [status],
      orderBy: 'addedDate DESC',
    );
    return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
  }

  /// Cuenta series archivadas
  Future<int> countArchivedSeries() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT seriesName) as count
      FROM books
      WHERE isArchived = 1 AND seriesName IS NOT NULL
    ''');
    return (result.first['count'] as int?) ?? 0;
  }
}
