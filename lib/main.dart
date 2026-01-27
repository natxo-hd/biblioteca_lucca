import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/book_provider.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'services/parent_settings_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/parent_setup_screen.dart';
import 'theme/comic_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp();

  runApp(const BibliotecaLuccaApp());
}

class BibliotecaLuccaApp extends StatelessWidget {
  const BibliotecaLuccaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SyncService()),
        ChangeNotifierProxyProvider2<AuthService, SyncService, BookProvider>(
          create: (_) => BookProvider(),
          update: (_, authService, syncService, bookProvider) {
            bookProvider?.updateServices(authService, syncService);
            return bookProvider ?? BookProvider();
          },
        ),
      ],
      child: MaterialApp(
        title: 'Biblioteca de Lucca',
        debugShowCheckedModeBanner: false,
        theme: ComicTheme.lightTheme,
        darkTheme: ComicTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const AuthWrapper(),
      ),
    );
  }
}

// Widget que decide qué pantalla mostrar según el estado de autenticación
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final ParentSettingsService _parentSettings = ParentSettingsService();
  bool _checkingSetup = true;
  bool _setupComplete = false;

  @override
  void initState() {
    super.initState();
    _checkParentSetup();
  }

  Future<void> _checkParentSetup() async {
    final isComplete = await _parentSettings.isSetupComplete();
    if (mounted) {
      setState(() {
        _setupComplete = isComplete;
        _checkingSetup = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        // Mientras verifica configuración
        if (_checkingSetup) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Si no está logueado, mostrar Login
        if (!authService.isLoggedIn) {
          return const LoginScreen();
        }

        // Si está logueado pero no ha configurado el email del padre
        if (!_setupComplete) {
          return ParentSetupScreen(
            onSetupComplete: () {
              setState(() => _setupComplete = true);
            },
          );
        }

        // Todo listo, mostrar Home
        return const HomeScreen();
      },
    );
  }
}
