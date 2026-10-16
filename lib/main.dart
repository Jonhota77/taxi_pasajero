import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/service_selector_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const TaxiPasajeroApp());
}

class TaxiPasajeroApp extends StatelessWidget {
  const TaxiPasajeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bipy',
      debugShowCheckedModeBanner: false,
      // NUEVO: fuerza el idioma español en toda la app, incluyendo los
      // selectores de fecha/hora nativos de Flutter (que por defecto
      // salian en ingles).
      locale: const Locale('es', 'CO'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'CO'),
        Locale('es'),
      ],
      theme: AppTheme.light(),
      home: const _StartupGate(),
    );
  }
}

/// Decide si mostrar el mapa (si ya hay sesion guardada y valida) o el
/// login. NUEVO: ademas de revisar esto al abrir la app, ahora tambien
/// observa el ciclo de vida de la app (WidgetsBindingObserver) y
/// revalida la sesion contra el servidor cada vez que la app vuelve de
/// segundo plano -- si el token ya vencio, manda al usuario de vuelta
/// al login (limpiando toda la navegacion, sin importar en que pantalla
/// estaba) en vez de dejar que falle a medias al pedir un servicio.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> with WidgetsBindingObserver {
  final _authService = AuthService();
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _validateSessionOnResume();
    }
  }

  /// Revision inicial al abrir la app: si hay un token guardado,
  /// confirma que siga siendo valido antes de dejar entrar directo al
  /// mapa.
  Future<void> _check() async {
    final loggedIn = await _authService.isLoggedIn();
    bool valid = loggedIn;
    if (loggedIn) {
      valid = await _authService.validateToken();
      if (!valid) {
        await _authService.logout();
      }
    }
    if (!mounted) return;
    setState(() {
      _loggedIn = valid;
      _checking = false;
    });
  }

  /// Revalidacion cuando la app vuelve de segundo plano. Si el usuario
  /// ya esta en el login, no hay nada que revisar. Si estaba
  /// autenticado y el token ya no es valido, lo regresamos al login
  /// limpiando cualquier pantalla en la que estuviera navegando.
  Future<void> _validateSessionOnResume() async {
    if (!_loggedIn) return;

    final valid = await _authService.validateToken();
    if (!valid) {
      await _authService.logout();
      if (!mounted) return;

      setState(() {
        _loggedIn = false;
      });

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu sesión expiró. Inicia sesión de nuevo.'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppTheme.navy,
        body: Center(child: CircularProgressIndicator(color: AppTheme.yellow)),
      );
    }
    return _loggedIn ? const ServiceSelectorScreen() : const LoginScreen();
  }
}
