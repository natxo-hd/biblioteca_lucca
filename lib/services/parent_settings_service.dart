import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ParentSettingsService {
  static const String _parentEmailKey = 'parent_email';
  static const String _parentNameKey = 'parent_name';
  static const String _setupCompleteKey = 'setup_complete';
  static const String _completedSeriesKey = 'completed_series';

  // Singleton
  static final ParentSettingsService _instance = ParentSettingsService._internal();
  factory ParentSettingsService() => _instance;
  ParentSettingsService._internal();

  SharedPreferences? _prefs;

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Verificar si la configuración inicial está completa
  Future<bool> isSetupComplete() async {
    await _ensureInitialized();
    return _prefs?.getBool(_setupCompleteKey) ?? false;
  }

  // Guardar email del padre
  Future<void> setParentEmail(String email) async {
    await _ensureInitialized();
    await _prefs?.setString(_parentEmailKey, email);
  }

  // Obtener email del padre
  Future<String?> getParentEmail() async {
    await _ensureInitialized();
    return _prefs?.getString(_parentEmailKey);
  }

  // Guardar nombre del padre
  Future<void> setParentName(String name) async {
    await _ensureInitialized();
    await _prefs?.setString(_parentNameKey, name);
  }

  // Obtener nombre del padre
  Future<String?> getParentName() async {
    await _ensureInitialized();
    return _prefs?.getString(_parentNameKey);
  }

  // Marcar configuración como completa
  Future<void> completeSetup() async {
    await _ensureInitialized();
    await _prefs?.setBool(_setupCompleteKey, true);
  }

  // Resetear configuración
  Future<void> resetSetup() async {
    await _ensureInitialized();
    await _prefs?.remove(_parentEmailKey);
    await _prefs?.remove(_parentNameKey);
    await _prefs?.setBool(_setupCompleteKey, false);
  }

  /// Envía un email solicitando un libro
  /// Retorna true si se pudo abrir el cliente de email
  Future<bool> sendBookRequestEmail({
    required String bookTitle,
    required String seriesName,
    required int volumeNumber,
    String? author,
  }) async {
    final email = await getParentEmail();
    final parentName = await getParentName();

    if (email == null || email.isEmpty) {
      return false;
    }

    final subject = Uri.encodeComponent('📚 Lucca quiere: $seriesName Vol. $volumeNumber');
    final body = Uri.encodeComponent(
      '¡Hola${parentName != null && parentName.isNotEmpty ? ' $parentName' : ''}! 👋\n\n'
      '¡He terminado de leer y me gustaría el siguiente libro de mi colección!\n\n'
      '📖 Serie: $seriesName\n'
      '📚 Volumen: $volumeNumber\n'
      '${author != null && author.isNotEmpty ? '✍️ Autor: $author\n' : ''}'
      '\n¡Gracias! 🎉\n\n'
      '- Lucca 📚',
    );

    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
    } catch (e) {
      // Error al abrir email
    }

    return false;
  }

  /// Verifica si hay un email configurado
  Future<bool> hasParentEmail() async {
    final email = await getParentEmail();
    return email != null && email.isNotEmpty;
  }

  // ============ SERIES COMPLETADAS ============

  /// Obtiene la lista de series marcadas como completas
  Future<Set<String>> getCompletedSeries() async {
    await _ensureInitialized();
    final list = _prefs?.getStringList(_completedSeriesKey) ?? [];
    return list.toSet();
  }

  /// Marca una serie como completa (no hay más volúmenes)
  Future<void> markSeriesAsComplete(String seriesName) async {
    await _ensureInitialized();
    final current = await getCompletedSeries();
    current.add(seriesName.toLowerCase());
    await _prefs?.setStringList(_completedSeriesKey, current.toList());
  }

  /// Desmarca una serie como completa
  Future<void> unmarkSeriesAsComplete(String seriesName) async {
    await _ensureInitialized();
    final current = await getCompletedSeries();
    current.remove(seriesName.toLowerCase());
    await _prefs?.setStringList(_completedSeriesKey, current.toList());
  }

  /// Verifica si una serie está marcada como completa
  Future<bool> isSeriesComplete(String seriesName) async {
    final completed = await getCompletedSeries();
    return completed.contains(seriesName.toLowerCase());
  }
}
