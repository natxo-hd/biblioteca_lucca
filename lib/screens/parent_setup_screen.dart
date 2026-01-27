import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/comic_theme.dart';
import '../services/parent_settings_service.dart';

class ParentSetupScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const ParentSetupScreen({
    super.key,
    required this.onSetupComplete,
  });

  @override
  State<ParentSetupScreen> createState() => _ParentSetupScreenState();
}

class _ParentSetupScreenState extends State<ParentSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _parentSettings = ParentSettingsService();
  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ComicTheme.backgroundCream,
      body: MangaBackground(
        animate: false,
        child: SafeArea(
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Icono
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ComicTheme.secondaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ComicTheme.comicBorder,
                      width: 4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(4, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.family_restroom,
                    size: 60,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 24),

                // Titulo
                Text(
                  'CONFIGURAR PAPA/MAMA',
                  style: GoogleFonts.bangers(
                    fontSize: 28,
                    color: ComicTheme.comicBorder,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                Text(
                  'Para que puedas pedir libros nuevos',
                  style: GoogleFonts.comicNeue(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Campo nombre
                _buildInputField(
                  controller: _nameController,
                  label: 'Nombre de papa/mama',
                  hint: 'Ej: Papa, Mama, Natxo...',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Escribe un nombre';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Campo email
                _buildInputField(
                  controller: _emailController,
                  label: 'Email de papa/mama',
                  hint: 'ejemplo@gmail.com',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Escribe el email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Email no valido';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Explicacion
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ComicTheme.accentYellow.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ComicTheme.primaryOrange,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: ComicTheme.primaryOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cuando termines un libro y quieras el siguiente, le llegara un email automaticamente!',
                          style: GoogleFonts.comicNeue(
                            fontSize: 14,
                            color: ComicTheme.comicBorder,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Boton guardar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ComicTheme.powerGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                          color: ComicTheme.comicBorder,
                          width: 3,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'GUARDAR',
                            style: GoogleFonts.bangers(
                              fontSize: 24,
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.bangers(
            fontSize: 18,
            color: ComicTheme.comicBorder,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.comicNeue(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.comicNeue(
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
            prefixIcon: Icon(icon, color: ComicTheme.secondaryBlue),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: ComicTheme.comicBorder,
                width: 3,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: ComicTheme.comicBorder,
                width: 3,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: ComicTheme.secondaryBlue,
                width: 3,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: ComicTheme.heroRed,
                width: 3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await _parentSettings.setParentName(_nameController.text.trim());
      await _parentSettings.setParentEmail(_emailController.text.trim());
      await _parentSettings.completeSetup();

      widget.onSetupComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar. Intentalo de nuevo.',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.heroRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
