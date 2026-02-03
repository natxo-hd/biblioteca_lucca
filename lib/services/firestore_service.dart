import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Referencia a la colección de libros del usuario
  CollectionReference<Map<String, dynamic>> _booksCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('books');
  }

  // Guardar o actualizar un libro en Firestore
  Future<void> saveBook(String userId, Book book) async {
    try {
      final docRef = _booksCollection(userId).doc(book.isbn);
      await docRef.set(_bookToFirestore(book), SetOptions(merge: true));
      debugPrint('Libro guardado en Firestore: ${book.title}');
    } catch (e) {
      debugPrint('Error guardando libro en Firestore: $e');
      rethrow;
    }
  }

  // Obtener todos los libros del usuario
  Future<List<Book>> getAllBooks(String userId) async {
    try {
      final snapshot = await _booksCollection(userId).get();
      return snapshot.docs
          .map((doc) => _bookFromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo libros de Firestore: $e');
      return [];
    }
  }

  // Obtener un libro específico
  Future<Book?> getBook(String userId, String isbn) async {
    try {
      final doc = await _booksCollection(userId).doc(isbn).get();
      if (doc.exists && doc.data() != null) {
        return _bookFromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error obteniendo libro de Firestore: $e');
      return null;
    }
  }

  // Eliminar un libro
  Future<void> deleteBook(String userId, String isbn) async {
    try {
      await _booksCollection(userId).doc(isbn).delete();
      debugPrint('Libro eliminado de Firestore: $isbn');
    } catch (e) {
      debugPrint('Error eliminando libro de Firestore: $e');
      rethrow;
    }
  }

  // Actualizar campos específicos de un libro
  Future<void> updateBook(
    String userId,
    String isbn,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['lastModified'] = FieldValue.serverTimestamp();
      await _booksCollection(userId).doc(isbn).update(updates);
    } catch (e) {
      debugPrint('Error actualizando libro en Firestore: $e');
      rethrow;
    }
  }

  // Escuchar cambios en tiempo real
  Stream<List<Book>> watchBooks(String userId) {
    return _booksCollection(userId)
        .orderBy('lastModified', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _bookFromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Obtener libros modificados después de cierta fecha
  Future<List<Book>> getBooksModifiedAfter(
    String userId,
    DateTime date,
  ) async {
    try {
      final snapshot = await _booksCollection(userId)
          .where('lastModified', isGreaterThan: Timestamp.fromDate(date))
          .get();
      return snapshot.docs
          .map((doc) => _bookFromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo libros modificados: $e');
      return [];
    }
  }

  // Crear perfil de usuario
  Future<void> createUserProfile(
    String userId,
    String displayName,
    String email,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'displayName': displayName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error creando perfil de usuario: $e');
    }
  }

  // Guardar pedido de libro para notificar a papá
  Future<bool> saveBookRequest({
    required String userId,
    required String userName,
    required String bookTitle,
    required String author,
    String? coverUrl,
  }) async {
    try {
      await _firestore.collection('book_requests').add({
        'userId': userId,
        'userName': userName,
        'bookTitle': bookTitle,
        'author': author,
        'coverUrl': coverUrl,
        'requestedAt': FieldValue.serverTimestamp(),
        'fulfilled': false,
      });
      debugPrint('Pedido guardado: $bookTitle');
      return true;
    } catch (e) {
      debugPrint('Error guardando pedido: $e');
      return false;
    }
  }

  // Obtener todos los pedidos pendientes (para que papá los vea)
  Stream<List<Map<String, dynamic>>> watchBookRequests() {
    return _firestore
        .collection('book_requests')
        .where('fulfilled', isEqualTo: false)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  // Marcar pedido como completado
  Future<void> fulfillRequest(String requestId) async {
    await _firestore.collection('book_requests').doc(requestId).update({
      'fulfilled': true,
      'fulfilledAt': FieldValue.serverTimestamp(),
    });
  }

  // Convertir Book a mapa para Firestore
  Map<String, dynamic> _bookToFirestore(Book book) {
    return {
      'isbn': book.isbn,
      'title': book.title,
      'author': book.author,
      'coverUrl': book.coverUrl,
      'status': book.status,
      'currentPage': book.currentPage,
      'totalPages': book.totalPages,
      'addedDate': Timestamp.fromDate(book.addedDate),
      'seriesName': book.seriesName,
      'volumeNumber': book.volumeNumber,
      'nextVolumeIsbn': book.nextVolumeIsbn,
      'nextVolumeTitle': book.nextVolumeTitle,
      'nextVolumeCover': book.nextVolumeCover,
      'isArchived': book.isArchived,
      'publisher': book.publisher,
      'comicUniverse': book.comicUniverse,
      'apiSource': book.apiSource,
      'sourceUrl': book.sourceUrl,
      'lastModified': FieldValue.serverTimestamp(),
    };
  }

  // Convertir documento de Firestore a Book
  Book _bookFromFirestore(Map<String, dynamic> data, String docId) {
    return Book(
      isbn: data['isbn'] ?? docId,
      title: data['title'] ?? 'Sin título',
      author: data['author'] ?? 'Autor desconocido',
      coverUrl: data['coverUrl'],
      status: data['status'] ?? 'reading',
      currentPage: data['currentPage'] ?? 0,
      totalPages: data['totalPages'] ?? 0,
      addedDate: (data['addedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seriesName: data['seriesName'],
      volumeNumber: data['volumeNumber'],
      nextVolumeIsbn: data['nextVolumeIsbn'],
      nextVolumeTitle: data['nextVolumeTitle'],
      nextVolumeCover: data['nextVolumeCover'],
      isArchived: data['isArchived'] == true,
      publisher: data['publisher'] as String?,
      comicUniverse: data['comicUniverse'] as String?,
      apiSource: data['apiSource'] as String?,
      sourceUrl: data['sourceUrl'] as String?,
    );
  }
}
