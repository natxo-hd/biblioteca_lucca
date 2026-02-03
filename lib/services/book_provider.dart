import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../constants/translations.dart';
import 'database_service.dart';
import 'book_api_service.dart';
import 'auth_service.dart';
import 'sync_service.dart';
import 'firestore_service.dart';
import 'comic_search_service.dart';
import 'comic_type_detector.dart';
import 'api/tomosygrapas_client.dart';
import 'image_storage_service.dart';
import 'new_volume_checker_service.dart';

class BookProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final BookApiService _apiService = BookApiService();
  final FirestoreService _firestoreService = FirestoreService();
  final TomosYGrapasClient _tomosYGrapasClient = TomosYGrapasClient();
  final ImageStorageService _imageStorage = ImageStorageService();
  late final ComicSearchService _comicSearchService;

  AuthService? _authService;
  SyncService? _syncService;

  BookProvider() {
    _comicSearchService = ComicSearchService(_apiService);
  }

  List<Book> _readingBooks = [];
  List<Book> _finishedBooks = [];
  List<Book> _wishlistBooks = [];
  List<Book> _archivedBooks = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  List<NewVolumeAlert> _newVolumeAlerts = [];

  List<Book> get readingBooks => _readingBooks;
  List<Book> get finishedBooks => _finishedBooks;
  List<Book> get archivedBooks => _archivedBooks;
  List<Book> get wishlistBooks => _wishlistBooks;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _syncService?.isOnline ?? false;
  List<NewVolumeAlert> get newVolumeAlerts => _newVolumeAlerts;

  // Actualizar servicios cuando cambian
  void updateServices(AuthService authService, SyncService syncService) {
    final wasLoggedIn = _authService?.isLoggedIn ?? false;
    final isNowLoggedIn = authService.isLoggedIn;

    _authService = authService;
    _syncService = syncService;

    // Si el usuario acaba de iniciar sesión, inicializar sync
    if (!wasLoggedIn && isNowLoggedIn && authService.userId != null) {
      _initializeSync(authService.userId!);
    }
  }

  // Inicializar sincronización cuando el usuario inicia sesión
  Future<void> _initializeSync(String userId) async {
    try {
      _isSyncing = true;
      notifyListeners();

      // Crear perfil de usuario en Firestore
      await _firestoreService.createUserProfile(
        userId,
        _authService?.displayName ?? 'Lucca',
        _authService?.email ?? '',
      );

      // Inicializar sync service
      await _syncService?.initialize(userId);

      // Recargar libros
      await loadBooks();

      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error inicializando sync: $e');
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> loadBooks() async {
    _isLoading = true;
    notifyListeners();

    // Limpiar duplicados lógicos si los hay (mismo libro con diferente título/ISBN)
    final duplicatesRemoved = await _dbService.cleanupLogicalDuplicates();
    if (duplicatesRemoved > 0) {
      debugPrint('🧹 Eliminados $duplicatesRemoved libros duplicados');
    }

    // Purgar entradas antiguas de deleted_books (>90 días)
    await _dbService.purgeOldDeletedBooks();

    // Cargar solo libros NO archivados en las listas principales
    _readingBooks = await _dbService.getActiveBooksByStatus('reading');
    _finishedBooks = await _dbService.getActiveBooksByStatus('finished');
    _wishlistBooks = await _dbService.getActiveBooksByStatus('wishlist');

    // Cargar libros archivados
    _archivedBooks = await _dbService.getArchivedBooks();

    _isLoading = false;
    notifyListeners();

    // Descargar portadas que faltan en segundo plano (sin bloquear UI)
    _downloadMissingCoversInBackground();
  }

  /// Descarga portadas en segundo plano para libros que solo tienen URL
  /// y busca portadas para libros que no tienen ninguna
  bool _isDownloadingCovers = false;
  Future<void> _downloadMissingCoversInBackground() async {
    if (_isDownloadingCovers) return; // Evitar múltiples descargas simultáneas
    _isDownloadingCovers = true;

    try {
      final allBooks = await _dbService.getAllBooks();

      // 1. Libros que tienen URL pero no copia local
      final booksNeedingDownload = allBooks.where((b) =>
          b.coverUrl != null &&
          b.coverUrl!.isNotEmpty &&
          (b.localCoverPath == null || b.localCoverPath!.isEmpty)).toList();

      // 2. Libros que NO tienen ninguna portada
      final booksWithoutCover = allBooks.where((b) =>
          (b.coverUrl == null || b.coverUrl!.isEmpty) &&
          (b.localCoverPath == null || b.localCoverPath!.isEmpty)).toList();

      int downloaded = 0;
      int found = 0;

      // Primero descargar las que ya tienen URL
      if (booksNeedingDownload.isNotEmpty) {
        debugPrint('📥 Descargando ${booksNeedingDownload.length} portadas en segundo plano...');

        for (final book in booksNeedingDownload) {
          try {
            final localPath = await _imageStorage.downloadAndSave(book.coverUrl!, book.isbn);
            if (localPath != null && book.id != null) {
              await _dbService.updateLocalCoverPath(book.id!, localPath);
              downloaded++;
              debugPrint('📥 [$downloaded/${booksNeedingDownload.length}] ${book.title}');
            }
          } catch (e) {
            debugPrint('❌ Error descargando portada de ${book.title}: $e');
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }
        debugPrint('✅ Descarga completada: $downloaded/${booksNeedingDownload.length}');
      }

      // Luego buscar portadas para libros que no tienen ninguna
      if (booksWithoutCover.isNotEmpty) {
        debugPrint('🔍 Buscando portadas para ${booksWithoutCover.length} libros sin portada...');

        for (final book in booksWithoutCover) {
          try {
            debugPrint('🔍 Buscando portada: ${book.title}');

            // Intentar buscar portada
            String? coverUrl = await searchCover(
              book.seriesName ?? book.title,
              book.author,
              volumeNumber: book.volumeNumber,
            );

            if (coverUrl != null && coverUrl.isNotEmpty && book.id != null) {
              // Guardar URL y descargar localmente
              await _dbService.updateCoverUrl(book.id!, coverUrl);
              final localPath = await _imageStorage.downloadAndSave(coverUrl, book.isbn);
              if (localPath != null) {
                await _dbService.updateLocalCoverPath(book.id!, localPath);
              }
              found++;
              debugPrint('✅ [$found/${booksWithoutCover.length}] Encontrada: ${book.title}');
            } else {
              debugPrint('❌ No encontrada: ${book.title}');
            }
          } catch (e) {
            debugPrint('❌ Error buscando portada de ${book.title}: $e');
          }
          // Pausa más larga entre búsquedas para no saturar APIs
          await Future.delayed(const Duration(milliseconds: 500));
        }
        debugPrint('✅ Búsqueda completada: encontradas $found/${booksWithoutCover.length}');
      }

      // Recargar libros para actualizar las rutas locales (sin recursión)
      if (downloaded > 0 || found > 0) {
        _readingBooks = await _dbService.getActiveBooksByStatus('reading');
        _finishedBooks = await _dbService.getActiveBooksByStatus('finished');
        _wishlistBooks = await _dbService.getActiveBooksByStatus('wishlist');
        _archivedBooks = await _dbService.getArchivedBooks();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error en descarga de portadas: $e');
    } finally {
      _isDownloadingCovers = false;
    }
  }

  // Forzar sincronización manual
  Future<void> syncNow() async {
    if (_authService?.userId == null) return;

    _isSyncing = true;
    notifyListeners();

    await _syncService?.syncAll();
    await loadBooks();

    _isSyncing = false;
    notifyListeners();
  }

  Future<Book?> searchBookByIsbn(String isbn) async {
    // Usar el servicio de cómics para búsquedas inteligentes
    final result = await _comicSearchService.searchByIsbn(isbn);
    if (result != null) {
      return result;
    }
    // Fallback al servicio tradicional
    return await _apiService.searchByIsbn(isbn);
  }

  Future<List<Book>> searchBookByTitle(String title) async {
    // Detectar tipo y usar servicio apropiado
    final comicType = ComicTypeDetector.detectFromTitle(title);
    if (comicType == ComicType.marvel || comicType == ComicType.dc) {
      final results = await _comicSearchService.searchByTitle(title);
      if (results.isNotEmpty) {
        return results;
      }
    }
    return await _apiService.searchByTitle(title);
  }

  /// Busca portada usando todas las fuentes disponibles
  Future<String?> searchCover(String title, String author, {int? volumeNumber}) async {
    return await _comicSearchService.searchCover(title, author, volumeNumber: volumeNumber);
  }

  /// Obtiene el estado de las APIs configuradas
  Future<Map<String, dynamic>> getApiStatus() async {
    return await _comicSearchService.getApiStatus();
  }

  /// Verifica la conexión de todas las APIs
  Future<Map<String, bool>> testApiConnections() async {
    return await _comicSearchService.testAllConnections();
  }

  Future<bool> addBook(Book book) async {
    // Verificar si ya existe por ISBN
    final existingByIsbn = await _dbService.getBookByIsbn(book.isbn);
    if (existingByIsbn != null) {
      return false;
    }

    // Verificar también por serie + número de volumen (evita duplicados con ISBN sintético diferente)
    if (book.seriesName != null && book.volumeNumber != null) {
      final existingInSeries = await _dbService.getBookBySeriesAndVolume(
        book.seriesName!,
        book.volumeNumber!,
      );
      if (existingInSeries != null) {
        debugPrint('⚠️ Libro duplicado detectado: ${book.seriesName} Vol.${book.volumeNumber}');
        return false;
      }
    }

    // Si el usuario está re-añadiendo un libro que eliminó, desmarcarlo
    await _dbService.unmarkAsDeleted(book.isbn);

    // Descargar y guardar la portada localmente si tiene URL
    String? localCoverPath;
    if (book.coverUrl != null && book.coverUrl!.isNotEmpty) {
      localCoverPath = await _imageStorage.downloadAndSave(book.coverUrl!, book.isbn);
    }

    // Determinar si hay conexión para pendingSync
    final pendingSync = !(_syncService?.isOnline ?? false);
    final bookToSave = book.copyWith(
      pendingSync: pendingSync,
      localCoverPath: localCoverPath,
    );

    final id = await _dbService.insertBook(bookToSave);
    final newBook = bookToSave.copyWith(id: id);

    // Crear nuevas listas para que Selector detecte el cambio
    if (newBook.isReading) {
      _readingBooks = [newBook, ..._readingBooks];
    } else if (newBook.isWishlist) {
      _wishlistBooks = [newBook, ..._wishlistBooks];
    } else {
      _finishedBooks = [newBook, ..._finishedBooks];
    }

    notifyListeners();

    // Sincronizar a la nube si hay conexión y usuario logueado
    if (_authService?.userId != null && _syncService?.isOnline == true) {
      try {
        await _firestoreService.saveBook(_authService!.userId!, newBook);
        await _dbService.markAsSynced(id);
      } catch (e) {
        debugPrint('Error sincronizando nuevo libro: $e');
        // Marcar como pendiente para reintentar cuando haya conexión
        await _dbService.updateBook(newBook.copyWith(pendingSync: true));
      }
    }

    return true;
  }

  /// Añade un libro solo si no existe (para importación)
  /// Retorna true si se añadió, false si ya existía
  Future<bool> addBookIfNotExists(Book book) async {
    // Verificar si ya existe por ISBN
    final existingByIsbn = await _dbService.getBookByIsbn(book.isbn);
    if (existingByIsbn != null) {
      return false;
    }

    // Verificar también por serie + número de volumen
    if (book.seriesName != null && book.volumeNumber != null) {
      final existingInSeries = await _dbService.getBookBySeriesAndVolume(
        book.seriesName!,
        book.volumeNumber!,
      );
      if (existingInSeries != null) {
        return false;
      }
    }

    // Descargar y guardar la portada localmente si tiene URL
    String? localCoverPath;
    if (book.coverUrl != null && book.coverUrl!.isNotEmpty) {
      localCoverPath = await _imageStorage.downloadAndSave(book.coverUrl!, book.isbn);
    }

    // Añadir el libro
    final bookToSave = book.copyWith(localCoverPath: localCoverPath);
    final id = await _dbService.insertBook(bookToSave);
    final newBook = bookToSave.copyWith(id: id);

    // Añadir a la lista correspondiente (crear nuevas listas para Selector)
    if (newBook.isArchived) {
      _archivedBooks = [..._archivedBooks, newBook];
    } else if (newBook.isReading) {
      _readingBooks = [newBook, ..._readingBooks];
    } else if (newBook.isWishlist) {
      _wishlistBooks = [newBook, ..._wishlistBooks];
    } else {
      _finishedBooks = [newBook, ..._finishedBooks];
    }

    notifyListeners();

    // Sincronizar si hay conexión
    if (_authService?.userId != null && _syncService?.isOnline == true) {
      try {
        await _firestoreService.saveBook(_authService!.userId!, newBook);
        await _dbService.markAsSynced(id);
      } catch (e) {
        debugPrint('Error sincronizando libro importado: $e');
        // Marcar como pendiente para reintentar cuando haya conexión
        await _dbService.updateBook(newBook.copyWith(pendingSync: true));
      }
    }

    return true;
  }

  /// Descarga y guarda portadas localmente para libros que solo tienen URL
  /// Útil para migrar libros existentes al sistema de almacenamiento local
  Future<int> downloadMissingCovers({Function(int, int)? onProgress}) async {
    final allBooks = await _dbService.getAllBooks();
    final booksWithoutLocalCover = allBooks.where((b) =>
        b.coverUrl != null &&
        b.coverUrl!.isNotEmpty &&
        (b.localCoverPath == null || b.localCoverPath!.isEmpty)).toList();

    int downloaded = 0;
    for (int i = 0; i < booksWithoutLocalCover.length; i++) {
      final book = booksWithoutLocalCover[i];
      onProgress?.call(i + 1, booksWithoutLocalCover.length);

      final localPath = await _imageStorage.downloadAndSave(book.coverUrl!, book.isbn);
      if (localPath != null && book.id != null) {
        await _dbService.updateLocalCoverPath(book.id!, localPath);
        downloaded++;
      }
    }

    // Recargar libros para actualizar las rutas locales
    if (downloaded > 0) {
      await loadBooks();
    }

    return downloaded;
  }

  /// Obtiene estadísticas de almacenamiento de portadas
  Future<Map<String, dynamic>> getCoverStorageStats() async {
    final totalSize = await _imageStorage.getTotalSize();
    final coverCount = await _imageStorage.getCoverCount();
    return {
      'totalSize': totalSize,
      'formattedSize': _imageStorage.formatSize(totalSize),
      'coverCount': coverCount,
    };
  }

  /// Limpia todas las portadas locales (para liberar espacio)
  Future<void> clearLocalCovers() async {
    await _imageStorage.clearAllCovers();
    // Actualizar las rutas locales en la base de datos
    final allBooks = await _dbService.getAllBooks();
    for (final book in allBooks) {
      if (book.id != null && book.localCoverPath != null) {
        await _dbService.updateLocalCoverPath(book.id!, '');
      }
    }
    await loadBooks();
  }

  Future<void> updateCurrentPage(int bookId, int page) async {
    await _dbService.updateCurrentPage(bookId, page);

    final index = _readingBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      final book = _readingBooks[index].copyWith(currentPage: page);
      _readingBooks = List.from(_readingBooks)..[index] = book;
      notifyListeners();

      // Sincronizar cambio si hay conexión
      _syncBookChange(book);
    }
  }

  Future<void> updateTotalPages(int bookId, int totalPages) async {
    await _dbService.updateTotalPages(bookId, totalPages);

    // Buscar en ambas listas
    var index = _readingBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      final book = _readingBooks[index].copyWith(totalPages: totalPages);
      _readingBooks = List.from(_readingBooks)..[index] = book;
      notifyListeners();
      _syncBookChange(book);
    } else {
      index = _finishedBooks.indexWhere((b) => b.id == bookId);
      if (index != -1) {
        final book = _finishedBooks[index].copyWith(totalPages: totalPages);
        _finishedBooks = List.from(_finishedBooks)..[index] = book;
        notifyListeners();
        _syncBookChange(book);
      }
    }
  }

  Future<void> updateCoverUrl(int bookId, String coverUrl) async {
    await _dbService.updateCoverUrl(bookId, coverUrl);

    // Buscar en ambas listas
    var index = _readingBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      // Descargar la nueva imagen
      String? localPath;
      final isbn = _readingBooks[index].isbn;
      if (isbn.isNotEmpty) {
        localPath = await _imageStorage.downloadAndSave(coverUrl, isbn);
        debugPrint('📸 Portada descargada para actualización: $localPath');
      }
      final book = _readingBooks[index].copyWith(
        coverUrl: coverUrl,
        localCoverPath: localPath,
      );
      _readingBooks[index] = book;
      // Forzar reconstrucción creando nueva lista
      _readingBooks = List.from(_readingBooks);
      debugPrint('🔄 Lista de lectura actualizada, notificando...');
      notifyListeners();
      _syncBookChange(book);
    } else {
      index = _finishedBooks.indexWhere((b) => b.id == bookId);
      if (index != -1) {
        // Descargar la nueva imagen
        String? localPath;
        final isbn = _finishedBooks[index].isbn;
        if (isbn.isNotEmpty) {
          localPath = await _imageStorage.downloadAndSave(coverUrl, isbn);
          debugPrint('📸 Portada descargada para actualización: $localPath');
        }
        final book = _finishedBooks[index].copyWith(
          coverUrl: coverUrl,
          localCoverPath: localPath,
        );
        _finishedBooks[index] = book;
        // Forzar reconstrucción creando nueva lista
        _finishedBooks = List.from(_finishedBooks);
        debugPrint('🔄 Lista de completados actualizada, notificando...');
        notifyListeners();
        _syncBookChange(book);
      }
    }
  }

  Future<void> markAsFinished(int bookId) async {
    await _dbService.updateStatus(bookId, 'finished');

    final index = _readingBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      final book = _readingBooks[index].copyWith(status: 'finished');
      // Crear nuevas listas para que Selector detecte el cambio
      _readingBooks = [..._readingBooks]..removeAt(index);
      _finishedBooks = [book, ..._finishedBooks];
      notifyListeners();

      // Sincronizar cambio
      _syncBookChange(book);
    }
  }

  Future<void> markAsReading(int bookId) async {
    await _dbService.updateStatus(bookId, 'reading');

    // Buscar en libros terminados
    var index = _finishedBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      final book = _finishedBooks[index].copyWith(status: 'reading', currentPage: 0);
      // Crear nuevas listas para que Selector detecte el cambio
      _finishedBooks = [..._finishedBooks]..removeAt(index);
      _readingBooks = [book, ..._readingBooks];
      await _dbService.updateCurrentPage(bookId, 0);
      notifyListeners();
      _syncBookChange(book);
      return;
    }

    // Buscar en wishlist (solicitados)
    index = _wishlistBooks.indexWhere((b) => b.id == bookId);
    if (index != -1) {
      final book = _wishlistBooks[index].copyWith(status: 'reading', currentPage: 0);
      // Crear nuevas listas para que Selector detecte el cambio
      _wishlistBooks = [..._wishlistBooks]..removeAt(index);
      _readingBooks = [book, ..._readingBooks];
      await _dbService.updateCurrentPage(bookId, 0);
      notifyListeners();
      _syncBookChange(book);
      return;
    }
  }

  // Métodos para archivar series

  /// Archiva una serie completa
  Future<void> archiveSeries(String seriesName) async {
    await _dbService.archiveSeries(seriesName);

    // Mover libros de las listas activas a archivados
    final toArchive = <Book>[];

    // Crear nuevas listas filtrando la serie
    _readingBooks = _readingBooks.where((b) {
      if (b.seriesName == seriesName) {
        toArchive.add(b.copyWith(isArchived: true));
        return false;
      }
      return true;
    }).toList();

    _finishedBooks = _finishedBooks.where((b) {
      if (b.seriesName == seriesName) {
        toArchive.add(b.copyWith(isArchived: true));
        return false;
      }
      return true;
    }).toList();

    _wishlistBooks = _wishlistBooks.where((b) {
      if (b.seriesName == seriesName) {
        toArchive.add(b.copyWith(isArchived: true));
        return false;
      }
      return true;
    }).toList();

    _archivedBooks = [..._archivedBooks, ...toArchive];
    notifyListeners();

    // Sincronizar cambios
    for (final book in toArchive) {
      _syncBookChange(book);
    }
  }

  /// Desarchiva una serie completa
  Future<void> unarchiveSeries(String seriesName) async {
    await _dbService.unarchiveSeries(seriesName);

    // Mover libros de archivados a las listas activas
    final toUnarchive = _archivedBooks.where((b) => b.seriesName == seriesName).toList();
    _archivedBooks = _archivedBooks.where((b) => b.seriesName != seriesName).toList();

    final newReading = <Book>[];
    final newFinished = <Book>[];
    final newWishlist = <Book>[];

    for (final book in toUnarchive) {
      final unarchived = book.copyWith(isArchived: false);
      if (unarchived.isReading) {
        newReading.add(unarchived);
      } else if (unarchived.isFinished) {
        newFinished.add(unarchived);
      } else if (unarchived.isWishlist) {
        newWishlist.add(unarchived);
      }
      _syncBookChange(unarchived);
    }

    _readingBooks = [...newReading, ..._readingBooks];
    _finishedBooks = [...newFinished, ..._finishedBooks];
    _wishlistBooks = [...newWishlist, ..._wishlistBooks];

    notifyListeners();
  }

  /// Elimina una serie completa
  Future<int> deleteSeries(String seriesName) async {
    // Recopilar todos los libros de la serie
    final toDelete = <Book>[];

    toDelete.addAll(_readingBooks.where((b) => b.seriesName == seriesName));
    toDelete.addAll(_finishedBooks.where((b) => b.seriesName == seriesName));
    toDelete.addAll(_wishlistBooks.where((b) => b.seriesName == seriesName));
    toDelete.addAll(_archivedBooks.where((b) => b.seriesName == seriesName));

    // Eliminar de la base de datos y marcar como eliminados
    for (final book in toDelete) {
      if (book.id != null) {
        await _dbService.deleteBook(book.id!);
      }
      if (book.isbn.isNotEmpty) {
        await _dbService.markAsDeleted(book.isbn);
        await _imageStorage.deleteCover(book.isbn);
      }

      // Eliminar de la nube si hay conexión
      if (_authService?.userId != null &&
          _syncService?.isOnline == true &&
          book.isbn.isNotEmpty) {
        try {
          await _firestoreService.deleteBook(_authService!.userId!, book.isbn);
        } catch (e) {
          debugPrint('Error eliminando libro de la nube: $e');
        }
      }
    }

    // Eliminar de las listas locales (crear nuevas listas)
    _readingBooks = _readingBooks.where((b) => b.seriesName != seriesName).toList();
    _finishedBooks = _finishedBooks.where((b) => b.seriesName != seriesName).toList();
    _wishlistBooks = _wishlistBooks.where((b) => b.seriesName != seriesName).toList();
    _archivedBooks = _archivedBooks.where((b) => b.seriesName != seriesName).toList();

    notifyListeners();

    return toDelete.length;
  }

  /// Obtiene las series archivadas agrupadas
  Map<String, List<Book>> getArchivedSeriesGrouped() {
    final Map<String, List<Book>> grouped = {};

    for (final book in _archivedBooks) {
      final seriesKey = book.seriesName ?? book.title;
      if (!grouped.containsKey(seriesKey)) {
        grouped[seriesKey] = [];
      }
      grouped[seriesKey]!.add(book);
    }

    // Ordenar por volumen dentro de cada serie
    for (final series in grouped.keys) {
      grouped[series]!.sort((a, b) => (a.volumeNumber ?? 0).compareTo(b.volumeNumber ?? 0));
    }

    return grouped;
  }

  Future<void> deleteBook(int bookId) async {
    // Obtener el libro antes de eliminarlo para tener el ISBN
    Book? bookToDelete;
    bookToDelete = _readingBooks.firstWhere(
      (b) => b.id == bookId,
      orElse: () => _finishedBooks.firstWhere(
        (b) => b.id == bookId,
        orElse: () => _wishlistBooks.firstWhere(
          (b) => b.id == bookId,
          orElse: () => Book(isbn: '', title: '', author: ''),
        ),
      ),
    );

    await _dbService.deleteBook(bookId);

    // Eliminar portada local si existe
    if (bookToDelete.isbn.isNotEmpty) {
      await _imageStorage.deleteCover(bookToDelete.isbn);
    }

    // Marcar como eliminado para evitar re-sync desde la nube
    if (bookToDelete.isbn.isNotEmpty) {
      await _dbService.markAsDeleted(bookToDelete.isbn);
      debugPrint('Libro marcado como eliminado: ${bookToDelete.isbn}');
    }

    // Crear nuevas listas para que Selector detecte el cambio
    _readingBooks = _readingBooks.where((b) => b.id != bookId).toList();
    _finishedBooks = _finishedBooks.where((b) => b.id != bookId).toList();
    _wishlistBooks = _wishlistBooks.where((b) => b.id != bookId).toList();

    notifyListeners();

    // Eliminar de la nube si hay conexión
    if (_authService?.userId != null &&
        _syncService?.isOnline == true &&
        bookToDelete.isbn.isNotEmpty) {
      try {
        await _firestoreService.deleteBook(_authService!.userId!, bookToDelete.isbn);
      } catch (e) {
        debugPrint('Error eliminando libro de la nube: $e');
      }
    }
  }

  // Sincronizar cambio de un libro específico
  Future<void> _syncBookChange(Book book) async {
    if (_authService?.userId != null && _syncService?.isOnline == true) {
      try {
        await _firestoreService.saveBook(_authService!.userId!, book);
        if (book.id != null) {
          await _dbService.markAsSynced(book.id!);
        }
      } catch (e) {
        debugPrint('Error sincronizando cambio: $e');
        // Marcar como pendiente de sync
        if (book.id != null) {
          await _dbService.updateBook(book.copyWith(pendingSync: true));
        }
      }
    }
  }

  /// Añadir volúmenes anteriores de una serie como completados
  /// [baseBook] es el libro base con la info de la serie
  /// [volumeNumbers] es la lista de números de volumen a añadir
  ///
  /// Este método:
  /// 1. Busca en Tomos y Grapas los ISBNs REALES de cada volumen
  /// 2. Crea los libros con ISBN real y portada correcta
  /// 3. Los volúmenes sin ISBN en T&G se crean con ISBN sintético y se buscan portadas después
  Future<int> addPreviousVolumesAsFinished(Book baseBook, List<int> volumeNumbers) async {
    int addedCount = 0;
    final seriesName = baseBook.seriesName ?? baseBook.title;

    // Detectar si es edición omnibus (ej: "ONE PIECE 3 EN 1")
    final isOmnibus = RegExp(r'\d+\s*[Ee][Nn]\s*1', caseSensitive: false).hasMatch(seriesName);

    debugPrint('╔════════════════════════════════════════╗');
    debugPrint('║ CREANDO VOLUMENES ANTERIORES           ║');
    debugPrint('╠════════════════════════════════════════╣');
    debugPrint('║ Serie: $seriesName');
    debugPrint('║ Omnibus: $isOmnibus');
    debugPrint('║ Volúmenes: $volumeNumbers');
    debugPrint('╚════════════════════════════════════════╝');

    // PASO 1: Buscar ISBNs reales en Tomos y Grapas
    debugPrint('🔍 Buscando ISBNs reales en Tomos y Grapas...');
    Map<int, Map<String, String>> seriesVolumes = {};
    try {
      seriesVolumes = await _tomosYGrapasClient.searchSeriesVolumes(seriesName);
      debugPrint('📚 ISBNs encontrados para ${seriesVolumes.length} volúmenes');
    } catch (e) {
      debugPrint('⚠️ Error buscando en T&G, usando ISBNs sintéticos: $e');
    }

    // Lista de libros añadidos para buscar portadas después (solo los que no tienen)
    final List<Book> booksNeedingCovers = [];
    final List<Book> addedBooks = [];

    // PASO 2: Crear libros con ISBN real o sintético
    for (final volNum in volumeNumbers) {
      // Comprobar si tenemos datos reales de T&G para este volumen
      final volumeData = seriesVolumes[volNum];
      final hasRealData = volumeData != null && volumeData['isbn'] != null && volumeData['isbn']!.isNotEmpty;

      String isbn;
      String? coverUrl;
      String? sourceUrl;
      String volumeTitle;

      if (hasRealData) {
        // Usar datos reales de T&G
        isbn = volumeData!['isbn']!;
        coverUrl = volumeData['coverUrl'];
        sourceUrl = volumeData['productUrl'];
        volumeTitle = volumeData['title'] ?? (isOmnibus ? '$seriesName $volNum' : '$seriesName Vol. $volNum');
        debugPrint('✅ Vol.$volNum: ISBN real $isbn');
      } else {
        // Usar ISBN sintético
        isbn = '${seriesName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}-vol-$volNum';
        volumeTitle = isOmnibus ? '$seriesName $volNum' : '$seriesName Vol. $volNum';
        debugPrint('⚠️ Vol.$volNum: ISBN sintético (no encontrado en T&G)');
      }

      // Verificar si ya existe por ISBN
      final existingByIsbn = await _dbService.getBookByIsbn(isbn);
      if (existingByIsbn != null) {
        debugPrint('📌 Vol.$volNum ya existe con ISBN $isbn, saltando...');
        continue;
      }

      // Verificar también por serie + número de volumen (evita duplicados)
      final existingInSeries = await _dbService.getBookBySeriesAndVolume(seriesName, volNum);
      if (existingInSeries != null) {
        debugPrint('📌 Vol.$volNum ya existe en la serie, saltando...');
        continue;
      }

      // Descargar y guardar la portada localmente si tenemos URL
      String? localCoverPath;
      if (coverUrl != null && coverUrl.isNotEmpty) {
        localCoverPath = await _imageStorage.downloadAndSave(coverUrl, isbn);
      }

      // Crear el libro
      final volumeBook = Book(
        isbn: isbn,
        title: volumeTitle,
        author: baseBook.author,
        coverUrl: coverUrl,
        localCoverPath: localCoverPath,
        status: 'finished',
        currentPage: 0,
        totalPages: baseBook.totalPages,
        seriesName: seriesName,
        volumeNumber: volNum,
        publisher: baseBook.publisher,
        apiSource: hasRealData ? 'tomosygrapas' : null,
        sourceUrl: sourceUrl,
        pendingSync: !(_syncService?.isOnline ?? false),
      );

      final id = await _dbService.insertBook(volumeBook);
      final newBook = volumeBook.copyWith(id: id);
      addedBooks.add(newBook);
      addedCount++;

      // Si no tiene portada, añadir a la lista para buscar después
      if (coverUrl == null || coverUrl.isEmpty) {
        booksNeedingCovers.add(newBook);
      }
    }

    // Crear nueva lista con los libros añadidos al principio
    if (addedCount > 0) {
      _finishedBooks = [...addedBooks.reversed, ..._finishedBooks];
      notifyListeners();
    }

    // PASO 3: Buscar portadas EN BACKGROUND para los que no tienen (sin bloquear UI)
    if (booksNeedingCovers.isNotEmpty) {
      debugPrint('🔍 ${booksNeedingCovers.length} volúmenes sin portada, buscando en background...');
      _searchCoversInBackground(booksNeedingCovers, baseBook);
    }

    return addedCount;
  }

  /// Busca portadas en segundo plano y actualiza los libros
  Future<void> _searchCoversInBackground(List<Book> books, Book baseBook) async {
    // Para omnibus, extraer serie del TÍTULO (ej: "ONE PIECE 3 EN 1 10" -> "ONE PIECE 3 EN 1")
    String seriesName;
    String? baseSeriesName;

    // Detectar omnibus del título primero
    final omnibusMatch = RegExp(r'^(.+\d+\s*[Ee][Nn]\s*1)\s+\d+$').firstMatch(baseBook.title.trim());
    final isOmnibus = omnibusMatch != null;

    if (isOmnibus) {
      // Extraer serie completa incluyendo "3 EN 1"
      seriesName = omnibusMatch.group(1)!.trim();
      // Base es sin el "X EN 1" (ej: "ONE PIECE")
      baseSeriesName = seriesName.replaceAll(RegExp(r'\s*\d+\s*[Ee][Nn]\s*1\s*$', caseSensitive: false), '').trim();
      debugPrint('📚 Serie omnibus detectada del título: "$seriesName" -> base: "$baseSeriesName"');
    } else {
      // No omnibus: usar seriesName guardado o título
      seriesName = baseBook.seriesName ?? baseBook.title;
    }

    final englishName = ComicTranslations.getEnglishName(seriesName);
    final authorFirst = baseBook.author.split(',').first.trim();

    debugPrint('🔍 Iniciando búsqueda de ${books.length} portadas en background...');

    // SOLUCIÓN GENERAL: Buscar si tenemos un libro de esta serie con sourceUrl
    // Esto permite encontrar volúmenes relacionados sin hardcodear ISBNs
    Map<int, Map<String, String>>? relatedVolumes;
    final bookWithSourceUrl = await _dbService.getBookWithSourceUrlBySeries(seriesName);
    if (bookWithSourceUrl != null && bookWithSourceUrl.sourceUrl != null) {
      debugPrint('📦 Encontrado libro con sourceUrl: ${bookWithSourceUrl.sourceUrl}');
      debugPrint('🔗 Buscando volúmenes relacionados desde Tomos y Grapas...');
      relatedVolumes = await _tomosYGrapasClient.getRelatedVolumes(bookWithSourceUrl.sourceUrl!);
      debugPrint('📚 Volúmenes relacionados encontrados: ${relatedVolumes.keys.toList()}');
    } else if (baseBook.sourceUrl != null) {
      // El libro base tiene sourceUrl
      debugPrint('📦 Usando sourceUrl del libro base: ${baseBook.sourceUrl}');
      relatedVolumes = await _tomosYGrapasClient.getRelatedVolumes(baseBook.sourceUrl!);
      debugPrint('📚 Volúmenes relacionados encontrados: ${relatedVolumes.keys.toList()}');
    }

    for (final book in books) {
      final volNum = book.volumeNumber ?? 0;
      String? coverUrl;

      // PRIMERO: Intentar obtener la portada de volúmenes relacionados (solución general)
      if (relatedVolumes != null && relatedVolumes.containsKey(volNum)) {
        coverUrl = relatedVolumes[volNum]!['coverUrl'];
        if (coverUrl != null && coverUrl.isNotEmpty) {
          debugPrint('✅ Portada Vol.$volNum desde volúmenes relacionados: $coverUrl');
        }
      }

      // SEGUNDO: Si no hay en relacionados, buscar directamente en Tomos y Grapas
      if (coverUrl == null || coverUrl.isEmpty) {
        debugPrint('🔍 Buscando directamente en Tomos y Grapas: $seriesName vol $volNum');
        try {
          coverUrl = await _tomosYGrapasClient.searchCover(seriesName, volNum);
          if (coverUrl != null && coverUrl.isNotEmpty) {
            debugPrint('✅ Portada Vol.$volNum encontrada en Tomos y Grapas');
          }
        } catch (e) {
          debugPrint('Error buscando en Tomos y Grapas: $e');
        }
      }

      // TERCERO: Si aún no hay, buscar con queries adicionales
      if (coverUrl == null || coverUrl.isEmpty) {
        // Para omnibus, usar queries específicas SIN "vol" y con el formato correcto
        final searchQueries = <String>[
          // Queries específicas para omnibus (ej: "ONE PIECE 3 EN 1 5")
          if (isOmnibus) '$seriesName $volNum',
          if (isOmnibus && baseSeriesName != null) '$baseSeriesName 3 en 1 $volNum',
          if (isOmnibus && baseSeriesName != null) '$baseSeriesName omnibus $volNum',
          // Queries estándar
          '$authorFirst $seriesName vol $volNum',
          '$authorFirst $seriesName $volNum',
          if (englishName != seriesName) '$authorFirst $englishName vol $volNum',
          if (englishName != seriesName) '$englishName vol $volNum',
          '$seriesName vol $volNum',
          '$seriesName $volNum',
          // Queries adicionales con número con padding
          '$seriesName ${volNum.toString().padLeft(2, '0')}',
          // Fallback: nombre base + volumen (para One Piece normal)
          if (isOmnibus && baseSeriesName != null) '$baseSeriesName vol $volNum',
        ];

        for (final query in searchQueries) {
          if (coverUrl != null && coverUrl.isNotEmpty) break;
          try {
            debugPrint('🔍 Background Vol.$volNum: "$query"');
            coverUrl = await _comicSearchService.searchCover(
              query,
              baseBook.author,
              volumeNumber: volNum,
            );
            if (coverUrl != null && coverUrl.isNotEmpty) {
              debugPrint('✅ Portada encontrada para Vol.$volNum');
              break;
            }
          } catch (e) {
            debugPrint('Error buscando portada: $e');
          }
        }
      }

      // Delay entre volúmenes para evitar rate limiting de APIs
      await Future.delayed(const Duration(milliseconds: 500));

      // Si encontramos portada, actualizar el libro
      if (coverUrl != null && coverUrl.isNotEmpty && book.id != null) {
        await _dbService.updateCoverUrl(book.id!, coverUrl);

        // Actualizar en la lista local (crear nueva lista para que Selector detecte cambio)
        final index = _finishedBooks.indexWhere((b) => b.id == book.id);
        if (index != -1) {
          _finishedBooks = List.from(_finishedBooks)
            ..[index] = _finishedBooks[index].copyWith(coverUrl: coverUrl);
        }

        // Sincronizar con Firebase si hay conexión
        if (_authService?.userId != null && _syncService?.isOnline == true) {
          try {
            final updatedBook = book.copyWith(coverUrl: coverUrl);
            await _firestoreService.saveBook(_authService!.userId!, updatedBook);
          } catch (e) {
            debugPrint('Error sincronizando portada: $e');
          }
        }

        // Notificar para actualizar UI con la nueva portada
        notifyListeners();
      }
    }

    debugPrint('✅ Búsqueda de portadas en background completada');
  }

  Future<Book> getSeriesInfo(Book book) async {
    final bookWithSeries = await _apiService.getSeriesInfo(book);

    // Actualizar en base de datos si encontramos info de serie
    if (book.id != null && bookWithSeries.isPartOfSeries) {
      await _dbService.updateSeriesInfo(book.id!, bookWithSeries);

      // Actualizar en las listas locales
      final readingIndex = _readingBooks.indexWhere((b) => b.id == book.id);
      if (readingIndex != -1) {
        _readingBooks = List.from(_readingBooks)
          ..[readingIndex] = bookWithSeries.copyWith(id: book.id);
      }

      final finishedIndex = _finishedBooks.indexWhere((b) => b.id == book.id);
      if (finishedIndex != -1) {
        _finishedBooks = List.from(_finishedBooks)
          ..[finishedIndex] = bookWithSeries.copyWith(id: book.id);
      }

      notifyListeners();

      // Sincronizar info de serie
      _syncBookChange(bookWithSeries.copyWith(id: book.id));
    }

    return bookWithSeries;
  }

  // ============ COMPROBACIÓN DE VOLÚMENES NUEVOS ============

  /// Comprobar volúmenes nuevos al abrir la app (máximo 1 vez cada 24h)
  Future<void> checkForNewVolumesOnStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString('last_new_volume_check');
      if (lastCheck != null) {
        final lastDate = DateTime.tryParse(lastCheck);
        if (lastDate != null &&
            DateTime.now().difference(lastDate).inHours < 24) {
          debugPrint('NewVolumeCheck: Ya se comprobó hoy, omitiendo');
          return;
        }
      }

      debugPrint('NewVolumeCheck: Iniciando comprobación de volúmenes nuevos');

      final checker = NewVolumeCheckerService();
      await checker.init();
      final alerts =
          await checker.checkForNewVolumes(_readingBooks, _finishedBooks);

      if (alerts.isNotEmpty) {
        _newVolumeAlerts = alerts;
        notifyListeners();
      }

      await prefs.setString(
          'last_new_volume_check', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('NewVolumeCheck: Error: $e');
    }
  }

  /// Limpiar alertas de volúmenes nuevos
  void clearNewVolumeAlerts() {
    _newVolumeAlerts = [];
    notifyListeners();
  }
}
