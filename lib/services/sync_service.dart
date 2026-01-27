import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/book.dart';
import 'database_service.dart';
import 'firestore_service.dart';

class SyncService extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final FirestoreService _firestoreService = FirestoreService();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = false;
  bool _isSyncing = false;
  String? _userId;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  // Inicializar servicio de sincronización
  Future<void> initialize(String userId) async {
    _userId = userId;

    // Verificar conectividad inicial
    final result = await _connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);

    // Escuchar cambios de conectividad
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final wasOnline = _isOnline;
        _isOnline = !results.contains(ConnectivityResult.none);

        if (!wasOnline && _isOnline) {
          // Recuperamos conexión - sincronizar pendientes
          debugPrint('Conexión recuperada - sincronizando...');
          syncPendingChanges();
        }

        notifyListeners();
      },
    );

    // Sincronizar al iniciar si hay conexión
    if (_isOnline) {
      await syncAll();
    }
  }

  // Sincronización completa (descargar todo de Firestore)
  Future<void> syncAll() async {
    if (_userId == null || !_isOnline || _isSyncing) return;

    try {
      _isSyncing = true;
      notifyListeners();

      // Obtener todos los libros de Firestore
      final cloudBooks = await _firestoreService.getAllBooks(_userId!);
      final localBooks = await _dbService.getAllBooks();

      // Crear mapa de libros locales por ISBN
      final localBooksMap = {for (var b in localBooks) b.isbn: b};

      // Obtener lista de libros eliminados localmente
      final deletedIsbns = await _dbService.getDeletedIsbns();
      final deletedSet = deletedIsbns.toSet();

      // Procesar libros de la nube
      for (final cloudBook in cloudBooks) {
        // IMPORTANTE: No re-añadir libros que el usuario eliminó
        if (deletedSet.contains(cloudBook.isbn)) {
          debugPrint('Ignorando libro eliminado: ${cloudBook.title}');
          // También eliminar de la nube para mantener consistencia
          try {
            await _firestoreService.deleteBook(_userId!, cloudBook.isbn);
            debugPrint('Eliminado de nube: ${cloudBook.title}');
          } catch (e) {
            debugPrint('Error eliminando de nube: $e');
          }
          continue;
        }

        final localBook = localBooksMap[cloudBook.isbn];

        if (localBook == null) {
          // Libro nuevo de la nube - añadir a local
          await _dbService.insertBook(cloudBook.copyWith(pendingSync: false));
          debugPrint('Descargado de nube: ${cloudBook.title}');
        } else {
          // Comparar fechas de modificación
          final cloudModified = cloudBook.addedDate;
          final localModified = localBook.addedDate;

          if (cloudModified.isAfter(localModified)) {
            // Nube más reciente - actualizar local
            await _dbService.updateBook(
              cloudBook.copyWith(id: localBook.id, pendingSync: false),
            );
            debugPrint('Actualizado desde nube: ${cloudBook.title}');
          }
        }
      }

      // Subir libros locales que no están en la nube
      final cloudBooksMap = {for (var b in cloudBooks) b.isbn: b};
      for (final localBook in localBooks) {
        if (!cloudBooksMap.containsKey(localBook.isbn)) {
          await _firestoreService.saveBook(_userId!, localBook);
          await _dbService.markAsSynced(localBook.id!);
          debugPrint('Subido a nube: ${localBook.title}');
        }
      }

      // Sincronizar cambios pendientes
      await syncPendingChanges();

      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error en sincronización completa: $e');
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Sincronizar solo cambios pendientes
  Future<void> syncPendingChanges() async {
    if (_userId == null || !_isOnline) return;

    try {
      final pendingBooks = await _dbService.getPendingSyncBooks();

      for (final book in pendingBooks) {
        try {
          await _firestoreService.saveBook(_userId!, book);
          await _dbService.markAsSynced(book.id!);
          debugPrint('Sincronizado: ${book.title}');
        } catch (e) {
          debugPrint('Error sincronizando ${book.title}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error sincronizando pendientes: $e');
    }
  }

  // Guardar libro (local + nube si hay conexión)
  Future<void> saveBook(Book book) async {
    // Siempre guardar en local primero
    final bookWithSync = book.copyWith(pendingSync: !_isOnline);
    int bookId;

    if (book.id == null) {
      bookId = await _dbService.insertBook(bookWithSync);
    } else {
      await _dbService.updateBook(bookWithSync);
      bookId = book.id!;
    }

    // Si hay conexión, sincronizar a la nube
    if (_isOnline && _userId != null) {
      try {
        await _firestoreService.saveBook(_userId!, book);
        await _dbService.markAsSynced(bookId);
      } catch (e) {
        debugPrint('Error subiendo a nube, quedará pendiente: $e');
      }
    }
  }

  // Actualizar libro
  Future<void> updateBook(Book book) async {
    final bookWithSync = book.copyWith(pendingSync: !_isOnline);
    await _dbService.updateBook(bookWithSync);

    if (_isOnline && _userId != null) {
      try {
        await _firestoreService.saveBook(_userId!, book);
        await _dbService.markAsSynced(book.id!);
      } catch (e) {
        debugPrint('Error actualizando en nube: $e');
      }
    }
  }

  // Eliminar libro
  Future<void> deleteBook(Book book) async {
    await _dbService.deleteBook(book.id!);

    if (_isOnline && _userId != null) {
      try {
        await _firestoreService.deleteBook(_userId!, book.isbn);
      } catch (e) {
        debugPrint('Error eliminando de nube: $e');
      }
    }
  }

  // Obtener todos los libros (siempre de local)
  Future<List<Book>> getAllBooks() async {
    return _dbService.getAllBooks();
  }

  // Limpiar al cerrar sesión
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // Resetear para nuevo usuario
  void reset() {
    _userId = null;
    _connectivitySubscription?.cancel();
  }
}
