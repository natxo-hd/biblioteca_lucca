import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/comic_theme.dart';
import '../services/book_provider.dart';
import '../config/api_keys.dart';

/// Sección que muestra el estado de las APIs de cómics configuradas
class ApiSettingsSection extends StatefulWidget {
  const ApiSettingsSection({super.key});

  @override
  State<ApiSettingsSection> createState() => _ApiSettingsSectionState();
}

class _ApiSettingsSectionState extends State<ApiSettingsSection> {
  bool _isTesting = false;
  Map<String, bool> _connectionStatus = {};

  Future<void> _testConnections() async {
    setState(() => _isTesting = true);

    try {
      final bookProvider = context.read<BookProvider>();
      final results = await bookProvider.testApiConnections();

      if (mounted) {
        setState(() {
          _connectionStatus = results;
        });
      }
    } catch (e) {
      debugPrint('Error probando conexiones: $e');
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  Widget _buildApiStatus({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String description,
    required bool isConfigured,
    String? connectionKey,
    bool isFree = false,
  }) {
    final isConnected = connectionKey != null
        ? _connectionStatus[connectionKey]
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConfigured ? ComicTheme.powerGreen : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.bangers(
                        fontSize: 16,
                        color: ComicTheme.comicBorder,
                      ),
                    ),
                    if (isFree) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ComicTheme.powerGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'GRATIS',
                          style: GoogleFonts.bangers(
                            fontSize: 9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  description,
                  style: GoogleFonts.comicNeue(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Status indicator
          if (isConnected != null)
            Icon(
              isConnected ? Icons.check_circle : Icons.error,
              color: isConnected ? ComicTheme.powerGreen : Colors.red,
              size: 20,
            )
          else
            Icon(
              isConfigured ? Icons.check_circle_outline : Icons.remove_circle_outline,
              color: isConfigured ? ComicTheme.powerGreen : Colors.grey,
              size: 20,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // APIs con claves configuradas
        _buildApiStatus(
          title: 'MARVEL API',
          icon: Icons.shield,
          iconColor: Colors.red,
          description: 'Cómics oficiales de Marvel',
          isConfigured: ApiKeys.hasMarvelKeys,
          connectionKey: 'marvel',
        ),

        _buildApiStatus(
          title: 'COMIC VINE',
          icon: Icons.menu_book,
          iconColor: Colors.blue,
          description: 'Marvel, DC, Image y más',
          isConfigured: ApiKeys.hasComicVineKey,
          connectionKey: 'comicVine',
        ),

        // APIs gratuitas
        _buildApiStatus(
          title: 'SUPERHERO API',
          icon: Icons.flash_on,
          iconColor: Colors.amber,
          description: 'Imágenes de personajes',
          isConfigured: true,
          connectionKey: 'superHero',
          isFree: true,
        ),

        _buildApiStatus(
          title: 'MANGADEX',
          icon: Icons.auto_stories,
          iconColor: Colors.orange,
          description: 'Manga japonés',
          isConfigured: true,
          isFree: true,
        ),

        _buildApiStatus(
          title: 'GOOGLE BOOKS',
          icon: Icons.local_library,
          iconColor: Colors.green,
          description: 'Libros generales',
          isConfigured: true,
          isFree: true,
        ),

        _buildApiStatus(
          title: 'CASA DEL LIBRO',
          icon: Icons.store,
          iconColor: Colors.purple,
          description: 'Portadas españolas',
          isConfigured: true,
          isFree: true,
        ),

        const SizedBox(height: 16),

        // Botón para probar conexiones
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isTesting ? null : _testConnections,
            icon: _isTesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.wifi_tethering, size: 18),
            label: Text(
              _isTesting ? 'PROBANDO...' : 'PROBAR CONEXIONES',
              style: GoogleFonts.bangers(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.secondaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
              ),
            ),
          ),
        ),

        // Nota sobre las APIs
        if (!ApiKeys.hasMarvelKeys || !ApiKeys.hasComicVineKey) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ComicTheme.accentYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ComicTheme.accentYellow, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: ComicTheme.primaryOrange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Las APIs de Marvel y Comic Vine no están configuradas. '
                    'La app usará las fuentes gratuitas.',
                    style: GoogleFonts.comicNeue(
                      fontSize: 12,
                      color: ComicTheme.comicBorder,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
