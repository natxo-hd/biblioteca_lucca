/// Tipos de evento de lectura
enum ReadingEventType {
  progress,  // Actualización de progreso normal
  started,   // Comenzó a leer el libro
  completed, // Completó el libro
}

/// Modelo para registrar eventos de lectura
class ReadingEvent {
  final int? id;
  final int bookId;
  final int previousPage;
  final int newPage;
  final int pagesRead;
  final ReadingEventType eventType;
  final DateTime timestamp;

  ReadingEvent({
    this.id,
    required this.bookId,
    required this.previousPage,
    required this.newPage,
    required this.pagesRead,
    required this.eventType,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Crea un evento de progreso de lectura
  factory ReadingEvent.progress({
    required int bookId,
    required int previousPage,
    required int newPage,
  }) {
    return ReadingEvent(
      bookId: bookId,
      previousPage: previousPage,
      newPage: newPage,
      pagesRead: newPage - previousPage,
      eventType: ReadingEventType.progress,
    );
  }

  /// Crea un evento de inicio de lectura
  factory ReadingEvent.started({
    required int bookId,
  }) {
    return ReadingEvent(
      bookId: bookId,
      previousPage: 0,
      newPage: 0,
      pagesRead: 0,
      eventType: ReadingEventType.started,
    );
  }

  /// Crea un evento de libro completado
  factory ReadingEvent.completed({
    required int bookId,
    required int totalPages,
    int? previousPage,
  }) {
    final prevPage = previousPage ?? 0;
    return ReadingEvent(
      bookId: bookId,
      previousPage: prevPage,
      newPage: totalPages,
      pagesRead: totalPages - prevPage,
      eventType: ReadingEventType.completed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bookId': bookId,
      'previousPage': previousPage,
      'newPage': newPage,
      'pagesRead': pagesRead,
      'eventType': eventType.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ReadingEvent.fromMap(Map<String, dynamic> map) {
    return ReadingEvent(
      id: map['id'] as int?,
      bookId: map['bookId'] as int,
      previousPage: map['previousPage'] as int,
      newPage: map['newPage'] as int,
      pagesRead: map['pagesRead'] as int,
      eventType: ReadingEventType.values.firstWhere(
        (e) => e.name == map['eventType'],
        orElse: () => ReadingEventType.progress,
      ),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  ReadingEvent copyWith({
    int? id,
    int? bookId,
    int? previousPage,
    int? newPage,
    int? pagesRead,
    ReadingEventType? eventType,
    DateTime? timestamp,
  }) {
    return ReadingEvent(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      previousPage: previousPage ?? this.previousPage,
      newPage: newPage ?? this.newPage,
      pagesRead: pagesRead ?? this.pagesRead,
      eventType: eventType ?? this.eventType,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'ReadingEvent(id: $id, bookId: $bookId, type: ${eventType.name}, pages: $pagesRead, at: $timestamp)';
  }
}
