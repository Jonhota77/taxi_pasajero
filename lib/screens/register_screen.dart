import 'package:flutter/material.dart';
import '../services/auth_service.dart';

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
      backgroundColor: const Color(0xFF0F1B2B),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Crear cuenta",
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildField(_nameController, "Nombre completo", TextInputType.name),
            const SizedBox(height: 16),
            _buildField(_phoneController, "Número de teléfono", TextInputType.phone),
            const SizedBox(height: 16),
            _buildField(_passwordController, "Contraseña", TextInputType.text, obscure: true),
            const SizedBox(height: 24),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            if (_success) const Text("¡Cuenta creada! Ya puedes iniciar sesión.", style: TextStyle(color: Colors.greenAccent)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text("Registrarme", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
