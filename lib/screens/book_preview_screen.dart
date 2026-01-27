import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../services/book_provider.dart';

class BookPreviewScreen extends StatelessWidget {
  final Book book;

  const BookPreviewScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libro encontrado'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Portada
            Container(
              height: 280,
              width: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: book.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: book.coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(height: 24),
            // Título
            Text(
              book.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Autor
            Text(
              book.author,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Info adicional
            if (book.totalPages > 0)
              Chip(
                avatar: const Icon(Icons.menu_book, size: 18),
                label: Text('${book.totalPages} páginas'),
              ),
            const SizedBox(height: 8),
            Chip(
              avatar: const Icon(Icons.qr_code, size: 18),
              label: Text('ISBN: ${book.isbn}'),
            ),
            const SizedBox(height: 32),
            // Botones
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _addBook(context, 'reading'),
                icon: const Icon(Icons.auto_stories),
                label: const Text('Añadir a Leyendo'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addBook(context, 'finished'),
                icon: const Icon(Icons.done_all),
                label: const Text('Añadir a Leídos'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: 60,
            color: Colors.grey[500],
          ),
          const SizedBox(height: 8),
          Text(
            'Sin portada',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addBook(BuildContext context, String status) async {
    final provider = context.read<BookProvider>();
    final bookToAdd = book.copyWith(status: status);

    final success = await provider.addBook(bookToAdd);

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${book.title} añadido a tu biblioteca'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este libro ya está en tu biblioteca'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
