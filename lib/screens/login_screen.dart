import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';
import 'service_selector_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await _authService.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _loading = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ServiceSelectorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior naranja, igual al estilo de referencia.
            Container(
              width: double.infinity,
              color: AppTheme.primaryOrange,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  // NUEVO: logo real de Bipy, con tarjeta blanca detrás para
                  // que resalte bien sobre el naranja (el dorado del logo
                  // se perderia si quedara directo sobre este color).
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Image.asset("assets/images/logo_bipy.png", height: 70),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Muévete fácil, llega seguro",
                    style: TextStyle(color: Colors.white, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildField(_phoneController, "Número de teléfono", TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildField(_passwordController, "Contraseña", TextInputType.text, obscure: true),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.actionGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Ingresar", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text("¿No tienes cuenta? Regístrate", style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, TextInputType type, {bool obscure = false}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.cardBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryOrange)),
      ),
    );
  }
}
