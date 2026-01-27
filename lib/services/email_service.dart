import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'parent_settings_service.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ParentSettingsService _parentSettings = ParentSettingsService();

  // Enviar pedido de libro por email usando Firebase Extension
  Future<bool> sendBookRequest({
    required String childName,
    required String bookTitle,
    required String author,
    String? coverUrl,
  }) async {
    try {
      final parentEmail = await _parentSettings.getParentEmail();
      final parentName = await _parentSettings.getParentName();

      if (parentEmail == null || parentEmail.isEmpty) {
        debugPrint('No hay email de padre configurado');
        return false;
      }

      // Guardar en colección 'mail' para Firebase Trigger Email Extension
      await _firestore.collection('mail').add({
        'to': parentEmail,
        'message': {
          'subject': '📚 $childName quiere: $bookTitle',
          'html': _buildEmailHtml(
            childName: childName,
            parentName: parentName ?? 'Papa/Mama',
            bookTitle: bookTitle,
            author: author,
            coverUrl: coverUrl,
          ),
          'text': 'Hola $parentName!\n\n$childName quiere el libro "$bookTitle" de $author.\n\nEnviado desde la Biblioteca de $childName',
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Email enviado a $parentEmail');
      return true;
    } catch (e) {
      debugPrint('Error enviando email: $e');
      return false;
    }
  }

  String _buildEmailHtml({
    required String childName,
    required String parentName,
    required String bookTitle,
    required String author,
    String? coverUrl,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Comic Sans MS', 'Chalkboard', cursive, sans-serif; background: #FFF8E7; margin: 0; padding: 20px; }
    .container { max-width: 500px; margin: 0 auto; background: white; border-radius: 20px; border: 4px solid #2D3047; box-shadow: 6px 6px 0 #2D3047; overflow: hidden; }
    .header { background: #4A90D9; color: white; padding: 20px; text-align: center; }
    .header h1 { margin: 0; font-size: 28px; }
    .content { padding: 24px; }
    .book-card { background: linear-gradient(135deg, #FFF3E0 0%, #FFE0B2 100%); border: 3px solid #FF6B35; border-radius: 16px; padding: 20px; text-align: center; margin: 16px 0; }
    .book-cover { max-height: 180px; border-radius: 8px; border: 2px solid #2D3047; margin-bottom: 12px; }
    .book-title { color: #2D3047; font-size: 22px; margin: 8px 0; font-weight: bold; }
    .book-author { color: #666; font-size: 16px; }
    .footer { background: #F5F5F5; padding: 16px; text-align: center; font-size: 12px; color: #888; }
    .emoji { font-size: 40px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="emoji">📚</div>
      <h1>¡Nuevo Pedido!</h1>
    </div>
    <div class="content">
      <p style="font-size: 18px;">¡Hola <strong>$parentName</strong>!</p>
      <p style="font-size: 16px;"><strong>$childName</strong> ha terminado un libro y quiere el siguiente:</p>
      <div class="book-card">
        ${coverUrl != null && coverUrl.isNotEmpty ? '<img src="$coverUrl" class="book-cover" alt="Portada" /><br/>' : '<div class="emoji">📖</div>'}
        <div class="book-title">$bookTitle</div>
        <div class="book-author">por $author</div>
      </div>
      <p style="text-align: center; font-size: 14px; color: #666;">
        ¡Sigue leyendo, campeón! 🌟
      </p>
    </div>
    <div class="footer">
      Enviado automáticamente desde la Biblioteca de $childName
    </div>
  </div>
</body>
</html>
''';
  }
}
