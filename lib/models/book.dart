class Book {
  final int? id;
  final String isbn;
  final String title;
  final String author;
  final String? coverUrl;
  final String? localCoverPath;  // Ruta local de la portada guardada
  final String status; // 'reading', 'finished' o 'wishlist'
  final int currentPage;
  final int totalPages;
  final DateTime addedDate;

  // Información de serie
  final String? seriesName;
  final int? volumeNumber;
  final String? nextVolumeIsbn;
  final String? nextVolumeTitle;
  final String? nextVolumeCover;

  // Sincronización
  final bool pendingSync;

  // Archivado (series terminadas o abandonadas)
  final bool isArchived;

  // Información adicional de cómics
  final String? publisher;      // Editorial: "Marvel", "DC", "Planeta", etc.
  final String? comicUniverse;  // Universo: "Marvel Universe", "DC Universe", etc.
  final String? apiSource;      // Fuente de datos: "marvel", "comicvine", "mangadex", etc.
  final String? sourceUrl;      // URL del producto en la tienda (para buscar volúmenes relacionados)

  Book({
    this.id,
    required this.isbn,
    required this.title,
    required this.author,
    this.coverUrl,
    this.localCoverPath,
    this.status = 'reading',
    this.currentPage = 0,
    this.totalPages = 0,
    DateTime? addedDate,
    this.seriesName,
    this.volumeNumber,
    this.nextVolumeIsbn,
    this.nextVolumeTitle,
    this.nextVolumeCover,
    this.pendingSync = false,
    this.isArchived = false,
    this.publisher,
    this.comicUniverse,
    this.apiSource,
    this.sourceUrl,
  }) : addedDate = addedDate ?? DateTime.now();

  Book copyWith({
    int? id,
    String? isbn,
    String? title,
    String? author,
    String? coverUrl,
    String? localCoverPath,
    String? status,
    int? currentPage,
    int? totalPages,
    DateTime? addedDate,
    String? seriesName,
    int? volumeNumber,
    String? nextVolumeIsbn,
    String? nextVolumeTitle,
    String? nextVolumeCover,
    bool? pendingSync,
    bool? isArchived,
    String? publisher,
    String? comicUniverse,
    String? apiSource,
    String? sourceUrl,
  }) {
    return Book(
      id: id ?? this.id,
      isbn: isbn ?? this.isbn,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      status: status ?? this.status,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      addedDate: addedDate ?? this.addedDate,
      seriesName: seriesName ?? this.seriesName,
      volumeNumber: volumeNumber ?? this.volumeNumber,
      nextVolumeIsbn: nextVolumeIsbn ?? this.nextVolumeIsbn,
      nextVolumeTitle: nextVolumeTitle ?? this.nextVolumeTitle,
      nextVolumeCover: nextVolumeCover ?? this.nextVolumeCover,
      pendingSync: pendingSync ?? this.pendingSync,
      isArchived: isArchived ?? this.isArchived,
      publisher: publisher ?? this.publisher,
      comicUniverse: comicUniverse ?? this.comicUniverse,
      apiSource: apiSource ?? this.apiSource,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isbn': isbn,
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'localCoverPath': localCoverPath,
      'status': status,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'addedDate': addedDate.toIso8601String(),
      'seriesName': seriesName,
      'volumeNumber': volumeNumber,
      'nextVolumeIsbn': nextVolumeIsbn,
      'nextVolumeTitle': nextVolumeTitle,
      'nextVolumeCover': nextVolumeCover,
      'pendingSync': pendingSync ? 1 : 0,
      'isArchived': isArchived ? 1 : 0,
      'publisher': publisher,
      'comicUniverse': comicUniverse,
      'apiSource': apiSource,
      'sourceUrl': sourceUrl,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as int?,
      isbn: map['isbn'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      coverUrl: map['coverUrl'] as String?,
      localCoverPath: map['localCoverPath'] as String?,
      status: map['status'] as String,
      currentPage: map['currentPage'] as int,
      totalPages: map['totalPages'] as int,
      addedDate: DateTime.parse(map['addedDate'] as String),
      seriesName: map['seriesName'] as String?,
      volumeNumber: map['volumeNumber'] as int?,
      nextVolumeIsbn: map['nextVolumeIsbn'] as String?,
      nextVolumeTitle: map['nextVolumeTitle'] as String?,
      nextVolumeCover: map['nextVolumeCover'] as String?,
      pendingSync: (map['pendingSync'] as int?) == 1,
      isArchived: (map['isArchived'] as int?) == 1,
      publisher: map['publisher'] as String?,
      comicUniverse: map['comicUniverse'] as String?,
      apiSource: map['apiSource'] as String?,
      sourceUrl: map['sourceUrl'] as String?,
    );
  }

  double get progress {
    if (totalPages == 0) return 0;
    return currentPage / totalPages;
  }

  bool get isFinished => status == 'finished';
  bool get isReading => status == 'reading';
  bool get isWishlist => status == 'wishlist';
  bool get isPartOfSeries => seriesName != null && seriesName!.isNotEmpty;
  bool get hasNextVolume => nextVolumeIsbn != null && nextVolumeIsbn!.isNotEmpty;
}
