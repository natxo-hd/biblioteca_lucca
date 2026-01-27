import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/comic_theme.dart';
import '../services/parent_settings_service.dart';
import '../services/auth_service.dart';
import '../services/book_provider.dart';
import '../services/export_service.dart';
import '../services/backup_service.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _parentSettings = ParentSettingsService();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final email = await _parentSettings.getParentEmail();
    final name = await _parentSettings.getParentName();

    if (mounted) {
      setState(() {
        _emailController.text = email ?? '';
        _nameController.text = name ?? '';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AJUSTES',
          style: GoogleFonts.bangers(
            fontSize: 24,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: ComicTheme.secondaryBlue,
        foregroundColor: Colors.white,
      ),
      body: MangaBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cuenta del usuario
                  _buildSection(
                    title: 'MI CUENTA',
                    icon: Icons.person,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ComicTheme.comicBorder, width: 2),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: user?.photoURL != null
                                ? NetworkImage(user!.photoURL!)
                                : null,
                            backgroundColor: ComicTheme.secondaryBlue,
                            child: user?.photoURL == null
                                ? const Icon(Icons.person, color: Colors.white, size: 30)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName ?? 'Usuario',
                                  style: GoogleFonts.bangers(
                                    fontSize: 20,
                                    color: ComicTheme.comicBorder,
                                  ),
                                ),
                                Text(
                                  user?.email ?? '',
                                  style: GoogleFonts.comicNeue(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Email del padre
                  _buildSection(
                    title: 'EMAIL DE PAPA/MAMA',
                    icon: Icons.mail,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Nombre',
                          hint: 'Papa, Mama...',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'ejemplo@gmail.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _saveSettings,
                            icon: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              'GUARDAR',
                              style: GoogleFonts.bangers(fontSize: 18),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ComicTheme.powerGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: ComicTheme.comicBorder,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Copia de seguridad completa
                  _buildBackupSection(),

                  const SizedBox(height: 24),

                  // Exportar/Importar biblioteca
                  _buildExportSection(),

                  const SizedBox(height: 24),

                  // Cerrar sesion
                  _buildSection(
                    title: 'SESION',
                    icon: Icons.logout,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: Text(
                          'CERRAR SESION',
                          style: GoogleFonts.bangers(fontSize: 18),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ComicTheme.heroRed,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(
                            color: ComicTheme.heroRed,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: ComicTheme.secondaryBlue, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.bangers(
                fontSize: 18,
                color: ComicTheme.comicBorder,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.comicNeue(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
        hintStyle: GoogleFonts.comicNeue(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: ComicTheme.secondaryBlue),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ComicTheme.comicBorder, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ComicTheme.comicBorder, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ComicTheme.secondaryBlue, width: 2),
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Escribe un email',
            style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
          ),
          backgroundColor: ComicTheme.heroRed,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _parentSettings.setParentName(_nameController.text.trim());
      await _parentSettings.setParentEmail(_emailController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Guardado!',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.powerGreen,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildBackupSection() {
    return _buildSection(
      title: 'COPIA DE SEGURIDAD',
      icon: Icons.backup,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ComicTheme.comicBorder, width: 2),
        ),
        child: Column(
          children: [
            Text(
              'Guarda TODO: libros, portadas y configuracion.\nIdeal para cambiar de movil.',
              textAlign: TextAlign.center,
              style: GoogleFonts.comicNeue(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _createBackup,
                    icon: const Icon(Icons.cloud_download, size: 20),
                    label: Text(
                      'CREAR',
                      style: GoogleFonts.bangers(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ComicTheme.powerGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _restoreBackup,
                    icon: const Icon(Icons.cloud_upload, size: 20),
                    label: Text(
                      'RESTAURAR',
                      style: GoogleFonts.bangers(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ComicTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createBackup() async {
    final provider = context.read<BookProvider>();
    final totalBooks = provider.readingBooks.length +
        provider.finishedBooks.length +
        provider.wishlistBooks.length +
        provider.archivedBooks.length;

    if (totalBooks == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay libros para guardar',
            style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
          ),
          backgroundColor: ComicTheme.primaryOrange,
        ),
      );
      return;
    }

    // Mostrar diálogo de progreso
    String currentStatus = 'Iniciando...';
    double currentProgress = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: ComicTheme.backgroundCream,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: currentProgress > 0 ? currentProgress : null,
                        color: ComicTheme.powerGreen,
                        strokeWidth: 4,
                      ),
                    ),
                    if (currentProgress > 0)
                      Text(
                        '${(currentProgress * 100).toInt()}%',
                        style: GoogleFonts.bangers(
                          fontSize: 16,
                          color: ComicTheme.comicBorder,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  currentStatus,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final backupService = BackupService();
      final filePath = await backupService.createBackup(
        onProgress: (status, progress) {
          currentStatus = status;
          currentProgress = progress;
          // Actualizar el diálogo
          if (mounted) {
            (context as Element).markNeedsBuild();
          }
        },
      );

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso

        // Preguntar si quiere compartir
        final share = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ComicTheme.backgroundCream,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
            ),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: ComicTheme.powerGreen, size: 28),
                const SizedBox(width: 8),
                Text(
                  'BACKUP CREADO',
                  style: GoogleFonts.bangers(
                    color: ComicTheme.powerGreen,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu copia de seguridad esta lista.',
                  style: GoogleFonts.comicNeue(
                    fontWeight: FontWeight.bold,
                    color: ComicTheme.comicBorder,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    filePath.split('/').last,
                    style: GoogleFonts.comicNeue(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '¿Quieres enviarla a Google Drive, email u otra app?',
                  style: GoogleFonts.comicNeue(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'NO, GRACIAS',
                  style: GoogleFonts.bangers(color: Colors.grey),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.share, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ComicTheme.secondaryBlue,
                ),
                label: Text(
                  'COMPARTIR',
                  style: GoogleFonts.bangers(color: Colors.white),
                ),
              ),
            ],
          ),
        );

        if (share == true) {
          await backupService.shareBackup(filePath);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.heroRed,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    // Confirmar restauración
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ComicTheme.backgroundCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
        ),
        title: Text(
          'RESTAURAR BACKUP',
          style: GoogleFonts.bangers(
            color: ComicTheme.primaryOrange,
            fontSize: 22,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona un archivo .zip de backup creado anteriormente.',
              style: GoogleFonts.comicNeue(
                fontWeight: FontWeight.bold,
                color: ComicTheme.comicBorder,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ComicTheme.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ComicTheme.primaryOrange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: ComicTheme.primaryOrange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los libros que ya existan no se duplicaran.',
                      style: GoogleFonts.comicNeue(
                        fontSize: 13,
                        color: ComicTheme.comicBorder,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.bangers(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.primaryOrange,
            ),
            child: Text(
              'SELECCIONAR',
              style: GoogleFonts.bangers(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Mostrar diálogo de progreso
    String currentStatus = 'Seleccionando archivo...';
    double currentProgress = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: ComicTheme.backgroundCream,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: currentProgress > 0 ? currentProgress : null,
                        color: ComicTheme.primaryOrange,
                        strokeWidth: 4,
                      ),
                    ),
                    if (currentProgress > 0)
                      Text(
                        '${(currentProgress * 100).toInt()}%',
                        style: GoogleFonts.bangers(
                          fontSize: 16,
                          color: ComicTheme.comicBorder,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  currentStatus,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final backupService = BackupService();
      final result = await backupService.restoreBackup(
        onProgress: (status, progress) {
          currentStatus = status;
          currentProgress = progress;
          if (mounted) {
            (context as Element).markNeedsBuild();
          }
        },
      );

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso

        // Recargar libros
        await context.read<BookProvider>().loadBooks();

        // Mostrar resultado
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ComicTheme.backgroundCream,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
            ),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: ComicTheme.powerGreen, size: 28),
                const SizedBox(width: 8),
                Text(
                  'RESTAURADO',
                  style: GoogleFonts.bangers(
                    color: ComicTheme.powerGreen,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRestoreResultRow(
                  icon: Icons.menu_book,
                  label: 'Libros restaurados',
                  value: '${result.booksRestored}',
                  color: ComicTheme.powerGreen,
                ),
                if (result.booksSkipped > 0)
                  _buildRestoreResultRow(
                    icon: Icons.skip_next,
                    label: 'Ya existian',
                    value: '${result.booksSkipped}',
                    color: Colors.grey,
                  ),
                _buildRestoreResultRow(
                  icon: Icons.image,
                  label: 'Portadas restauradas',
                  value: '${result.coversRestored}',
                  color: ComicTheme.secondaryBlue,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ComicTheme.powerGreen,
                ),
                child: Text(
                  'GENIAL',
                  style: GoogleFonts.bangers(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }
    } on BackupCancelledException {
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.heroRed,
          ),
        );
      }
    }
  }

  Widget _buildRestoreResultRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.comicNeue(
                fontWeight: FontWeight.bold,
                color: ComicTheme.comicBorder,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.bangers(
              fontSize: 20,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection() {
    return _buildSection(
      title: 'EXPORTAR / IMPORTAR',
      icon: Icons.sync_alt,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ComicTheme.comicBorder, width: 2),
        ),
        child: Column(
          children: [
            Text(
              'Guarda o restaura tu biblioteca',
              style: GoogleFonts.comicNeue(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Fila de exportar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportToCSV,
                    icon: const Icon(Icons.file_download, size: 20),
                    label: Text(
                      'CSV',
                      style: GoogleFonts.bangers(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ComicTheme.secondaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportToPDF,
                    icon: const Icon(Icons.picture_as_pdf, size: 20),
                    label: Text(
                      'PDF',
                      style: GoogleFonts.bangers(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ComicTheme.heroRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: ComicTheme.comicBorder, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Botón de importar
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _importFromCSV,
                icon: const Icon(Icons.file_upload, size: 20),
                label: Text(
                  'IMPORTAR CSV',
                  style: GoogleFonts.bangers(fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ComicTheme.powerGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: ComicTheme.powerGreen, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToCSV() async {
    final provider = context.read<BookProvider>();
    final allBooks = [
      ...provider.readingBooks,
      ...provider.finishedBooks,
      ...provider.wishlistBooks,
      ...provider.archivedBooks,
    ];

    if (allBooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay libros para exportar',
            style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
          ),
          backgroundColor: ComicTheme.primaryOrange,
        ),
      );
      return;
    }

    try {
      final exportService = ExportService();
      final filePath = await exportService.exportToCSV(allBooks);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Archivo guardado!',
                  style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                ),
                Text(
                  filePath,
                  style: GoogleFonts.comicNeue(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: ComicTheme.powerGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.heroRed,
          ),
        );
      }
    }
  }

  Future<void> _importFromCSV() async {
    // Confirmar importación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ComicTheme.backgroundCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
        ),
        title: Text(
          'IMPORTAR BIBLIOTECA',
          style: GoogleFonts.bangers(
            color: ComicTheme.powerGreen,
            fontSize: 22,
          ),
        ),
        content: Text(
          'Selecciona un archivo CSV exportado previamente.\n\nLos libros nuevos se añadirán a tu biblioteca. Los que ya existan se ignorarán.',
          style: GoogleFonts.comicNeue(
            fontWeight: FontWeight.bold,
            color: ComicTheme.comicBorder,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.bangers(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.powerGreen,
            ),
            child: Text(
              'SELECCIONAR',
              style: GoogleFonts.bangers(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final exportService = ExportService();
      final books = await exportService.importFromCSV();

      if (books == null) {
        // Usuario canceló la selección
        return;
      }

      if (books.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se encontraron libros en el archivo',
                style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
              ),
              backgroundColor: ComicTheme.primaryOrange,
            ),
          );
        }
        return;
      }

      // Añadir libros al provider
      final provider = context.read<BookProvider>();
      int imported = 0;
      int skipped = 0;

      for (final book in books) {
        final added = await provider.addBookIfNotExists(book);
        if (added) {
          imported++;
        } else {
          skipped++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Importados $imported libros! ($skipped ya existían)',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.powerGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.heroRed,
          ),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    final provider = context.read<BookProvider>();
    final allBooks = [
      ...provider.readingBooks,
      ...provider.finishedBooks,
      ...provider.wishlistBooks,
      ...provider.archivedBooks,
    ];

    if (allBooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay libros para exportar',
            style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
          ),
          backgroundColor: ComicTheme.primaryOrange,
        ),
      );
      return;
    }

    // Mostrar diálogo de progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ComicTheme.backgroundCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: ComicTheme.heroRed),
            const SizedBox(height: 16),
            Text(
              'Generando PDF...',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    try {
      final exportService = ExportService();
      final user = FirebaseAuth.instance.currentUser;
      final filePath = await exportService.exportToPDF(
        allBooks,
        userName: user?.displayName ?? 'Lucca',
      );

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡PDF guardado!',
                  style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
                ),
                Text(
                  filePath,
                  style: GoogleFonts.comicNeue(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: ComicTheme.powerGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de progreso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.comicNeue(fontWeight: FontWeight.bold),
            ),
            backgroundColor: ComicTheme.heroRed,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ComicTheme.backgroundCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ComicTheme.comicBorder, width: 3),
        ),
        title: Text(
          '¿CERRAR SESION?',
          style: GoogleFonts.bangers(
            color: ComicTheme.heroRed,
            fontSize: 22,
          ),
        ),
        content: Text(
          'Tendras que volver a iniciar sesion con Google.',
          style: GoogleFonts.comicNeue(
            fontWeight: FontWeight.bold,
            color: ComicTheme.comicBorder,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.bangers(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ComicTheme.heroRed,
            ),
            child: Text(
              'CERRAR',
              style: GoogleFonts.bangers(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthService>().signOut();
    }
  }
}
