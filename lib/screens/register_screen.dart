import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;
  bool _success = false;

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await _authService.register(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
    );

    setState(() {
      _loading = false;
      _error = error;
      _success = error == null;
    });

    if (_success && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text("Crear cuenta")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _buildField(_nameController, "Nombre completo", TextInputType.name, icon: Icons.person_outline),
            const SizedBox(height: 16),
            _buildField(_phoneController, "Número de teléfono", TextInputType.phone, icon: Icons.phone_outlined),
            const SizedBox(height: 16),
            _buildField(_passwordController, "Contraseña", TextInputType.text, obscure: true, icon: Icons.lock_outline),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 15, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
            if (_success)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text("¡Cuenta creada! Ya puedes iniciar sesión.", style: TextStyle(color: AppTheme.success, fontSize: 15, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.navy))
                  : const Text("Registrarme"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, TextInputType type, {bool obscure = false, IconData? icon}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.textDark, fontSize: 17),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
    );
  }
}
